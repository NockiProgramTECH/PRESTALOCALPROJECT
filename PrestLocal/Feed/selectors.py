"""Requêtes de lecture du fil d'actualité.

Un « selector » ne fait que **lire** et préparer des données : pas d'écriture,
pas de logique métier, pas d'objet HTTP. Le but est d'écrire une seule fois les
relations à précharger (`select_related` / `prefetch_related`) et les compteurs
annotés, puis de les réutiliser côté site (`Feed.views`, `main.views`) et côté
API (`api.views`).

Sans ce module, chaque appelant reconstruisait son queryset : c'est ce qui
produisait des requêtes N+1 (une requête par carte pour les likes) et des
divergences entre le site et l'application mobile.
"""

from django.db.models import Count, Exists, OuterRef, Prefetch

from .models import Commentaire, Like, Realisation


def publications_avec_relations():
    """Publications prêtes pour le rendu d'une carte (relations préchargées).

    - `select_related` : auteur, son métier, sa ville, la catégorie.
    - `prefetch_related` : images et likes — les gabarits testent
      `request.user in real.likes.all` et affichent `likes.count`, ce qui
      déclencherait sinon une requête par publication.
    """
    return (
        Realisation.objects.select_related(
            'prestataire',
            'prestataire__metier',
            'prestataire__ville',
            'categorie',
        )
        .prefetch_related('images', 'likes')
        .order_by('-date_ajout')
    )


def publications_annotees(user=None):
    """Publications du fil avec compteurs et commentaires (usage API).

    Ajoute à :func:`publications_avec_relations` les commentaires (avec leur
    auteur) et les compteurs `like_count` / `comment_count`, ainsi que
    `liked_by_user` quand un utilisateur connecté est fourni.
    """
    qs = (
        publications_avec_relations()
        .prefetch_related(
            Prefetch('commentaires', queryset=Commentaire.objects.select_related('user'))
        )
        .annotate(
            like_count=Count('likes', distinct=True),
            comment_count=Count('commentaires', distinct=True),
        )
    )
    if user is not None and user.is_authenticated:
        qs = qs.annotate(
            liked_by_user=Exists(
                Like.objects.filter(user=user, realisation=OuterRef('pk'))
            )
        )
    return qs
