"""Tests des avis et des favoris (API)."""

from rest_framework import status

from main.models import (
    Evaluation,
    Favorite,
)

from .base import BaseAPITestCase


class EvaluationAPITests(BaseAPITestCase):

    def test_anonymous_cannot_review(self):
        response = self.client.post(
            f'/api/prestataire/{self.pro.id}/evaluer/',
            {'note': 5, 'commentaire': 'Super travail'},
            format='json',
        )
        self.assertEqual(response.status_code, 401)

    def test_client_creates_then_updates_review(self):
        self.login(email=self.client_user.email)

        creation = self.client.post(
            f'/api/prestataire/{self.pro.id}/evaluer/',
            {'note': 5, 'commentaire': 'Travail impeccable'},
            format='json',
        )
        self.assertEqual(creation.status_code, status.HTTP_201_CREATED, creation.data)
        self.assertEqual(creation.data['nombre_avis'], 1)
        self.assertAlmostEqual(creation.data['moyenne_etoile'], 5.0)
        self.assertEqual(Evaluation.objects.count(), 1)

        # Second appel -> mise à jour, pas de doublon (unique_together)
        update = self.client.post(
            f'/api/prestataire/{self.pro.id}/evaluer/',
            {'note': 3, 'commentaire': 'Finalement moyen'},
            format='json',
        )
        self.assertEqual(update.status_code, status.HTTP_200_OK, update.data)
        self.assertEqual(Evaluation.objects.count(), 1)
        self.assertAlmostEqual(update.data['moyenne_etoile'], 3.0)

    def test_review_validation_and_self_review(self):
        self.login(email=self.client_user.email)
        invalid = self.client.post(
            f'/api/prestataire/{self.pro.id}/evaluer/',
            {'note': 9, 'commentaire': 'Note invalide'},
            format='json',
        )
        self.assertEqual(invalid.status_code, 400)

        self.client.credentials()
        self.login()
        self_eval = self.client.post(
            f'/api/prestataire/{self.pro.id}/evaluer/',
            {'note': 5, 'commentaire': 'Auto évaluation'},
            format='json',
        )
        self.assertEqual(self_eval.status_code, status.HTTP_400_BAD_REQUEST)


class FavoriteAPITests(BaseAPITestCase):

    def test_favorites_require_authentication(self):
        self.assertEqual(self.client.get('/api/me/favorites/').status_code, 401)
        response = self.client.post(
            f'/api/prestataire/{self.pro.id}/toggle_favorite/'
        )
        self.assertEqual(response.status_code, 401)

    def test_toggle_and_list_favorites(self):
        self.login(email=self.client_user.email)

        added = self.client.post(
            f'/api/prestataire/{self.pro.id}/toggle_favorite/'
        )
        self.assertEqual(added.status_code, 200)
        self.assertEqual(added.data['status'], 'added')
        self.assertTrue(added.data['is_favorite'])
        self.assertEqual(Favorite.objects.count(), 1)

        listing = self.client.get('/api/me/favorites/')
        self.assertEqual(listing.status_code, 200)
        self.assertEqual(len(listing.data['results']), 1)
        self.assertEqual(listing.data['results'][0]['id'], str(self.pro.id))
        self.assertTrue(listing.data['results'][0]['is_favorite'])

        # Le drapeau est aussi exposé dans la liste générale
        detail = self.client.get(f'/api/prestataire/{self.pro.id}/')
        self.assertTrue(detail.data['is_favorite'])

        removed = self.client.post(
            f'/api/prestataire/{self.pro.id}/toggle_favorite/'
        )
        self.assertEqual(removed.data['status'], 'removed')
        self.assertEqual(Favorite.objects.count(), 0)
