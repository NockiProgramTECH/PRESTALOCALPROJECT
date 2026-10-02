"""Services métier de relance d'abonnement (qui, quand, quel message ?).

Trois situations, un seul envoi par situation et par période :

- ``abonnement_expire_bientot`` : l'abonnement se termine dans N jours (N
  réglable) → « renouvelez pour rester en avant » ;
- ``abonnement_expire`` : l'abonnement est terminé → « réabonnez-vous pour
  rester visible et contactable » ;
- ``abonnement_jamais_souscrit`` : prestataire inscrit depuis quelques jours
  qui n'a jamais activé d'abonnement → « activez votre profil ».

Chaque message contient un **lien signé vers la page d'abonnement** de
l'utilisateur : la page reconnaît le prestataire (badge personnalisé) sans
ouvrir de faille d'authentification (le lien reste soumis à la connexion).
"""

from dataclasses import dataclass, field
from datetime import timedelta

from django.conf import settings
from django.core import signing
from django.db.models import Q
from django.urls import reverse
from django.utils import timezone

from Abonnement.models import Abonnement
from main.models import Prestataire

# Types de notification (utilisés par le journal et les statistiques).
TYPE_EXPIRATION_PROCHE = "abonnement_expire_bientot"
TYPE_EXPIRE = "abonnement_expire"
TYPE_JAMAIS_SOUSCRIT = "abonnement_jamais_souscrit"

#: Gabarit HTML unique des relances (le motif change le texte affiché).
TEMPLATE_RELANCE = "emails/abonnement_relance.html"

#: Sel du lien signé (change la signature si on le modifie).
SEL_REFERENCE = "relance-abonnement"


@dataclass
class CibleRelance:
    """Un prestataire à relancer, avec son motif et sa clé d'idempotence."""

    prestataire: Prestataire
    motif: str
    cle_unique: str
    abonnement: Abonnement | None = None
    jours_restants: int = 0


@dataclass
class RapportRelance:
    """Synthèse d'une campagne de relance."""

    cibles: int = 0
    envoyes: int = 0
    ignores: int = 0
    echecs: int = 0
    details: list[str] = field(default_factory=list)

    def ajouter_resultat(self, cible: CibleRelance, rapport_envoi) -> None:
        if rapport_envoi.envoye:
            self.envoyes += 1
        elif rapport_envoi.resultats and all(r.est_ignore for r in rapport_envoi.resultats):
            self.ignores += 1
        else:
            self.echecs += 1
        self.details.append(
            f"{cible.prestataire.email} [{cible.motif}] "
            f"{', '.join(rapport_envoi.details)}"
        )


# ---------------------------------------------------------------------------
# Lien vers l'abonnement du prestataire
# ---------------------------------------------------------------------------
def reference_relance(prestataire: Prestataire) -> str:
    """Jeton signé identifiant le prestataire (sans donnée sensible)."""
    return signing.dumps({"p": str(prestataire.pk)}, salt=SEL_REFERENCE, compress=True)


def prestataire_depuis_reference(reference: str):
    """Retrouve le prestataire d'un jeton de relance, ou ``None`` si invalide."""
    if not reference:
        return None
    age_max = getattr(settings, "RELANCE_LIEN_TTL_JOURS", 90) * 24 * 3600
    try:
        donnees = signing.loads(reference, salt=SEL_REFERENCE, max_age=age_max)
    except (signing.BadSignature, signing.SignatureExpired):
        return None
    return Prestataire.objects.filter(pk=donnees.get("p")).first()


def url_abonnement(prestataire: Prestataire, *, base_url: str = "") -> str:
    """URL absolue de l'espace d'abonnement du prestataire.

    Le lien identifie le prestataire dans l'URL **et** porte un jeton signé :
    la page vérifie que le compte connecté correspond avant d'afficher le
    message personnalisé (aucun droit supplémentaire n'est accordé).
    """
    base = (base_url or getattr(settings, "SITE_URL", "")).rstrip("/")
    chemin = reverse(
        "Abonnement:gestion", kwargs={"prestataire_id": prestataire.pk}
    )
    url = f"{chemin}?ref={reference_relance(prestataire)}"
    return f"{base}{url}" if base else url


# ---------------------------------------------------------------------------
# Sélection des destinataires (règles métier)
# ---------------------------------------------------------------------------
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


# ---------------------------------------------------------------------------
# Rédaction et envoi
# ---------------------------------------------------------------------------
def _contenu(cible: CibleRelance) -> tuple[str, str, str]:
    """Retourne ``(sujet, texte court, titre du mail)`` selon le motif."""
    prenom = cible.prestataire.first_name or "Bonjour"
    if cible.motif == TYPE_EXPIRATION_PROCHE:
        sujet = "Votre abonnement LesProduFao expire bientôt"
        titre = "Votre mise en avant se termine bientôt"
        texte = (
            f"{prenom}, votre abonnement se termine dans "
            f"{cible.jours_restants} jour(s). Renouvelez-le pour rester en avant "
            "dans les résultats de recherche."
        )
    elif cible.motif == TYPE_EXPIRE:
        sujet = "Réabonnez-vous pour rester visible sur LesProduFao"
        titre = "Votre profil n'est plus mis en avant"
        texte = (
            f"{prenom}, votre abonnement LesProduFao est terminé. Sans "
            "abonnement actif, votre profil n'est plus contactable : "
            "réabonnez-vous pour revenir en avant."
        )
    else:
        sujet = "Activez votre abonnement et soyez visible sur LesProduFao"
        titre = "Activez votre abonnement pour être trouvé"
        texte = (
            f"{prenom}, votre profil est prêt. Activez un abonnement pour "
            "apparaître en avant dans les recherches et recevoir des demandes."
        )
    return sujet, texte, titre


def relancer(cible: CibleRelance, *, canaux=None, base_url: str = "") -> RapportRelance:
    """Envoie la relance d'une cible via le service de notification."""
    from .service import envoyer_email  # import local : évite un cycle

    sujet, texte, titre = _contenu(cible)
    plan = cible.abonnement.plan.nom if cible.abonnement and cible.abonnement.plan else ""
    rapport = envoyer_email(
        cible.prestataire,
        sujet=sujet,
        texte=texte,
        template=TEMPLATE_RELANCE,
        contexte={
            "user": cible.prestataire,
            "titre": titre,
            "motif": cible.motif,
            "message_texte": texte,
            "plan": plan,
            "date_fin": cible.abonnement.date_fin if cible.abonnement else None,
            "jours_restants": cible.jours_restants,
            "url_abonnement": url_abonnement(cible.prestataire, base_url=base_url),
            "site_url": (base_url or getattr(settings, "SITE_URL", "")).rstrip("/"),
        },
        url_action=url_abonnement(cible.prestataire, base_url=base_url),
        type_notification=cible.motif,
        cle_unique=cible.cle_unique,
    )
    resultat = RapportRelance(cibles=1)
    resultat.ajouter_resultat(cible, rapport)
    return resultat
