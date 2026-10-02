"""Socle commun des tests de notifications : canal factice et fabrique de comptes."""

from Notifications.channels.base import (
    STATUT_ENVOYE,
    CanalNotification,
    ResultatEnvoi,
)
from main.models import Prestataire


EMAIL_LOCMEM = 'django.core.mail.backends.locmem.EmailBackend'


class CanalEnregistreur(CanalNotification):
    """Canal de test : capture les messages au lieu de les transporter."""

    nom = "test"

    def __init__(self, disponible=True):
        self._disponible = disponible
        self.messages = []

    def disponible(self):
        return self._disponible

    def envoyer(self, message, destinataire):
        self.messages.append((destinataire, message))
        return ResultatEnvoi(self.nom, STATUT_ENVOYE)


def creer_prestataire(email="artisan@lesprodufao.bf", **extra):
    return Prestataire.objects.create_user(
        email=email,
        password="MotDePasse123",
        first_name="Awa",
        last_name="Ouédraogo",
        role=Prestataire.ROLE_PRESTATAIRE,
        **extra,
    )
