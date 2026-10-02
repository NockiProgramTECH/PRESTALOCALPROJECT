"""Tests de l'API prestataires (liste, fiche, filtres, visibilité)."""

from datetime import timedelta

from django.utils import timezone

from Abonnement.models import Abonnement
from main.models import Evaluation

from .base import BaseAPITestCase


class PrestataireAPITests(BaseAPITestCase):

    def test_list_is_public_and_paginated(self):
        response = self.client.get('/api/prestataire/')
        self.assertEqual(response.status_code, 200)
        self.assertIn('results', response.data)
        # Seuls les comptes « prestataire » sont exposés
        ids = [item['id'] for item in response.data['results']]
        self.assertIn(str(self.pro.id), ids)
        self.assertNotIn(str(self.client_user.id), ids)

    def test_list_exposes_rating_and_favorite_flag(self):
        response = self.client.get('/api/prestataire/')
        item = next(
            i for i in response.data['results'] if i['id'] == str(self.pro.id)
        )
        self.assertEqual(item['nom_complet'], 'Issa Kaboré')
        self.assertEqual(item['moyenne_etoile'], 0)
        self.assertEqual(item['nombre_avis'], 0)
        self.assertFalse(item['is_favorite'])

    def test_filters_by_ville_and_metier(self):
        # `include_all=1` : on teste les filtres, pas la visibilité.
        response = self.client.get(
            f'/api/prestataire/?ville={self.ville.id}&include_all=1'
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.data['results']), 2)

        response = self.client.get(
            f'/api/prestataire/?metier={self.metier2.id}&include_all=1'
        )
        self.assertEqual(len(response.data['results']), 1)
        self.assertEqual(
            response.data['results'][0]['id'], str(self.other_pro.id)
        )

    def test_filters_by_categorie(self):
        response = self.client.get(
            f'/api/prestataire/?categorie={self.categorie.id}&include_all=1'
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.data['results']), 2)

    # ---- Visibilité liée à l'abonnement ---------------------------------

    def test_only_subscribed_providers_are_listed(self):
        """Seuls les abonnés sont visibles ; les autres restent consultables."""
        response = self.client.get('/api/prestataire/')
        ids = [item['id'] for item in response.data['results']]
        self.assertIn(str(self.pro.id), ids)
        self.assertNotIn(str(self.other_pro.id), ids)

        # La fiche du non-abonné reste accessible (depuis une publication)…
        detail = self.client.get(f'/api/prestataire/{self.other_pro.id}/')
        self.assertEqual(detail.status_code, 200)
        self.assertFalse(detail.data['abonnement_actif'])
        # … mais ses coordonnées sont masquées : on ne peut pas le contacter.
        self.assertFalse(detail.data['contact_disponible'])
        self.assertIsNone(detail.data['telephone'])
        self.assertIsNone(detail.data['email'])

    def test_subscribed_provider_contact_is_visible(self):
        detail = self.client.get(f'/api/prestataire/{self.pro.id}/')
        self.assertTrue(detail.data['contact_disponible'])
        self.assertEqual(detail.data['telephone'], '+226 70 00 00 01')
        self.assertIsNotNone(detail.data['email'])

        liste = self.client.get('/api/prestataire/')
        item = next(
            i for i in liste.data['results'] if i['id'] == str(self.pro.id)
        )
        self.assertTrue(item['contact_disponible'])
        self.assertEqual(item['telephone'], '+226 70 00 00 01')

    def test_include_all_bypasses_visibility_rule(self):
        response = self.client.get('/api/prestataire/?include_all=1')
        ids = [item['id'] for item in response.data['results']]
        self.assertIn(str(self.other_pro.id), ids)
        item = next(
            i for i in response.data['results'] if i['id'] == str(self.other_pro.id)
        )
        # Le filtre levé n'ouvre pas les coordonnées pour autant.
        self.assertFalse(item['contact_disponible'])
        self.assertIsNone(item['telephone'])

    def test_expired_subscription_hides_provider(self):
        Abonnement.objects.filter(prestataire=self.pro).update(
            date_fin=timezone.now() - timedelta(days=1),
        )
        response = self.client.get('/api/prestataire/')
        ids = [item['id'] for item in response.data['results']]
        self.assertNotIn(str(self.pro.id), ids)

    def test_search_and_star_filter(self):
        Evaluation.objects.create(
            prestataire=self.pro, client=self.client_user,
            note=5, commentaire='Parfait', client_nom='Test',
        )
        starred = self.client.get('/api/prestataire/?etoile=4')
        self.assertEqual(len(starred.data['results']), 1)

        searched = self.client.get('/api/prestataire/?search=Issa')
        self.assertEqual(len(searched.data['results']), 1)
        self.assertEqual(searched.data['results'][0]['id'], str(self.pro.id))

    def test_detail_includes_portfolio_and_reviews(self):
        Evaluation.objects.create(
            prestataire=self.pro, client=self.client_user,
            note=4, commentaire='Bon travail', client_nom='Test',
        )
        response = self.client.get(f'/api/prestataire/{self.pro.id}/')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.data['realisations']), 1)
        self.assertEqual(response.data['realisations'][0]['titre'], 'Salle de bain rénovée')
        self.assertEqual(len(response.data['evaluations']), 1)
        self.assertEqual(response.data['nombre_avis'], 1)
        self.assertAlmostEqual(response.data['moyenne_etoile'], 4.0)
        self.assertIn('photo_profil_url', response.data)

    def test_categories_villes_prestations_are_public(self):
        for url in ('/api/categories/', '/api/villes/', '/api/prestations/'):
            response = self.client.get(url)
            self.assertEqual(response.status_code, 200, url)
            # Ces trois listes alimentent les menus déroulants de l'application
            # (ville, métier) : elles doivent être renvoyées sous forme de
            # **tableau JSON** (pas d'objet paginé).
            self.assertIsInstance(response.data, list, url)

        categories = self.client.get('/api/categories/')
        self.assertEqual(categories.data[0]['nom'], 'Plomberie')

        villes = self.client.get('/api/villes/')
        self.assertEqual(villes.data[0]['nom'], 'Ouagadougou')
        self.assertIn('id', villes.data[0])

        prestations = self.client.get('/api/prestations/')
        self.assertIn('nom', prestations.data[0])

    def test_abonnement_actif_flag(self):
        # `pro` est abonné depuis `setUpTestData` (voir BaseAPITestCase).
        response = self.client.get(f'/api/prestataire/{self.pro.id}/')
        self.assertTrue(response.data['abonnement_actif'])
        self.assertTrue(response.data['contact_disponible'])
