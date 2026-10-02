"""Tests des codes HTTP de l'endpoint AJAX d'avis (contrat du site)."""

import uuid

from django.test import TestCase
from django.urls import reverse

from main.models import (
    Prestataire,
    Evaluation,
)

from .base import creer_prestataire


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
