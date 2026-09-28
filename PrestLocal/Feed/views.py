from django.shortcuts import render, get_object_or_404
from django.http import JsonResponse
from django.contrib.auth.decorators import login_required
from django.views.decorators.http import require_POST
from django.core.paginator import Paginator
from main.models import Realisation
from .models import Like, Commentaire

# Nombre de réalisations chargées par page (utilisé ici ET dans main/views.py)
FEED_PAGE_SIZE = 6

@login_required
@require_POST
def toggle_like(request, realisation_id):
    """
    Aime ou retire le like d'une réalisation.
    """
    realisation = get_object_or_404(Realisation, id=realisation_id)
    like, created = Like.objects.get_or_create(user=request.user, realisation=realisation)
    
    if not created:
        like.delete()
        liked = False
    else:
        liked = True
        
    return JsonResponse({
        'status': 'success',
        'liked': liked,
        'like_count': realisation.likes.count()
    })

@login_required
@require_POST
def add_comment(request, realisation_id):
    """
    Ajoute un commentaire à une réalisation.
    """
    realisation = get_object_or_404(Realisation, id=realisation_id)
    contenu = request.POST.get('contenu')
    
    if not contenu or not contenu.strip():
        return JsonResponse({'status': 'error', 'message': 'Le commentaire est vide.'}, status=400)
        
    commentaire = Commentaire.objects.create(
        user=request.user,
        realisation=realisation,
        contenu=contenu.strip()
    )
    
    return JsonResponse({
        'status': 'success',
        'comment': {
            'user': f"{request.user.first_name} {request.user.last_name}",
            'contenu': commentaire.contenu,
            'date': "À l'instant"
        },
        'comment_count': realisation.commentaires.count()
    })

def feed_list(request):
    """
    Renvoie une page de réalisations pour l'infinite scroll.

    Paramètres GET :
      - page (int, défaut 1) : numéro de la page demandée

    Réponse JSON (requête AJAX) :
      {
        "html"      : "<article>...</article>",  # HTML des cartes
        "has_next"  : true | false,              # y a-t-il une page suivante ?
        "next_page" : 3                          # numéro de la prochaine page
      }

    Réponse HTML (premier chargement via include Django) :
      Renvoie le template feed/feed_items.html directement.
    """
    qs   = Realisation.objects.select_related('prestataire', 'prestataire__metier').order_by('-date_ajout')
    page_num = request.GET.get('page', 1)

    paginator = Paginator(qs, FEED_PAGE_SIZE)
    page_obj  = paginator.get_page(page_num)

    # Requête AJAX (infinite scroll) → JSON + HTML partiel
    if request.headers.get('X-Requested-With') == 'XMLHttpRequest':
        html = render(request, 'feed/feed_items.html', {
            'realisations': page_obj.object_list,
        }).content.decode('utf-8')

        return JsonResponse({
            'status'    : 'success',
            'html'      : html,
            'has_next'  : page_obj.has_next(),
            'next_page' : page_obj.next_page_number() if page_obj.has_next() else None,
        })

    # Premier chargement (include Django depuis index.html)
    return render(request, 'feed/feed_items.html', {'realisations': page_obj.object_list})
