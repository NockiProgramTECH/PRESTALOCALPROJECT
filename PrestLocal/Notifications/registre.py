"""Registre des canaux de notification.

Point d'entrée unique pour savoir **quels transports** sont actifs. Les
services métier ne construisent jamais un canal eux-mêmes : ils demandent la
liste au registre (inversion de dépendance) et peuvent en injecter une autre
dans les tests.

Ajouter un canal = une classe + une ligne dans :data:`CANAUX_DISPONIBLES`.
L'activer = une variable d'environnement (``NOTIFICATIONS_CHANNELS``).
"""

from django.conf import settings

from .channels.base import CanalNotification
from .channels.email import CanalEmail
from .channels.push import CanalPush
from .channels.whatsapp import CanalWhatsApp

#: Canaux connus du projet, indexés par leur nom de configuration.
CANAUX_DISPONIBLES: dict[str, type[CanalNotification]] = {
    CanalEmail.nom: CanalEmail,
    CanalWhatsApp.nom: CanalWhatsApp,
    CanalPush.nom: CanalPush,
}

#: Canaux utilisés par défaut tant que `NOTIFICATIONS_CHANNELS` n'est pas réglé.
CANAUX_PAR_DEFAUT: tuple[str, ...] = ("email",)


def noms_canaux_actifs() -> list[str]:
    """Noms des canaux demandés par la configuration."""
    return list(
        getattr(settings, "NOTIFICATIONS_CHANNELS", CANAUX_PAR_DEFAUT)
        or CANAUX_PAR_DEFAUT
    )


def canaux_actifs() -> list[CanalNotification]:
    """Instancie les canaux actifs (les noms inconnus sont ignorés)."""
    canaux = []
    for nom in noms_canaux_actifs():
        classe = CANAUX_DISPONIBLES.get(str(nom).strip().lower())
        if classe is None:
            continue
        canaux.append(classe())
    return canaux
