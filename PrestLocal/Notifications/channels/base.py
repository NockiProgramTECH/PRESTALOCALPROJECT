"""Contrats communs à tous les canaux de notification.

Un **canal** est un transport : il sait seulement acheminer un message vers un
destinataire (email, WhatsApp, notification push…). Il ne connaît ni le métier
ni les règles de relance : cette séparation permet d'ajouter un canal sans
toucher aux services métier ni aux vues.

Pour ajouter un canal plus tard :

1. créer une classe héritant de :class:`CanalNotification` dans ce dossier ;
2. l'enregistrer dans ``Notifications/registre.py`` ;
3. l'activer par configuration (``NOTIFICATIONS_CHANNELS``).

Aucun autre code n'a besoin d'être modifié (principe ouvert/fermé).
"""

from abc import ABC, abstractmethod
from dataclasses import dataclass, field

# Statuts possibles d'un envoi (utilisés aussi par le journal en base).
STATUT_ENVOYE = "envoye"
STATUT_IGNORE = "ignore"
STATUT_ECHEC = "echec"


@dataclass(frozen=True)
class MessageNotification:
    """Contenu **neutre** d'une notification, indépendant du canal.

    - ``type`` : identifiant métier (``abonnement_expire``, ``code_verification``…)
      utilisé pour la journalisation et les statistiques ;
    - ``sujet`` : objet de l'email / titre de la notification push ;
    - ``texte`` : version courte, utilisable par tous les canaux (WhatsApp, SMS) ;
    - ``html`` : version riche optionnelle (email uniquement) ;
    - ``url_action`` : lien d'action (bouton du mail, deep link du push).
    """

    type: str
    sujet: str
    texte: str
    html: str = ""
    url_action: str = ""
    contexte: dict = field(default_factory=dict)


@dataclass(frozen=True)
class ResultatEnvoi:
    """Résultat d'une tentative d'envoi sur un canal donné."""

    canal: str
    statut: str
    detail: str = ""

    @property
    def est_envoye(self) -> bool:
        return self.statut == STATUT_ENVOYE

    @property
    def est_ignore(self) -> bool:
        return self.statut == STATUT_IGNORE


class CanalNotification(ABC):
    """Transport d'une notification vers un destinataire.

    Un canal doit être **sans effet de bord métier** : il ne décide jamais
    d'envoyer ou non (c'est le rôle des services), il se contente de transporter
    le message et de rapporter ce qui s'est passé.
    """

    nom: str = ""

    @abstractmethod
    def disponible(self) -> bool:
        """Le canal est-il configuré et utilisable dans cet environnement ?"""

    @abstractmethod
    def envoyer(
        self,
        message: MessageNotification,
        destinataire,
    ) -> ResultatEnvoi:
        """Achemine ``message`` vers ``destinataire``.

        Ne lève pas d'exception métier : retourne un :class:`ResultatEnvoi`
        (``envoye``, ``ignore`` ou ``echec``) pour que l'appelant décide.
        """
