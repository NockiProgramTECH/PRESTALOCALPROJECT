"""Service « favoris » : bascule un prestataire dans les favoris d'un utilisateur.

Même opération pour le site (`/favorite/toggle/<id>/`) et pour l'API
(`POST /api/prestataire/<id>/toggle_favorite/`) : la règle était écrite deux
fois, elle ne l'est plus qu'ici.
"""

from django.db import transaction

from ..models import Favorite


@transaction.atomic
def basculer_favori(user, prestataire):
    """Ajoute le prestataire aux favoris, ou l'en retire s'il y est déjà.

    :returns: ``(favori, cree)`` — `cree=True` si la ligne vient d'être créée,
        `False` si elle a été supprimée (le favori retourné est alors détaché).
    """
    favori, cree = Favorite.objects.get_or_create(user=user, prestataire=prestataire)
    if not cree:
        favori.delete()
    return favori, cree
