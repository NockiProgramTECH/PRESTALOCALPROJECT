"""Vues de l'API REST, organisées par domaine.

Le paquet remplace l'ancien `api/views.py` (800 lignes, six domaines mêlés).
Les vues restent fines : permissions, validation de frontière, appel d'un
service (`main.services`, `Feed.services`) ou d'un selector (`api.selectors`),
puis mise en forme de la réponse.

`api/urls.py` importe depuis ce paquet : le contrat des routes est inchangé."""

from .prestataires import (
    PrestataireViews,
)

from .comptes import (
    MeAPIView,
    LogoutView,
    PasswordResetRequestView,
    PasswordResetConfirmView,
    RegisterView,
    VerifyEmailView,
)

from .reference import (
    VilleListView,
    PrestationListView,
    CategorieListView,
    MyFavoritesView,
)

from .feed import (
    FeedPagination,
    FeedListView,
    FeedDetailView,
    FeedLikeView,
    FeedCommentView,
)

from .abonnement import (
    PlanAbonnementListView,
    MonAbonnementView,
    SouscrireAbonnementView,
)

__all__ = [
    'PrestataireViews',
    'MeAPIView',
    'LogoutView',
    'PasswordResetRequestView',
    'PasswordResetConfirmView',
    'RegisterView',
    'VerifyEmailView',
    'VilleListView',
    'PrestationListView',
    'CategorieListView',
    'MyFavoritesView',
    'FeedPagination',
    'FeedListView',
    'FeedDetailView',
    'FeedLikeView',
    'FeedCommentView',
    'PlanAbonnementListView',
    'MonAbonnementView',
    'SouscrireAbonnementView',
]
