"""Vues DRF du fil d'actualité (publications, likes, commentaires)."""

from django.db.models import Q
from django.shortcuts import get_object_or_404

from rest_framework import status
from rest_framework.generics import ListCreateAPIView
from rest_framework.pagination import PageNumberPagination
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated, IsAuthenticatedOrReadOnly
from rest_framework.response import Response
from rest_framework.views import APIView

from Feed.models import Realisation
from Feed.services import (
    CommentaireVide,
    ajouter_commentaire,
    basculer_like,
    compter_commentaires,
)

from .. import selectors
from ..serializers import (
    CommentaireSerializer,
    FeedCreateSerializer,
    FeedDetailSerializer,
    FeedRealisationSerializer,
    FeedUpdateSerializer,
)


class FeedPagination(PageNumberPagination):
    """Pagination du fil : 10 par défaut, 50 au maximum.

    L'application mobile peut demander `?page_size=` (rafraîchissement de
    l'accueil) tout en gardant un plafond qui évite de charger tout le fil.
    """
    page_size = 10
    page_size_query_param = 'page_size'
    max_page_size = 50


class FeedListView(ListCreateAPIView):
    """Fil d'actualité communautaire.

    - `GET` (public) : publications paginées (« results », 10 par page),
      triées de la plus récente à la plus ancienne. Filtres :
      `?mine=1` (mes publications), `?prestataire=<uuid>`,
      `?categorie=<id>`, `?search=<texte>`.
    - `POST` (authentifié, multipart) : publie un contenu pour le compte
      connecté. Champs : `contenu` (texte), `titre`, `images` (1 à 10),
      `video`, `lien`, `categorie`.
    """
    permission_classes = [IsAuthenticatedOrReadOnly]
    parser_classes = [MultiPartParser, FormParser, JSONParser]
    pagination_class = FeedPagination

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return FeedCreateSerializer
        return FeedRealisationSerializer

    def _base_queryset(self):
        """Publications annotées (compteurs + like du lecteur) et préchargées.

        Requête écrite une seule fois pour le site et l'API
        (`Feed.selectors.publications_annotees`) : la vue ne fait que
        l'appeler avec l'utilisateur courant.
        """
        return selectors.publications_api(self.request.user)

    def get_queryset(self):
        qs = self._base_queryset().order_by('-date_ajout')
        params = self.request.query_params

        if params.get('mine') in ('1', 'true', 'True'):
            if self.request.user.is_authenticated:
                return qs.filter(prestataire=self.request.user)
            return qs.none()

        prestataire_id = params.get('prestataire')
        if prestataire_id:
            qs = qs.filter(prestataire__id=prestataire_id)

        categorie = params.get('categorie')
        if categorie:
            qs = qs.filter(categorie_id=categorie)

        search = (params.get('search') or '').strip()
        if search:
            qs = qs.filter(
                Q(contenu__icontains=search)
                | Q(titre__icontains=search)
                | Q(prestataire__first_name__icontains=search)
                | Q(prestataire__last_name__icontains=search)
            )
        return qs

    def create(self, request, *args, **kwargs):
        """Publie le contenu et renvoie la publication complète (201)."""
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        realisation = serializer.save(prestataire=request.user)

        # Relecture annotée : la réponse contient les compteurs et les
        # permissions, ce qui permet à l'application d'insérer la publication
        # en tête du fil sans second appel.
        publication = self._base_queryset().get(pk=realisation.pk)
        output = FeedRealisationSerializer(
            publication, context=self.get_serializer_context()
        )
        return Response(output.data, status=status.HTTP_201_CREATED)


class FeedDetailView(APIView):
    """Détail, modification et suppression d'une publication.

    - `GET` public : publication complète + commentaires.
    - `PATCH` : **auteur uniquement** (texte, titre, lien, catégorie).
    - `DELETE` : auteur, ou rôle de modération (`is_staff`).
    """
    permission_classes = [IsAuthenticatedOrReadOnly]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get_object(self, pk):
        """Publication annotée (mêmes annotations que la liste du fil)."""
        return get_object_or_404(selectors.publications_api(), id=pk)

    def get(self, request, pk):
        realisation = self.get_object(pk)
        serializer = FeedDetailSerializer(
            realisation, context={'request': request}
        )
        return Response(serializer.data)

    def patch(self, request, pk):
        realisation = self.get_object(pk)
        if realisation.prestataire_id != request.user.id:
            return Response(
                {"detail": "Vous ne pouvez modifier que vos propres publications."},
                status=status.HTTP_403_FORBIDDEN,
            )
        serializer = FeedUpdateSerializer(
            realisation, data=request.data, partial=True
        )
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        serializer.save()

        # Relecture annotée : compteurs et permissions à jour.
        realisation = self.get_object(pk)
        return Response(
            FeedDetailSerializer(realisation, context={'request': request}).data
        )

    def delete(self, request, pk):
        realisation = self.get_object(pk)
        est_auteur = realisation.prestataire_id == request.user.id
        if not est_auteur and not request.user.is_staff:
            return Response(
                {"detail": "Suppression réservée à l'auteur de la publication."},
                status=status.HTTP_403_FORBIDDEN,
            )
        realisation.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class FeedLikeView(APIView):
    """Aime ou retire le like d'une réalisation (toggle).

    La règle métier est dans `Feed.services.basculer_like` (partagée avec le
    site web) ; la vue se limite à l'authentification, la récupération de
    l'objet et la mise en forme de la réponse.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        realisation = get_object_or_404(Realisation, id=pk)
        resultat = basculer_like(request.user, realisation)
        return Response({
            'liked': resultat.liked,
            'like_count': resultat.like_count,
        })


class FeedCommentView(APIView):
    """Commentaires d'une publication.

    - `GET` (public) : liste des commentaires, du plus récent au plus ancien.
    - `POST` (authentifié) : ajoute un commentaire (`contenu` non vide).
    """
    permission_classes = [IsAuthenticatedOrReadOnly]

    def get(self, request, pk):
        realisation = get_object_or_404(Realisation, id=pk)
        commentaires = realisation.commentaires.select_related('user').all()
        return Response(
            CommentaireSerializer(
                commentaires, many=True, context={'request': request}
            ).data
        )

    def post(self, request, pk):
        realisation = get_object_or_404(Realisation, id=pk)
        try:
            commentaire = ajouter_commentaire(
                request.user, realisation, request.data.get('contenu')
            )
        except CommentaireVide:
            # Erreur métier → 400 explicite (jamais une 500).
            return Response(
                {'detail': 'Le commentaire est vide.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        serializer = CommentaireSerializer(
            commentaire, context={'request': request}
        )
        return Response({
            'comment': serializer.data,
            'comment_count': compter_commentaires(realisation),
        }, status=status.HTTP_201_CREATED)
