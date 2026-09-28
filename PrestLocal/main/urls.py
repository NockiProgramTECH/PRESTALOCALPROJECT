from django.urls import path
from .views import (AboutView, index, login_view, logout_view, signup_view,
    verify_email_view, password_reset_request_view, password_reset_confirm_view,
    PrestataireDetailView, submit_evaluation, PrestataireListView,
    profile_view, update_profile, toggle_availability, record_call_click,
    record_contact_click, add_realisation, delete_realisation, OfflineView,
    toggle_favorite, notification_list, mark_notification_read,
    mark_all_notifications_read, unread_notification_count, client_dashboard)

app_name = 'main'

urlpatterns = [
    path("", index, name="index"),
    path("login/", login_view, name="login"),
    path("signup/", signup_view, name="signup"),
    path("verify-email/", verify_email_view, name="verify_email"),
    path("password-reset/", password_reset_request_view, name="password_reset_request"),
    path("password-reset/confirm/", password_reset_confirm_view, name="password_reset_confirm"),
    path("logout/", logout_view, name="logout"),


    path("profile/", profile_view, name="profile"),
    path("profile/update/", update_profile, name="update_profile"),
    path("profile/toggle-availability/", toggle_availability, name="toggle_availability"),
    path("profile/realisation/add/", add_realisation, name="add_realisation"),
    path("profile/realisation/delete/<int:pk>/", delete_realisation, name="delete_realisation"),
    path("prestataires/", PrestataireListView.as_view(), name="prestataire_list"),
    path("prestataire/<uuid:pk>/", PrestataireDetailView.as_view(), name="prestataire_detail"),
    path("prestataire/<uuid:pk>/evaluer/", submit_evaluation, name="submit_evaluation"),
    path("prestataire/<uuid:pk>/record-call/", record_call_click, name="record_call_click"),
    path("prestataire/<uuid:pk>/record-contact/", record_contact_click, name="record_contact_click"),
    path("offline/", OfflineView.as_view(), name="offline"),
    path("about/", AboutView.as_view(), name="about"),

    # Favoris
    path("favorite/toggle/<uuid:pk>/", toggle_favorite, name="toggle_favorite"),

    # Notifications
    path("notifications/", notification_list, name="notifications"),
    path("notifications/<int:pk>/read/", mark_notification_read, name="mark_notification_read"),
    path("notifications/read-all/", mark_all_notifications_read, name="mark_all_notifications_read"),
    path("notifications/unread-count/", unread_notification_count, name="unread_notification_count"),

    # Client
    path("client/dashboard/", client_dashboard, name="client_dashboard"),
]
