
from os import read

from rest_framework import serializers
from django.core.mail import EmailMultiAlternatives
from django.template.loader import render_to_string
import random

from main.models import Prestataire, Prestation, Realisation, Ville, Evaluation
from Abonnement.models import Abonnement
from Feed.models import Commentaire, Like

class PrestataireSerializers(serializers.ModelSerializer):
   moyenne_etoile =serializers.FloatField(
       source ='average_rating',
       read_only =True
   )
   nombre_avis =serializers.IntegerField(
    source ='review_count',
    read_only =True
   )

   abonnement_actif =serializers.BooleanField(
       source ='has_active_subscription',
       read_only =True
   )
   ville =serializers.StringRelatedField()
   metier =serializers.StringRelatedField()

   class Meta:
       model =Prestataire
       fields =[
           'id',
           "first_name",
           "last_name",
           "email",
           "telephone",
           "photo_profil",
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


       ]



class RealisationSerializer(serializers.ModelSerializer):
    image =serializers.ImageField(read_only =True)
    class Meta:
        model =Realisation
        fields =[
            "id",
            "titre",
            "image",
            "date_ajout"
        ]

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
        ]

    def get_nom_complet(self, obj):
        return f"{obj.first_name} {obj.last_name}".strip()


class FeedRealisationSerializer(serializers.ModelSerializer):
    """Réalisation avec son auteur (prestataire) pour le fil d'actualité."""
    prestataire = FeedPrestataireSerializer(read_only=True)
    like_count = serializers.IntegerField(read_only=True)
    comment_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = Realisation
        fields = [
            'id',
            'titre',
            'image',
            'date_ajout',
            'prestataire',
            'like_count',
            'comment_count',
        ]


class FeedCreateSerializer(serializers.ModelSerializer):
    """Création d'une réalisation (publication prestataire).

    `titre` optionnel, `image` obligatoire (multipart). Le prestataire
    auteur est déduit de `request.user` dans la vue.
    """
    image = serializers.ImageField(required=True)
    titre = serializers.CharField(required=False, allow_blank=True, max_length=200)

    class Meta:
        model = Realisation
        fields = ['id', 'titre', 'image', 'date_ajout']
        read_only_fields = ['id', 'date_ajout']


class CommentaireSerializer(serializers.ModelSerializer):
    """Commentaire d'une réalisation, avec le nom du commentateur."""
    user = serializers.SerializerMethodField()

    class Meta:
        model = Commentaire
        fields = ['id', 'user', 'contenu', 'created_at']

    def get_user(self, obj):
        return f"{obj.user.first_name} {obj.user.last_name}".strip() or "Utilisateur"


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
    is_liked = serializers.SerializerMethodField()

    class Meta:
        model = Realisation
        fields = [
            'id',
            'titre',
            'image',
            'date_ajout',
            'prestataire',
            'commentaires',
            'like_count',
            'comment_count',
            'is_liked',
        ]

    def get_is_liked(self, obj):
        request = self.context.get('request')
        if request is None or not request.user.is_authenticated:
            return False
        return Like.objects.filter(
            user=request.user, realisation=obj
        ).exists()


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
    moyenne_etoile =serializers.FloatField(
        source ='average_rating',
        read_only =True
    )
    nombre_avis = serializers.IntegerField(
        source='review_count',
        read_only=True
    )

    abonnement_actif = serializers.BooleanField(
        source='has_active_subscription',
        read_only=True
    )

    realisations = RealisationSerializer(
        many=True,
        read_only=True
    )

    evaluations = EvaluationSerializer(
        many=True,
        read_only=True,
    )

    metier = PrestationSerializer(
        read_only=True
    )

    ville = serializers.StringRelatedField()

    class Meta:
        model = Prestataire

        fields = [
            'id',
            'first_name',
            'last_name',
            'email',
            'telephone',
            'photo_profil',
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

            'date_inscription',

            'realisations',
            'evaluations',
        ]


# ---------------------------------------------------------------------------
# Sérialiseurs d'authentification / profil
# ---------------------------------------------------------------------------

class UserSerializer(serializers.ModelSerializer):
    """Profil de l'utilisateur connecté (lecture + mise à jour partielle).

    - `photo_profil` est writable (multipart) pour l'upload de l'avatar.
    - `ville` / `metier` sont des FK (id) pour la mise à jour, avec un champ
      `*_nom` en lecture seule pour l'affichage.
    """
    is_prestataire = serializers.BooleanField(read_only=True)
    is_client = serializers.BooleanField(read_only=True)

    photo_profil = serializers.ImageField(required=False, allow_null=True)
    photo_profil_url = serializers.SerializerMethodField()

    ville = serializers.PrimaryKeyRelatedField(
        queryset=Ville.objects.all(), required=False, allow_null=True)
    ville_nom = serializers.StringRelatedField(source='ville', read_only=True)

    metier = serializers.PrimaryKeyRelatedField(
        queryset=Prestation.objects.all(), required=False, allow_null=True)
    metier_nom = serializers.StringRelatedField(source='metier', read_only=True)

    def get_photo_profil_url(self, obj):
        if not obj.photo_profil:
            return None
        request = self.context.get('request')
        url = obj.photo_profil.url
        if request is not None:
            return request.build_absolute_uri(url)
        return url

    class Meta:
        model = Prestataire
        fields = [
            'id',
            'email',
            'first_name',
            'last_name',
            'telephone',
            'role',
            'bio',
            'photo_profil',
            'photo_profil_url',
            'ville',
            'ville_nom',
            'metier',
            'metier_nom',
            'annee_experience',
            'quartier',
            'is_available',
            'is_prestataire',
            'is_client',
        ]
        read_only_fields = ['id', 'email', 'role']


