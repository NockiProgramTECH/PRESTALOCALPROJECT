"""Vues de l'API REST LesProduFao (DRF).

Organisation :

- `PrestataireViews`  : liste / détail des prestataires + actions
  (`evaluer`, `toggle_favorite`, `realisations`).
- Authentification     : JWT (connexion, refresh, logout), inscription,
  vérification email, réinitialisation du mot de passe.
- Données de référence : villes, métiers (`prestations`), catégories.
- Fil d'actualité      : réalisations, likes, commentaires.
- Favoris              : `GET /api/me/favorites/`.

Sécurité : les endpoints sensibles (inscription, mot de passe, avis) sont
limités par `throttle_scope` (voir `DEFAULT_THROTTLE_RATES` dans settings).
"""

from django.core.cache import cache
from django.db.models import Avg, Count
from django.shortcuts import get_object_or_404
from django.utils import timezone

from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import status
from rest_framework.decorators import action
from rest_framework.filters import OrderingFilter, SearchFilter
from rest_framework.generics import ListAPIView, ListCreateAPIView
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.permissions import (
    AllowAny,
    IsAuthenticated,
    IsAuthenticatedOrReadOnly,
)
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView
from rest_framework.viewsets import ModelViewSet
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import RefreshToken

from Feed.models import Commentaire, Like
from main.models import (
    CategoriePrestation,
    Evaluation,
    Favorite,
    Prestataire,
    Prestation,
    Realisation,
    Ville,
)

from .permissions import IsOwnerOrReadOnly
from Abonnement.models import Abonnement, PlanAbonnement

from .serializers import (
    AbonnementSerializer,
    CategorieSerializer,
    CommentaireSerializer,
    EvaluationCreateSerializer,
    EvaluationSerializer,
    FeedCreateSerializer,
    FeedDetailSerializer,
    FeedRealisationSerializer,
    PasswordResetConfirmSerializer,
    DEFAULT_PLANS,
    PasswordResetRequestSerializer,
    PlanAbonnementSerializer,
    PrestataireSerializers,
    PrestationListSerializer,
    PrestatireDetailSerialzer,
    RegisterSerializer,
    SouscriptionAbonnementSerializer,
    UserSerializer,
    VerifyEmailSerializer,
    VilleSerializer,
)


