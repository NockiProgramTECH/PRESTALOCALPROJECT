"""Rédaction et envoi d'une relance.

Le texte dépend du motif (`_contenu`) ; l'envoi passe par la façade
`Notifications.service.envoyer_email`, donc par les canaux configurés et la
journalisation d'idempotence.
"""

from django.conf import settings

from .liens import url_abonnement
from .types import (
    TEMPLATE_RELANCE,
    TYPE_EXPIRE,
    TYPE_EXPIRATION_PROCHE,
    CibleRelance,
    RapportRelance,
)


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
    from ..service import envoyer_email  # import local : évite un cycle

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
