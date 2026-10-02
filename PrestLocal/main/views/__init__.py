"""Vues du site LesProduFao, organisées par domaine.

Le paquet remplace l'ancien `main/views.py` (600+ lignes, cinq domaines
mélangés). Les vues restent **fines** : elles interprètent la requête,
vérifient les permissions, appellent un service ou un selector, puis
construisent la réponse HTTP. La logique métier est dans `main/services/`, les
requêtes de lecture dans `main/selectors.py`.

`main/urls.py` importe depuis ce paquet : le contrat d'URL est inchangé.
"""

from .comptes import (
    login_view,
    logout_view,
    password_reset_confirm_view,
    password_reset_request_view,
    signup_view,
    verify_email_view,
)
from .notifications import (
    mark_all_notifications_read,
    mark_notification_read,
    notification_list,
    unread_notification_count,
)
from .pages import AboutView, OfflineView, client_dashboard, index
from .portfolio import add_realisation, delete_realisation, submit_evaluation
from .prestataires import (
    PrestataireDetailView,
    PrestataireListView,
    profile_view,
    record_call_click,
    record_contact_click,
    toggle_availability,
    toggle_favorite,
    update_profile,
)

__all__ = [
    'AboutView',
    'OfflineView',
    'PrestataireDetailView',
    'PrestataireListView',
    'add_realisation',
    'client_dashboard',
    'delete_realisation',
    'index',
    'login_view',
    'logout_view',
    'mark_all_notifications_read',
    'mark_notification_read',
    'notification_list',
    'password_reset_confirm_view',
    'password_reset_request_view',
    'profile_view',
    'record_call_click',
    'record_contact_click',
    'signup_view',
    'submit_evaluation',
    'toggle_availability',
    'toggle_favorite',
    'unread_notification_count',
    'update_profile',
    'verify_email_view',
]
