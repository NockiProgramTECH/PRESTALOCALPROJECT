"""Tests du fil d'actualité (API) : publications, likes, commentaires."""

from django.core.files.uploadedfile import SimpleUploadedFile
from rest_framework import status

from Feed.models import (
    Commentaire,
    Like,
)
from main.models import (
    CategoriePrestation,
    Realisation,
)

from .base import BaseAPITestCase, Prestataire, upload


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
