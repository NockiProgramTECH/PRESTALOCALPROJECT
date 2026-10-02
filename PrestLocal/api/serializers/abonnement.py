"""Sérialiseurs de l'abonnement prestataire (plans, souscription)."""

from Abonnement.models import Abonnement, PlanAbonnement
from Abonnement.services import souscrire
from rest_framework import serializers


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
        # Activation déléguée au service métier partagé avec le site web :
        # une seule règle de souscription dans tout le projet.
        return souscrire(
            self.context['request'].user,
            validated_data['plan'],
            prefixe="MOB",
        )
