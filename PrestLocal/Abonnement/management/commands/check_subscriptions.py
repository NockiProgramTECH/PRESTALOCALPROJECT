"""Ancienne commande de rappel — conservée comme alias.

La logique a été déplacée dans les services (`Notifications/abonnement.py`) et
le worker (`Notifications/tasks.py`), puis étendue aux abonnements **expirés**
et aux prestataires **jamais abonnés**. Cette commande est conservée pour ne
pas casser une planification existante (cron, documentation, hébergeur) : elle
délègue à la nouvelle commande.

Préférer désormais :

.. code-block:: bash

    python manage.py relancer_abonnements
"""

import logging

from django.core.management.base import BaseCommand

from Notifications.registre import canaux_actifs
from Notifications.tasks import executer_relances_abonnement

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = (
        "DÉPRÉCIÉ : alias de « relancer_abonnements ». Relance les "
        "prestataires dont l'abonnement arrive à expiration, est expiré, ou "
        "qui ne se sont jamais abonnés."
    )

    def handle(self, *args, **options):
        self.stdout.write(
            self.style.WARNING(
                "« check_subscriptions » est dépréciée : utilisez "
                "« python manage.py relancer_abonnements » (mêmes garanties, "
                "relances plus complètes)."
            )
        )
        rapport = executer_relances_abonnement(canaux=canaux_actifs())
        for ligne in rapport.details:
            self.stdout.write(f"  - {ligne}")
        self.stdout.write(
            self.style.SUCCESS(
                f"Relances : {rapport.cibles} cible(s), {rapport.envoyes} envoyée(s), "
                f"{rapport.ignores} ignorée(s), {rapport.echecs} échec(s)."
            )
        )