class VilleSerializer(serializers.ModelSerializer):
    class Meta:
        model = Ville
        fields = ['id', 'nom']


class PrestationListSerializer(serializers.ModelSerializer):
    class Meta:
        model = Prestation
        fields = ['id', 'nom']


class PasswordResetRequestSerializer(serializers.Serializer):
    """Demande un code de réinitialisation envoyé par email."""
    email = serializers.EmailField()

    def validate(self, attrs):
        email = attrs.get('email')
        try:
            user = Prestataire.objects.get(email=email)
        except Prestataire.DoesNotExist:
            # Ne pas révéler si l'adresse existe ou non.
            raise serializers.ValidationError(
                {"email": "Aucun compte n'est associé à cette adresse email."}
            )
        attrs['user'] = user
        return attrs

    def create(self, validated_data):
        user = validated_data['user']
        code = str(random.randint(100000, 999999))
        user.code_verification = code
        user.save(update_fields=['code_verification'])

        subject = "Réinitialisation de mot de passe - PrestLocal"
        text_content = f"Votre code de réinitialisation est : {code}"
        html_content = render_to_string('emails/password_reset_code.html', {
            'user': user,
            'code': code
        })

        msg = EmailMultiAlternatives(
            subject, text_content,
            'lankoandeenock002@gmail.com',
            [user.email]
        )
        msg.attach_alternative(html_content, "text/html")
        msg.send()
        return user


class PasswordResetConfirmSerializer(serializers.Serializer):
    """Vérifie le code et définit le nouveau mot de passe."""
    email = serializers.EmailField()
    code = serializers.CharField(max_length=6)
    new_password = serializers.CharField(min_length=8, write_only=True)

    def validate(self, attrs):
        email = attrs.get('email')
        code = attrs.get('code')
        try:
            user = Prestataire.objects.get(email=email)
        except Prestataire.DoesNotExist:
            raise serializers.ValidationError(
                {"email": "Aucun compte n'est associé à cette adresse email."}
            )

        if not user.code_verification or user.code_verification != code:
            raise serializers.ValidationError(
                {"code": "Code de vérification incorrect."}
            )

        attrs['user'] = user
        return attrs

    def create(self, validated_data):
        user = validated_data['user']
        user.set_password(validated_data['new_password'])
        user.code_verification = None
        user.save(update_fields=['password', 'code_verification'])
        return user


class RegisterSerializer(serializers.ModelSerializer):
    """Inscription : crée un compte et envoie un code de vérification par email.

    Le compte est créé inactif (`is_active=False`) et ne peut se connecter
    qu'après validation de l'email via `/auth/verify-email/`.
    """
    password = serializers.CharField(min_length=8, write_only=True)
    role = serializers.ChoiceField(
        choices=Prestataire.ROLE_CHOICES,
        default=Prestataire.ROLE_CLIENT,
    )

    class Meta:
        model = Prestataire
        fields = [
            'email',
            'first_name',
            'last_name',
            'telephone',
            'role',
            'password',
        ]

    def validate_email(self, value):
        email = self.normalized_value(value)
        if Prestataire.objects.filter(email__iexact=email).exists():
            raise serializers.ValidationError(
                "Un compte existe déjà avec cette adresse email."
            )
        return email

    def normalized_value(self, value):
        return value.strip().lower()

    def create(self, validated_data):
        password = validated_data.pop('password')
        role = validated_data.pop('role')

        user = Prestataire(
            **validated_data,
            role=role,
            is_active=False,
        )
        user.username = user.email
        user.set_password(password)

        code = str(random.randint(100000, 999999))
        user.code_verification = code
        user.save()

        subject = "Code de vérification - PrestLocal"
        text_content = f"Votre code de vérification est : {code}"
        html_content = render_to_string('emails/verification_code.html', {
            'user': user,
            'code': code,
        })

        msg = EmailMultiAlternatives(
            subject, text_content,
            'lankoandeenock002@gmail.com',
            [user.email],
        )
        msg.attach_alternative(html_content, "text/html")
        msg.send()
        return user


class VerifyEmailSerializer(serializers.Serializer):
    """Active le compte après validation du code reçu par email."""
    email = serializers.EmailField()
    code = serializers.CharField(max_length=6)

    def validate(self, attrs):
        email = self.normalized_value(attrs.get('email'))
        code = attrs.get('code')
        try:
            user = Prestataire.objects.get(email__iexact=email)
        except Prestataire.DoesNotExist:
            raise serializers.ValidationError(
                {"email": "Aucun compte n'est associé à cette adresse email."}
            )
        if user.is_active:
            raise serializers.ValidationError(
                {"email": "Ce compte est déjà actif."}
            )
        if not user.code_verification or user.code_verification != code:
            raise serializers.ValidationError(
                {"code": "Code de vérification incorrect."}
            )
        attrs['user'] = user
        return attrs

    def normalized_value(self, value):
        return value.strip().lower()

    def create(self, validated_data):
        user = validated_data['user']
        user.is_active = True
        user.code_verification = None
        user.save(update_fields=['is_active', 'code_verification'])
        return user
