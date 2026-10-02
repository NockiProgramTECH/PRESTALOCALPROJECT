"""Tests des services d'avis (bornes, doublon, remplacement, notification)."""

from django.core import mail
from django.test import TestCase

from main.models import (
    Prestataire,
    Evaluation,
)
from main.services import (
    AvisDejaDonne,
    AvisInvalide,
    NoteHorsBornes,
    notifier_nouvel_avis,
    soumettre_avis,
    statistiques_avis,
)

from .base import creer_prestataire


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
