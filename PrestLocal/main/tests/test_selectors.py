"""Tests des selectors : visibilité, recherche, annotations et N+1."""

from datetime import timedelta

from django.db import connection
from django.test import TestCase
from django.test.utils import CaptureQueriesContext
from django.utils import timezone

from Abonnement.models import Abonnement
from main import selectors
from main.models import Realisation

from .base import creer_prestataire


class SelectorsTests(TestCase):
    """Visibilité, recherche et nombre de requêtes des listes."""

    def setUp(self):
        self.visible = creer_prestataire(
            'visible@lesprodufao.bf', ville=None, metier=None, quartier='Gounghin'
        )
        self.invisible = creer_prestataire('invisible@lesprodufao.bf', abonne=False)
        self.expire = creer_prestataire('expire@lesprodufao.bf', abonne=False)
        Abonnement.objects.create(
            prestataire=self.expire,
            paye=True,
            est_actif=True,
            date_fin=timezone.now() - timedelta(days=1),
        )

    def test_prestataires_en_avant_ignore_non_abonnes_et_expires(self):
        emails = [p.email for p in selectors.prestataires_en_avant()]

        self.assertIn('visible@lesprodufao.bf', emails)
        self.assertNotIn('invisible@lesprodufao.bf', emails)
        self.assertNotIn('expire@lesprodufao.bf', emails)

    def test_recherche_filtre_texte_ville_et_categorie(self):
        deja = list(selectors.prestataires_recherches(q='Awa'))
        self.assertIn(self.visible, deja)

        introuvable = list(selectors.prestataires_recherches(q='Zzz-inexistant'))
        self.assertEqual(introuvable, [])

        # Un prestataire non abonné n'apparaît jamais dans l'annuaire.
        self.assertNotIn(
            self.invisible, list(selectors.prestataires_recherches(q='Awa'))
        )

    def test_les_notes_ne_declenchent_pas_une_requete_par_carte(self):
        """Régression N+1 : afficher 6 cartes ne coûte pas plus que 2 cartes.

        Les notes sont annotées dans le queryset (`avec_note_et_avis`) : les
        propriétés `average_rating` / `review_count` lisent l'annotation au
        lieu d'interroger la base carte par carte.
        """
        for index in range(1, 7):
            creer_prestataire(f'liste{index}@lesprodufao.bf', first_name=f'Pro{index}')

        def requetes_pour(limite):
            with CaptureQueriesContext(connection) as contexte:
                for prestataire in selectors.prestataires_en_avant(limite=limite):
                    prestataire.average_rating
                    prestataire.review_count
            return len(contexte)

        self.assertEqual(requetes_pour(2), requetes_pour(6))


class FilSelectorsTests(TestCase):
    """Le fil précharge ses relations (auteur, likes, images)."""

    def test_publications_prechargees(self):
        auteur = creer_prestataire('auteur@lesprodufao.bf')
        Realisation.objects.create(prestataire=auteur, contenu='Première')
        Realisation.objects.create(prestataire=auteur, contenu='Seconde')

        # 1 requête pour les publications + 1 par relation préchargée
        # (images, likes) : aucune requête supplémentaire dans la boucle.
        with self.assertNumQueries(3):
            for publication in selectors.dernieres_publications():
                publication.prestataire.first_name
                publication.likes.count()
                list(publication.images.all())
