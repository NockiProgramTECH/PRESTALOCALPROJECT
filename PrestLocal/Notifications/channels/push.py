"""Canal notification push (FCM / OneSignal) — **squelette prêt à brancher**.

Même principe que le canal WhatsApp : le canal est déjà connu du service et du
journal. Pour l'activer plus tard :

1. stocker les jetons d'appareil (ex. modèle ``Appareil`` avec ``user`` +
   ``token`` + ``plateforme``) ;
2. implémenter :meth:`CanalPush.envoyer` (appel FCM/OneSignal, suppression des
   jetons invalides) ;
3. renseigner ``NOTIFICATIONS_PUSH_ENABLED=True`` et l'ajouter à
   ``NOTIFICATIONS_CHANNELS``.
"""

import logging

from django.conf import settings

from .base import (
    STATUT_IGNORE,
    CanalNotification,
    MessageNotification,
    ResultatEnvoi,
)

logger = logging.getLogger(__name__)


class CanalPush(CanalNotification):
    """Transport push (application mobile)."""

    nom = "push"

    def disponible(self) -> bool:
        return bool(
            getattr(settings, "NOTIFICATIONS_PUSH_ENABLED", False)
            and getattr(settings, "PUSH_API_KEY", "")
        )

    def envoyer(
        self,
        message: MessageNotification,
        destinataire,
    ) -> ResultatEnvoi:
        if not self.disponible():
            return ResultatEnvoi(self.nom, STATUT_IGNORE, "canal push non configuré")

        # Aucun jeton d'appareil n'est encore stocké côté backend : le canal
        # rapporte explicitement pourquoi il n'envoie rien (pas d'échec).
        jetons = getattr(destinataire, "jetons_push", None)
        if not jetons:
            return ResultatEnvoi(
                self.nom, STATUT_IGNORE, "aucun appareil enregistré"
            )

        logger.info(
            "Canal push non implémenté : message « %s » non envoyé", message.type
        )
        return ResultatEnvoi(self.nom, STATUT_IGNORE, "canal push non implémenté")
