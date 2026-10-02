"""Tests des compteurs d'audience, de la disponibilité et des favoris."""

from django.test import TestCase

from main.models import (
    Prestataire,
    Favorite,
)
from main.services import (
    basculer_favori,
    definir_disponibilite,
    enregistrer_clic,
)

from .base import creer_prestataire


class ServicesPrestatairesTests(TestCase):
    """Compteurs d'audience, disponibilité et favoris."""

    def setUp(self):
        self.prestataire = creer_prestataire('pro.audience@lesprodufao.bf')
        self.visiteur = Prestataire.objects.create_user(
            email='visiteur@lesprodufao.bf', password='MotDePasse123'
        )

    def test_compteurs_incrementes_un_par_un(self):
        enregistrer_clic(self.prestataire, 'appel')
        enregistrer_clic(self.prestataire, 'appel')
        enregistrer_clic(self.prestataire, 'contact')
        enregistrer_clic(self.prestataire, 'vue')

        self.prestataire.refresh_from_db()
        self.assertEqual(self.prestataire.call_clicks, 2)
        self.assertEqual(self.prestataire.contact_clicks, 1)
        self.assertEqual(self.prestataire.profile_views, 1)

    def test_type_de_clic_inconnu_refuse(self):
        with self.assertRaises(ValueError):
            enregistrer_clic(self.prestataire, 'inconnu')

    def test_disponibilite_modifiee(self):
        self.assertFalse(definir_disponibilite(self.prestataire, False))
        self.prestataire.refresh_from_db()
        self.assertFalse(self.prestataire.is_available)

        self.assertTrue(definir_disponibilite(self.prestataire, True))
        self.prestataire.refresh_from_db()
        self.assertTrue(self.prestataire.is_available)

    def test_favori_bascule_dans_les_deux_sens(self):
        favori, cree = basculer_favori(self.visiteur, self.prestataire)
        self.assertTrue(cree)
        self.assertTrue(Favorite.objects.filter(pk=favori.pk).exists())

        _, cree = basculer_favori(self.visiteur, self.prestataire)
        self.assertFalse(cree)
        self.assertFalse(Favorite.objects.exists())
