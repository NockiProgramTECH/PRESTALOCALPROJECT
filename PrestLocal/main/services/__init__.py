"""Services métier du domaine « main » (comptes, avis, favoris, prestataires).

Un service = une opération métier nommée, avec des dépendances explicites, un
résultat compréhensible et, si nécessaire, des exceptions métier. Ils ne
connaissent ni `request`, ni `HttpResponse` : les vues web et l'API les
appellent de la même façon, et les tests aussi.

Contrat public — importer depuis ce paquet plutôt que depuis les modules :
``from main.services import soumettre_avis``.
"""

from .avis import (
    AvisDejaDonne,
    AvisInvalide,
    NoteHorsBornes,
    notifier_nouvel_avis,
    soumettre_avis,
    statistiques_avis,
)
from .comptes import (
    CodeInvalide,
    EnvoiCodeImpossible,
    activer_compte,
    demarrer_inscription,
    demander_reinitialisation,
    envoyer_invitation_abonnement,
    reinitialiser_mot_de_passe,
)
from .favoris import basculer_favori
from .prestataires import (
    enregistrer_clic,
    enregistrer_vue_profil,
    definir_disponibilite,
)

__all__ = [
    'AvisDejaDonne',
    'AvisInvalide',
    'NoteHorsBornes',
    'CodeInvalide',
    'EnvoiCodeImpossible',
    'activer_compte',
    'basculer_favori',
    'demarrer_inscription',
    'demander_reinitialisation',
    'definir_disponibilite',
    'enregistrer_clic',
    'enregistrer_vue_profil',
    'envoyer_invitation_abonnement',
    'notifier_nouvel_avis',
    'reinitialiser_mot_de_passe',
    'soumettre_avis',
    'statistiques_avis',
]
