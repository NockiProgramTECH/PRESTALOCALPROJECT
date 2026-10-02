"""Commande planifiée : relance des prestataires pour leur abonnement.

Exemples :

.. code-block:: bash

    python manage.py relancer_abonnements --simulation
    python manage.py relancer_abonnements                  # email (défaut)
    python manage.py relancer_abonnements --canal email --canal whatsapp

À planifier une fois par jour (cron, « scheduled job » de l'hébergeur, ou
service systemd). Les envois sont idempotents : relancer la commande dans la
journée ne renvoie pas deux fois le même message.
"""

from django.core.management.base import BaseCommand

from Notifications.registre import CANAUX_DISPONIBLES, canaux_actifs
from Notifications.tasks import executer_relances_abonnement


class Command(BaseCommand):
    help = (
        "Relance les prestataires dont l'abonnement expire bientôt, est "
        "expiré, ou qui ne se sont jamais abonnés (emails avec lien vers "
        "leur page d'abonnement)."
    )

    def add_arguments(self, parser):
        parser.add_argument(
            "--jours-avant-expiration",
            type=int,
            default=None,
            help="Délai du rappel « expire bientôt » (défaut : réglage).",
        )
        parser.add_argument(
            "--delai-sans-abonnement",
            type=int,
            default=None,
            help="Ancienneté minimale des prestataires jamais abonnés.",
        )
        parser.add_argument(
            "--canal",
            action="append",
            choices=sorted(CANAUX_DISPONIBLES),
            help="Canal à utiliser (répétable). Défaut : configuration.",
        )
        parser.add_argument(
            "--simulation",
            action="store_true",
            help="Lister les cibles sans rien envoyer.",
        )

    def handle(self, *args, **options):
        canaux = None
        if options.get("canal"):
            classes = [CANAUX_DISPONIBLES[nom]() for nom in options["canal"]]
            canaux = classes
        else:
            canaux = canaux_actifs()

        rapport = executer_relances_abonnement(
            jours_avant_expiration=options.get("jours_avant_expiration"),
            delai_sans_abonnement=options.get("delai_sans_abonnement"),
            canaux=canaux,
            simulation=options["simulation"],
        )

        for ligne in rapport.details:
            self.stdout.write(f"  - {ligne}")

        self.stdout.write(
            self.style.SUCCESS(
                f"Relances : {rapport.cibles} cible(s), {rapport.envoyes} envoyée(s), "
                f"{rapport.ignores} ignorée(s), {rapport.echecs} échec(s)."
            )
        )
