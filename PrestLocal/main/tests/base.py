"""Fabrique de comptes et réglages partagés par les tests du domaine `main`."""

from datetime import timedelta

from django.utils import timezone

from Abonnement.models import (
    Abonnement,
    PlanAbonnement,
)
from main.models import Prestataire


EMAIL_LOCMEM = 'django.core.mail.backends.locmem.EmailBackend'


def creer_prestataire(email, *, abonne=True, **extra):
    """Crée un prestataire, abonné (visible) par défaut."""
    champs = {
        'email': email,
        'first_name': 'Awa',
        'last_name': 'Ouédraogo',
        'role': Prestataire.ROLE_PRESTATAIRE,
    }
    champs.update(extra)
    prestataire = Prestataire.objects.create_user(password='MotDePasse123', **champs)
    if abonne:
        plan = PlanAbonnement.objects.create(nom='Test', prix=5000, duree_jours=30)
        Abonnement.objects.create(
            prestataire=prestataire,
            plan=plan,
            paye=True,
            est_actif=True,
            date_fin=timezone.now() + timedelta(days=30),
        )
    return prestataire
