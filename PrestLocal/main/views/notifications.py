"""Notifications internes de l'utilisateur connecté (cloche du site)."""

from django.contrib.auth.decorators import login_required
from django.http import JsonResponse
from django.shortcuts import get_object_or_404, render
from django.views.decorators.http import require_POST

from ..models import Notification

#: Nombre de notifications affichées sur la page dédiée.
NOTIFICATIONS_AFFICHEES = 50


@login_required
def notification_list(request):
    notifications = request.user.notifications.all()[:NOTIFICATIONS_AFFICHEES]
    return render(request, 'main/notifications.html', {'notifications': notifications})


@require_POST
@login_required
def mark_notification_read(request, pk):
    notification = get_object_or_404(Notification, pk=pk, recipient=request.user)
    notification.is_read = True
    notification.save(update_fields=['is_read'])
    return JsonResponse({'status': 'ok'})


@require_POST
@login_required
def mark_all_notifications_read(request):
    request.user.notifications.filter(is_read=False).update(is_read=True)
    return JsonResponse({'status': 'ok'})


@login_required
def unread_notification_count(request):
    return JsonResponse(
        {'count': request.user.notifications.filter(is_read=False).count()}
    )
