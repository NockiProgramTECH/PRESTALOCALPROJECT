
import random
import re
import uuid
from datetime import timedelta

from django.conf import settings
from django.core.mail import EmailMultiAlternatives
from django.template.loader import render_to_string
from django.utils import timezone
from rest_framework import serializers

from Abonnement.models import Abonnement, PlanAbonnement
from Feed.models import Commentaire, Like
from main.models import (
    CategoriePrestation,
    Evaluation,
    Prestataire,
    Prestation,
    Realisation,
    Ville,
)

# Numéros burkinabè : +226 XX XX XX XX / 00226... / 8 chiffres locaux
PHONE_REGEX = re.compile(r'^(\+?226)?[\s.-]?\d{2}[\s.-]?\d{2}[\s.-]?\d{2}[\s.-]?\d{2}$')


def send_code_email(user, code, subject, template_name):
    """Envoie un code (vérification / réinitialisation) par email.

    L'expéditeur provient de `settings.DEFAULT_FROM_EMAIL` (plus d'adresse
    codée en dur). En développement, `EMAIL_BACKEND` peut pointer vers la
    console pour éviter d'envoyer de vrais emails.
    """
    text_content = f"Votre code est : {code}"
    html_content = render_to_string(template_name, {'user': user, 'code': code})
    msg = EmailMultiAlternatives(
        subject,
        text_content,
        settings.DEFAULT_FROM_EMAIL,
        [user.email],
    )
    msg.attach_alternative(html_content, "text/html")
    msg.send(fail_silently=False)


def contact_visible(obj):
    """Règle produit : seuls les prestataires dont l'abonnement est payé, actif
    et non expiré sont **contactables**.

    Leur fiche reste consultable (utile depuis une publication du fil
    d'actualité), mais sans téléphone ni email : `contact_disponible` indique à
    l'application si elle doit afficher les boutons d'appel / message.
    """
    return bool(getattr(obj, 'has_active_subscription', False))


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
        return _absolute_media_url(self.context.get('request'), obj.photo_profil)

    def get_is_favorite(self, obj):
        """Vrai si le prestataire est dans les favoris de l'utilisateur connecté."""
        return is_favorite_for(self.context.get('request'), obj)


def is_favorite_for(request, prestataire):
    """Indique si `prestataire` est en favori pour l'utilisateur de `request`."""
    if request is None or not getattr(request, 'user', None):
        return False
    if not request.user.is_authenticated:
        return False
    from main.models import Favorite
    return Favorite.objects.filter(user=request.user, prestataire=prestataire).exists()


def _absolute_media_url(request, file_field):
    """Retourne l'URL absolue d'un `ImageField` (ou None)."""
    if not file_field:
        return None
    try:
        url = file_field.url
    except ValueError:
        return None
    if request is not None:
        return request.build_absolute_uri(url)
    return url


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
        return _absolute_media_url(self.context.get('request'), obj.image)

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
        return _absolute_media_url(self.context.get('request'), obj.photo_profil)

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
    # Permet à l'application de proposer la configuration du profil juste
    # après l'inscription (prestataire : métier + ville + quartier).
    profile_completed = serializers.BooleanField(read_only=True)

    # État d'abonnement, utile pour afficher l'invitation à s'abonner et le
    # badge « profil mis en avant » sans appel supplémentaire.
    abonnement_actif = serializers.SerializerMethodField()
    abonnement_plan = serializers.SerializerMethodField()
    abonnement_fin = serializers.SerializerMethodField()
    abonnement_jours_restants = serializers.SerializerMethodField()

    def _abonnement(self, obj):
        try:
            return obj.abonnement
        except Abonnement.DoesNotExist:
            return None

    def get_abonnement_actif(self, obj):
        abo = self._abonnement(obj)
        return bool(abo and abo.est_valide)

    def get_abonnement_plan(self, obj):
        abo = self._abonnement(obj)
        return abo.plan.nom if abo and abo.plan else None

    def get_abonnement_fin(self, obj):
        abo = self._abonnement(obj)
        return abo.date_fin if abo else None

    def get_abonnement_jours_restants(self, obj):
        abo = self._abonnement(obj)
        return abo.jours_restants if abo else 0

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
            'profile_completed',
            'abonnement_actif',
            'abonnement_plan',
            'abonnement_fin',
            'abonnement_jours_restants',
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
    """Demande un code de réinitialisation envoyé par email.

    Sécurité : la réponse est **toujours identique**, que l'adresse existe ou
    non (protection contre l'énumération des comptes). Si le compte existe, un
    code est généré et envoyé ; sinon rien n'est envoyé.
    """
    email = serializers.EmailField()

    def validate_email(self, value):
        return value.strip().lower()

    def validate(self, attrs):
        email = attrs.get('email')
        user = Prestataire.objects.filter(email__iexact=email).first()
        # Aucune exception ici : on ne révèle jamais l'existence du compte.
        # `user` vaut None si l'adresse est inconnue -> aucun email envoyé.
        attrs['user'] = user
        return attrs

    def save(self, **kwargs):
        """Génère et envoie le code si le compte existe (sinon ne fait rien).

        Surcharge volontaire de `Serializer.save()` : le sérialiseur ne crée
        aucun objet en base, il déclenche seulement l'envoi de l'email.
        """
        user = self.validated_data.get('user')
        if user is None:
            return None

        code = str(random.randint(100000, 999999))
        user.code_verification = code
        user.save(update_fields=['code_verification'])

        send_code_email(
            user,
            code,
            subject="Réinitialisation de mot de passe - LesProduFao",
            template_name='emails/password_reset_code.html',
        )
        return user


