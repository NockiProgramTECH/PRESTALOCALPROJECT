"""Requêtes de lecture des pages du site.

Un *selector* ne fait que lire et préparer des données : pas d'écriture, pas de
logique métier, pas d'objet HTTP. Les vues web y trouvent un queryset prêt à
l'emploi, ce qui évite de réécrire les mêmes filtres (`visibles()`, préchargements,
annotations) à plusieurs endroits et rend ces requêtes testables sans client HTTP.
"""

from django.db.models import Q

from Feed.selectors import publications_avec_relations

from .models import CategoriePrestation, Evaluation, Favorite, Prestataire, Ville


def prestataires_en_avant(limite=8):
    """Prestataires visibles et disponibles mis en avant sur l'accueil.

    Les notes sont annotées : le gabarit peut afficher `average_rating` et
    `review_count` sans déclencher une requête par carte.
    """
    return (
        Prestataire.objects.visibles()
        .filter(is_available=True)
        .select_related('ville', 'metier')
        .avec_note_et_avis()
        .order_by('id')[:limite]
    )


def prestataires_recherches(*, q=None, ville_id=None, categorie_id=None):
    """Annuaire des prestataires visibles, filtré par la recherche utilisateur.

    `q` cherche dans le prénom, le nom et le métier ; `ville_id` et
    `categorie_id` viennent des filtres de la page. Le tri reprend celui de la
    page : les inscriptions les plus récentes d'abord.
    """
    queryset = (
        Prestataire.objects.visibles()
        .filter(is_available=True)
        .select_related('ville', 'metier')
        .avec_note_et_avis()
    )
    if q:
        queryset = queryset.filter(
            Q(first_name__icontains=q)
            | Q(last_name__icontains=q)
            | Q(metier__nom__icontains=q)
        )
    if ville_id:
        queryset = queryset.filter(ville_id=ville_id)
    if categorie_id:
        queryset = queryset.filter(metier__categorie_id=categorie_id)
    return queryset.order_by('-date_inscription')


def dernieres_publications(limite=10):
    """Dernières publications du fil, affichées sur l'accueil."""
    return publications_avec_relations()[:limite]


def avis_donnes_par(user):
    """Avis déposés par un client (espace client)."""
    return (
        Evaluation.objects.filter(client=user)
        .select_related('prestataire', 'prestataire__metier')
        .order_by('-date_evaluation')
    )


def favoris_de(user):
    """Prestataires favoris d'un utilisateur (espace client)."""
    return Favorite.objects.filter(user=user).select_related(
        'prestataire', 'prestataire__metier'
    )


def references_prestataire():
    """Villes et catégories nécessaires aux filtres de l'annuaire."""
    return {
        'villes': Ville.objects.all(),
        'categories': CategoriePrestation.objects.all(),
    }
