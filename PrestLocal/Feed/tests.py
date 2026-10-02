"""Tests des services métier du fil d'actualité.

Ces services sont partagés par le site web et l'API mobile : les tester
directement garantit que les deux points d'entrée se comportent pareil, sans
passer par HTTP.
"""

from django.test import TestCase
from django.urls import reverse

from Feed.models import Commentaire, Like
from Feed.services import (
    CommentaireVide,
    ajouter_commentaire,
    basculer_like,
    compter_commentaires,
)
from main.models import Prestataire, Realisation


class ServicesFilTests(TestCase):
    def setUp(self):
        self.auteur = Prestataire.objects.create_user(
            email="auteur@lesprodufao.bf",
            password="MotDePasse123",
            first_name="Awa",
            last_name="Ouédraogo",
            role=Prestataire.ROLE_PRESTATAIRE,
        )
        self.visiteur = Prestataire.objects.create_user(
            email="visiteur@lesprodufao.bf",
            password="MotDePasse123",
            first_name="Issa",
            last_name="Kaboré",
            role=Prestataire.ROLE_CLIENT,
        )
        self.realisation = Realisation.objects.create(
            prestataire=self.auteur, contenu="Chantier terminé"
        )

    def test_basculer_like_ajoute_puis_retire(self):
        premier = basculer_like(self.visiteur, self.realisation)
        self.assertTrue(premier.liked)
        self.assertEqual(premier.like_count, 1)
        self.assertTrue(Like.objects.filter(realisation=self.realisation).exists())

        second = basculer_like(self.visiteur, self.realisation)
        self.assertFalse(second.liked)
        self.assertEqual(second.like_count, 0)
        self.assertFalse(Like.objects.filter(realisation=self.realisation).exists())

    def test_like_du_meme_utilisateur_ne_se_double_pas(self):
        # Deux « J'aime » consécutifs doivent rester dans [0, 1] (toggle).
        for _ in range(4):
            basculer_like(self.visiteur, self.realisation)
        self.assertLessEqual(self.realisation.likes.count(), 1)

    def test_commentaire_vide_leve_une_erreur_metier(self):
        for contenu in ["", "   ", None]:
            with self.assertRaises(CommentaireVide):
                ajouter_commentaire(self.visiteur, self.realisation, contenu)

    def test_ajouter_commentaire_nettoie_le_texte(self):
        commentaire = ajouter_commentaire(
            self.visiteur, self.realisation, "  Super travail !  "
        )
        self.assertEqual(commentaire.contenu, "Super travail !")
        self.assertEqual(Commentaire.objects.count(), 1)
        self.assertEqual(compter_commentaires(self.realisation), 1)


class VuesFilTests(TestCase):
    """Endpoints AJAX du fil côté site : codes de réponse et contrat JSON."""

    def setUp(self):
        self.auteur = Prestataire.objects.create_user(
            email="vues.fil@lesprodufao.bf",
            password="MotDePasse123",
            first_name="Awa",
            last_name="Ouédraogo",
        )
        self.visiteur = Prestataire.objects.create_user(
            email="visiteur.fil@lesprodufao.bf",
            password="MotDePasse123",
            first_name="Issa",
            last_name="Sawadogo",
        )
        self.publication = Realisation.objects.create(
            prestataire=self.auteur, contenu="Chantier terminé."
        )
        self.url_like = reverse('Feed:toggle_like', args=[self.publication.pk])
        self.url_comment = reverse('Feed:add_comment', args=[self.publication.pk])

    def test_like_anonyme_redirige_vers_la_connexion(self):
        reponse = self.client.post(self.url_like)
        self.assertEqual(reponse.status_code, 302)
        self.assertIn('/login/', reponse['Location'])

    def test_like_bascule_pour_un_utilisateur_connecte(self):
        self.client.force_login(self.visiteur)

        aime = self.client.post(self.url_like)
        retire = self.client.post(self.url_like)

        self.assertEqual(aime.json(), {'status': 'success', 'liked': True, 'like_count': 1})
        self.assertEqual(retire.json(), {'status': 'success', 'liked': False, 'like_count': 0})
        self.assertFalse(Like.objects.exists())

    def test_commentaire_vide_refuse_en_json(self):
        self.client.force_login(self.visiteur)
        reponse = self.client.post(self.url_comment, {'contenu': '   '})
        self.assertEqual(reponse.status_code, 400)
        self.assertEqual(reponse.json()['message'], 'Le commentaire est vide.')

    def test_commentaire_enregistre(self):
        self.client.force_login(self.visiteur)
        reponse = self.client.post(self.url_comment, {'contenu': 'Très beau travail.'})
        self.assertEqual(reponse.status_code, 200)
        self.assertEqual(reponse.json()['comment']['contenu'], 'Très beau travail.')
        self.assertEqual(Commentaire.objects.count(), 1)

    def test_fil_ajax_renvoie_le_html_de_la_page_suivante(self):
        for index in range(8):
            Realisation.objects.create(
                prestataire=self.auteur, contenu=f'Publication {index}'
            )

        reponse = self.client.get(
            reverse('Feed:feed_list'), {'page': 1}, HTTP_X_REQUESTED_WITH='XMLHttpRequest'
        )

        donnees = reponse.json()
        self.assertEqual(donnees['status'], 'success')
        self.assertTrue(donnees['has_next'])
        self.assertEqual(donnees['next_page'], 2)
        self.assertIn('feed-card', donnees['html'])
