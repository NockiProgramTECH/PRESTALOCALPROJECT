"""Tâches planifiées de notification (workers).

Un worker **orchestre** : il décide quand exécuter, itère sur les cibles,
isole les erreurs et produit un rapport. Il ne rédige pas les messages et
n'accède pas aux modèles d'abonnement : ce travail appartient aux services
(``Notifications/abonnement.py``).

Le projet n'embarque pas de file de tâches (pas de Celery) : ces fonctions sont
appelées par les commandes de gestion, elles-mêmes déclenchées par un cron (ou
un « job » planifié côté hébergeur). Le jour où une file de tâches est
introduite, seule la commande change : le worker reste identique.
"""

import logging
from django.conf import settings

from .abonnement import RapportRelance, cibles_relance, relancer

logger = logging.getLogger(__name__)


def executer_relances_abonnement(
    *,
    jours_avant_expiration: int | None = None,
    delai_sans_abonnement: int | None = None,
    canaux=None,
    simulation: bool = False,
) -> RapportRelance:
    """Relance les prestataires concernés et retourne le rapport global.

    :param jours_avant_expiration: délai (jours) du rappel « expire bientôt » ;
        par défaut ``RELANCE_ABONNEMENT_JOURS_AVANT``.
    :param delai_sans_abonnement: ancienneté minimale des prestataires jamais
        abonnés avant de les relancer ; par défaut
        ``RELANCE_SANS_ABONNEMENT_DELAI_JOURS``.
    :param canaux: canaux d'envoi (tests) ; par défaut la configuration.
    :param simulation: ``True`` = ne rien envoyer, seulement lister les cibles.
    """
    jours = (
        jours_avant_expiration
        if jours_avant_expiration is not None
        else getattr(settings, "RELANCE_ABONNEMENT_JOURS_AVANT", 7)
    )
    delai = (
        delai_sans_abonnement
        if delai_sans_abonnement is not None
        else getattr(settings, "RELANCE_SANS_ABONNEMENT_DELAI_JOURS", 3)
    )

    rapport = RapportRelance()
    for cible in cibles_relance(
        jours_avant_expiration=jours, delai_sans_abonnement=delai
    ):
        rapport.cibles += 1
        if simulation:
            rapport.details.append(
                f"[simulation] {cible.prestataire.email} [{cible.motif}] "
                f"clé={cible.cle_unique}"
            )
            continue
        try:
            resultat = relancer(cible, canaux=canaux)
        except Exception:
            # Une cible en erreur ne doit jamais interrompre la campagne.
            logger.exception(
                "Relance d'abonnement impossible pour %s", cible.prestataire_id
            )
            rapport.echecs += 1
            rapport.details.append(
                f"{cible.prestataire.email} [{cible.motif}] exception"
            )
            continue
        rapport.envoyes += resultat.envoyes
        rapport.ignores += resultat.ignores
        rapport.echecs += resultat.echecs
        rapport.details.extend(resultat.details)

    logger.info(
        "Relances d'abonnement : %s cible(s), %s envoyée(s), %s ignorée(s), "
        "%s échec(s)",
        rapport.cibles,
        rapport.envoyes,
        rapport.ignores,
        rapport.echecs,
    )
    return rapport
