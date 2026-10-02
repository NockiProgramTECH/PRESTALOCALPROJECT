"""Socle commun des tests d'API : imports, jeu de données et helpers."""

from datetime import timedelta

from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.core.files.uploadedfile import SimpleUploadedFile
from django.utils import timezone
from rest_framework.test import APITestCase

from Abonnement.models import (
    Abonnement,
    PlanAbonnement,
)
from main.models import (
    CategoriePrestation,
    Prestation,
    Realisation,
    Ville,
)


Prestataire = get_user_model()


PNG_1PX = (
    b'\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01'
    b'\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01'
    b'\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82'
)


def upload(name='photo.png'):
    return SimpleUploadedFile(name, PNG_1PX, content_type='image/png')


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
