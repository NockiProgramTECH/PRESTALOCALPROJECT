"""Tests de l'API abonnement (offres, état, souscription)."""

from rest_framework import status

from Abonnement.models import (
    Abonnement,
    PlanAbonnement,
)

from .base import BaseAPITestCase


class AbonnementAPITests(BaseAPITestCase):
    """Offres d'abonnement, souscription Mobile Money et mise en avant."""

    def setUp(self):
        super().setUp()
        self.plan = PlanAbonnement.objects.create(
            nom='Découverte (1 mois)',
            prix=5000,
            duree_jours=30,
            description='Idéal pour commencer.',
        )

    def test_plans_are_public(self):
        response = self.client.get('/api/abonnement/plans/')
        self.assertEqual(response.status_code, status.HTTP_200_OK, response.data)
        self.assertGreaterEqual(len(response.data), 1)
        self.assertEqual(response.data[0]['nom'], 'Découverte (1 mois)')
        self.assertIn('prix', response.data[0])
        self.assertIn('duree_jours', response.data[0])

    def test_provider_without_subscription(self):
        # `other_pro` n'a aucun abonnement (contrairement à `pro`, abonné pour
        # les tests de visibilité).
        self.login(email=self.other_pro.email)
        response = self.client.get('/api/abonnement/mon-abonnement/')
        self.assertEqual(response.status_code, status.HTTP_200_OK, response.data)
        self.assertFalse(response.data['actif'])
        self.assertIsNone(response.data['abonnement'])

    def test_subscribe_activates_and_highlights_profile(self):
        self.login()
        response = self.client.post(
            '/api/abonnement/souscrire/',
            {'plan': self.plan.id, 'methode': 'Orange Money', 'otp': '123456'},
            format='json',
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED, response.data)
        self.assertTrue(response.data['actif'])
        self.assertTrue(response.data['abonnement']['est_valide'])
        self.assertGreater(response.data['abonnement']['jours_restants'], 0)
        self.assertTrue(response.data['abonnement']['transaction_id'])

        # L'état remonte directement dans le profil (`/auth/me/`).
        me = self.client.get('/api/auth/me/')
        self.assertTrue(me.data['abonnement_actif'])
        self.assertEqual(me.data['abonnement_plan'], 'Découverte (1 mois)')
        self.assertIsNotNone(me.data['abonnement_fin'])

        # Le prestataire abonné apparaît dans le filtre « mis en avant ».
        highlighted = self.client.get('/api/prestataire/?abonnes_only=1')
        emails = [p['email'] for p in highlighted.data['results']]
        self.assertIn('pro@lesprodufao.bf', emails)

        # Et l'abonnement devient actif côté API dédiée.
        status_response = self.client.get('/api/abonnement/mon-abonnement/')
        self.assertTrue(status_response.data['actif'])

    def test_wrong_otp_is_rejected(self):
        self.login(email=self.other_pro.email)
        response = self.client.post(
            '/api/abonnement/souscrire/',
            {'plan': self.plan.id, 'methode': 'Wave', 'otp': '12'},
            format='json',
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('otp', response.data)
        self.assertFalse(
            Abonnement.objects.filter(prestataire=self.other_pro).exists()
        )

    def test_unknown_operator_is_rejected(self):
        self.login()
        response = self.client.post(
            '/api/abonnement/souscrire/',
            {'plan': self.plan.id, 'methode': 'Bitcoin', 'otp': '123456'},
            format='json',
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('methode', response.data)

    def test_client_cannot_subscribe(self):
        self.login(email=self.client_user.email)
        response = self.client.post(
            '/api/abonnement/souscrire/',
            {'plan': self.plan.id, 'methode': 'Moov Money', 'otp': '123456'},
            format='json',
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.assertFalse(Abonnement.objects.filter(prestataire=self.client_user).exists())

        status_response = self.client.get('/api/abonnement/mon-abonnement/')
        self.assertEqual(status_response.status_code, status.HTTP_403_FORBIDDEN)

    def test_subscription_requires_authentication(self):
        response = self.client.post(
            '/api/abonnement/souscrire/',
            {'plan': self.plan.id, 'methode': 'Wave', 'otp': '123456'},
            format='json',
        )
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
