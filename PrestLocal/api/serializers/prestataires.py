"""Sérialiseurs du domaine prestataire (liste, fiche, avis)."""

from .commun import absolute_media_url, contact_visible, is_favorite_for
from .reference import PrestationSerializer, RealisationSerializer
from main.models import Evaluation, Prestataire
from rest_framework import serializers


class PrestataireSerializers(serializers.ModelSerializer):
    """Prestataire exposé dans la liste (`GET /api/prestataire/`)."""
    moyenne_etoile = serializers.FloatField(
        source='average_rating',
        read_only=True,
    )
    nombre_avis = serializers.IntegerField(
        source='review_count',
        read_only=True,
    )
    abonnement_actif = serializers.BooleanField(
        source='has_active_subscription',
        read_only=True,
    )
    nom_complet = serializers.SerializerMethodField()
    photo_profil_url = serializers.SerializerMethodField()
    ville = serializers.StringRelatedField()
    metier = serializers.StringRelatedField()
    is_favorite = serializers.SerializerMethodField()

    # Coordonnées réservées aux prestataires abonnés (voir `contact_visible`).
    contact_disponible = serializers.SerializerMethodField()

    def get_contact_disponible(self, obj):
        return contact_visible(obj)

    def to_representation(self, instance):
        """Masque téléphone et email quand l'abonnement n'est pas actif.

        Le masquage se fait à la lecture uniquement : les champs restent
        modifiables en écriture (mise à jour d'un profil par un administrateur).
        """
        data = super().to_representation(instance)
        if not contact_visible(instance):
            data['telephone'] = None
            data['email'] = None
        return data

    class Meta:
        model = Prestataire
        fields = [
            'id',
            "first_name",
            "last_name",
            "nom_complet",
            "email",
            "telephone",
            "photo_profil",
            "photo_profil_url",
            "bio",
            "metier",
            "ville",
            "quartier",
            "annee_experience",
            "est_verifie",
            "is_available",
            'moyenne_etoile',
            'nombre_avis',
            'abonnement_actif',
            'contact_disponible',
            'is_favorite',
        ]

    def get_nom_complet(self, obj):
        return f"{obj.first_name} {obj.last_name}".strip()

    def get_photo_profil_url(self, obj):
        return absolute_media_url(self.context.get('request'), obj.photo_profil)

    def get_is_favorite(self, obj):
        """Vrai si le prestataire est dans les favoris de l'utilisateur connecté."""
        return is_favorite_for(self.context.get('request'), obj)


class FeedPrestataireSerializer(serializers.ModelSerializer):
    """Présta identité compacte pour le fil d'actualité."""
    nom_complet = serializers.SerializerMethodField()
    metier = serializers.StringRelatedField()
    ville = serializers.StringRelatedField()
    moyenne_etoile = serializers.FloatField(
        source='average_rating', read_only=True
    )
    nombre_avis = serializers.IntegerField(
        source='review_count', read_only=True
    )
    # Publications visibles par tous, mais contact réservé aux abonnés.
    abonnement_actif = serializers.BooleanField(
        source='has_active_subscription', read_only=True
    )
    contact_disponible = serializers.BooleanField(
        source='has_active_subscription', read_only=True
    )

    class Meta:
        model = Prestataire
        fields = [
            'id',
            'nom_complet',
            'photo_profil',
            'metier',
            'ville',
            'quartier',
            'est_verifie',
            'moyenne_etoile',
            'nombre_avis',
            'abonnement_actif',
            'contact_disponible',
        ]

    def get_nom_complet(self, obj):
        return f"{obj.first_name} {obj.last_name}".strip()


class EvaluationSerializer(serializers.ModelSerializer):
    """Avis d'un client sur un prestataire (lecture seule, exposé dans le détail)."""
    class Meta:
        model = Evaluation
        fields = [
            'id',
            'client_prenom',
            'client_nom',
            'note',
            'commentaire',
            'date_evaluation',
        ]


class PrestatireDetailSerialzer(serializers.ModelSerializer):
    """Fiche complète d'un prestataire (`GET /api/prestataire/<uuid>/`).

    Contient les informations à afficher dans l'app mobile : identité,
    photo de profil (+ URL absolue), métier, ville/quartier, bio,
    réalisations (portfolio) et évaluations clients.
    """
    moyenne_etoile = serializers.FloatField(
        source='average_rating',
        read_only=True,
    )
    nombre_avis = serializers.IntegerField(
        source='review_count',
        read_only=True,
    )

    abonnement_actif = serializers.BooleanField(
        source='has_active_subscription',
        read_only=True,
    )

    realisations = RealisationSerializer(
        many=True,
        read_only=True,
    )

    evaluations = EvaluationSerializer(
        many=True,
        read_only=True,
    )

    metier = PrestationSerializer(read_only=True)
    ville = serializers.StringRelatedField()
    nom_complet = serializers.SerializerMethodField()
    photo_profil_url = serializers.SerializerMethodField()
    is_favorite = serializers.SerializerMethodField()

    # Coordonnées réservées aux prestataires abonnés (voir `contact_visible`).
    contact_disponible = serializers.SerializerMethodField()

    def get_contact_disponible(self, obj):
        return contact_visible(obj)

    def to_representation(self, instance):
        """Fiche consultable sans abonnement, mais coordonnées masquées."""
        data = super().to_representation(instance)
        if not contact_visible(instance):
            data['telephone'] = None
            data['email'] = None
        return data

    class Meta:
        model = Prestataire

        fields = [
            'id',
            'first_name',
            'last_name',
            'nom_complet',
            'email',
            'telephone',
            'photo_profil',
            'photo_profil_url',
            'bio',

            'metier',

            'ville',
            'quartier',

            'annee_experience',

            'est_verifie',
            'is_available',

            'profile_views',
            'call_clicks',
            'contact_clicks',

            'moyenne_etoile',
            'nombre_avis',

            'abonnement_actif',
            'contact_disponible',
            'is_favorite',

            'date_inscription',

            'realisations',
            'evaluations',
        ]

    def get_nom_complet(self, obj):
        return f"{obj.first_name} {obj.last_name}".strip()

    def get_photo_profil_url(self, obj):
        return absolute_media_url(self.context.get('request'), obj.photo_profil)

    def get_is_favorite(self, obj):
        return is_favorite_for(self.context.get('request'), obj)


class EvaluationCreateSerializer(serializers.ModelSerializer):
    """Dépôt / mise à jour d'un avis client sur un prestataire.

    Une seule évaluation par couple (prestataire, client) : un second appel
    met à jour l'avis existant au lieu d'en créer un doublon.
    """

    class Meta:
        model = Evaluation
        fields = ['note', 'commentaire']

    def validate_note(self, value):
        if value < 1 or value > 5:
            raise serializers.ValidationError("La note doit être comprise entre 1 et 5.")
        return value

    def validate_commentaire(self, value):
        value = (value or '').strip()
        if len(value) < 3:
            raise serializers.ValidationError("Le commentaire est trop court.")
        return value
