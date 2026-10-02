"""Tests de la couche services / selectors du domaine `main`.

Ces tests n'utilisent **pas** le client HTTP : ils appellent les services
directement, ce qui les rend rapides et lisibles. Ils couvrent :

- le cycle de vie du compte (code, activation, réinitialisation, atomicité) ;
- les règles des avis (bornes, doublon, remplacement, statistiques) ;
- les compteurs d'audience, la disponibilité et les favoris ;
- les selectors (visibilité, recherche) et l'absence de requête par carte
  (régression N+1).

Lancer :

    python manage.py test main.test_services -v 2
"""

import uuid
from datetime import timedelta

from django.core import mail
from django.db import connection
from django.test import TestCase, override_settings
from django.test.utils import CaptureQueriesContext
from django.urls import reverse
from django.utils import timezone

from Abonnement.models import Abonnement, PlanAbonnement
from main import selectors
from main.models import Evaluation, Favorite, Prestataire, Realisation
from main.services import (
    AvisDejaDonne,
    AvisInvalide,
    CodeInvalide,
    EnvoiCodeImpossible,
    NoteHorsBornes,
    activer_compte,
    basculer_favori,
    demarrer_inscription,
    demander_reinitialisation,
    definir_disponibilite,
    enregistrer_clic,
    notifier_nouvel_avis,
    reinitialiser_mot_de_passe,
    soumettre_avis,
    statistiques_avis,
)

EMAIL_LOCMEM = 'django.core.mail.backends.locmem.EmailBackend'


def creer_prestataire(email, *, abonne=True, **extra):
    """Crée un prestataire, abonné (visible) par défaut."""
    champs = {
        'email': email,
        'first_name': 'Awa',
        'last_name': 'Ouédraogo',
        'role': Prestataire.ROLE_PRESTATAIRE,
    }
    champs.update(extra)
    prestataire = Prestataire.objects.create_user(password='MotDePasse123', **champs)
    if abonne:
        plan = PlanAbonnement.objects.create(nom='Test', prix=5000, duree_jours=30)
        Abonnement.objects.create(
            prestataire=prestataire,
            plan=plan,
            paye=True,
            est_actif=True,
            date_fin=timezone.now() + timedelta(days=30),
        )
    return prestataire


@override_settings(EMAIL_BACKEND=EMAIL_LOCMEM)
class ServicesComptesTests(TestCase):
    """Inscription, activation et réinitialisation d'un compte."""

    def _nouveau_compte(self, email='nouveau@lesprodufao.bf'):
        return Prestataire(email=email, first_name='Issa', last_name='Sawadogo')

    # ---- Inscription -----------------------------------------------------

    def test_inscription_cree_un_compte_inactif_et_envoie_le_code(self):
        compte = self._nouveau_compte()

        demarrer_inscription(utilisateur=compte, base_url='https://exemple.bf')

        self.assertFalse(compte.is_active)
        self.assertTrue(compte.pk)
        self.assertEqual(len(compte.code_verification), 6)
        self.assertEqual(len(mail.outbox), 1)
        self.assertIn(compte.code_verification, mail.outbox[0].body)

    @override_settings(NOTIFICATIONS_CHANNELS=['push'])
    def test_inscription_annulee_si_aucun_canal_ne_delivre_le_code(self):
        """Pas de code délivré = pas de compte conservé (transaction annulée)."""
        compte = self._nouveau_compte(email='echec@lesprodufao.bf')

        with self.assertRaises(EnvoiCodeImpossible):
            demarrer_inscription(utilisateur=compte)

        self.assertFalse(
            Prestataire.objects.filter(email='echec@lesprodufao.bf').exists()
        )

    # ---- Activation ------------------------------------------------------

    def test_activation_avec_le_bon_code(self):
        compte = self._nouveau_compte()
        demarrer_inscription(utilisateur=compte)

        activer_compte(compte, compte.code_verification)

        compte.refresh_from_db()
        self.assertTrue(compte.is_active)
        self.assertIsNone(compte.code_verification)

    def test_activation_refusee_avec_un_mauvais_code(self):
        compte = self._nouveau_compte()
        demarrer_inscription(utilisateur=compte)

        with self.assertRaises(CodeInvalide):
            activer_compte(compte, '000000')

        compte.refresh_from_db()
        self.assertFalse(compte.is_active)

    # ---- Réinitialisation ------------------------------------------------

    def test_reinitialisation_inconnue_ne_revele_rien_et_nenvoie_rien(self):
        self.assertIsNone(demander_reinitialisation('inconnu@lesprodufao.bf'))
        self.assertEqual(len(mail.outbox), 0)

    def test_reinitialisation_envoie_un_code_puis_change_le_mot_de_passe(self):
        compte = Prestataire.objects.create_user(
            email='oublie@lesprodufao.bf', password='AncienMotDePasse123'
        )

        retrouve = demander_reinitialisation('OUBLIE@lesprodufao.bf')

        self.assertEqual(retrouve, compte)
        self.assertEqual(len(mail.outbox), 1)
        code = retrouve.code_verification
        self.assertEqual(len(code), 6)

        # L'instance renvoyée par le service porte le code à jour.
        reinitialiser_mot_de_passe(retrouve, code, 'NouveauMotDePasse123')

        compte.refresh_from_db()
        self.assertTrue(compte.check_password('NouveauMotDePasse123'))
        self.assertIsNone(compte.code_verification)

    def test_reinitialisation_refusee_avec_un_mauvais_code(self):
        compte = Prestataire.objects.create_user(
            email='oublie2@lesprodufao.bf', password='AncienMotDePasse123'
        )
        demander_reinitialisation('oublie2@lesprodufao.bf')

        with self.assertRaises(CodeInvalide):
            reinitialiser_mot_de_passe(compte, '999999', 'NouveauMotDePasse123')

        compte.refresh_from_db()
        self.assertTrue(compte.check_password('AncienMotDePasse123'))


