from django.urls import path
from rest_framework import routers
from rest_framework_simplejwt.views import (
    TokenObtainPairView,
    TokenRefreshView,
)

from .views import (
    PrestataireViews,
    MeAPIView,
    LogoutView,
    PasswordResetRequestView,
    PasswordResetConfirmView,
    RegisterView,
    VerifyEmailView,
    VilleListView,
    PrestationListView,
    FeedListView,
    FeedDetailView,
    FeedLikeView,
    FeedCommentView,
)
from Messagerie.api import (
    ConversationListAPIView,
    ConversationDetailAPIView,
    SendMessageAPIView,
    StartConversationAPIView,
)

router = routers.DefaultRouter()
router.register(r"prestataire", PrestataireViews, basename="prestataire")

urlpatterns = [
    path("auth/token/", TokenObtainPairView.as_view(), name="token_obtain_pair"),
    path("auth/token/refresh/", TokenRefreshView.as_view(), name="token_refresh"),
    path("auth/token/logout/", LogoutView.as_view(), name="logout"),
    path("auth/me/", MeAPIView.as_view(), name="me"),
    path("auth/password-reset/", PasswordResetRequestView.as_view(), name="password_reset_request"),
    path("auth/password-reset/confirm/", PasswordResetConfirmView.as_view(), name="password_reset_confirm"),
    path("auth/register/", RegisterView.as_view(), name="register"),
    path("auth/verify-email/", VerifyEmailView.as_view(), name="verify_email"),
    path("villes/", VilleListView.as_view(), name="ville_list"),
    path("prestations/", PrestationListView.as_view(), name="prestation_list"),
    path("feed/", FeedListView.as_view(), name="feed_list"),
    # Spécifiques avant `feed/<int:pk>/` pour ne pas être capturées comme un pk
    path("feed/<int:pk>/like/", FeedLikeView.as_view(), name="feed_like"),
    path("feed/<int:pk>/comment/", FeedCommentView.as_view(), name="feed_comment"),
    path("feed/<int:pk>/", FeedDetailView.as_view(), name="feed_detail"),
    # Messagerie (JSON) — clients mobiles
    path("messagerie/conversations/", ConversationListAPIView.as_view(), name="messagerie_conversations"),
    path("messagerie/conversations/<int:pk>/", ConversationDetailAPIView.as_view(), name="messagerie_conversation"),
    path("messagerie/conversations/<int:pk>/messages/", SendMessageAPIView.as_view(), name="messagerie_send"),
    path("messagerie/conversations/start/<uuid:prestataire_id>/", StartConversationAPIView.as_view(), name="messagerie_start"),
] + router.urls
