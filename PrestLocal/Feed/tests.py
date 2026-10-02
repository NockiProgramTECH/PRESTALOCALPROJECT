"""Tests des services métier du fil d'actualité.

Ces services sont partagés par le site web et l'API mobile : les tester
directement garantit que les deux points d'entrée se comportent pareil, sans
passer par HTTP.
"""

from django.test import TestCase

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