@override_settings(EMAIL_BACKEND=EMAIL_LOCMEM)
class ServicesAvisTests(TestCase):
    """Règles métier du dépôt d'avis et statistiques associées."""

    def setUp(self):
        self.prestataire = creer_prestataire('pro.avis@lesprodufao.bf')
        self.client_ = creer_prestataire(
            'client.avis@lesprodufao.bf', abonne=False, role=Prestataire.ROLE_CLIENT
        )

    def test_note_hors_bornes_refusee(self):
        for note in (0, 6, 'abc', None):
            with self.subTest(note=note), self.assertRaises(NoteHorsBornes):
                soumettre_avis(
                    prestataire=self.prestataire,
                    client=self.client_,
                    note=note,
                    commentaire='Un avis détaillé.',
                )
        self.assertFalse(Evaluation.objects.exists())

    def test_commentaire_trop_court_refuse(self):
        with self.assertRaises(AvisInvalide):
            soumettre_avis(
                prestataire=self.prestataire,
                client=self.client_,
                note=5,
                commentaire='  ',
            )

    def test_auto_evaluation_refusee(self):
        with self.assertRaises(AvisInvalide):
            soumettre_avis(
                prestataire=self.prestataire,
                client=self.prestataire,
                note=5,
                commentaire='Excellent travail.',
            )

    def test_doublon_refuse_sans_remplacement_puis_mis_a_jour(self):
        evaluation, cree = soumettre_avis(
            prestataire=self.prestataire,
            client=self.client_,
            note=4,
            commentaire='Travail soigné.',
        )
        self.assertTrue(cree)

        with self.assertRaises(AvisDejaDonne):
            soumettre_avis(
                prestataire=self.prestataire,
                client=self.client_,
                note=2,
                commentaire='Finalement déçu.',
            )

        evaluation, cree = soumettre_avis(
            prestataire=self.prestataire,
            client=self.client_,
            note=2,
            commentaire='Finalement déçu.',
            remplacer=True,
        )

        self.assertFalse(cree)
        self.assertEqual(Evaluation.objects.count(), 1)
        self.assertEqual(evaluation.note, 2)

    def test_statistiques_avis(self):
        soumettre_avis(
            prestataire=self.prestataire, client=self.client_,
            note=5, commentaire='Parfait du début à la fin.',
        )
        self.assertEqual(
            statistiques_avis(self.prestataire),
            {'moyenne_etoile': 5.0, 'nombre_avis': 1},
        )

    def test_email_d_avis_non_duplique(self):
        """Rejouer la notification (retry, double clic) n'envoie qu'un email."""
        evaluation, _ = soumettre_avis(
            prestataire=self.prestataire, client=self.client_,
            note=5, commentaire='Très bon contact.',
        )

        notifier_nouvel_avis(evaluation)
        notifier_nouvel_avis(evaluation)

        self.assertEqual(len(mail.outbox), 1)
        self.assertEqual(
            self.prestataire.notifications.filter(notification_type='evaluation').count(),
            2,
        )


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


class VueEvaluationTests(TestCase):
    """Codes de réponse de l'endpoint AJAX d'avis (contrat du site).

    Les règles sont testées dans `ServicesAvisTests` ; ici on vérifie la
    traduction HTTP : permissions, cas limites et erreurs métier.
    """

    def setUp(self):
        self.prestataire = creer_prestataire('pro.http@lesprodufao.bf')
        self.client_ = Prestataire.objects.create_user(
            email='client.http@lesprodufao.bf',
            password='MotDePasse123',
            role=Prestataire.ROLE_CLIENT,
        )
        self.url = reverse('main:submit_evaluation', args=[self.prestataire.pk])

    def test_visiteur_anonyme_refuse(self):
        reponse = self.client.post(self.url, {'note': 5, 'commentaire': 'Très bien.'})
        self.assertEqual(reponse.status_code, 403)

    def test_prestataire_inconnu_renvoie_404_json(self):
        self.client.force_login(self.client_)
        url = reverse('main:submit_evaluation', args=[uuid.uuid4()])

        reponse = self.client.post(url, {'note': 5, 'commentaire': 'Très bien.'})

        self.assertEqual(reponse.status_code, 404)
        self.assertEqual(reponse.json()['status'], 'error')

    def test_champs_manquants_refuses(self):
        self.client.force_login(self.client_)
        reponse = self.client.post(self.url, {'note': '', 'commentaire': ''})
        self.assertEqual(reponse.status_code, 400)
        self.assertEqual(reponse.json()['message'], 'Note et commentaire requis.')

    def test_note_hors_bornes_refusee_sans_erreur_serveur(self):
        self.client.force_login(self.client_)
        reponse = self.client.post(
            self.url, {'note': 9, 'commentaire': 'Note impossible.'}
        )
        self.assertEqual(reponse.status_code, 400)
        self.assertFalse(Evaluation.objects.exists())

    def test_avis_enregistre_puis_second_avis_refuse(self):
        self.client.force_login(self.client_)
        payload = {'note': 5, 'commentaire': 'Excellent travail.'}

        premiere = self.client.post(self.url, payload)
        seconde = self.client.post(self.url, payload)

        self.assertEqual(premiere.status_code, 200)
        self.assertEqual(premiere.json()['status'], 'success')
        self.assertEqual(seconde.status_code, 400)
        self.assertIn('déjà', seconde.json()['message'])
        self.assertEqual(Evaluation.objects.count(), 1)
