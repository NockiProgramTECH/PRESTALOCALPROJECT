"""Sélection des destinataires d'une campagne de relance.

Trois populations, une requête chacune, toutes préchargées (`select_related`) :

- abonnement qui expire bientôt ;
- abonnement expiré, désactivé ou impayé ;
- prestataire actif jamais abonné depuis N jours.

`cibles_relance()` les rassemble et fournit à chacune une **clé d'idempotence**
(un envoi par situation et par période).
"""

from datetime import timedelta

from django.db.models import Q
from django.utils import timezone

from Abonnement.models import Abonnement
from main.models import Prestataire

from .types import (
    TYPE_EXPIRE,
    TYPE_EXPIRATION_PROCHE,
    TYPE_JAMAIS_SOUSCRIT,
    CibleRelance,
)


def abonnements_expirant_bientot(jours: int) -> list[Abonnement]:
    """Abonnements encore valides qui se terminent dans ``jours`` jours."""
    maintenant = timezone.now()
    return list(
        Abonnement.objects.select_related("prestataire", "plan")
        .filter(
            est_actif=True,
            paye=True,
            date_fin__gt=maintenant,
            date_fin__lte=maintenant + timedelta(days=jours),
        )
        .order_by("date_fin")
    )


def abonnements_expires() -> list[Abonnement]:
    """Abonnements qui ne donnent plus accès à la mise en avant."""
    maintenant = timezone.now()
    return list(
        Abonnement.objects.select_related("prestataire", "plan")
        .filter(
            Q(date_fin__lte=maintenant) | Q(est_actif=False) | Q(paye=False)
        )
        .order_by("-date_fin")
    )


def prestataires_sans_abonnement(delai_jours: int) -> list[Prestataire]:
    """Prestataires actifs, inscrits depuis ``delai_jours``, jamais abonnés."""
    limite = timezone.now() - timedelta(days=delai_jours)
    return list(
        Prestataire.objects.filter(
            role=Prestataire.ROLE_PRESTATAIRE,
            is_active=True,
            date_inscription__lte=limite,
            abonnement__isnull=True,
        ).order_by("date_inscription")
    )


def cibles_relance(
    *,
    jours_avant_expiration: int = 7,
    delai_sans_abonnement: int = 3,
) -> list[CibleRelance]:
    """Construit la liste des prestataires à relancer, tous motifs confondus."""
    cibles: list[CibleRelance] = []

    for abonnement in abonnements_expirant_bientot(jours_avant_expiration):
        cibles.append(
            CibleRelance(
                prestataire=abonnement.prestataire,
                motif=TYPE_EXPIRATION_PROCHE,
                abonnement=abonnement,
                jours_restants=abonnement.jours_restants,
                cle_unique=(
                    f"expire-bientot:{abonnement.pk}:"
                    f"{abonnement.date_fin:%Y-%m-%d}"
                ),
            )
        )

    for abonnement in abonnements_expires():
        if abonnement.prestataire_id is None:
            continue
        cibles.append(
            CibleRelance(
                prestataire=abonnement.prestataire,
                motif=TYPE_EXPIRE,
                abonnement=abonnement,
                cle_unique=f"expire:{abonnement.pk}:{abonnement.date_fin:%Y-%m-%d}",
            )
        )

    mois = timezone.now().strftime("%Y-%m")
    for prestataire in prestataires_sans_abonnement(delai_sans_abonnement):
        cibles.append(
            CibleRelance(
                prestataire=prestataire,
                motif=TYPE_JAMAIS_SOUSCRIT,
                cle_unique=f"sans-abonnement:{prestataire.pk}:{mois}",
            )
        )

    return cibles