class PrestataireViews(ModelViewSet):
    """Prestataires de services.

    - `GET /api/prestataire/` : liste filtrée / recherchée / triée.
      Filtres : `ville`, `metier`, `est_verifie`, `is_available`,
      `categorie`, `quartier`, `etoile` (note minimale), `abonnes_only`.
      Recherche : `search=` (prénom, nom, bio, quartier).
      Tri : `ordering=annee_experience|-moyenne_etoile|date_inscription`.
    - `GET /api/prestataire/{id}/` : fiche complète (réalisations, avis).
    - `POST /api/prestataire/{id}/evaluer/` : déposer / mettre à jour un avis.
    - `POST /api/prestataire/{id}/toggle_favorite/` : ajouter / retirer des favoris.
    """

    serializer_class = PrestataireSerializers
    permission_classes = [IsOwnerOrReadOnly]
    # `throttle_scope` est surchargé par l'action `evaluer` (voir plus bas).
    throttle_scope = None

    filter_backends = [DjangoFilterBackend, SearchFilter, OrderingFilter]

    # Filtres simples
    filterset_fields = [
        'ville',
        'metier',
        'est_verifie',
        'is_available',
    ]

    # Recherche texte
    search_fields = [
        'first_name',
        'last_name',
        'bio',
        'quartier',
    ]

    # Tri
    ordering_fields = [
        'annee_experience',
        'date_inscription',
        'first_name',
    ]

    def get_serializer_class(self):
        if self.action == 'retrieve':
            return PrestatireDetailSerialzer
        return PrestataireSerializers

    def get_queryset(self):
        # NOTE: on ne filtre plus en dur sur l'abonnement payé/actif :
        # - `populate_db.py` ne crée aucun abonnement → liste vide côté mobile.
        # - les nouveaux comptes n'ont pas d'abonnement non plus.
        # La visibilité « abonné en avant » reste exposée via
        # `abonnement_actif` dans le serializer ; le filtre dur peut être
        # réactivé avec `?abonnes_only=1`.
        queryset = (
            Prestataire.objects.filter(role=Prestataire.ROLE_PRESTATAIRE)
            .select_related('ville', 'metier', 'abonnement')
            .prefetch_related('realisations__likes', 'realisations__commentaires', 'evaluations')
            .annotate(average_note=Avg('evaluations__note'))
            # Tri par défaut : évite une pagination incohérente (OrderedObjectList).
            .order_by('first_name', 'last_name')
        )

        params = self.request.query_params

        if params.get('abonnes_only') in ('1', 'true', 'True'):
            queryset = queryset.filter(
                abonnement__paye=True,
                abonnement__est_actif=True,
                abonnement__date_fin__gt=timezone.now(),
            )

        # Filtre par catégorie de prestation (chips de l'accueil / recherche)
        categorie = params.get('categorie')
        if categorie:
            queryset = queryset.filter(metier__categorie_id=categorie)

        quartier = params.get('quartier')
        if quartier:
            queryset = queryset.filter(quartier__icontains=quartier)

        # Filtre étoiles personnalisé (note minimale)
        etoile = params.get('etoile')
        if etoile:
            try:
                queryset = queryset.filter(average_note__gte=float(etoile))
            except (TypeError, ValueError):
                pass

        return queryset

    # ------------------------------------------------------------------
    # Actions
    # ------------------------------------------------------------------
    @action(
        detail=True,
        methods=['post'],
        permission_classes=[IsAuthenticated],
        throttle_classes=[ScopedRateThrottle],
        throttle_scope='review',
    )
    def evaluer(self, request, pk=None):
        """Dépose (ou met à jour) l'avis de l'utilisateur connecté.

        Corps : `{"note": 1-5, "commentaire": "...", "prenom": "", "nom": ""}`.
        Un client ne peut pas s'auto-évaluer et ne peut laisser qu'un avis
        par prestataire (le second appel met à jour le premier).
        """
        prestataire = self.get_object()
        if prestataire.pk == request.user.pk:
            return Response(
                {"detail": "Vous ne pouvez pas vous évaluer vous-même."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        serializer = EvaluationCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        evaluation, created = Evaluation.objects.update_or_create(
            prestataire=prestataire,
            client=request.user,
            defaults={
                'note': serializer.validated_data['note'],
                'commentaire': serializer.validated_data['commentaire'],
                # Dénormalisation (affichage sans jointure, comme côté web)
                'client_nom': request.data.get('nom') or request.user.last_name or '',
                'client_prenom': (
                    request.data.get('prenom') or request.user.first_name or ''
                ),
                'client_email': request.user.email,
            },
        )

        # Statistiques recalculées en base : `prestataire` a été chargé avec
        # `prefetch_related('evaluations')`, son cache est donc périmé.
        stats = Evaluation.objects.filter(prestataire=prestataire).aggregate(
            moyenne=Avg('note'), total=Count('id')
        )

        return Response(
            {
                'detail': "Avis enregistré." if created else "Avis mis à jour.",
                'evaluation': EvaluationSerializer(evaluation).data,
                'moyenne_etoile': round(stats['moyenne'] or 0, 2),
                'nombre_avis': stats['total'],
            },
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )

    @action(detail=True, methods=['post'], url_path='toggle_favorite',
            permission_classes=[IsAuthenticated])
    def toggle_favorite(self, request, pk=None):
        """Ajoute ou retire le prestataire des favoris (toggle).

        Réponse : `{"status": "added"|"removed", "is_favorite": bool, "count": n}`.
        """
        prestataire = self.get_object()
        favorite, created = Favorite.objects.get_or_create(
            user=request.user, prestataire=prestataire
        )
        if created:
            action_label = 'added'
        else:
            favorite.delete()
            action_label = 'removed'

        return Response(
            {
                'status': action_label,
                'is_favorite': created,
                'count': Favorite.objects.filter(user=request.user).count(),
            }
        )

    @action(detail=True, methods=['get'])
    def realisations(self, request, pk=None):
        """Portfolio d'un prestataire (galerie de réalisations)."""
        prestataire = self.get_object()
        realisations = prestataire.realisations.prefetch_related(
            'likes', 'commentaires'
        ).order_by('-date_ajout')
        serializer = FeedRealisationSerializer(
            realisations, many=True, context={'request': request}
        )
        return Response(serializer.data)


# ---------------------------------------------------------------------------
# Vues d'authentification / profil
# ---------------------------------------------------------------------------

class MeAPIView(APIView):
    """Profil de l'utilisateur connecté (GET) et mise à jour (PATCH).

    Accepte le JSON et le `multipart/form-data` (upload de `photo_profil`).
    """
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get(self, request):
        serializer = UserSerializer(request.user, context={'request': request})
        return Response(serializer.data)

    def patch(self, request):
        serializer = UserSerializer(
            request.user,
            data=request.data,
            partial=True,
            context={'request': request},
        )
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class LogoutView(APIView):
    """Révoque le refresh token fourni (blacklist)."""
    permission_classes = [IsAuthenticated]

    def post(self, request):
        refresh = request.data.get('refresh')
        if not refresh:
            return Response(
                {"detail": "Le refresh token est requis."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            token = RefreshToken(refresh)
            token.blacklist()
        except TokenError:
            # Token déjà révoqué ou invalide : on considère la déconnexion réussie.
            pass
        return Response(status=status.HTTP_204_NO_CONTENT)


class PasswordResetRequestView(APIView):
    """Envoie un code de réinitialisation par email.

    Réponse volontairement identique (200) pour toute adresse, connue ou non.
    """
    permission_classes = [AllowAny]
    throttle_scope = 'auth'

    def post(self, request):
        serializer = PasswordResetRequestSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response(
                {"detail": "Si un compte existe pour cette adresse, un code de réinitialisation vient d'être envoyé."},
                status=status.HTTP_200_OK,
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class PasswordResetConfirmView(APIView):
    """Vérifie le code et définit le nouveau mot de passe."""
    permission_classes = [AllowAny]
    throttle_scope = 'auth'

    def post(self, request):
        serializer = PasswordResetConfirmSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response(
                {"detail": "Votre mot de passe a été réinitialisé avec succès."},
                status=status.HTTP_200_OK,
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class RegisterView(APIView):
    """Crée un compte et envoie un code de vérification par email."""
    permission_classes = [AllowAny]
    throttle_scope = 'auth'

    def post(self, request):
        serializer = RegisterSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response(
                {"detail": "Compte créé. Un code de vérification a été envoyé à votre adresse email."},
                status=status.HTTP_201_CREATED,
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class VerifyEmailView(APIView):
    """Active le compte après validation du code reçu par email.

    Le compte est **immédiatement connecté** : la réponse contient les jetons
    JWT (comme `/auth/token/`) ainsi que le profil, ce qui évite de redemander
    à l'utilisateur de saisir ses identifiants juste après l'inscription.
    """
    permission_classes = [AllowAny]
    throttle_scope = 'auth'

    def post(self, request):
        serializer = VerifyEmailSerializer(data=request.data)
        if serializer.is_valid():
            # Un compte déjà vérifié ne reçoit jamais de jetons ici : le code
            # n'est plus vérifiable, seule une connexion avec mot de passe est
            # légitime (sinon l'email seul suffirait à se connecter).
            if serializer.validated_data.get('already_active'):
                return Response(
                    {"detail": "Cet email est déjà vérifié. Connectez-vous."},
                    status=status.HTTP_200_OK,
                )
            user = serializer.save()
            refresh = RefreshToken.for_user(user)
            return Response(
                {
                    "detail": "Votre email a été vérifié. Vous êtes maintenant connecté.",
                    "access": str(refresh.access_token),
                    "refresh": str(refresh),
                    "user": UserSerializer(user, context={'request': request}).data,
                },
                status=status.HTTP_200_OK,
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class VilleListView(ListAPIView):
    """Liste des villes disponibles (menus déroulants : inscription, profil)."""
    serializer_class = VilleSerializer
    # Données publiques de référence : pas besoin d'être connecté.
    permission_classes = [AllowAny]
    pagination_class = None
    queryset = Ville.objects.all().order_by('nom')

    def list(self, request, *args, **kwargs):
        # Ces listes changent très rarement : mises en cache 1 heure.
        data = cache.get('api:villes')
        if data is None:
            data = VilleSerializer(self.get_queryset(), many=True).data
            cache.set('api:villes', data, 3600)
        return Response(data)


class PrestationListView(ListAPIView):
    """Liste des métiers/prestations disponibles (profil prestataire)."""
    serializer_class = PrestationListSerializer
    permission_classes = [AllowAny]
    pagination_class = None
    queryset = Prestation.objects.filter(est_actif=True).order_by('nom')

    def list(self, request, *args, **kwargs):
        data = cache.get('api:prestations')
        if data is None:
            data = PrestationListSerializer(self.get_queryset(), many=True).data
            cache.set('api:prestations', data, 3600)
        return Response(data)


class CategorieListView(ListAPIView):
    """Catégories de prestations (chips de l'accueil / recherche mobile)."""
    serializer_class = CategorieSerializer
    permission_classes = [AllowAny]
    pagination_class = None
    queryset = CategoriePrestation.objects.all().order_by('nom')

    def list(self, request, *args, **kwargs):
        data = cache.get('api:categories')
        if data is None:
            data = CategorieSerializer(
                self.get_queryset(), many=True, context={'request': request}
            ).data
            cache.set('api:categories', data, 600)
        return Response(data)


class MyFavoritesView(ListAPIView):
    """Prestataires favoris de l'utilisateur connecté.

    `GET /api/me/favorites/` → liste paginée (clé `results`) de prestataires,
    au même format que `GET /api/prestataire/`.
    """
    serializer_class = PrestataireSerializers
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return (
            Prestataire.objects.filter(favorited_by__user=self.request.user)
            .select_related('ville', 'metier', 'abonnement')
            .prefetch_related('realisations__likes', 'realisations__commentaires', 'evaluations')
            .annotate(average_note=Avg('evaluations__note'))
            .order_by('-favorited_by__created_at')
        )


class FeedListView(ListCreateAPIView):
    """Fil d'actualité : réalisations des prestataires locaux.

    - GET (public) : liste paginée (clé `results`) des réalisations, avec
      les infos du prestataire auteur, triées de la plus récente à la plus
      ancienne.
    - POST (authentifié, multipart `titre` + `image`) : publie une
      réalisation pour le compte connecté (comme `add_realisation` côté web).
    """
    permission_classes = [IsAuthenticatedOrReadOnly]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return FeedCreateSerializer
        return FeedRealisationSerializer

    def get_queryset(self):
        # Comme le portfolio web (`profile_view`) : grille perso + feed global.
        # - `?mine=1` : réalisations du compte connecté (Mon Portfolio mobile).
        # - `?prestataire=<uuid>` : réalisations d'un prestataire donné.
        # NB: `distinct=True` est indispensable quand on agrège deux relations
        # multiples dans la même requête (sinon les compteurs sont multipliés).
        qs = (
            Realisation.objects.select_related(
                'prestataire', 'prestataire__metier', 'prestataire__ville'
            )
            .annotate(
                like_count=Count('likes', distinct=True),
                comment_count=Count('commentaires', distinct=True),
            )
            .order_by('-date_ajout')
        )
        if self.request.query_params.get('mine') in ('1', 'true', 'True'):
            if self.request.user.is_authenticated:
                return qs.filter(prestataire=self.request.user)
            return qs.none()
        prestataire_id = self.request.query_params.get('prestataire')
        if prestataire_id:
            return qs.filter(prestataire__id=prestataire_id)
        return qs

    def perform_create(self, serializer):
        serializer.save(prestataire=self.request.user)


class FeedDetailView(APIView):
    """Détail d'une réalisation (image, auteur, likes, commentaires).

    GET public. DELETE authentifié + propriétaire uniquement
    (comme `delete_realisation` côté web).
    """
    permission_classes = [IsAuthenticatedOrReadOnly]

    def get_object(self, pk):
        return get_object_or_404(
            Realisation.objects.select_related(
                'prestataire', 'prestataire__metier', 'prestataire__ville'
            )
            .prefetch_related('commentaires__user', 'likes')
            .annotate(
                like_count=Count('likes', distinct=True),
                comment_count=Count('commentaires', distinct=True),
            ),
            id=pk,
        )

    def get(self, request, pk):
        realisation = self.get_object(pk)
        serializer = FeedDetailSerializer(realisation, context={'request': request})
        return Response(serializer.data)

    def delete(self, request, pk):
        realisation = get_object_or_404(
            Realisation, id=pk, prestataire=request.user
        )
        realisation.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class FeedLikeView(APIView):
    """Aime ou retire le like d'une réalisation (toggle)."""
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        realisation = get_object_or_404(Realisation, id=pk)
        like, created = Like.objects.get_or_create(
            user=request.user, realisation=realisation
        )
        if not created:
            like.delete()
            liked = False
        else:
            liked = True
        return Response({
            'liked': liked,
            'like_count': realisation.likes.count(),
        })


class FeedCommentView(APIView):
    """Ajoute un commentaire à une réalisation."""
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        realisation = get_object_or_404(Realisation, id=pk)
        contenu = (request.data.get('contenu') or '').strip()
        if not contenu:
            return Response(
                {'detail': 'Le commentaire est vide.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        commentaire = Commentaire.objects.create(
            user=request.user,
            realisation=realisation,
            contenu=contenu,
        )
        serializer = CommentaireSerializer(commentaire)
        return Response({
            'comment': serializer.data,
            'comment_count': realisation.commentaires.count(),
        }, status=status.HTTP_201_CREATED)


# ---------------------------------------------------------------------------
# Abonnement des prestataires
# ---------------------------------------------------------------------------
def _ensure_default_plans():
    """Crée les offres par défaut si la base n'en contient aucune.

    Même comportement que la page web « Abonnement » : la plateforme reste
    utilisable même sur une base neuve où `populate_db` n'a pas été lancé.
    """
    if PlanAbonnement.objects.exists():
        return
    for nom, prix, duree, description in DEFAULT_PLANS:
        PlanAbonnement.objects.get_or_create(
            nom=nom,
            defaults={
                'prix': prix,
                'duree_jours': duree,
                'description': description,
            },
        )


class PlanAbonnementListView(ListAPIView):
    """Offres d'abonnement disponibles (`GET /api/abonnement/plans/`).

    Tarifs publics : consultables avant même la connexion.
    """
    serializer_class = PlanAbonnementSerializer
    permission_classes = [AllowAny]
    pagination_class = None

    def get_queryset(self):
        _ensure_default_plans()
        return PlanAbonnement.objects.all().order_by('prix')


class MonAbonnementView(APIView):
    """État de l'abonnement du prestataire connecté.

    Réponse : `{"actif": bool, "abonnement": {...}|null}`.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not request.user.is_prestataire:
            return Response(
                {"detail": "L'abonnement est réservé aux comptes prestataires."},
                status=status.HTTP_403_FORBIDDEN,
            )
        try:
            abonnement = request.user.abonnement
        except Abonnement.DoesNotExist:
            abonnement = None

        return Response({
            'actif': bool(abonnement and abonnement.est_valide),
            'abonnement': (
                AbonnementSerializer(abonnement).data if abonnement else None
            ),
        })


class SouscrireAbonnementView(APIView):
    """Souscription d'un prestataire à une offre (`POST /api/abonnement/souscrire/`).

    Corps : `{"plan": <id>, "methode": "Orange Money"|"Moov Money"|"Wave",
    "otp": "123456"}`. Le paiement est simulé (comme sur le site web) : un code
    à 6 chiffres active immédiatement l'abonnement, qui met le profil en avant
    dans les résultats de recherche.
    """
    permission_classes = [IsAuthenticated]
    throttle_scope = 'auth'

    def post(self, request):
        if not request.user.is_prestataire:
            return Response(
                {"detail": "Seuls les prestataires peuvent s'abonner."},
                status=status.HTTP_403_FORBIDDEN,
            )

        serializer = SouscriptionAbonnementSerializer(
            data=request.data, context={'request': request},
        )
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        abonnement = serializer.save()
        plan = abonnement.plan
        return Response(
            {
                'detail': (
                    f"Paiement réussi ! Votre abonnement « {plan.nom} » est actif "
                    f"jusqu'au {abonnement.date_fin.strftime('%d/%m/%Y')}. "
                    "Votre profil est désormais mis en avant."
                ),
                'actif': abonnement.est_valide,
                'abonnement': AbonnementSerializer(abonnement).data,
            },
            status=status.HTTP_201_CREATED,
        )
