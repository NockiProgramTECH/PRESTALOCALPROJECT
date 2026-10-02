"""Canal WhatsApp — **squelette prêt à brancher**.

Le canal est déjà intégré au registre, au service et au journal : le jour où
l'API WhatsApp Business (ou un fournisseur type Twilio) est disponible, il
suffit d'implémenter :meth:`CanalWhatsApp.envoyer` et de renseigner
``NOTIFICATIONS_WHATSAPP_ENABLED=True`` (plus le jeton) dans l'environnement.

Aucun service métier ni vue n'a besoin d'être modifié : c'est l'intérêt de la
séparation « service (quoi) / canal (comment) ».
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


class CanalWhatsApp(CanalNotification):
    """Transport WhatsApp (à implémenter avec le fournisseur retenu)."""

    nom = "whatsapp"

    def disponible(self) -> bool:
        return bool(
            getattr(settings, "NOTIFICATIONS_WHATSAPP_ENABLED", False)
            and getattr(settings, "WHATSAPP_API_TOKEN", "")
        )

    def envoyer(
        self,
        message: MessageNotification,
        destinataire,
    ) -> ResultatEnvoi:
        if not self.disponible():
            return ResultatEnvoi(
                self.nom, STATUT_IGNORE, "canal WhatsApp non configuré"
            )

        numero = (getattr(destinataire, "telephone", "") or "").strip()
        if not numero:
            return ResultatEnvoi(
                self.nom, STATUT_IGNORE, "destinataire sans numéro de téléphone"
            )

        # Implémentation future : appel de l'API du fournisseur avec
        # `settings.WHATSAPP_API_URL` / `settings.WHATSAPP_API_TOKEN` et le
        # contenu `message.texte` (+ `message.url_action`). Tant que l'appel
        # n'est pas écrit, le canal reste inactif et ne bloque rien.
        logger.info(
            "Canal WhatsApp non implémenté : message « %s » non envoyé à %s",
            message.type,
            numero,
        )
        return ResultatEnvoi(
            self.nom, STATUT_IGNORE, "canal WhatsApp non implémenté"
        )
