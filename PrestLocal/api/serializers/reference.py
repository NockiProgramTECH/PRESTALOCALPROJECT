"""Sérialiseurs des données de référence et des réalisations.

Villes, catégories, prestations et réalisations d'un prestataire : des objets
simples, réutilisés comme briques par les sérialiseurs de prestataires et du
fil d'actualité."""

from .commun import absolute_media_url
from main.models import CategoriePrestation, Prestation, Prestataire, Realisation, Ville
from rest_framework import serializers


class CategorieSerializer(serializers.ModelSerializer):
    """Catégorie de prestation (chips de l'accueil / recherche mobile)."""
    description = serializers.CharField(source='descriptionText', read_only=True)
    provider_count = serializers.SerializerMethodField()

    class Meta:
        model = CategoriePrestation
        fields = ['id', 'nom', 'description', 'provider_count']

    def get_provider_count(self, obj):
        """Nombre de prestataires actifs exerçant un métier de cette catégorie."""
        return Prestataire.objects.filter(
            role=Prestataire.ROLE_PRESTATAIRE,
            metier__categorie=obj,
        ).count()


class RealisationSerializer(serializers.ModelSerializer):
    """Réalisation exposée dans la fiche détail d'un prestataire.

    Inclut l'URL absolue de l'image et les compteurs d'interactions
    (`like_count`, `comment_count`) ainsi que `is_liked` pour l'utilisateur
    connecté — sans requête supplémentaire si la vue a préchargé les
    relations (`prefetch_related`).
    """
    image = serializers.ImageField(read_only=True)
    image_url = serializers.SerializerMethodField()
    like_count = serializers.SerializerMethodField()
    comment_count = serializers.SerializerMethodField()
    is_liked = serializers.SerializerMethodField()

    class Meta:
        model = Realisation
        fields = [
            "id",
            "titre",
            "image",
            "image_url",
            "date_ajout",
            "like_count",
            "comment_count",
            "is_liked",
        ]

    def get_image_url(self, obj):
        return absolute_media_url(self.context.get('request'), obj.image)

    def get_like_count(self, obj):
        return obj.likes.count()

    def get_comment_count(self, obj):
        return obj.commentaires.count()

    def get_is_liked(self, obj):
        request = self.context.get('request')
        if request is None or not request.user.is_authenticated:
            return False
        # `obj.likes.all()` est mis en cache par `prefetch_related` dans la vue.
        return any(like.user_id == request.user.id for like in obj.likes.all())


class PrestationSerializer(serializers.ModelSerializer):
    class Meta:
        model =Prestation
        fields =[
            "id",
            "nom",
            "slug",
            "description",
            "image_couverture",
            'icone',
        ]


class VilleSerializer(serializers.ModelSerializer):
    class Meta:
        model = Ville
        fields = ['id', 'nom']


class PrestationListSerializer(serializers.ModelSerializer):
    class Meta:
        model = Prestation
        fields = ['id', 'nom']
