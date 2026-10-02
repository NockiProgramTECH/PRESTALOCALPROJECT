"""Vues DRF des données de référence et des favoris de l'utilisateur."""

from django.core.cache import cache

from rest_framework.generics import ListAPIView
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response

from main.models import CategoriePrestation, Prestation, Ville

from .. import selectors
from ..serializers import (
    CategorieSerializer,
    PrestataireSerializers,
    PrestationListSerializer,
    VilleSerializer,
)


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
        # Requête (relations + note annotée) décrite dans `api.selectors`.
        return selectors.favoris_api(self.request.user)
