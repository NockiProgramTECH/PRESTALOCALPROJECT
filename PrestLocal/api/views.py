from django.shortcuts import render, get_object_or_404
from django.views import View
from django.db.models import Avg, Count
from django.utils import timezone


from rest_framework.filters import OrderingFilter
# from pytz import timezone
from rest_framework.viewsets import ReadOnlyModelViewSet,ModelViewSet
from rest_framework.permissions import AllowAny, IsAuthenticated, IsAuthenticatedOrReadOnly
from rest_framework.filters import SearchFilter
from rest_framework.views import APIView
from rest_framework.generics import ListAPIView, ListCreateAPIView
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework.response import Response
from rest_framework import status
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.exceptions import TokenError


from django_filters.rest_framework import DjangoFilterBackend



from .serializers import (
    PrestataireSerializers,
    PrestatireDetailSerialzer,
    UserSerializer,
    PasswordResetRequestSerializer,
    PasswordResetConfirmSerializer,
    RegisterSerializer,
    VerifyEmailSerializer,
    VilleSerializer,
    PrestationListSerializer,
    FeedRealisationSerializer,
    FeedCreateSerializer,
    FeedDetailSerializer,
    CommentaireSerializer,
)
from main.models import Prestataire, Ville, Prestation, Realisation
from Feed.models import Like, Commentaire
from .permissions import IsOwnerOrReadOnly

class PrestataireViews(ModelViewSet):
    serializer_class =PrestataireSerializers
    permission_classes = [IsOwnerOrReadOnly]

    filter_backends =[
        DjangoFilterBackend,
        SearchFilter,
        OrderingFilter
    ]

    #filtre simples
    filterset_fields =[
        'ville',
        'metier',
        'est_verifie',
        "is_available",
    ]

    #recher texte
    search_fields =[
        'first_name',
        'last_name',
        'bio',
        'quartier',

    ]

    #tri 
    ordering_fields =[
       "annee_experience",
       "average_note",
    ]

    def get_serializer_class(self):
        if self.action =="retrieve":
            return PrestatireDetailSerialzer
        return PrestataireSerializers

    def get_queryset(self):
        # NOTE: on ne filtre plus en dur sur l'abonnement payé/actif :
        # - `populate_db.py` ne crée aucun abonnement → liste vide côté mobile.
        # - les nouveaux comptes n'ont pas d'abonnement non plus.
        # La visibilité "abonné en avant" reste exposée via
        # `abonnement_actif` dans le serializer ; le filtre dur pourra
        # être réactivé avec `?abonnes_only=1` si besoin.
        queryset =Prestataire.objects.filter(
            role ='prestataire',
        ).select_related(
            'ville',
            'metier',
            'abonnement'
        ).annotate(
            average_note =Avg('evaluations__note')
        )
        abonnes_only = self.request.query_params.get("abonnes_only")
        if abonnes_only in ("1", "true", "True"):
            queryset = queryset.filter(
                abonnement__paye=True,
                abonnement__est_actif=True,
                abonnement__date_fin__gt=timezone.now(),
            )
    #filtre etoile personnalisé
        etoile =self.request.query_params.get("etoile")
        if etoile:
            queryset =queryset.filter(
                average_note__gte =float(etoile)
            )
        return queryset


# ---------------------------------------------------------------------------
# Vues d'authentification / profil
# ---------------------------------------------------------------------------

class MeAPIView(APIView):
    """Profil de l'utilisateur connecté (GET) et mise à jour (PATCH)."""
    permission_classes = [IsAuthenticated]

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
    """Envoie un code de réinitialisation par email."""
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = PasswordResetRequestSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response(
                {"detail": "Un code de réinitialisation a été envoyé à votre adresse email."},
                status=status.HTTP_200_OK,
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class PasswordResetConfirmView(APIView):
    """Vérifie le code et définit le nouveau mot de passe."""
    permission_classes = [AllowAny]

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
    """Active le compte après validation du code reçu par email."""
    permission_classes = [AllowAny]

    def post(self, request):
        serializer = VerifyEmailSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response(
                {"detail": "Votre email a été vérifié. Vous pouvez maintenant vous connecter."},
                status=status.HTTP_200_OK,
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class VilleListView(ListAPIView):
    """Liste des villes disponibles (menu déroulant du profil)."""
    serializer_class = VilleSerializer
    permission_classes = [IsAuthenticated]
    queryset = Ville.objects.all().order_by('nom')


class PrestationListView(ListAPIView):
    """Liste des métiers/prestations disponibles (profil prestataire)."""
    serializer_class = PrestationListSerializer
    permission_classes = [IsAuthenticated]
    queryset = Prestation.objects.filter(est_actif=True).order_by('nom')


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
        qs = Realisation.objects.select_related(
            'prestataire', 'prestataire__metier', 'prestataire__ville'
        ).annotate(
            like_count=Count('likes'),
            comment_count=Count('commentaires'),
        ).order_by('-date_ajout')
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

    def get(self, request, pk):
        realisation = get_object_or_404(
            Realisation.objects.select_related(
                'prestataire', 'prestataire__metier', 'prestataire__ville'
            ).annotate(
                like_count=Count('likes'),
                comment_count=Count('commentaires'),
            ),
            id=pk,
        )
        serializer = FeedDetailSerializer(
            realisation, context={'request': request}
        )
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

