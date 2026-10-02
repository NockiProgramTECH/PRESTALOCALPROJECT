"""Vues du profil prestataire : page profil, annuaire, fiche, contacts, favoris."""

from django.contrib import messages
from django.contrib.auth.decorators import login_required
from django.http import Http404, JsonResponse
from django.shortcuts import get_object_or_404, redirect, render
from django.views.decorators.http import require_POST
from django.views.generic import DetailView, ListView

from .. import selectors
from ..forms import PrestataireProfileForm, RealisationForm
from ..models import Favorite, Prestataire
from ..services import (
    basculer_favori,
    definir_disponibilite,
    enregistrer_clic,
    enregistrer_vue_profil,
)

MESSAGE_RESERVE_PRESTATAIRES = "Cet espace est réservé aux prestataires."


@login_required
def profile_view(request):
    """Page de gestion du profil pour le prestataire connecté."""
    prestataire = request.user
    if not prestataire.is_prestataire:
        messages.error(request, MESSAGE_RESERVE_PRESTATAIRES)
        return redirect('main:index')

    stats = {
        'profile_views': prestataire.profile_views,
        'call_clicks': prestataire.call_clicks,
        'contact_clicks': prestataire.contact_clicks,
        'average_rating': prestataire.average_rating,
        'review_count': prestataire.review_count,
    }

    return render(request, 'main/profile.html', {
        'prestataire': prestataire,
        'realisations': prestataire.realisations.all().order_by('-date_ajout'),
        'form': RealisationForm(),
        'profile_form': PrestataireProfileForm(instance=prestataire),
        'stats': stats,
    })


@require_POST
@login_required
def update_profile(request):
    if not request.user.is_prestataire:
        return JsonResponse(
            {'status': 'error', 'message': MESSAGE_RESERVE_PRESTATAIRES}, status=403
        )

    form = PrestataireProfileForm(request.POST, request.FILES, instance=request.user)
    if form.is_valid():
        form.save()
        return JsonResponse(
            {'status': 'success', 'message': 'Profil mis à jour avec succès.'}
        )
    return JsonResponse({'status': 'error', 'errors': form.errors.as_json()}, status=400)


@require_POST
@login_required
def toggle_availability(request):
    if not request.user.is_prestataire:
        return JsonResponse(
            {'status': 'error', 'message': MESSAGE_RESERVE_PRESTATAIRES}, status=403
        )

    valeur = request.POST.get('is_available')
    if valeur is None:
        return JsonResponse(
            {'status': 'error', 'message': 'Valeur de disponibilité manquante.'},
            status=400,
        )

    disponible = definir_disponibilite(request.user, valeur == 'true')
    return JsonResponse({'status': 'success', 'is_available': disponible})


def _prestataire_introuvable():
    """Réponse JSON conservée pour les endpoints appelés en AJAX par le site."""
    return JsonResponse(
        {'status': 'error', 'message': 'Prestataire introuvable.'}, status=404
    )


def _prestataire_demande(pk):
    """Retourne `(prestataire, None)` ou `(None, réponse 404)`."""
    try:
        return Prestataire.objects.get(pk=pk), None
    except Prestataire.DoesNotExist:
        return None, _prestataire_introuvable()


@require_POST
def record_call_click(request, pk):
    """Compte un clic « appeler » (endpoint public, appelé par le site)."""
    prestataire, erreur = _prestataire_demande(pk)
    if erreur:
        return erreur
    return JsonResponse(
        {'status': 'success', 'call_clicks': enregistrer_clic(prestataire, 'appel')}
    )


@require_POST
def record_contact_click(request, pk):
    """Compte un clic « contacter » (endpoint public, appelé par le site)."""
    prestataire, erreur = _prestataire_demande(pk)
    if erreur:
        return erreur
    enregistrer_clic(prestataire, 'contact')
    return JsonResponse({'status': 'success'})


class PrestataireDetailView(DetailView):
    """Fiche publique d'un prestataire (réservée à ceux qui sont abonnés)."""
    model = Prestataire
    template_name = 'main/prestataire_detail.html'
    context_object_name = 'prestataire'

    def get_object(self, queryset=None):
        prestataire = super().get_object(queryset=queryset)

        # La règle de visibilité vaut aussi pour la fiche : seul le
        # propriétaire peut consulter son profil sans abonnement actif.
        if not prestataire.has_active_subscription and self.request.user != prestataire:
            raise Http404("Ce prestataire n'est pas disponible pour le moment.")

        if not self.request.user.is_authenticated or self.request.user != prestataire:
            enregistrer_vue_profil(prestataire)
        return prestataire

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        utilisateur = self.request.user
        context['is_favori'] = (
            utilisateur.is_authenticated
            and Favorite.objects.filter(
                user=utilisateur, prestataire=self.object
            ).exists()
        )
        return context


class PrestataireListView(ListView):
    """Annuaire : prestataires visibles, filtrables par recherche/ville/métier."""
    model = Prestataire
    template_name = 'main/prestataire_list.html'
    context_object_name = 'prestataires'
    paginate_by = 12

    def get_queryset(self):
        params = self.request.GET
        return selectors.prestataires_recherches(
            q=params.get('q'),
            ville_id=params.get('ville'),
            categorie_id=params.get('categorie'),
        )

    def get(self, request, *args, **kwargs):
        if request.headers.get('x-requested-with') == 'XMLHttpRequest':
            self.object_list = self.get_queryset()
            context = self.get_context_data()
            return render(request, 'includes/prestataire_list_partial.html', context)
        return super().get(request, *args, **kwargs)

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context.update(selectors.references_prestataire())
        context['search_query'] = self.request.GET.get('q', '')
        context['current_ville'] = self.request.GET.get('ville', '')
        context['current_categorie'] = self.request.GET.get('categorie', '')
        context['total_count'] = self.get_queryset().count()
        return context


@require_POST
@login_required
def toggle_favorite(request, pk):
    """Ajoute ou retire un prestataire des favoris de l'utilisateur connecté."""
    prestataire = get_object_or_404(Prestataire, pk=pk)
    _, cree = basculer_favori(request.user, prestataire)
    return JsonResponse({
        'status': 'favori' if cree else 'retire',
        'count': Favorite.objects.filter(prestataire=prestataire).count(),
    })
