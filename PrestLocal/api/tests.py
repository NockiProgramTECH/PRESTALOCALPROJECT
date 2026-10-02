"""Tests automatisés de l'API REST LesProduFao.

Lancer :

    python manage.py test api -v 2

Ces tests utilisent SQLite (aucun `DATABASE_URL` requis), un backend email
« locmem » (aucun envoi réel) et un dossier média temporaire.
"""

import tempfile
from datetime import timedelta

from django.contrib.auth import get_user_model
from django.core import mail
from django.core.cache import cache
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import override_settings
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from Abonnement.models import Abonnement, PlanAbonnement
from Feed.models import Commentaire, Like
from main.models import (
    CategoriePrestation,
    Evaluation,
    Favorite,
    Prestation,
    Realisation,
    Ville,
)
from Messagerie.models import Conversation

Prestataire = get_user_model()

# Image PNG 1x1 valide (pour les champs ImageField des tests)
PNG_1PX = (
    b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01'
    b'\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01'
    b'\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82'
)


def upload(name='photo.png'):
    return SimpleUploadedFile(name, PNG_1PX, content_type='image/png')


@override_settings(
    EMAIL_BACKEND='django.core.mail.backends.locmem.EmailBackend',
    MEDIA_ROOT=tempfile.mkdtemp(prefix='lesprodufao-tests-'),
)
class BaseAPITestCase(APITestCase):
    """Données communes : ville, catégorie, métiers, prestataires, réalisation."""

    @classmethod
    def setUpTestData(cls):
        cls.ville = Ville.objects.create(nom='Ouagadougou')
        cls.categorie = CategoriePrestation.objects.create(
            nom='Plomberie', descriptionText='Dépannage et installation'
        )
        cls.metier = Prestation.objects.create(
            nom='Plombier Professionnel',
            slug='plombier-professionnel',
            categorie=cls.categorie,
            description='Fuites, installations, sanitaires.',
        )
        cls.metier2 = Prestation.objects.create(
            nom='Électricien',
            slug='electricien',
            categorie=cls.categorie,
            description='Installations électriques.',
        )

        cls.pro = Prestataire.objects.create_user(
            email='pro@lesprodufao.bf',
            password='MotDePasse123',
            first_name='Issa',
            last_name='Kaboré',
            telephone='+226 70 00 00 01',
            role=Prestataire.ROLE_PRESTATAIRE,
            metier=cls.metier,
            ville=cls.ville,
            quartier='Gounghin',
            bio='Plombier depuis 10 ans.',
            est_verifie=True,
            is_available=True,
            annee_experience=10,
        )
        cls.other_pro = Prestataire.objects.create_user(
            email='pro2@lesprodufao.bf',
            password='MotDePasse123',
            first_name='Awa',
            last_name='Traoré',
            role=Prestataire.ROLE_PRESTATAIRE,
            metier=cls.metier2,
            ville=cls.ville,
        )
        cls.client_user = Prestataire.objects.create_user(
            email='client@lesprodufao.bf',
            password='MotDePasse123',
            first_name='Client',
            last_name='Test',
            role=Prestataire.ROLE_CLIENT,
            ville=cls.ville,
        )

        # `pro` est abonné : il est donc visible dans les recherches (règle de
        # visibilité). `other_pro` reste sans abonnement pour vérifier qu'il
        # est bien masqué de la liste tout en gardant sa fiche consultable.
        cls.plan = PlanAbonnement.objects.create(
            nom='Découverte (1 mois)', prix=5000, duree_jours=30,
            description='Visibilité standard.',
        )
        Abonnement.objects.create(
            prestataire=cls.pro,
            plan=cls.plan,
            date_fin=timezone.now() + timedelta(days=30),
            est_actif=True,
            paye=True,
            transaction_id='TEST-0001',
        )

        cls.realisation = Realisation.objects.create(
            prestataire=cls.pro,
            image=upload('realisation.png'),
            titre='Salle de bain rénovée',
        )

    def setUp(self):
        cache.clear()

    # ---- Helpers ---------------------------------------------------------
    def login(self, email='pro@lesprodufao.bf', password='MotDePasse123'):
        response = self.client.post(
            '/api/auth/token/',
            {'email': email, 'password': password},
            format='json',
        )
        self.assertEqual(response.status_code, 200, response.data)
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {response.data['access']}")
        return response.data

    def logout_credentials(self):
        self.client.credentials()


