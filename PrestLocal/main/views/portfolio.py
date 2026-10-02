"""Portfolio du prestataire (réalisations) et dépôt d'un avis client.

Endpoints appelés en AJAX : les réponses sont donc en JSON, y compris les
erreurs (contrat conservé).
"""

import logging

from django.contrib.auth.decorators import login_required
from django.http import JsonResponse
from django.views.decorators.http import require_POST

from ..forms import RealisationForm
from ..models import Prestataire, Realisation
from ..services import (
    AvisDejaDonne,
    AvisInvalide,
    notifier_nouvel_avis,
    soumettre_avis,
)

logger = logging.getLogger(__name__)


@require_POST
@login_required
def add_realisation(request):
    """Ajoute une réalisation au portfolio du prestataire connecté."""
    form = RealisationForm(request.POST, request.FILES)
    if not form.is_valid():
        return JsonResponse({'status': 'error', 'errors': form.errors.as_json()}, status=400)

    realisation = form.save(commit=False)
    realisation.prestataire = request.user
    realisation.save()

    return JsonResponse({
        'status': 'success',
        'message': 'Réalisation ajoutée avec succès !',
        'realisation': {
            'id': realisation.id,
            'titre': realisation.titre,
            # `image` est facultative (publications texte seul).
            'image_url': realisation.image.url if realisation.image else None,
        },
    })


@require_POST
@login_required
def delete_realisation(request, pk):
    """Supprime une réalisation — uniquement celle du prestataire connecté."""
    try:
        realisation = Realisation.objects.get(pk=pk, prestataire=request.user)
    except Realisation.DoesNotExist:
        return JsonResponse(
            {'status': 'error', 'message': 'Réalisation introuvable.'}, status=404
        )

    realisation.delete()
    return JsonResponse({'status': 'success', 'message': 'Réalisation supprimée.'})


@require_POST
def submit_evaluation(request, pk):
    """Dépose l'avis de l'utilisateur connecté sur un prestataire.

    Validation de frontière ici (présence des champs), règles métier dans
    `main.services.avis`, notification (email + interne) dans le même module.
    """
    if not request.user.is_authenticated:
        return JsonResponse(
            {'status': 'error', 'message': 'Vous devez être connecté pour évaluer.'},
            status=403,
        )

    try:
        prestataire = Prestataire.objects.get(pk=pk)
    except Prestataire.DoesNotExist:
        return JsonResponse(
            {'status': 'error', 'message': 'Prestataire introuvable.'}, status=404
        )

    note = request.POST.get('note')
    commentaire = request.POST.get('commentaire')
    if not note or not commentaire:
        return JsonResponse(
            {'status': 'error', 'message': 'Note et commentaire requis.'}, status=400
        )

    try:
        evaluation, _ = soumettre_avis(
            prestataire=prestataire,
            client=request.user,
            note=note,
            commentaire=commentaire,
        )
    except AvisDejaDonne as exc:
        return JsonResponse({'status': 'error', 'message': str(exc)}, status=400)
    except AvisInvalide as exc:
        return JsonResponse({'status': 'error', 'message': str(exc)}, status=400)

    notifier_nouvel_avis(evaluation, hote=request.get_host())
    return JsonResponse(
        {'status': 'success', 'message': 'Votre avis a été pris en compte.'}
    )
