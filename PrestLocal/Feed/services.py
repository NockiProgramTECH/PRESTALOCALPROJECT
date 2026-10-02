"""Services métier du fil d'actualité.

Ces opérations étaient **dupliquées** entre le site web (`Feed/views.py`) et
l'API REST (`api/views.py`) : la logique vit maintenant ici, une seule fois, et
les deux points d'entrée l'appellent.

Un service ne connaît ni ``request`` ni ``JsonResponse`` : il reçoit des objets
du domaine et retourne un résultat compréhensible (donc testable seul).
"""

from dataclasses import dataclass

from .models import Commentaire, Like


@dataclass(frozen=True)
class ResultatLike:
    """Nouvel état d'un « J'aime » après bascule."""

    liked: bool
    like_count: int


class CommentaireVide(Exception):
    """Le commentaire reçu est vide (erreur métier, pas erreur technique)."""


def basculer_like(user, realisation) -> ResultatLike:
    """Aime la réalisation, ou retire le like déjà posé (toggle).

    Retourne l'état **réel** après opération : le compteur provient de la base,
    jamais d'un calcul local.
    """
    like, cree = Like.objects.get_or_create(user=user, realisation=realisation)
    if not cree:
        like.delete()
    return ResultatLike(liked=cree, like_count=realisation.likes.count())


def ajouter_commentaire(user, realisation, contenu: str) -> Commentaire:
    """Ajoute un commentaire non vide à une réalisation.

    Lève :class:`CommentaireVide` si le texte est vide après nettoyage : les
    appelants traduisent cette erreur métier en 400 (API) ou en message (web).
    """
    texte = (contenu or "").strip()
    if not texte:
        raise CommentaireVide()
    return Commentaire.objects.create(
        user=user, realisation=realisation, contenu=texte
    )


def compter_commentaires(realisation) -> int:
    """Nombre de commentaires d'une réalisation (compteur affiché)."""
    return realisation.commentaires.count()
