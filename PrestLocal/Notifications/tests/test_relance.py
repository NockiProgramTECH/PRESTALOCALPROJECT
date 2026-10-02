"""Tests de la sélection des cibles et de l'envoi des relances d'abonnement."""

from datetime import timedelta

from django.core import mail
from django.test import (
    TestCase,
    override_settings,
)
from django.utils import timezone

from Abonnement.models import (
    Abonnement,
    PlanAbonnement,
)
from Notifications.abonnement import (
    TYPE_EXPIRE,
    TYPE_EXPIRATION_PROCHE,
    TYPE_JAMAIS_SOUSCRIT,
    cibles_relance,
    url_abonnement,
)
from Notifications.models import JournalNotification
from Notifications.tasks import executer_relances_abonnement
from main.models import Prestataire

from .base import EMAIL_LOCMEM, creer_prestataire


class RelanceAbonnementTests(TestCase):
    """Règles métier de relance : qui relancer, avec quel motif."""

    def setUp(self):
        self.plan = PlanAbonnement.objects.create(
            nom="Basique", prix=5000, duree_jours=30
        )

    def _abonnement(self, prestataire, jours_restants):
        return Abonnement.objects.create(
            prestataire=prestataire,
            plan=self.plan,
            date_fin=timezone.now() + timedelta(days=jours_restants),
            est_actif=True,
            paye=True,
        )

    @override_settings(EMAIL_BACKEND=EMAIL_LOCMEM)
    def test_abonnement_bientot_expire_envoye_avec_lien(self):
        prestataire = creer_prestataire()
        self._abonnement(prestataire, jours_restants=5)

        rapport = executer_relances_abonnement()
        self.assertEqual(rapport.cibles, 1)
        self.assertEqual(rapport.envoyes, 1)
        self.assertEqual(len(mail.outbox), 1)

        contenu = mail.outbox[0].alternatives[0][0]
        lien = url_abonnement(prestataire)
        self.assertIn(f"/abonnement/gestion/{prestataire.pk}/", lien)
        self.assertIn(lien, contenu)
        self.assertIn("restez en avant", contenu.lower())

        journal = JournalNotification.objects.get()
        self.assertEqual(journal.type_notification, TYPE_EXPIRATION_PROCHE)

    @override_settings(EMAIL_BACKEND=EMAIL_LOCMEM)
    def test_abonnement_expire_est_relance(self):
        prestataire = creer_prestataire(email="expire@lesprodufao.bf")
        self._abonnement(prestataire, jours_restants=-3)

        rapport = executer_relances_abonnement()
        self.assertEqual(rapport.envoyes, 1)
        self.assertEqual(
            JournalNotification.objects.get().type_notification, TYPE_EXPIRE
        )
        self.assertIn("/abonnement/gestion/", mail.outbox[0].alternatives[0][0])

    @override_settings(EMAIL_BACKEND=EMAIL_LOCMEM)
    def test_prestataire_jamais_abonne_est_relance(self):
        prestataire = creer_prestataire(email="nouveau@lesprodufao.bf")
        # Inscrit il y a 10 jours, sans aucun abonnement.
        Prestataire.objects.filter(pk=prestataire.pk).update(
            date_inscription=timezone.now() - timedelta(days=10)
        )

        rapport = executer_relances_abonnement()
        self.assertEqual(rapport.cibles, 1)
        self.assertEqual(
            JournalNotification.objects.get().type_notification,
            TYPE_JAMAIS_SOUSCRIT,
        )

    @override_settings(EMAIL_BACKEND=EMAIL_LOCMEM)
    def test_prestataire_recent_et_client_non_relances(self):
        recent = creer_prestataire(email="recent@lesprodufao.bf")
        Prestataire.objects.filter(pk=recent.pk).update(
            date_inscription=timezone.now() - timedelta(days=1)
        )
        client = Prestataire.objects.create_user(
            email="client@lesprodufao.bf",
            password="MotDePasse123",
            role=Prestataire.ROLE_CLIENT,
        )
        Prestataire.objects.filter(pk=client.pk).update(
            date_inscription=timezone.now() - timedelta(days=30)
        )

        rapport = executer_relances_abonnement()
        self.assertEqual(rapport.cibles, 0)
        self.assertEqual(len(mail.outbox), 0)

    @override_settings(EMAIL_BACKEND=EMAIL_LOCMEM)
    def test_relance_idempotente_sur_deux_executions(self):
        prestataire = creer_prestataire(email="double@lesprodufao.bf")
        self._abonnement(prestataire, jours_restants=4)

        premier = executer_relances_abonnement()
        second = executer_relances_abonnement()

        self.assertEqual(premier.envoyes, 1)
        self.assertEqual(second.envoyes, 0)
        self.assertEqual(second.ignores, 1)
        self.assertEqual(len(mail.outbox), 1, "pas de second email")

    @override_settings(EMAIL_BACKEND=EMAIL_LOCMEM)
    def test_mode_simulation_n_envoie_rien(self):
        prestataire = creer_prestataire(email="simu@lesprodufao.bf")
        self._abonnement(prestataire, jours_restants=2)

        rapport = executer_relances_abonnement(simulation=True)
        self.assertEqual(rapport.cibles, 1)
        self.assertEqual(rapport.envoyes, 0)
        self.assertEqual(len(mail.outbox), 0)
        self.assertFalse(JournalNotification.objects.exists())

    def test_cibles_couvrent_les_trois_motifs(self):
        proche = creer_prestataire(email="proche@lesprodufao.bf")
        self._abonnement(proche, jours_restants=6)
        expire = creer_prestataire(email="fini@lesprodufao.bf")
        self._abonnement(expire, jours_restants=-1)
        jamais = creer_prestataire(email="jamais@lesprodufao.bf")
        Prestataire.objects.filter(pk=jamais.pk).update(
            date_inscription=timezone.now() - timedelta(days=5)
        )

        motifs = {cible.motif for cible in cibles_relance()}
        self.assertEqual(
            motifs, {TYPE_EXPIRATION_PROCHE, TYPE_EXPIRE, TYPE_JAMAIS_SOUSCRIT}
        )
