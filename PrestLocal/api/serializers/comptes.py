"""Sérialiseurs d'authentification et de profil utilisateur."""

from .commun import PHONE_REGEX
import random

from rest_framework import serializers

from Abonnement.models import Abonnement
from main.models import Prestataire, Prestation, Ville
from Notifications.service import envoyer_email


def send_code_email(user, code, subject, template_name, type_notification='code'):
    """Envoie un code (vérification / réinitialisation) par email.

    Délègue au service de notification : l'expéditeur, le rendu du gabarit, la
    journalisation et la gestion des erreurs sont centralisés (plus d'envoi
    direct dans les sérialiseurs). En développement, ``EMAIL_BACKEND`` peut
    pointer vers la console pour éviter d'envoyer de vrais emails.
    """
    envoyer_email(
        user,
        sujet=subject,
        texte=f"Votre code est : {code}",
        template=template_name,
        contexte={'user': user, 'code': code},
        type_notification=type_notification,
    )


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
            type_notification='code_reinitialisation',
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
            type_notification='code_verification',
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
