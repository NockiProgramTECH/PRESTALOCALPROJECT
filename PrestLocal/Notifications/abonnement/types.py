"""Types partagés des relances d'abonnement : constantes et structures.

Aucune requête, aucun envoi : uniquement le vocabulaire du domaine, importable
par la sélection (`cibles.py`), la rédaction (`envoi.py`) et les tests.
"""

from dataclasses import dataclass, field

from Abonnement.models import Abonnement
from main.models import Prestataire

TYPE_EXPIRATION_PROCHE = "abonnement_expire_bientot"
TYPE_EXPIRE = "abonnement_expire"
TYPE_JAMAIS_SOUSCRIT = "abonnement_jamais_souscrit"

#: Gabarit HTML unique des relances (le motif change le texte affiché).
TEMPLATE_RELANCE = "emails/abonnement_relance.html"

#: Sel du lien signé (change la signature si on le modifie).
SEL_REFERENCE = "relance-abonnement"


@dataclass
class CibleRelance:
    """Un prestataire à relancer, avec son motif et sa clé d'idempotence."""

    prestataire: Prestataire
    motif: str
    cle_unique: str
    abonnement: Abonnement | None = None
    jours_restants: int = 0


@dataclass
class RapportRelance:
    """Synthèse d'une campagne de relance."""

    cibles: int = 0
    envoyes: int = 0
    ignores: int = 0
    echecs: int = 0
    details: list[str] = field(default_factory=list)

    def ajouter_resultat(self, cible: CibleRelance, rapport_envoi) -> None:
        if rapport_envoi.envoye:
            self.envoyes += 1
        elif rapport_envoi.resultats and all(r.est_ignore for r in rapport_envoi.resultats):
            self.ignores += 1
        else:
            self.echecs += 1
        self.details.append(
            f"{cible.prestataire.email} [{cible.motif}] "
            f"{', '.join(rapport_envoi.details)}"
        )
