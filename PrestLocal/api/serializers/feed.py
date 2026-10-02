"""Sérialiseurs du fil d'actualité (publications, commentaires)."""

from .commun import (
    ALLOWED_IMAGE_EXTENSIONS,
    ALLOWED_VIDEO_EXTENSIONS,
    MAX_IMAGE_SIZE,
    MAX_PUBLICATION_IMAGES,
    MAX_VIDEO_SIZE,
    absolute_media_url,
    realisation_image_urls,
    validate_upload,
)
from .prestataires import FeedPrestataireSerializer
from Feed.models import Commentaire, Like
from main.models import CategoriePrestation, Realisation, RealisationImage
from rest_framework import serializers


class FeedRealisationSerializer(serializers.ModelSerializer):
    """Publication du fil d'actualité, avec son auteur.

    Expose le texte, les images (une ou plusieurs), la vidéo, le lien, la
    catégorie, les compteurs de réactions/commentaires et les permissions
    d'édition du lecteur courant.
    """
    prestataire = FeedPrestataireSerializer(read_only=True)
    like_count = serializers.IntegerField(read_only=True)
    comment_count = serializers.IntegerField(read_only=True)
    images = serializers.SerializerMethodField()
    image = serializers.SerializerMethodField()
    video_url = serializers.SerializerMethodField()
    categorie_nom = serializers.SerializerMethodField()
    categorie = serializers.PrimaryKeyRelatedField(read_only=True)
    is_liked = serializers.SerializerMethodField()
    can_edit = serializers.SerializerMethodField()
    can_delete = serializers.SerializerMethodField()

    class Meta:
        model = Realisation
        fields = [
            'id',
            'titre',
            'contenu',
            'lien',
            'categorie',
            'categorie_nom',
            'images',
            'image',
            'video_url',
            'date_ajout',
            'modifie_le',
            'prestataire',
            'like_count',
            'comment_count',
            'is_liked',
            'can_edit',
            'can_delete',
        ]

    def get_images(self, obj):
        return realisation_image_urls(obj, self.context.get('request'))

    def get_image(self, obj):
        """Image principale (compatibilité : ancien champ unique)."""
        urls = realisation_image_urls(obj, self.context.get('request'))
        return urls[0] if urls else None

    def get_video_url(self, obj):
        return absolute_media_url(self.context.get('request'), obj.video)

    def get_categorie_nom(self, obj):
        return obj.categorie.nom if obj.categorie_id else None

    def get_is_liked(self, obj):
        request = self.context.get('request')
        if request is None or not request.user.is_authenticated:
            return False
        liked = getattr(obj, 'liked_by_user', None)
        if liked is not None:
            return liked
        return Like.objects.filter(user=request.user, realisation=obj).exists()

    def _peut_gerer(self, obj):
        request = self.context.get('request')
        if request is None or not request.user.is_authenticated:
            return False
        # Auteur de la publication, ou rôle de modération (staff).
        return obj.prestataire_id == request.user.id or request.user.is_staff

    def get_can_edit(self, obj):
        request = self.context.get('request')
        if request is None or not request.user.is_authenticated:
            return False
        return obj.prestataire_id == request.user.id

    def get_can_delete(self, obj):
        return self._peut_gerer(obj)


class FeedCreateSerializer(serializers.ModelSerializer):
    """Création d'une publication (texte, images, vidéo, lien, catégorie).

    Champs multipart acceptés :
    - `contenu` : texte multiligne (facultatif si un média est fourni) ;
    - `titre` : titre court facultatif (portfolio) ;
    - `images` : une ou plusieurs images (max 10, 5 Mo chacune) ;
    - `video` : vidéo facultative (max 50 Mo) ;
    - `lien` : lien externe facultatif ;
    - `categorie` : identifiant de catégorie facultatif.

    L'auteur est déduit de `request.user` dans la vue.
    """
    titre = serializers.CharField(
        required=False, allow_blank=True, max_length=200
    )
    contenu = serializers.CharField(required=False, allow_blank=True)
    lien = serializers.URLField(
        required=False, allow_blank=True, max_length=500
    )
    categorie = serializers.PrimaryKeyRelatedField(
        queryset=CategoriePrestation.objects.all(),
        required=False, allow_null=True,
    )
    images = serializers.ListField(
        child=serializers.ImageField(), required=False, write_only=True
    )
    # Ancien champ unique, conservé pour les clients existants (site web).
    image = serializers.ImageField(
        required=False, allow_null=True, write_only=True
    )
    video = serializers.FileField(required=False, allow_null=True, write_only=True)

    class Meta:
        model = Realisation
        fields = [
            'id',
            'titre',
            'contenu',
            'lien',
            'categorie',
            'images',
            'image',
            'video',
            'date_ajout',
        ]
        read_only_fields = ['id', 'date_ajout']

    def validate_images(self, value):
        if len(value) > MAX_PUBLICATION_IMAGES:
            raise serializers.ValidationError(
                f"Maximum {MAX_PUBLICATION_IMAGES} images par publication."
            )
        for image in value:
            validate_upload(
                image,
                allowed=ALLOWED_IMAGE_EXTENSIONS,
                max_size=MAX_IMAGE_SIZE,
                label="Image",
            )
        return value

    def validate_video(self, value):
        if value:
            validate_upload(
                value,
                allowed=ALLOWED_VIDEO_EXTENSIONS,
                max_size=MAX_VIDEO_SIZE,
                label="Vidéo",
            )
        return value

    def validate_image(self, value):
        if value:
            validate_upload(
                value,
                allowed=ALLOWED_IMAGE_EXTENSIONS,
                max_size=MAX_IMAGE_SIZE,
                label="Image",
            )
        return value

    def validate(self, attrs):
        contenu = (attrs.get('contenu') or '').strip()
        # `image` (ancien champ unique) rejoint la liste des images.
        images = list(attrs.get('images') or [])
        if attrs.get('image'):
            images = [attrs.pop('image')] + images
        attrs['images'] = images
        video = attrs.get('video')
        lien = (attrs.get('lien') or '').strip()
        if not contenu and not images and not video and not lien:
            raise serializers.ValidationError({
                'detail': (
                    "Publication vide : ajoutez un texte, une image, "
                    "une vidéo ou un lien."
                )
            })
        attrs['contenu'] = contenu
        attrs['lien'] = lien
        return attrs

    def create(self, validated_data):
        images = validated_data.pop('images', []) or []
        prestataire = validated_data.pop('prestataire', None)
        if prestataire is None:
            prestataire = self.context['request'].user

        # La première image sert d'image principale (portfolio, aperçus) ;
        # les suivantes sont conservées dans `RealisationImage`.
        if images:
            validated_data['image'] = images[0]

        realisation = Realisation.objects.create(
            prestataire=prestataire, **validated_data
        )
        for ordre, image in enumerate(images[1:], start=1):
            RealisationImage.objects.create(
                realisation=realisation, image=image, ordre=ordre
            )
        return realisation


