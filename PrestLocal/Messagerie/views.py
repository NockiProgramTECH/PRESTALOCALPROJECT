from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.views.decorators.http import require_POST
from django.http import JsonResponse
from django.contrib import messages
from django.db.models import Q

from .models import Conversation
from .services import create_and_broadcast_message
from main.models import Prestataire


@login_required
def inbox(request):
    conversations = request.user.conversations.all().prefetch_related('participants', 'messages')
    for conv in conversations:
        conv.unread = conv.messages.filter(is_read=False).exclude(sender=request.user).count()
    return render(request, 'messagerie/inbox.html', {'conversations': conversations})


@login_required
def conversation_detail(request, pk):
    conversation = get_object_or_404(Conversation, pk=pk, participants=request.user)

    if request.method == 'POST':
        content = request.POST.get('content', '').strip()
        if content:
            # Création + diffusion temps réel via le service partagé
            msg = create_and_broadcast_message(conversation, request.user, content)

            if request.headers.get('x-requested-with') == 'XMLHttpRequest':
                return JsonResponse({
                    'status': 'ok',
                    'sender': request.user.first_name,
                    'content': content,
                    'created_at': msg.created_at.isoformat()
                })
        return redirect('Messagerie:conversation_detail', pk=pk)

    # Marquer les messages comme lus
    conversation.messages.filter(is_read=False).exclude(sender=request.user).update(is_read=True)

    messages_list = conversation.messages.select_related('sender').all()
    other_participants = conversation.participants.exclude(pk=request.user.pk)

    return render(request, 'messagerie/conversation.html', {
        'conversation': conversation,
        'messages': messages_list,
        'other_participants': other_participants,
    })


@login_required
def start_conversation(request, prestataire_id):
    prestataire = get_object_or_404(Prestataire, pk=prestataire_id)

    # Vérifier si une conversation existe déjà entre ces deux utilisateurs
    existing = Conversation.objects.filter(
        participants=request.user
    ).filter(
        participants=prestataire
    )

    if existing.exists():
        return redirect('Messagerie:conversation_detail', pk=existing.first().pk)

    # Créer une nouvelle conversation
    conv = Conversation.objects.create()
    conv.participants.add(request.user, prestataire)

    return redirect('Messagerie:conversation_detail', pk=conv.pk)


@login_required
def unread_message_count(request):
    conversations = request.user.conversations.all()
    total = 0
    for conv in conversations:
        total += conv.messages.filter(is_read=False).exclude(sender=request.user).count()
    return JsonResponse({'count': total})
