"""Tests des parcours web LesProduFao.

Couvre l'inscription, la vérification de l'email (qui **connecte
immédiatement** l'utilisateur) et l'orientation selon le rôle :

- prestataire → configuration du profil (`main:profile`) ;
- client       → espace client (`main:client_dashboard`).

Lancer :

    python manage.py test main -v 2
"""

from django.core import mail
from django.test import TestCase, override_settings
from django.urls import reverse

from main.models import CategoriePrestation, Prestation, Prestataire, Ville


@override_settings(EMAIL_BACKEND='django.core.mail.backends.locmem.EmailBackend')
class SignupVerificationFlowTests(TestCase):
    """Inscription → code email → session ouverte + bonne destination."""

    EMAIL = 'client.web@lesprodufao.bf'
    PASSWORD = 'MotDePasse123'

    def setUp(self):
        self.ville = Ville.objects.create(nom='Ouagadougou')
        self.categorie = CategoriePrestation.objects.create(
            nom='Plomberie', descriptionText='Dépannage et installation'
        )
        self.metier = Prestation.objects.create(
            nom='Plombier',
            slug='plombier-web',
            categorie=self.categorie,
            description='Fuites et installations.',
        )

    # ---- Helpers ---------------------------------------------------------

    def _signup(self, **overrides):
        payload = {
            'email': self.EMAIL,
            'role': Prestataire.ROLE_CLIENT,
            'first_name': 'Awa',
            'last_name': 'Ouédraogo',
            'telephone': '+226 76 12 34 56',
            'password1': self.PASSWORD,
            'password2': self.PASSWORD,
        }
        payload.update(overrides)
        return self.client.post(reverse('main:signup'), payload)

    def _verify(self, user, code=None):
        return self.client.post(
            reverse('main:verify_email'),
            {'code': user.code_verification if code is None else code},
        )

    def _session_user_id(self):
        return str(self.client.session.get('_auth_user_id') or '')

    # ---- Inscription -----------------------------------------------------

    def test_client_signup_leaves_pro_fields_empty(self):
        """Un client n'a pas de métier ni de quartier d'intervention."""
        response = self._signup()
        self.assertEqual(response.status_code, 302)
        user = Prestataire.objects.get(email=self.EMAIL)
        self.assertTrue(user.is_client)
        self.assertIsNone(user.metier_id)
        self.assertEqual(user.quartier, '')
        self.assertFalse(user.is_active)

    def test_provider_signup_requires_metier_ville_quartier(self):
        response = self._signup(role=Prestataire.ROLE_PRESTATAIRE)
        self.assertEqual(response.status_code, 200)
        self.assertFalse(
            Prestataire.objects.filter(email=self.EMAIL).exists()
        )
        form = response.context['form']
        for champ in ('metier', 'ville', 'quartier'):
            self.assertIn(champ, form.errors)

    # ---- Vérification : connexion immédiate -------------------------------

    def test_client_verification_logs_in_and_opens_dashboard(self):
        self._signup()
        user = Prestataire.objects.get(email=self.EMAIL)
        self.assertEqual(len(mail.outbox), 1)

        response = self._verify(user)

        user.refresh_from_db()
        self.assertTrue(user.is_active)
        self.assertIsNone(user.code_verification)
        # Connexion immédiate : session ouverte dans la même requête…
        self.assertEqual(self._session_user_id(), str(user.pk))
        # … et destination adaptée au rôle.
        self.assertRedirects(
            response,
            reverse('main:client_dashboard'),
            fetch_redirect_response=False,
        )

    def test_provider_verification_logs_in_and_redirects_to_profile_setup(self):
        self._signup(
            role=Prestataire.ROLE_PRESTATAIRE,
            metier=self.metier.id,
            ville=self.ville.id,
            quartier='Karpala',
        )
        user = Prestataire.objects.get(email=self.EMAIL)
        self.assertTrue(user.is_prestataire)

        response = self._verify(user)

        user.refresh_from_db()
        self.assertTrue(user.is_active)
        self.assertEqual(self._session_user_id(), str(user.pk))
        self.assertRedirects(
            response,
            reverse('main:profile'),
            fetch_redirect_response=False,
        )
        # La session de vérification est nettoyée une fois le compte activé.
        self.assertIsNone(self.client.session.get('verification_user_id'))

    def test_wrong_code_keeps_account_inactive(self):
        self._signup()
        user = Prestataire.objects.get(email=self.EMAIL)

        response = self._verify(user, code='000000')

        user.refresh_from_db()
        self.assertFalse(user.is_active)
        self.assertEqual(response.status_code, 200)
        self.assertNotIn('_auth_user_id', self.client.session)

    def test_provider_profile_page_is_reachable_after_verification(self):
        """La redirection post-vérification mène à une page réellement servie."""
        self._signup(
            role=Prestataire.ROLE_PRESTATAIRE,
            metier=self.metier.id,
            ville=self.ville.id,
            quartier='Karpala',
        )
        user = Prestataire.objects.get(email=self.EMAIL)
        self._verify(user)

        page = self.client.get(reverse('main:profile'))
        self.assertEqual(page.status_code, 200)
        self.assertEqual(page.context['prestataire'].pk, user.pk)


@override_settings(EMAIL_BACKEND='django.core.mail.backends.locmem.EmailBackend')
class LoginRedirectionTests(TestCase):
    """Connexion web : un prestataire incomplet est envoyé à son profil."""

    PASSWORD = 'MotDePasse123'

    def setUp(self):
        self.ville = Ville.objects.create(nom='Ouagadougou')
        self.categorie = CategoriePrestation.objects.create(
            nom='Plomberie', descriptionText='Dépannage'
        )
        self.metier = Prestation.objects.create(
            nom='Plombier',
            slug='plombier-login',
            categorie=self.categorie,
            description='Fuites et installations.',
        )

    def _login(self, user):
        return self.client.post(reverse('main:login'), {
            'username': user.email,
            'password': self.PASSWORD,
        })

    def test_incomplete_provider_is_redirected_to_profile(self):
        user = Prestataire.objects.create_user(
            email='pro.incomplet@lesprodufao.bf',
            password=self.PASSWORD,
            first_name='Issa',
            last_name='Kaboré',
            role=Prestataire.ROLE_PRESTATAIRE,
            is_active=True,
        )
        response = self._login(user)
        self.assertRedirects(
            response,
            reverse('main:profile'),
            fetch_redirect_response=False,
        )
        self.assertEqual(str(self.client.session['_auth_user_id']), str(user.pk))

    def test_complete_provider_lands_on_home(self):
        user = Prestataire.objects.create_user(
            email='pro.complet@lesprodufao.bf',
            password=self.PASSWORD,
            first_name='Issa',
            last_name='Kaboré',
            role=Prestataire.ROLE_PRESTATAIRE,
            metier=self.metier,
            ville=self.ville,
            quartier='Gounghin',
            is_active=True,
        )
        response = self._login(user)
        self.assertRedirects(
            response,
            reverse('main:index'),
            fetch_redirect_response=False,
        )

    def test_client_lands_on_home(self):
        user = Prestataire.objects.create_user(
            email='client.login@lesprodufao.bf',
            password=self.PASSWORD,
            first_name='Awa',
            last_name='Ouédraogo',
            role=Prestataire.ROLE_CLIENT,
            is_active=True,
        )
        response = self._login(user)
        self.assertRedirects(
            response,
            reverse('main:index'),
            fetch_redirect_response=False,
        )
