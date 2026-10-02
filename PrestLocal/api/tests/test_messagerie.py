"""Tests de l'API messagerie (conversations, messages)."""

from rest_framework import status

from Messagerie.models import Conversation

from .base import BaseAPITestCase


class MessagerieAPITests(BaseAPITestCase):

    def test_start_conversation_is_idempotent(self):
        self.login(email=self.client_user.email)
        first = self.client.post(
            f'/api/messagerie/conversations/start/{self.pro.id}/', {}, format='json'
        )
        second = self.client.post(
            f'/api/messagerie/conversations/start/{self.pro.id}/', {}, format='json'
        )
        self.assertEqual(first.status_code, 200)
        self.assertEqual(
            first.data['conversation_id'], second.data['conversation_id']
        )
        self.assertEqual(Conversation.objects.count(), 1)

    def test_send_and_read_messages(self):
        self.login(email=self.client_user.email)
        conv_id = self.client.post(
            f'/api/messagerie/conversations/start/{self.pro.id}/', {}, format='json'
        ).data['conversation_id']

        sent = self.client.post(
            f'/api/messagerie/conversations/{conv_id}/messages/',
            {'content': 'Bonjour, êtes-vous disponible ?'},
            format='json',
        )
        self.assertEqual(sent.status_code, status.HTTP_201_CREATED, sent.data)

        detail = self.client.get(f'/api/messagerie/conversations/{conv_id}/')
        self.assertEqual(detail.status_code, 200)
        self.assertEqual(len(detail.data['messages']), 1)
        self.assertEqual(detail.data['participant']['first_name'], 'Issa')

        liste = self.client.get('/api/messagerie/conversations/')
        self.assertEqual(len(liste.data), 1)
        self.assertEqual(liste.data[0]['last_message']['content'],
                         'Bonjour, êtes-vous disponible ?')

    def test_cannot_read_others_conversation(self):
        conversation = Conversation.objects.create()
        conversation.participants.add(self.pro, self.other_pro)

        self.login(email=self.client_user.email)
        response = self.client.get(
            f'/api/messagerie/conversations/{conversation.id}/'
        )
        self.assertEqual(response.status_code, 404)
