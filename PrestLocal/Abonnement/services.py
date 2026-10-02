"""Services métier de l'abonnement.

L'activation d'un abonnement existait **en double** : dans la vue web
(`Abonnement/views.py::simuler_otp`) et dans le sérialiseur de l'API
(`api/serializers.py::SouscriptionAbonnementSerializer.create`). Les deux
chemins sont désormais servis par :func:`souscrire`, donc une seule règle :

- l'abonnement est créé s'il n'existe pas (``date_fin`` obligatoire) ;
- l'offre, l'échéance, l'état « payé/actif » et l'identifiant de transaction
  sont mis à jour de la même façon ;
- l'opération est **transactionnelle** : jamais d'abonnement à moitié activé.

Le service ne dépend ni de ``request`` ni d'un format de réponse : il peut être
appelé par le site, l'API mobile, une commande ou un test.
"""

import uuid

from django.db import transaction
from django.utils import timezone

from .models import Abonnement, PlanAbonnement


@transaction.atomic
def souscrire(prestataire, plan: PlanAbonnement, prefixe: str = "MOB") -> Abonnement:
    """Active (ou renouvelle) l'abonnement d'un prestataire pour ``plan``.

    :param prefixe: préfixe de l'identifiant de transaction (``MOB`` pour un
        paiement Mobile Money via l'API, ``SIM`` pour la simulation du site).
    """
    date_fin = timezone.now() + timezone.timedelta(days=plan.duree_jours)

    # `date_fin` est obligatoire côté modèle : on la fournit dès la création
    # pour ne jamais insérer de ligne incomplète.
    abonnement, _ = Abonnement.objects.select_for_update().get_or_create(
        prestataire=prestataire,
        defaults={'date_fin': date_fin},
    )
    abonnement.plan = plan
    abonnement.date_fin = date_fin
    abonnement.est_actif = True
    abonnement.paye = True
    abonnement.transaction_id = f"{prefixe}-{uuid.uuid4().hex[:8].upper()}"
    abonnement.save()
    return abonnement


def abonnement_actif(prestataire):
    """Abonnement du prestataire s'il est valide (payé, actif, non expiré)."""
    try:
        abonnement = prestataire.abonnement
    except Abonnement.DoesNotExist:
        return None
    return abonnement if abonnement.est_valide else None


#: Offres créées automatiquement sur une base vide (site web comme API).
PLANS_PAR_DEFAUT = (
    ('Découverte (1 mois)', 5000, 30, 'Idéal pour commencer et tester la plateforme.'),
    ('Professionnel (6 mois)', 25000, 180, 'Pour les pros qui veulent une visibilité durable.'),
    ('Premium (1 an)', 45000, 365, "La meilleure valeur pour une présence continue toute l'année."),
)


def assurer_plans_par_defaut() -> None:
    """Crée les offres par défaut si la base n'en contient aucune.

    Appelée par la page web « Abonnement » et par l'API : la plateforme reste
    utilisable même sur une base neuve où ``populate_db`` n'a pas été lancé.
    """
    if PlanAbonnement.objects.exists():
        return
    for nom, prix, duree, description in PLANS_PAR_DEFAUT:
        PlanAbonnement.objects.get_or_create(
            nom=nom,
            defaults={
                'prix': prix,
                'duree_jours': duree,
                'description': description,
            },
        )
