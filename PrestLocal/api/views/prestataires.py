"""Vues DRF des prestataires (liste, fiche, avis, favoris, portfolio)."""

from django_filters.rest_framework import DjangoFilterBackend
from rest_framework import status
from rest_framework.decorators import action
from rest_framework.filters import OrderingFilter, SearchFilter
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.viewsets import ModelViewSet

from main.models import Favorite
from main.services import basculer_favori, soumettre_avis, statistiques_avis

from .. import selectors
from ..permissions import IsOwnerOrReadOnly
from ..serializers import (
    EvaluationCreateSerializer,
    EvaluationSerializer,
    FeedRealisationSerializer,
    PrestataireSerializers,
    PrestatireDetailSerialzer,
)


class PrestataireViews(ModelViewSet):
    """Prestataires de services.

    - `GET /api/prestataire/` : liste filtrée / recherchée / triée.
      Par défaut, **seuls les prestataires dont l'abonnement est actif**
      apparaissent (`include_all=1` pour tout afficher, `abonnes_only=1`
      conservé pour compatibilité).
      Filtres : `ville`, `metier`, `est_verifie`, `is_available`,
      `categorie`, `quartier`, `etoile` (note minimale).
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
        # Règle de visibilité : seuls les prestataires dont l'abonnement est
        # payé, actif et non expiré apparaissent dans les recherches.
        # `?include_all=1` lève le filtre (aperçu interne, administration,
        # tests) ; `?abonnes_only=1` reste accepté pour compatibilité.
        #
        # Le filtre ne s'applique **qu'à la liste** : la fiche d'un
        # prestataire non abonné reste consultable (on peut y arriver depuis
        # une publication du fil), mais ses coordonnées sont masquées par le
        # serializer (`contact_disponible = false`).
        queryset = selectors.prestataires_api()

        params = self.request.query_params
        include_all = params.get('include_all') in ('1', 'true', 'True')

        if self.action == 'list' and not include_all:
            # Règle de visibilité écrite une seule fois (`main.querysets`).
            queryset = queryset.visibles()

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

        evaluation, created = soumettre_avis(
            prestataire=prestataire,
            client=request.user,
            note=serializer.validated_data['note'],
            commentaire=serializer.validated_data['commentaire'],
            prenom=request.data.get('prenom', ''),
            nom=request.data.get('nom', ''),
            # L'API met à jour l'avis existant au lieu d'en créer un second.
            remplacer=True,
        )

        # Statistiques recalculées en base : `prestataire` a été chargé avec
        # `prefetch_related('evaluations')`, son cache est donc périmé.
        stats = statistiques_avis(prestataire)

        return Response(
            {
                'detail': "Avis enregistré." if created else "Avis mis à jour.",
                'evaluation': EvaluationSerializer(evaluation).data,
                'moyenne_etoile': stats['moyenne_etoile'],
                'nombre_avis': stats['nombre_avis'],
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
        _, created = basculer_favori(request.user, prestataire)

        return Response(
            {
                'status': 'added' if created else 'removed',
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
