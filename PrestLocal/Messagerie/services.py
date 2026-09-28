"""
Service de messagerie temps réel.

Point unique de création + diffusion d'un message, partagé entre le chemin
WebSocket (ChatConsumer) et le repli HTTP (conversation_detail). Garantit que
toute diffusion passe par le channel layer, quelle que soit la voie utilisée.
"""

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer

from .models import Message
from main.models import Notification


def create_and_broadcast_message(conversation, sender, content):
    """
    Crée un Message, notifie les autres participants et diffuse le message
    + le compte non-lu à tous les participants via le channel layer.

    Renvoie le Message créé.
    """
    msg = Message.objects.create(conversation=conversation, sender=sender, content=content)
    conversation.save()  # met à jour updated_at

    link = f"/messages/{conversation.pk}/"
    counts = {}
    for participant in conversation.participants.exclude(pk=sender.pk):
        Notification.objects.create(
            recipient=participant,
            actor=sender,
            notification_type='message',
            message=f"{sender.first_name} vous a envoyé un message",
            link=link,
        )
        counts[str(participant.pk)] = participant.notifications.filter(is_read=False).count()
    # L'expéditeur n'a pas de nouvelle notification, mais on pousse son vrai
    # compte pour ne pas effacer son badge.
    counts[str(sender.pk)] = sender.notifications.filter(is_read=False).count()

    channel_layer = get_channel_layer()

    # Diffuse le message au groupe chat (le sender filtre son propre écho côté client)
    async_to_sync(channel_layer.group_send)(
        f'chat_{conversation.pk}',
        {'type': 'chat.message', 'message': {
            'id': msg.pk,
            'sender_id': str(sender.pk),
            'content': content,
            'created_at': msg.created_at.isoformat(),
        }},
    )

    # Pousse le compte non-lu à chaque participant (badge temps réel)
    for pid, cnt in counts.items():
        async_to_sync(channel_layer.group_send)(
            f'user_{pid}',
            {'type': 'notification.unread', 'count': cnt},
        )

    return msg
