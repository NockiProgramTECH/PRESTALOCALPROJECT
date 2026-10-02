"""Relances d'abonnement : qui relancer, avec quel message, par quel canal.

Le paquet remplace l'ancien module `Notifications/abonnement.py` (260 lignes) :

- :mod:`~Notifications.abonnement.types`   — constantes et structures (`CibleRelance`, `RapportRelance`) ;
- :mod:`~Notifications.abonnement.liens`   — jetons signés et URL d'abonnement ;
- :mod:`~Notifications.abonnement.cibles`  — sélection des destinataires ;
- :mod:`~Notifications.abonnement.envoi`   — rédaction et envoi.

Le contrat public est inchangé : `from Notifications.abonnement import
cibles_relance, relancer, url_abonnement` continue de fonctionner (les vues, le
worker et les tests ne sont pas modifiés).
"""

from .cibles import (
    abonnements_expirant_bientot,
    abonnements_expires,
    cibles_relance,
    prestataires_sans_abonnement,
)
from .envoi import relancer
from .liens import prestataire_depuis_reference, reference_relance, url_abonnement
from .types import (
    SEL_REFERENCE,
    TEMPLATE_RELANCE,
    TYPE_EXPIRE,
    TYPE_EXPIRATION_PROCHE,
    TYPE_JAMAIS_SOUSCRIT,
    CibleRelance,
    RapportRelance,
)

__all__ = [
    'CibleRelance',
    'RapportRelance',
    'SEL_REFERENCE',
    'TEMPLATE_RELANCE',
    'TYPE_EXPIRE',
    'TYPE_EXPIRATION_PROCHE',
    'TYPE_JAMAIS_SOUSCRIT',
    'abonnements_expirant_bientot',
    'abonnements_expires',
    'cibles_relance',
    'prestataire_depuis_reference',
    'prestataires_sans_abonnement',
    'reference_relance',
    'relancer',
    'url_abonnement',
]
