"""Vues DRF de l'abonnement prestataire (plans, état, souscription)."""


from rest_framework import status
from rest_framework.generics import ListAPIView
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from Abonnement.models import Abonnement, PlanAbonnement
from Abonnement.services import assurer_plans_par_defaut

from ..serializers import (
    AbonnementSerializer,
    PlanAbonnementSerializer,
    SouscriptionAbonnementSerializer,
)


class PlanAbonnementListView(ListAPIView):
    """Offres d'abonnement disponibles (`GET /api/abonnement/plans/`).

    Tarifs publics : consultables avant même la connexion.
    """
    serializer_class = PlanAbonnementSerializer
    permission_classes = [AllowAny]
    pagination_class = None

    def get_queryset(self):
        # Les offres par défaut sont garanties par le domaine Abonnement :
        # le site et l'API affichent donc toujours les mêmes tarifs.
        assurer_plans_par_defaut()
        return PlanAbonnement.objects.all().order_by('prix')


class MonAbonnementView(APIView):
    """État de l'abonnement du prestataire connecté.

    Réponse : `{"actif": bool, "abonnement": {...}|null}`.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not request.user.is_prestataire:
            return Response(
                {"detail": "L'abonnement est réservé aux comptes prestataires."},
                status=status.HTTP_403_FORBIDDEN,
            )
        try:
            abonnement = request.user.abonnement
        except Abonnement.DoesNotExist:
            abonnement = None

        return Response({
            'actif': bool(abonnement and abonnement.est_valide),
            'abonnement': (
                AbonnementSerializer(abonnement).data if abonnement else None
            ),
        })


class SouscrireAbonnementView(APIView):
    """Souscription d'un prestataire à une offre (`POST /api/abonnement/souscrire/`).

    Corps : `{"plan": <id>, "methode": "Orange Money"|"Moov Money"|"Wave",
    "otp": "123456"}`. Le paiement est simulé (comme sur le site web) : un code
    à 6 chiffres active immédiatement l'abonnement, qui met le profil en avant
    dans les résultats de recherche.
    """
    permission_classes = [IsAuthenticated]
    throttle_scope = 'auth'

    def post(self, request):
        if not request.user.is_prestataire:
            return Response(
                {"detail": "Seuls les prestataires peuvent s'abonner."},
                status=status.HTTP_403_FORBIDDEN,
            )

        serializer = SouscriptionAbonnementSerializer(
            data=request.data, context={'request': request},
        )
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        abonnement = serializer.save()
        plan = abonnement.plan
        return Response(
            {
                'detail': (
                    f"Paiement réussi ! Votre abonnement « {plan.nom} » est actif "
                    f"jusqu'au {abonnement.date_fin.strftime('%d/%m/%Y')}. "
                    "Votre profil est désormais mis en avant."
                ),
                'actif': abonnement.est_valide,
                'abonnement': AbonnementSerializer(abonnement).data,
            },
            status=status.HTTP_201_CREATED,
        )
