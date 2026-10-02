"""Tests de la façade d'envoi multi-canal (journalisation, idempotence, erreurs)."""

from django.core import mail
from django.test import (
    TestCase,
    override_settings,
)

from Abonnement.models import PlanAbonnement
from Notifications.channels.base import MessageNotification
from Notifications.models import JournalNotification
from Notifications.service import (
    ServiceNotification,
    envoyer_email,
)
from main.models import Prestataire

from .base import CanalEnregistreur, EMAIL_LOCMEM, creer_prestataire


class ServiceNotificationTests(TestCase):
    """Le service d'envoi : journalisation, idempotence, canaux injectés."""

    def setUp(self):
        self.prestataire = creer_prestataire()
        self.plan = PlanAbonnement.objects.create(
            nom="Basique", prix=5000, duree_jours=30
        )

    def test_envoi_email_journalise_le_resultat(self):
        with override_settings(EMAIL_BACKEND=EMAIL_LOCMEM):
            rapport = envoyer_email(
                self.prestataire,
                sujet="Bonjour",
                texte="Contenu",
                type_notification="test_email",
            )
        self.assertTrue(rapport.envoye)
        self.assertEqual(len(mail.outbox), 1)
        self.assertEqual(mail.outbox[0].to, [self.prestataire.email])

        journal = JournalNotification.objects.get()
        self.assertEqual(journal.canal, "email")
        self.assertEqual(journal.statut, "envoye")
        self.assertEqual(journal.type_notification, "test_email")

    def test_cle_unique_evite_les_doublons(self):
        with override_settings(EMAIL_BACKEND=EMAIL_LOCMEM):
            premier = envoyer_email(
                self.prestataire,
                sujet="Relance",
                texte="Contenu",
                type_notification="relance",
                cle_unique="relance:1",
            )
            second = envoyer_email(
                self.prestataire,
                sujet="Relance",
                texte="Contenu",
                type_notification="relance",
                cle_unique="relance:1",
            )
        self.assertTrue(premier.envoye)
        self.assertFalse(second.envoye)
        self.assertEqual(len(mail.outbox), 1, "un seul email doit partir")
        self.assertEqual(
            JournalNotification.objects.filter(statut="envoye").count(), 1
        )

    def test_canal_injecte_sans_smtp_ni_reseau(self):
        canal = CanalEnregistreur()
        message = MessageNotification(
            type="test", sujet="Sujet", texte="Texte", url_action="https://x.bf"
        )
        rapport = ServiceNotification(canaux=[canal]).envoyer(
            self.prestataire, message
        )
        self.assertTrue(rapport.envoye)
        self.assertEqual(len(canal.messages), 1)
        destinataire, envoye = canal.messages[0]
        self.assertEqual(destinataire, self.prestataire)
        self.assertEqual(envoye.url_action, "https://x.bf")

    def test_canal_indisponible_est_journalise_sans_erreur(self):
        canal = CanalEnregistreur(disponible=False)
        rapport = ServiceNotification(canaux=[canal]).envoyer(
            self.prestataire,
            MessageNotification(type="test", sujet="S", texte="T"),
        )
        self.assertFalse(rapport.envoye)
        self.assertFalse(canal.messages)
        journal = JournalNotification.objects.get()
        self.assertEqual(journal.statut, "ignore")

    def test_destinataire_sans_email_est_ignore(self):
        sans_email = Prestataire.objects.create_user(
            email="sans-adresse@lesprodufao.bf",
            password="MotDePasse123",
            role=Prestataire.ROLE_CLIENT,
        )
        sans_email.email = ""
        rapport = ServiceNotification().envoyer(
            sans_email, MessageNotification(type="test", sujet="S", texte="T")
        )
        self.assertFalse(rapport.envoye)
        self.assertEqual(rapport.resultats[0].statut, "ignore")
