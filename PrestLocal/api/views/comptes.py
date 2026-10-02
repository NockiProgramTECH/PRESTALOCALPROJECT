"""Vues DRF d'authentification et de profil (JWT, inscription, mot de passe)."""


from rest_framework import status
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import RefreshToken


from ..serializers import (
    PasswordResetConfirmSerializer,
    PasswordResetRequestSerializer,
    RegisterSerializer,
    UserSerializer,
    VerifyEmailSerializer,
)


class MeAPIView(APIView):
    """Profil de l'utilisateur connecté (GET) et mise à jour (PATCH).

    Accepte le JSON et le `multipart/form-data` (upload de `photo_profil`).
    """
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

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
    """Envoie un code de réinitialisation par email.

    Réponse volontairement identique (200) pour toute adresse, connue ou non.
    """
    permission_classes = [AllowAny]
    throttle_scope = 'auth'

    def post(self, request):
        serializer = PasswordResetRequestSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response(
                {"detail": "Si un compte existe pour cette adresse, un code de réinitialisation vient d'être envoyé."},
                status=status.HTTP_200_OK,
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class PasswordResetConfirmView(APIView):
    """Vérifie le code et définit le nouveau mot de passe."""
    permission_classes = [AllowAny]
    throttle_scope = 'auth'

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
    throttle_scope = 'auth'

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
    """Active le compte après validation du code reçu par email.

    Le compte est **immédiatement connecté** : la réponse contient les jetons
    JWT (comme `/auth/token/`) ainsi que le profil, ce qui évite de redemander
    à l'utilisateur de saisir ses identifiants juste après l'inscription.
    """
    permission_classes = [AllowAny]
    throttle_scope = 'auth'

    def post(self, request):
        serializer = VerifyEmailSerializer(data=request.data)
        if serializer.is_valid():
            # Un compte déjà vérifié ne reçoit jamais de jetons ici : le code
            # n'est plus vérifiable, seule une connexion avec mot de passe est
            # légitime (sinon l'email seul suffirait à se connecter).
            if serializer.validated_data.get('already_active'):
                return Response(
                    {"detail": "Cet email est déjà vérifié. Connectez-vous."},
                    status=status.HTTP_200_OK,
                )
            user = serializer.save()
            refresh = RefreshToken.for_user(user)
            return Response(
                {
                    "detail": "Votre email a été vérifié. Vous êtes maintenant connecté.",
                    "access": str(refresh.access_token),
                    "refresh": str(refresh),
                    "user": UserSerializer(user, context={'request': request}).data,
                },
                status=status.HTTP_200_OK,
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