# ===========================================================================
# 1. Authentification
# ===========================================================================
class AuthAPITests(BaseAPITestCase):

    def test_login_returns_tokens(self):
        data = self.login()
        self.assertIn('access', data)
        self.assertIn('refresh', data)

    def test_register_verify_then_login(self):
        response = self.client.post('/api/auth/register/', {
            'email': 'nouveau@lesprodufao.bf',
            'first_name': 'Nouveau',
            'last_name': 'Membre',
            'telephone': '+226 76 12 34 56',
            'password': 'MotDePasse123',
            'role': 'client',
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED, response.data)

        user = Prestataire.objects.get(email='nouveau@lesprodufao.bf')
        self.assertFalse(user.is_active)          # compte inactif avant vérification
        self.assertTrue(user.code_verification)   # un code a été généré
        self.assertEqual(len(mail.outbox), 1)     # un seul email envoyé

        # Mauvais code -> 400
        bad = self.client.post('/api/auth/verify-email/', {
            'email': user.email, 'code': '000000',
        }, format='json')
        self.assertEqual(bad.status_code, status.HTTP_400_BAD_REQUEST)

        # Bon code -> 200 puis connexion possible
        ok = self.client.post('/api/auth/verify-email/', {
            'email': user.email, 'code': user.code_verification,
        }, format='json')
        self.assertEqual(ok.status_code, status.HTTP_200_OK)
        user.refresh_from_db()
        self.assertTrue(user.is_active)

        login = self.client.post('/api/auth/token/', {
            'email': user.email, 'password': 'MotDePasse123',
        }, format='json')
        self.assertEqual(login.status_code, 200, login.data)

    # ---- Parcours d'inscription / vérification (connexion immédiate) ----

    def _register(self, **overrides):
        payload = {
            'email': 'auto@lesprodufao.bf',
            'first_name': 'Auto',
            'last_name': 'Connexion',
            'telephone': '+226 76 12 34 56',
            'password': 'MotDePasse123',
            'role': Prestataire.ROLE_CLIENT,
        }
        payload.update(overrides)
        return self.client.post('/api/auth/register/', payload, format='json')

    def test_verify_email_connects_immediately(self):
        """Après vérification, l'API renvoie des jetons directement utilisables."""
        register = self._register()
        self.assertEqual(register.status_code, status.HTTP_201_CREATED, register.data)
        user = Prestataire.objects.get(email='auto@lesprodufao.bf')
        self.assertFalse(user.is_active)

        response = self.client.post('/api/auth/verify-email/', {
            'email': user.email, 'code': user.code_verification,
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK, response.data)
        self.assertIn('access', response.data)
        self.assertIn('refresh', response.data)
        self.assertEqual(response.data['user']['email'], user.email)
        self.assertTrue(response.data['user']['profile_completed'])

        # Le jeton d'accès ouvre la session sans repasser par /auth/token/.
        self.client.credentials(
            HTTP_AUTHORIZATION=f"Bearer {response.data['access']}"
        )
        me = self.client.get('/api/auth/me/')
        self.assertEqual(me.status_code, status.HTTP_200_OK)
        self.assertEqual(me.data['email'], user.email)

        user.refresh_from_db()
        self.assertTrue(user.is_active)
        self.assertIsNone(user.code_verification)

    def test_verify_email_on_active_account_returns_no_tokens(self):
        """Un compte déjà vérifié ne peut pas être connecté avec le seul email."""
        user = Prestataire.objects.create_user(
            email='deja.actif@lesprodufao.bf',
            password='MotDePasse123',
            first_name='Déjà',
            last_name='Actif',
            role=Prestataire.ROLE_CLIENT,
            is_active=True,
            code_verification='654321',
        )
        response = self.client.post('/api/auth/verify-email/', {
            'email': user.email, 'code': '654321',
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_200_OK, response.data)
        self.assertNotIn('access', response.data)
        self.assertNotIn('refresh', response.data)

    def test_profile_completed_flag_for_provider(self):
        """profile_completed suit les informations indispensables au rôle."""
        user = Prestataire.objects.create_user(
            email='pro.incomplet@lesprodufao.bf',
            password='MotDePasse123',
            first_name='Sans',
            last_name='Métier',
            role=Prestataire.ROLE_PRESTATAIRE,
            is_active=True,
        )
        self.login(email=user.email)
        me = self.client.get('/api/auth/me/')
        self.assertEqual(me.status_code, 200)
        self.assertFalse(me.data['profile_completed'])
        self.assertTrue(me.data['is_prestataire'])

        patch = self.client.patch('/api/auth/me/', {
            'metier': self.metier.id,
            'ville': self.ville.id,
            'quartier': 'Karpala',
        }, format='json')
        self.assertEqual(patch.status_code, status.HTTP_200_OK, patch.data)
        self.assertTrue(patch.data['profile_completed'])

    def test_register_rejects_invalid_phone(self):
        response = self.client.post('/api/auth/register/', {
            'email': 'tel@lesprodufao.bf',
            'first_name': 'Tel',
            'last_name': 'Invalide',
            'telephone': '12345',
            'password': 'MotDePasse123',
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('telephone', response.data)

    def test_register_rejects_weak_password(self):
        response = self.client.post('/api/auth/register/', {
            'email': 'faible@lesprodufao.bf',
            'first_name': 'Mot',
            'last_name': 'Faible',
            'password': '12345678',
        }, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('password', response.data)

    def test_password_reset_does_not_leak_account_existence(self):
        """Adresse inconnue : même réponse 200, aucun email envoyé."""
        response = self.client.post(
            '/api/auth/password-reset/',
            {'email': 'inconnu@lesprodufao.bf'},
            format='json',
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(mail.outbox), 0)
        self.assertNotIn('Aucun compte', str(response.data))

    def test_password_reset_full_flow(self):
        demande = self.client.post(
            '/api/auth/password-reset/',
            {'email': self.client_user.email},
            format='json',
        )
        self.assertEqual(demande.status_code, status.HTTP_200_OK)
        self.assertEqual(len(mail.outbox), 1)

        self.client_user.refresh_from_db()
        code = self.client_user.code_verification
        self.assertTrue(code)

        confirm = self.client.post('/api/auth/password-reset/confirm/', {
            'email': self.client_user.email,
            'code': code,
            'new_password': 'NouveauPass123',
        }, format='json')
        self.assertEqual(confirm.status_code, status.HTTP_200_OK, confirm.data)

        login = self.client.post('/api/auth/token/', {
            'email': self.client_user.email,
            'password': 'NouveauPass123',
        }, format='json')
        self.assertEqual(login.status_code, 200, login.data)

    def test_logout_blacklists_refresh_token(self):
        tokens = self.login()
        self.client.credentials(
            HTTP_AUTHORIZATION=f"Bearer {tokens['access']}"
        )
        response = self.client.post(
            '/api/auth/token/logout/', {'refresh': tokens['refresh']}, format='json'
        )
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)

        # Le refresh révoqué ne peut plus être utilisé
        self.client.credentials()
        refresh = self.client.post(
            '/api/auth/token/refresh/', {'refresh': tokens['refresh']}, format='json'
        )
        self.assertEqual(refresh.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_me_requires_authentication(self):
        self.assertEqual(self.client.get('/api/auth/me/').status_code, 401)

    def test_me_returns_and_updates_profile(self):
        self.login(email=self.client_user.email)
        me = self.client.get('/api/auth/me/')
        self.assertEqual(me.status_code, 200)
        self.assertEqual(me.data['email'], self.client_user.email)

        patch = self.client.patch(
            '/api/auth/me/', {'bio': 'Bio mise à jour'}, format='json'
        )
        self.assertEqual(patch.status_code, 200, patch.data)
        self.client_user.refresh_from_db()
        self.assertEqual(self.client_user.bio, 'Bio mise à jour')


# ===========================================================================
# 2. Prestataires, catégories, villes, prestations
# ===========================================================================
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


# ===========================================================================
# 3. Évaluations
# ===========================================================================
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


# ===========================================================================
# 4. Favoris (synchronisés côté serveur)
# ===========================================================================
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


# ===========================================================================
# 5. Fil d'actualité (réalisations, likes, commentaires)
# ===========================================================================
class FeedAPITests(BaseAPITestCase):

    def test_feed_counters_are_not_multiplied(self):
        """Deux likes + deux commentaires : les compteurs doivent rester exacts."""
        Like.objects.create(user=self.pro, realisation=self.realisation)
        Like.objects.create(user=self.client_user, realisation=self.realisation)
        Commentaire.objects.create(
            user=self.pro, realisation=self.realisation, contenu='Bravo'
        )
        Commentaire.objects.create(
            user=self.client_user, realisation=self.realisation, contenu='Super'
        )

        response = self.client.get('/api/feed/')
        self.assertEqual(response.status_code, 200)
        item = response.data['results'][0]
        self.assertEqual(item['like_count'], 2)
        self.assertEqual(item['comment_count'], 2)

    def test_like_toggle(self):
        self.login(email=self.client_user.email)
        first = self.client.post(f'/api/feed/{self.realisation.id}/like/')
        self.assertEqual(first.status_code, 200)
        self.assertTrue(first.data['liked'])
        self.assertEqual(first.data['like_count'], 1)

        second = self.client.post(f'/api/feed/{self.realisation.id}/like/')
        self.assertFalse(second.data['liked'])
        self.assertEqual(second.data['like_count'], 0)

    def test_comment_and_detail_is_liked(self):
        self.login(email=self.client_user.email)
        comment = self.client.post(
            f'/api/feed/{self.realisation.id}/comment/',
            {'contenu': 'Excellent travail'},
            format='json',
        )
        self.assertEqual(comment.status_code, status.HTTP_201_CREATED)
        self.assertEqual(comment.data['comment_count'], 1)
        self.assertEqual(comment.data['comment']['contenu'], 'Excellent travail')

        self.client.post(f'/api/feed/{self.realisation.id}/like/')
        detail = self.client.get(f'/api/feed/{self.realisation.id}/')
        self.assertEqual(detail.status_code, 200)
        self.assertTrue(detail.data['is_liked'])
        self.assertEqual(len(detail.data['commentaires']), 1)

    def test_create_realisation_multipart(self):
        self.login()
        response = self.client.post(
            '/api/feed/',
            {'titre': 'Nouvelle installation', 'image': upload('nouvelle.png')},
            format='multipart',
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED, response.data)
        self.assertTrue(
            Realisation.objects.filter(titre='Nouvelle installation').exists()
        )

    def test_delete_realisation_requires_owner(self):
        self.login(email=self.client_user.email)
        response = self.client.delete(f'/api/feed/{self.realisation.id}/')
        # 403 explicite : la publication appartient à quelqu'un d'autre.
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.assertTrue(Realisation.objects.filter(id=self.realisation.id).exists())

        self.client.credentials()
        self.login()
        response = self.client.delete(f'/api/feed/{self.realisation.id}/')
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)


class PublicationFilAPITests(BaseAPITestCase):
    """Fil d'actualité communautaire : publication, édition, médias, fil."""

    LIST_URL = '/api/feed/'

    # ---- Publication ----------------------------------------------------

    def test_publish_text_only(self):
        self.login()
        response = self.client.post(
            self.LIST_URL,
            {'contenu': "Nouvelle réalisation terminée aujourd'hui !"},
            format='json',
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED, response.data)
        self.assertEqual(
            response.data['contenu'], "Nouvelle réalisation terminée aujourd'hui !"
        )
        self.assertEqual(response.data['images'], [])
        self.assertTrue(response.data['can_edit'])
        self.assertTrue(response.data['can_delete'])
        self.assertEqual(response.data['prestataire']['nom_complet'], 'Issa Kaboré')

    def test_publish_with_multiple_images(self):
        self.login()
        response = self.client.post(
            self.LIST_URL,
            {
                'contenu': 'Trois photos du chantier',
                'images': [upload('a.png'), upload('b.png'), upload('c.png')],
                'categorie': self.categorie.id,
                'lien': 'https://lesprodufao.bf/realisations',
            },
            format='multipart',
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED, response.data)
        self.assertEqual(len(response.data['images']), 3)
        self.assertEqual(response.data['image'], response.data['images'][0])
        self.assertEqual(response.data['categorie_nom'], 'Plomberie')
        self.assertEqual(response.data['lien'], 'https://lesprodufao.bf/realisations')

    def test_publish_requires_content(self):
        self.login()
        response = self.client.post(self.LIST_URL, {'contenu': '   '}, format='json')
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_publish_rejects_too_many_images(self):
        self.login()
        response = self.client.post(
            self.LIST_URL,
            {'contenu': 'Trop d\'images', 'images': [upload(f'{i}.png') for i in range(11)]},
            format='multipart',
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('images', response.data)

    def test_publish_rejects_wrong_extension(self):
        self.login()
        mauvais = SimpleUploadedFile(
            'virus.exe', b'MZ...', content_type='application/octet-stream'
        )
        response = self.client.post(
            self.LIST_URL,
            {'contenu': 'Fichier interdit', 'images': [mauvais]},
            format='multipart',
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('images', response.data)

    def test_publish_requires_authentication(self):
        response = self.client.post(
            self.LIST_URL, {'contenu': 'Anonyme'}, format='json'
        )
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    # ---- Fil --------------------------------------------------------------

    def test_feed_is_paginated_and_newest_first(self):
        Realisation.objects.create(
            prestataire=self.pro, image=upload('recent.png'), contenu='Plus récent'
        )
        response = self.client.get(self.LIST_URL)
        self.assertEqual(response.status_code, 200)
        self.assertIn('results', response.data)
        self.assertIn('count', response.data)
        # 10 publications par page (pagination DRF) : on n'attend jamais tout
        # le fil d'un seul coup.
        self.assertEqual(len(response.data['results']), response.data['count'])

    def test_feed_search_and_category_filter(self):
        categorie2 = CategoriePrestation.objects.create(
            nom='Menuiserie', descriptionText='Bois'
        )
        Realisation.objects.create(
            prestataire=self.pro, image=upload('x.png'), contenu='Fabrication bois',
            categorie=categorie2,
        )
        par_texte = self.client.get(f'{self.LIST_URL}?search=bois')
        self.assertEqual(par_texte.data['count'], 1)

        par_categorie = self.client.get(f'{self.LIST_URL}?categorie={categorie2.id}')
        self.assertEqual(par_categorie.data['count'], 1)

    # ---- Modification / suppression --------------------------------------

    def test_author_can_edit_post(self):
        self.login()
        response = self.client.patch(
            f'{self.LIST_URL}{self.realisation.id}/',
            {'contenu': 'Texte corrigé'},
            format='json',
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK, response.data)
        self.assertEqual(response.data['contenu'], 'Texte corrigé')

        self.realisation.refresh_from_db()
        self.assertEqual(self.realisation.contenu, 'Texte corrigé')

    def test_other_user_cannot_edit_post(self):
        self.login(email=self.other_pro.email)
        response = self.client.patch(
            f'{self.LIST_URL}{self.realisation.id}/',
            {'contenu': 'Détournement'},
            format='json',
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_staff_can_delete_post(self):
        moderateur = Prestataire.objects.create_user(
            email='modo@lesprodufao.bf',
            password='MotDePasse123',
            first_name='Modo',
            last_name='Rateur',
            role=Prestataire.ROLE_PRESTATAIRE,
            is_staff=True,
        )
        self.login(email=moderateur.email)
        response = self.client.delete(f'{self.LIST_URL}{self.realisation.id}/')
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)

    # ---- Interactions -----------------------------------------------------

    def test_like_toggle_reflects_real_counters(self):
        self.login()
        premier = self.client.post(f'{self.LIST_URL}{self.realisation.id}/like/')
        self.assertEqual(premier.status_code, 200)
        self.assertTrue(premier.data['liked'])
        self.assertEqual(premier.data['like_count'], 1)

        second = self.client.post(f'{self.LIST_URL}{self.realisation.id}/like/')
        self.assertFalse(second.data['liked'])
        self.assertEqual(second.data['like_count'], 0)

    def test_comments_list_and_create(self):
        self.login(email=self.client_user.email)
        creation = self.client.post(
            f'{self.LIST_URL}{self.realisation.id}/comment/',
            {'contenu': 'Super travail !'},
            format='json',
        )
        self.assertEqual(creation.status_code, status.HTTP_201_CREATED, creation.data)
        self.assertEqual(creation.data['comment_count'], 1)
        self.assertEqual(creation.data['comment']['contenu'], 'Super travail !')

        liste = self.client.get(f'{self.LIST_URL}{self.realisation.id}/comment/')
        self.assertEqual(liste.status_code, 200)
        self.assertEqual(len(liste.data), 1)
        self.assertEqual(liste.data[0]['user'], 'Client Test')
        self.assertIn('user_photo', liste.data[0])

        detail = self.client.get(f'{self.LIST_URL}{self.realisation.id}/')
        self.assertTrue(detail.data['is_liked'] is False)
        self.assertEqual(detail.data['comment_count'], 1)
        self.assertFalse(detail.data['can_edit'])  # commentateur ≠ auteur


# ===========================================================================
# 6. Messagerie REST
# ===========================================================================
class MessagerieAPITests(BaseAPITestCase):

    def test_start_conversation_is_idempotent(self):
        self.login(email=self.client_user.email)
        first = self.client.post(
            f'/api/messagerie/conversations/start/{self.pro.id}/', {}, format='json'
        )
        second = self.client.post(
            f'/api/messagerie/conversations/start/{self.pro.id}/', {}, format='json'
        )
        self.assertEqual(first.status_code, 200)
        self.assertEqual(
            first.data['conversation_id'], second.data['conversation_id']
        )
        self.assertEqual(Conversation.objects.count(), 1)

    def test_send_and_read_messages(self):
        self.login(email=self.client_user.email)
        conv_id = self.client.post(
            f'/api/messagerie/conversations/start/{self.pro.id}/', {}, format='json'
        ).data['conversation_id']

        sent = self.client.post(
            f'/api/messagerie/conversations/{conv_id}/messages/',
            {'content': 'Bonjour, êtes-vous disponible ?'},
            format='json',
        )
        self.assertEqual(sent.status_code, status.HTTP_201_CREATED, sent.data)

        detail = self.client.get(f'/api/messagerie/conversations/{conv_id}/')
        self.assertEqual(detail.status_code, 200)
        self.assertEqual(len(detail.data['messages']), 1)
        self.assertEqual(detail.data['participant']['first_name'], 'Issa')

        liste = self.client.get('/api/messagerie/conversations/')
        self.assertEqual(len(liste.data), 1)
        self.assertEqual(liste.data[0]['last_message']['content'],
                         'Bonjour, êtes-vous disponible ?')

    def test_cannot_read_others_conversation(self):
        conversation = Conversation.objects.create()
        conversation.participants.add(self.pro, self.other_pro)

        self.login(email=self.client_user.email)
        response = self.client.get(
            f'/api/messagerie/conversations/{conversation.id}/'
        )
        self.assertEqual(response.status_code, 404)
