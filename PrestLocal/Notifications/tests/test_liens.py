"""Tests des liens signés vers l'espace d'abonnement."""

from django.test import TestCase
from django.urls import reverse

from Abonnement.models import PlanAbonnement
from Notifications.abonnement import (
    prestataire_depuis_reference,
    reference_relance,
)

from .base import creer_prestataire


class LienAbonnementTests(TestCase):
    """Lien signé + vue qui le reçoit (aucun droit supplémentaire accordé)."""

    def setUp(self):
        self.plan = PlanAbonnement.objects.create(
            nom="Basique", prix=5000, duree_jours=30
        )
        self.prestataire = creer_prestataire(email="ligue@lesprodufao.bf")
        self.autre = creer_prestataire(email="autre@lesprodufao.bf")

    def test_reference_signee_identifie_le_prestataire(self):
        reference = reference_relance(self.prestataire)
        self.assertEqual(
            prestataire_depuis_reference(reference).pk, self.prestataire.pk
        )
        self.assertIsNone(prestataire_depuis_reference("faux-jeton"))
        self.assertIsNone(prestataire_depuis_reference(""))

    def test_vue_gestion_redirige_le_bon_compte(self):
        self.client.force_login(self.prestataire)
        url = reverse("Abonnement:gestion", args=[self.prestataire.pk])
        response = self.client.get(url)
        self.assertRedirects(response, reverse("Abonnement:plan_list"))

    def test_vue_gestion_refuse_un_autre_compte(self):
        self.client.force_login(self.autre)
        url = reverse("Abonnement:gestion", args=[self.prestataire.pk])
        response = self.client.get(url)
        self.assertRedirects(response, reverse("main:index"))
        # Aucune information sur l'autre compte n'a fuité.
        messages_rendus = [str(m) for m in response.wsgi_request._messages]
        self.assertTrue(
            any("ne correspond pas à votre compte" in m for m in messages_rendus)
        )

    def test_vue_gestion_exige_une_connexion(self):
        url = reverse("Abonnement:gestion", args=[self.prestataire.pk])
        response = self.client.get(url)
        self.assertEqual(response.status_code, 302)
        self.assertIn("/login/", response["Location"])

    def test_plan_list_affiche_le_bandeau_pour_le_bon_compte(self):
        self.client.force_login(self.prestataire)
        reference = reference_relance(self.prestataire)
        url = reverse("Abonnement:plan_list")
        response = self.client.get(url, {"ref": reference})
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.context["relance_abonnement"])
        self.assertContains(response, "Votre abonnement conditionne votre visibilité")

    def test_plan_list_ignore_une_reference_etrangere(self):
        self.client.force_login(self.autre)
        reference = reference_relance(self.prestataire)
        url = reverse("Abonnement:plan_list")
        response = self.client.get(url, {"ref": reference})
        self.assertEqual(response.status_code, 200)
        self.assertFalse(response.context["relance_abonnement"])
        self.assertNotContains(
            response, "Votre abonnement conditionne votre visibilité"
        )

    def test_gestion_conserve_le_jeton_jusqu_aux_offres(self):
        self.client.force_login(self.prestataire)
        reference = reference_relance(self.prestataire)
        url = reverse("Abonnement:gestion", args=[self.prestataire.pk])
        response = self.client.get(url, {"ref": reference})
        self.assertEqual(response.status_code, 302)
        self.assertIn("ref=", response["Location"])
        # En suivant la redirection, le bandeau apparaît bien.
        final = self.client.get(response["Location"])
        self.assertTrue(final.context["relance_abonnement"])
