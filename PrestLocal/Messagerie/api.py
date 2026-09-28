"""API REST JSON de la messagerie — destinée aux clients mobiles (Flutter).

Authentification : JWT (Bearer) via la config DRF par défaut.
Présence en ligne : délivrée en temps réel via les événements WebSocket
(`chat.presence`), pas via cette API.
"""

from django.contrib.auth import get_user_model
from django.shortcuts import get_object_or_404
from rest_framework import serializers, status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Conversation, Message
from .services import create_and_broadcast_message


class ParticipantSerializer(serializers.Serializer):
    id = serializers.CharField()
    first_name = serializers.CharField()
    last_name = serializers.CharField()
    full_name = serializers.SerializerMethodField()
    photo_url = serializers.SerializerMethodField()
    role = serializers.CharField()

    def get_full_name(self, obj):
        return f"{obj.first_name} {obj.last_name}".strip()

    def get_photo_url(self, obj):
        photo = getattr(obj, 'photo_profil', None)
        return photo.url if photo else None


class MessageSerializer(serializers.ModelSerializer):
    sender_id = serializers.SerializerMethodField()

    class Meta:
        model = Message
        fields = ['id', 'sender_id', 'content', 'created_at']

    def get_sender_id(self, obj):
        return str(obj.sender_id)


class ConversationSerializer(serializers.ModelSerializer):
    participant = serializers.SerializerMethodField()
    last_message = serializers.SerializerMethodField()
    unread_count = serializers.SerializerMethodField()

    class Meta:
        model = Conversation
        fields = ['id', 'participant', 'last_message', 'unread_count', 'updated_at']

    def get_participant(self, obj):
        user = self.context['request'].user
        other = obj.participants.exclude(pk=user.pk).first()
        return ParticipantSerializer(other).data if other else None

    def get_last_message(self, obj):
        m = obj.messages.last()
        return MessageSerializer(m).data if m else None

    def get_unread_count(self, obj):
        return obj.messages.filter(is_read=False).exclude(sender=self.context['request'].user).count()


class ConversationListAPIView(APIView):
    """Liste les conversations de l'utilisateur connecté."""
    permission_classes = [IsAuthenticated]

    def get(self, request):
        convs = request.user.conversations.all().prefetch_related('participants', 'messages')
        return Response(ConversationSerializer(convs, many=True, context={'request': request}).data)


class ConversationDetailAPIView(APIView):
    """Historique des messages d'une conversation (marque les non-lus comme lus)."""
    permission_classes = [IsAuthenticated]

    def get(self, request, pk):
        conv = get_object_or_404(Conversation, pk=pk, participants=request.user)
        conv.messages.filter(is_read=False).exclude(sender=request.user).update(is_read=True)
        messages = conv.messages.select_related('sender').order_by('created_at')

        data = {
            'id': conv.pk,
            'participant': ConversationSerializer(conv, context={'request': request}).data['participant'],
            'messages': MessageSerializer(messages, many=True).data,
        }
        return Response(data)


class SendMessageAPIView(APIView):
    """Envoie un message (crée + diffuse au groupe WebSocket)."""
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        conv = get_object_or_404(Conversation, pk=pk, participants=request.user)
        content = (request.data.get('content') or '').strip()
        if not content:
            return Response({'error': 'Contenu manquant.'}, status=status.HTTP_400_BAD_REQUEST)

        msg = create_and_broadcast_message(conv, request.user, content)
        return Response(MessageSerializer(msg).data, status=status.HTTP_201_CREATED)


class StartConversationAPIView(APIView):
    """Crée ou retrouve une conversation avec un prestataire."""
    permission_classes = [IsAuthenticated]

    def post(self, request, prestataire_id):
        prestataire = get_object_or_404(get_user_model(), pk=prestataire_id)

        existing = Conversation.objects.filter(participants=request.user).filter(participants=prestataire).first()
        conv = existing
        if conv is None:
            conv = Conversation.objects.create()
            conv.participants.add(request.user, prestataire)
        return Response({'conversation_id': conv.pk})
