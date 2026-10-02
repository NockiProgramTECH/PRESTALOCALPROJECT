"""Services « avis client sur un prestataire ».

Le dépôt d'un avis est une règle métier partagée par le site (formulaire AJAX)
et l'API mobile. Le service garantit les invariants :

- note entière entre 1 et 5 (le modèle valide, mais `objects.create()` ne
  déclenche pas les validateurs : la vérification est faite ici) ;
- commentaire non vide ;
- un seul avis par couple (prestataire, client) — soit refusé, soit remplacé
  selon l'appelant (`remplacer=True` pour l'API, qui met à jour l'avis).

L'email et la notification interne sont dans :func:`notifier_nouvel_avis`,
appelée séparément : le site l'utilise, l'API ne l'envoyait pas (comportement
conservé à l'identique).
"""

import logging

from django.db import transaction
from django.db.models import Avg, Count

from Notifications.service import envoyer_email

from ..models import Evaluation, Notification, Prestataire

logger = logging.getLogger(__name__)

NOTE_MINIMALE = 1
NOTE_MAXIMALE = 5
LONGUEUR_MINIMALE_COMMENTAIRE = 3


class AvisInvalide(Exception):
    """L'avis ne respecte pas une règle métier (note, commentaire, cible)."""


class NoteHorsBornes(AvisInvalide):
    """La note n'est pas comprise entre 1 et 5."""


class AvisDejaDonne(AvisInvalide):
    """Un avis existe déjà pour ce couple (prestataire, client)."""


def _valider(prestataire, client, note, commentaire):
    """Vérifie les données déjà converties ; lève :class:`AvisInvalide` si besoin."""
    if prestataire.pk == getattr(client, 'pk', None):
        raise AvisInvalide("Vous ne pouvez pas vous évaluer vous-même.")
    if prestataire.role != Prestataire.ROLE_PRESTATAIRE:
        raise AvisInvalide("Vous ne pouvez évaluer que des prestataires.")

    try:
        note = int(note)
    except (TypeError, ValueError) as exc:
        raise NoteHorsBornes("La note doit être un nombre entier.") from exc
    if not NOTE_MINIMALE <= note <= NOTE_MAXIMALE:
        raise NoteHorsBornes("La note doit être comprise entre 1 et 5.")

    commentaire = (commentaire or '').strip()
    if len(commentaire) < LONGUEUR_MINIMALE_COMMENTAIRE:
        raise AvisInvalide("Le commentaire est trop court.")
    return note, commentaire


@transaction.atomic
def soumettre_avis(
    *,
    prestataire,
    client,
    note,
    commentaire,
    prenom='',
    nom='',
    remplacer=False,
):
    """Enregistre l'avis de `client` sur `prestataire`.

    :param remplacer: ``True`` → un avis existant est mis à jour (API) ;
        ``False`` → un second avis est refusé (site).
    :returns: le couple ``(evaluation, cree)``.
    :raises AvisInvalide: règle violée (note, commentaire, cible, doublon).
    """
    note, commentaire = _valider(prestataire, client, note, commentaire)

    existant = Evaluation.objects.filter(prestataire=prestataire, client=client).first()
    if existant and not remplacer:
        raise AvisDejaDonne("Vous avez déjà évalué ce prestataire.")

    valeurs = {
        'note': note,
        'commentaire': commentaire,
        # Dénormalisation : affichage des avis sans jointure supplémentaire.
        'client_nom': (nom or client.last_name or '').strip(),
        'client_prenom': (prenom or client.first_name or '').strip(),
        'client_email': client.email,
    }

    if existant:
        for champ, valeur in valeurs.items():
            setattr(existant, champ, valeur)
        existant.save()
        return existant, False

    evaluation = Evaluation.objects.create(
        prestataire=prestataire, client=client, **valeurs
    )
    return evaluation, True


def statistiques_avis(prestataire):
    """Note moyenne (arrondie à 2 décimales) et nombre d'avis d'un prestataire."""
    stats = Evaluation.objects.filter(prestataire=prestataire).aggregate(
        moyenne=Avg('note'), total=Count('id')
    )
    return {
        'moyenne_etoile': round(stats['moyenne'] or 0, 2),
        'nombre_avis': stats['total'] or 0,
    }


def notifier_nouvel_avis(evaluation, *, hote=''):
    """Prévient le prestataire : email (idempotent) puis notification interne.

    L'échec d'un canal ne remonte jamais : l'avis est déjà enregistré.
    """
    prestataire = evaluation.prestataire
    client = evaluation.client

    envoyer_email(
        prestataire,
        sujet=f"Nouvel avis reçu ({evaluation.note}/5) - LesProduFao",
        texte=(
            f"Bonjour {prestataire.first_name}, vous avez reçu un nouvel avis "
            f"de {client.get_full_name()} : {evaluation.note}/5 étoiles."
        ),
        template='emails/evaluation.html',
        contexte={
            'prestataire': prestataire,
            'client': client,
            'note': evaluation.note,
            'commentaire': evaluation.commentaire,
            'domain': hote,
        },
        type_notification='evaluation',
        # Un avis donné une fois = un seul email (pas de doublon si rejoué).
        cle_unique=f"avis:{evaluation.pk}",
    )

    # Notification interne : purement indicative, elle ne doit pas casser
    # l'enregistrement de l'avis (table différente du journal d'envoi).
    try:
        Notification.objects.create(
            recipient=prestataire,
            actor=client,
            notification_type='evaluation',
            message=f"{client.first_name} a laissé un avis de {evaluation.note}/5",
            link=f"/prestataire/{prestataire.pk}/",
        )
    except Exception:  # volontaire : la notification interne est accessoire
        logger.exception("Notification interne non créée pour l'avis %s", evaluation.pk)
