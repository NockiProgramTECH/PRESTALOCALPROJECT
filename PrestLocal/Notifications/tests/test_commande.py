"""Tests du worker planifié (`relancer_abonnements`)."""

from datetime import timedelta

from django.core import mail
from django.test import (
    TestCase,
    override_settings,
)
from django.utils import timezone

from Abonnement.models import (
    Abonnement,
    PlanAbonnement,
)

from .base import EMAIL_LOCMEM, creer_prestataire


class CommandeRelanceTests(TestCase):
    """La commande planifiée relaie le worker et imprime un rapport."""

    def setUp(self):
        self.plan = PlanAbonnement.objects.create(
            nom="Basique", prix=5000, duree_jours=30
        )
        self.prestataire = creer_prestataire(email="commande@lesprodufao.bf")
        Abonnement.objects.create(
            prestataire=self.prestataire,
            plan=self.plan,
            date_fin=timezone.now() + timedelta(days=3),
            est_actif=True,
            paye=True,
        )

    @override_settings(EMAIL_BACKEND=EMAIL_LOCMEM)
    def test_commande_relancer_abonnements(self):
        from io import StringIO

        from django.core.management import call_command

        sortie = StringIO()
        call_command("relancer_abonnements", stdout=sortie)
        self.assertIn("1 envoyée(s)", sortie.getvalue())

    @override_settings(EMAIL_BACKEND=EMAIL_LOCMEM)
    def test_ancienne_commande_deleguee(self):
        from io import StringIO

        from django.core.management import call_command

        sortie = StringIO()
        call_command("check_subscriptions", stdout=sortie)
        contenu = sortie.getvalue()
        self.assertIn("dépréciée", contenu)
        self.assertEqual(len(mail.outbox), 1)
