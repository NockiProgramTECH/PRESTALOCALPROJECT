from channels.db import database_sync_to_async as db_async
from channels.generic.websocket import AsyncJsonWebsocketConsumer

from django.contrib.auth.models import AnonymousUser

from .models import Conversation
from .services import create_and_broadcast_message


# ---------------------------------------------------------------------------
# Helpers ORM (toujours via database_sync_to_async depuis les consumers async)
# ---------------------------------------------------------------------------
def _get_conversation(conversation_id, user_id):
    return Conversation.objects.filter(pk=conversation_id, participants=user_id).first()


def _unread_notification_count(user):
    return user.notifications.filter(is_read=False).count()


# ---------------------------------------------------------------------------
# ChatConsumer — messages temps réel + présence
# ---------------------------------------------------------------------------
class ChatConsumer(AsyncJsonWebsocketConsumer):
    async def connect(self):
        user = self.scope.get('user')
        if user is None or isinstance(user, AnonymousUser) or not user.is_authenticated:
            await self.close()
            return

        self.conversation_id = int(self.scope['url_route']['kwargs']['conversation_id'])
        self.group_name = f'chat_{self.conversation_id}'
        self.user_group = f'user_{user.pk}'  # pk UUID -> str

        # Vérifie l'appartenance à la conversation (autorisation) avant d'accepter
        conv = await db_async(_get_conversation)(self.conversation_id, user.pk)
        if conv is None:
            await self.close()
            return

        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.channel_layer.group_add(self.user_group, self.channel_name)
        await self.accept()

        # Présence : notifie le groupe chat qu'un participant est en ligne
        await self.channel_layer.group_send(
            self.group_name,
            {'type': 'chat.presence', 'user_id': str(user.pk), 'online': True}
        )

    async def disconnect(self, code):
        user = self.scope.get('user')
        if getattr(self, 'group_name', None):
            await self.channel_layer.group_discard(self.group_name, self.channel_name)
            if user and not isinstance(user, AnonymousUser):
                await self.channel_layer.group_send(
                    self.group_name,
                    {'type': 'chat.presence', 'user_id': str(user.pk), 'online': False}
                )
        if getattr(self, 'user_group', None):
            await self.channel_layer.group_discard(self.user_group, self.channel_name)

    async def receive_json(self, content, **kwargs):
        user = self.scope.get('user')
        if not user or isinstance(user, AnonymousUser) or not user.is_authenticated:
            return

        msg_type = content.get('type')
        if msg_type != 'chat.message':
            return

        text = (content.get('content') or '').strip()
        if not text:
            return

        conv = await db_async(_get_conversation)(self.conversation_id, user.pk)
        if conv is None:
            return

        # Création + diffusion via le service partagé (même comportement que le repli HTTP)
        await db_async(create_and_broadcast_message)(conv, user, text)

    # ---- Handlers de diffusion (déclenchés par group_send) ----
    async def chat_message(self, event):
        await self.send_json({'type': 'chat.message', 'message': event['message']})

    async def chat_presence(self, event):
        await self.send_json({'type': 'chat.presence', 'user_id': event['user_id'], 'online': event['online']})

    async def notification_unread(self, event):
        await self.send_json({'type': 'notification.unread', 'count': event['count']})


# ---------------------------------------------------------------------------
# NotificationConsumer — pousse le compte non-lu (remplace le polling 30 s)
# ---------------------------------------------------------------------------
class NotificationConsumer(AsyncJsonWebsocketConsumer):
    async def connect(self):
        user = self.scope.get('user')
        if user is None or isinstance(user, AnonymousUser) or not user.is_authenticated:
            await self.close()
            return

        self.user_group = f'user_{user.pk}'
        await self.channel_layer.group_add(self.user_group, self.channel_name)
        await self.accept()

        # Compte initial des notifications non lues
        count = await db_async(_unread_notification_count)(user)
        await self.send_json({'type': 'notification.unread', 'count': count})

    async def disconnect(self, code):
        if getattr(self, 'user_group', None):
            await self.channel_layer.group_discard(self.user_group, self.channel_name)

    async def notification_unread(self, event):
        await self.send_json({'type': 'notification.unread', 'count': event['count']})
