"""Requêtes de lecture de l'API REST.

Les vues DRF ne construisent plus leurs querysets : elles demandent ici un
queryset déjà filtré, préchargé et annoté. Les règles de visibilité et les
préchargements sont définis une seule fois (dans `main.querysets` et
`Feed.selectors`) et réutilisés par le site comme par l'API.
"""

from Feed.selectors import publications_annotees
from main.models import Prestataire


def prestataires_api():
    """Prestataires prêts pour la liste **et** la fiche détaillée.

    Contient tous les prestataires (la liste ajoute le filtre de visibilité
    selon `?include_all=`) : relations préchargées, note moyenne annotée et tri
    stable, sans lequel la pagination peut répéter ou oublier des lignes.
    """
    return (
        Prestataire.objects.prestataires()
        .avec_relations()
        .avec_note_moyenne()
        .order_by('first_name', 'last_name')
    )


def favoris_api(user):
    """Favoris d'un utilisateur, du plus récemment ajouté au plus ancien."""
    return (
        Prestataire.objects.filter(favorited_by__user=user)
        .avec_relations()
        .avec_note_moyenne()
        .order_by('-favorited_by__created_at')
    )


def publications_api(user=None):
    """Publications du fil : compteurs annotés et commentaires préchargés."""
    return publications_annotees(user)
