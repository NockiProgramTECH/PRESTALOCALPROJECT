"""Pages générales : accueil, pages statiques, espace client."""

from django.contrib import messages
from django.contrib.auth.decorators import login_required
from django.shortcuts import redirect, render
from django.views.generic import TemplateView

from .. import selectors


class OfflineView(TemplateView):
    """Page affichée lorsque l'utilisateur est hors ligne."""
    template_name = 'main/offline.html'


class AboutView(TemplateView):
    template_name = 'main/about.html'


def index(request):
    """Accueil : prestataires visibles et dernières publications du fil.

    La sélection (abonnement actif, notes annotées, relations préchargées) est
    dans `main.selectors` : la vue ne fait que passer le contexte au gabarit.
    """
    context = {
        'categorie': selectors.references_prestataire()['categories'],
        'prestataires': selectors.prestataires_en_avant(),
        'feed_items': selectors.dernieres_publications(),
    }
    return render(request, 'main/index.html', context)


@login_required
def client_dashboard(request):
    """Espace du client : ses avis et ses favoris (réservé aux clients)."""
    if not request.user.is_client:
        messages.error(request, "Cet espace est réservé aux clients.")
        return redirect('main:index')

    context = {
        'avis_donnes': selectors.avis_donnes_par(request.user),
        'favoris': selectors.favoris_de(request.user),
    }
    return render(request, 'main/client_dashboard.html', context)
