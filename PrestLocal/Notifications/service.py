"""Service d'envoi de notifications (orchestration, journalisation).

Ce module est la **façade unique** utilisée par le reste du projet pour
envoyer quelque chose à un utilisateur :

.. code-block:: python

    from Notifications.service import envoyer_email

    envoyer_email(
        prestataire,
        sujet="Votre abonnement expire bientôt",
        template="emails/abonnement_relance.html",
        contexte={"user": prestataire, "url_abonnement": ...},
        texte="Bonjour …, renouvelez votre abonnement.",
        type_notification="abonnement_expire_bientot",
        cle_unique="expire-bientot:12:2026-10-09",
    )

Responsabilités séparées :

- le **service métier** (``Notifications/abonnement.py``) décide *qui* relancer,
  *quand* et *avec quel contenu* ;
- le **service d'envoi** (ce module) exécute la diffusion sur les canaux actifs
  et journalise le résultat ;
- les **canaux** (``channels/``) ne font que transporter.

Aucun échec d'envoi ne remonte en exception : un prestataire injoignable par
email ne doit pas interrompre une campagne de relance.
"""

import logging
from dataclasses import dataclass, field

from django.db import IntegrityError, transaction

from .channels.base import MessageNotification, ResultatEnvoi
from .models import JournalNotification
from .registre import canaux_actifs

logger = logging.getLogger(__name__)


@dataclass
class RapportEnvoi:
    """Synthèse d'un envoi (un message, éventuellement plusieurs canaux)."""

    resultats: list[ResultatEnvoi] = field(default_factory=list)

    @property
    def envoye(self) -> bool:
        return any(r.est_envoye for r in self.resultats)

    @property
    def details(self) -> list[str]:
        return [f"{r.canal}:{r.statut}" for r in self.resultats]


class ServiceNotification:
    """Diffuse un message sur les canaux actifs et journalise le résultat.

    :param canaux: canaux à utiliser. Par défaut, ceux de la configuration
        (``NOTIFICATIONS_CHANNELS``). L'injection permet de tester le service
        sans réseau ni SMTP.
    """

    def __init__(self, canaux=None):
        self._canaux = list(canaux) if canaux is not None else canaux_actifs()

    @property
    def canaux(self):
        return list(self._canaux)

    def envoyer(
        self,
        destinataire,
        message: MessageNotification,
        *,
        cle_unique: str = "",
        canaux=None,
    ) -> RapportEnvoi:
        """Envoie ``message`` et retourne le rapport détaillé par canal."""
        rapport = RapportEnvoi()
        for canal in canaux or self._canaux:
            resultat = self._envoyer_sur(canal, message, destinataire, cle_unique)
            rapport.resultats.append(resultat)
            self._journaliser(destinataire, message, resultat, cle_unique)
        return rapport

    # ---- Implémentation --------------------------------------------------

    def _envoyer_sur(self, canal, message, destinataire, cle_unique) -> ResultatEnvoi:
        if cle_unique and self._deja_envoye(canal.nom, cle_unique):
            return ResultatEnvoi(canal.nom, "ignore", "déjà envoyé")
        if not canal.disponible():
            return ResultatEnvoi(canal.nom, "ignore", "canal indisponible")
        return canal.envoyer(message, destinataire)

    @staticmethod
    def _deja_envoye(canal: str, cle_unique: str) -> bool:
        return JournalNotification.objects.filter(
            canal=canal, cle_unique=cle_unique
        ).exists()

    @staticmethod
    def _journaliser(destinataire, message, resultat, cle_unique) -> None:
        """Enregistre la tentative ; une clé déjà prise est considérée dédupliquée."""
        try:
            with transaction.atomic():
                JournalNotification.objects.create(
                    destinataire=destinataire,
                    type_notification=message.type,
                    canal=resultat.canal,
                    statut=resultat.statut,
                    detail=resultat.detail[:500],
                    cle_unique=cle_unique,
                )
        except IntegrityError:
            # Deux exécutions simultanées avec la même clé : la seconde est un
            # doublon, ce n'est pas une erreur (idempotence).
            logger.info(
                "Notification déjà journalisée pour la clé %s (canal %s)",
                cle_unique,
                resultat.canal,
            )


# ---------------------------------------------------------------------------
# Raccourcis utilisés par les vues et les sérialiseurs existants
# ---------------------------------------------------------------------------
def envoyer_notification(
    destinataire,
    *,
    type_notification: str,
    sujet: str,
    texte: str,
    html: str = "",
    url_action: str = "",
    contexte: dict | None = None,
    cle_unique: str = "",
    canaux=None,
) -> RapportEnvoi:
    """Envoie une notification déjà rédigée (contenu fourni par l'appelant)."""
    message = MessageNotification(
        type=type_notification,
        sujet=sujet,
        texte=texte,
        html=html,
        url_action=url_action,
        contexte=contexte or {},
    )
    return ServiceNotification(canaux=canaux).envoyer(
        destinataire, message, cle_unique=cle_unique
    )


def envoyer_email(
    destinataire,
    *,
    sujet: str,
    texte: str,
    template: str = "",
    contexte: dict | None = None,
    url_action: str = "",
    type_notification: str = "system",
    cle_unique: str = "",
) -> RapportEnvoi:
    """Raccourci email : rend le gabarit HTML puis délègue au service.

    Remplace les envois directs ``EmailMultiAlternatives`` qui étaient
    dupliqués dans les vues : le rendu du gabarit, l'expéditeur et la
    journalisation sont centralisés ici.
    """
    from django.template.loader import render_to_string

    html = (
        render_to_string(template, contexte or {}) if template else ""
    )
    return envoyer_notification(
        destinataire,
        type_notification=type_notification,
        sujet=sujet,
        texte=texte,
        html=html,
        url_action=url_action,
        contexte=contexte,
        cle_unique=cle_unique,
    )