class FeedUpdateSerializer(serializers.ModelSerializer):
    """Modification d'une publication par son auteur (texte, lien, catégorie)."""

    class Meta:
        model = Realisation
        fields = ['titre', 'contenu', 'lien', 'categorie']

    def validate_contenu(self, value):
        return (value or '').strip()


class CommentaireSerializer(serializers.ModelSerializer):
    """Commentaire d'une réalisation, avec le nom et la photo du commentateur."""
    user = serializers.SerializerMethodField()
    user_id = serializers.SerializerMethodField()
    user_photo = serializers.SerializerMethodField()
    is_author = serializers.SerializerMethodField()

    class Meta:
        model = Commentaire
        fields = [
            'id',
            'user',
            'user_id',
            'user_photo',
            'is_author',
            'contenu',
            'created_at',
        ]

    def get_user(self, obj):
        return f"{obj.user.first_name} {obj.user.last_name}".strip() or "Utilisateur"

    def get_user_id(self, obj):
        return str(obj.user_id)

    def get_user_photo(self, obj):
        return absolute_media_url(self.context.get('request'), obj.user.photo_profil)

    def get_is_author(self, obj):
        request = self.context.get('request')
        if request is None or not request.user.is_authenticated:
            return False
        return obj.user_id == request.user.id


class FeedDetailSerializer(serializers.ModelSerializer):
    """Détail d'une réalisation pour la page dédiée.

    Inclut le prestataire auteur, la liste des commentaires (du plus récent au
    plus ancien), les compteurs like/commentaire et l'état de like de
    l'utilisateur courant.
    """
    prestataire = FeedPrestataireSerializer(read_only=True)
    commentaires = CommentaireSerializer(many=True, read_only=True)
    like_count = serializers.IntegerField(read_only=True)
    comment_count = serializers.IntegerField(read_only=True)
    images = serializers.SerializerMethodField()
    image = serializers.SerializerMethodField()
    video_url = serializers.SerializerMethodField()
    categorie = serializers.PrimaryKeyRelatedField(read_only=True)
    categorie_nom = serializers.SerializerMethodField()
    is_liked = serializers.SerializerMethodField()
    can_edit = serializers.SerializerMethodField()
    can_delete = serializers.SerializerMethodField()

    class Meta:
        model = Realisation
        fields = [
            'id',
            'titre',
            'contenu',
            'lien',
            'categorie',
            'categorie_nom',
            'images',
            'image',
            'video_url',
            'date_ajout',
            'modifie_le',
            'prestataire',
            'commentaires',
            'like_count',
            'comment_count',
            'is_liked',
            'can_edit',
            'can_delete',
        ]

    def get_images(self, obj):
        return realisation_image_urls(obj, self.context.get('request'))

    def get_image(self, obj):
        urls = realisation_image_urls(obj, self.context.get('request'))
        return urls[0] if urls else None

    def get_video_url(self, obj):
        return absolute_media_url(self.context.get('request'), obj.video)

    def get_categorie_nom(self, obj):
        return obj.categorie.nom if obj.categorie_id else None

    def get_is_liked(self, obj):
        request = self.context.get('request')
        if request is None or not request.user.is_authenticated:
            return False
        liked = getattr(obj, 'liked_by_user', None)
        if liked is not None:
            return liked
        return Like.objects.filter(
            user=request.user, realisation=obj
        ).exists()

    def get_can_edit(self, obj):
        request = self.context.get('request')
        if request is None or not request.user.is_authenticated:
            return False
        return obj.prestataire_id == request.user.id

    def get_can_delete(self, obj):
        request = self.context.get('request')
        if request is None or not request.user.is_authenticated:
            return False
        return obj.prestataire_id == request.user.id or request.user.is_staff
