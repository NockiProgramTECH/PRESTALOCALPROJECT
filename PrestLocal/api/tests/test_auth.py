"""Tests d'authentification de l'API (JWT, inscription, mot de passe)."""

from django.core import mail
from rest_framework import status

from .base import BaseAPITestCase, Prestataire


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