class PasswordResetConfirmSerializer(serializers.Serializer):
    """Vérifie le code et définit le nouveau mot de passe."""
    email = serializers.EmailField()
    code = serializers.CharField(max_length=6)
    new_password = serializers.CharField(min_length=8, write_only=True)

    def validate_new_password(self, value):
        # Applique les validateurs Django (longueur, mot de passe commun, …).
        from django.contrib.auth.password_validation import validate_password
        validate_password(value)
        return value

    def validate(self, attrs):
        email = attrs.get('email')
        code = attrs.get('code')
        user = Prestataire.objects.filter(email__iexact=email.strip().lower()).first()

        if user is None or not user.code_verification or user.code_verification != code:
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

    def validate_telephone(self, value):
        if value in (None, ''):
            return value
        cleaned = value.strip()
        if not PHONE_REGEX.match(cleaned):
            raise serializers.ValidationError(
                "Numéro de téléphone invalide (format attendu : +226 70 00 00 00)."
            )
        return cleaned

    def validate_password(self, value):
        from django.contrib.auth.password_validation import validate_password
        validate_password(value)
        return value

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

        send_code_email(
            user,
            code,
            subject="Code de vérification - LesProduFao",
            template_name='emails/verification_code.html',
        )
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
            # Déjà vérifié : réponse idempotente (aucune information révélée).
            attrs['user'] = user
            attrs['already_active'] = True
            return attrs
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
        if validated_data.get('already_active'):
            return user
        user.is_active = True
        user.code_verification = None
        user.save(update_fields=['is_active', 'code_verification'])
        return user


# ---------------------------------------------------------------------------
# Abonnement des prestataires (offres, état, souscription Mobile Money)
# ---------------------------------------------------------------------------

#: Offres créées automatiquement si la base n'en contient aucune (mêmes
#: valeurs que la page web « Abonnement »).
DEFAULT_PLANS = (
    ('Découverte (1 mois)', 5000, 30, 'Idéal pour commencer et tester la plateforme.'),
    ('Professionnel (6 mois)', 25000, 180, 'Pour les pros qui veulent une visibilité durable.'),
    ('Premium (1 an)', 45000, 365, "La meilleure valeur pour une présence continue toute l'année."),
)

#: Opérateurs Mobile Money proposés à la souscription (simulation).
MOBILE_MONEY_OPERATORS = ('Orange Money', 'Moov Money', 'Wave')


class PlanAbonnementSerializer(serializers.ModelSerializer):
    """Offre d'abonnement affichée dans l'application."""

    class Meta:
        model = PlanAbonnement
        fields = ['id', 'nom', 'prix', 'duree_jours', 'description']


class AbonnementSerializer(serializers.ModelSerializer):
    """Abonnement d'un prestataire (état + échéance)."""

    plan = PlanAbonnementSerializer(read_only=True)
    est_valide = serializers.BooleanField(read_only=True)
    jours_restants = serializers.IntegerField(read_only=True)

    class Meta:
        model = Abonnement
        fields = [
            'id',
            'plan',
            'date_debut',
            'date_fin',
            'est_actif',
            'paye',
            'transaction_id',
            'est_valide',
            'jours_restants',
        ]


class SouscriptionAbonnementSerializer(serializers.Serializer):
    """Souscription simulée : offre + opérateur Mobile Money + code OTP.

    Reproduit le parcours du site web (choix de l'offre, choix de l'opérateur,
    saisie du code à 6 chiffres). Aucun paiement réel n'est déclenché.
    """

    plan = serializers.PrimaryKeyRelatedField(queryset=PlanAbonnement.objects.all())
    methode = serializers.ChoiceField(choices=MOBILE_MONEY_OPERATORS)
    otp = serializers.CharField(min_length=6, max_length=6)

    def validate_otp(self, value):
        if not value.isdigit():
            raise serializers.ValidationError(
                "Le code OTP doit contenir 6 chiffres."
            )
        return value

    def create(self, validated_data):
        user = self.context['request'].user
        plan = validated_data['plan']
        date_fin = timezone.now() + timedelta(days=plan.duree_jours)

        # `date_fin` est obligatoire : on la fournit dès la création pour ne
        # jamais insérer de ligne incomplète.
        abonnement, _ = Abonnement.objects.get_or_create(
            prestataire=user,
            defaults={'date_fin': date_fin},
        )
        abonnement.plan = plan
        abonnement.date_fin = date_fin
        abonnement.est_actif = True
        abonnement.paye = True
        abonnement.transaction_id = f"MOB-{uuid.uuid4().hex[:8].upper()}"
        abonnement.save()
        return abonnement
