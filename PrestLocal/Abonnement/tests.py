"""Tests des services métier de l'abonnement.

`Abonnement.services.souscrire` est la règle unique d'activation, utilisée par
la page web (paiement simulé) et par l'API mobile : les tests ci-dessous
vérifient la règle elle-même, indépendamment des deux points d'entrée.
"""

from datetime import timedelta

from django.test import TestCase
from django.utils import timezone

from Abonnement.models import Abonnement, PlanAbonnement
from Abonnement.services import (
    PLANS_PAR_DEFAUT,
    abonnement_actif,
    assurer_plans_par_defaut,
    souscrire,
)
from main.models import Prestataire


class ServicesAbonnementTests(TestCase):
    def setUp(self):
        self.prestataire = Prestataire.objects.create_user(
            email="abonne@lesprodufao.bf",
            password="MotDePasse123",
            first_name="Awa",
            role=Prestataire.ROLE_PRESTATAIRE,
        )
        self.plan = PlanAbonnement.objects.create(
            nom="Basique", prix=5000, duree_jours=30
        )

    def test_souscrire_active_l_abonnement(self):
        abonnement = souscrire(self.prestataire, self.plan)
        self.assertTrue(abonnement.paye)
        self.assertTrue(abonnement.est_actif)
        self.assertTrue(abonnement.est_valide)
        self.assertTrue(abonnement.transaction_id.startswith("MOB-"))
        # Échéance cohérente avec la durée de l'offre (tolérance : secondes).
        attendu = timezone.now() + timedelta(days=30)
        self.assertAlmostEqual(
            abonnement.date_fin.timestamp(), attendu.timestamp(), delta=60
        )

    def test_souscrire_renouvelle_sans_creer_de_doublon(self):
        premier = souscrire(self.prestataire, self.plan)
        ancienne_fin = premier.date_fin

        deuxieme = souscrire(self.prestataire, self.plan, prefixe="SIM")
        self.assertEqual(premier.pk, deuxieme.pk)
        self.assertEqual(Abonnement.objects.count(), 1)
        self.assertGreater(deuxieme.date_fin, ancienne_fin)
        self.assertTrue(deuxieme.transaction_id.startswith("SIM-"))

    def test_abonnement_actif_ignore_un_abonnement_expire(self):
        abonnement = souscrire(self.prestataire, self.plan)
        abonnement.date_fin = timezone.now() - timedelta(days=1)
        abonnement.save()

        self.assertIsNone(abonnement_actif(self.prestataire))

    def test_abonnement_actif_sans_abonnement(self):
        self.assertIsNone(abonnement_actif(self.prestataire))

    def test_plans_par_defaut_crees_une_seule_fois(self):
        # Base vide (comme une installation neuve sans `populate_db`).
        PlanAbonnement.objects.all().delete()

        assurer_plans_par_defaut()
        self.assertEqual(PlanAbonnement.objects.count(), len(PLANS_PAR_DEFAUT))

        # Deuxième appel : aucune duplication (la base n'est plus vide).
        assurer_plans_par_defaut()
        self.assertEqual(PlanAbonnement.objects.count(), len(PLANS_PAR_DEFAUT))

    def test_plans_par_defaut_ne_touchent_pas_une_base_deja_remplie(self):
        # `setUp` a créé « Basique » : la fonction ne doit rien ajouter.
        assurer_plans_par_defaut()
        self.assertEqual(PlanAbonnement.objects.count(), 1)
        self.assertEqual(PlanAbonnement.objects.get().nom, "Basique")
