"""Canal email (implémentation complète, utilisée en production)."""

import logging

from django.conf import settings
from django.core.mail import EmailMultiAlternatives

from .base import (
    STATUT_ECHEC,
    STATUT_ENVOYE,
    STATUT_IGNORE,
    CanalNotification,
    MessageNotification,
    ResultatEnvoi,
)

logger = logging.getLogger(__name__)


class CanalEmail(CanalNotification):
    """Envoi par email (HTML + repli texte), via le backend configuré.

    Le backend est celui de Django (``EMAIL_BACKEND``) : en développement il
    peut pointer vers la console, en production vers le SMTP.
    """

    nom = "email"

    def disponible(self) -> bool:
        # L'email est le canal de base : toujours disponible. L'absence
        # d'adresse chez le destinataire est traitée dans `envoyer`.
        return True

    def envoyer(
        self,
        message: MessageNotification,
        destinataire,
    ) -> ResultatEnvoi:
        adresse = (getattr(destinataire, "email", "") or "").strip()
        if not adresse:
            return ResultatEnvoi(
                self.nom, STATUT_IGNORE, "destinataire sans adresse email"
            )

        email = EmailMultiAlternatives(
            subject=message.sujet,
            body=message.texte,
            from_email=settings.DEFAULT_FROM_EMAIL,
            to=[adresse],
        )
        if message.html:
            email.attach_alternative(message.html, "text/html")

        try:
            email.send(fail_silently=False)
        except Exception as exc:  # SMTP/authentification : on rapporte l'échec
            # On ne journalise jamais le contenu du message (données
            # personnelles) : uniquement la cause technique.
            logger.warning("Échec d'envoi email vers %s : %s", adresse, exc)
            return ResultatEnvoi(self.nom, STATUT_ECHEC, str(exc)[:500])

        return ResultatEnvoi(self.nom, STATUT_ENVOYE)
