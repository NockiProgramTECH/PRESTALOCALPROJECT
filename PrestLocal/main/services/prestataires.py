"""Services du profil prestataire : disponibilité et compteurs d'audience.

Ces opérations étaient écrites directement dans les vues, avec la même
arithmétique (`F(...) + 1` puis `refresh_from_db`) dupliquée pour l'appel et le
contact. Elles sont regroupées ici, testables sans HTTP.
"""

from django.db.models import F

from ..models import Prestataire

#: Compteurs d'audience incrémentables depuis l'interface.
CHAMPS_COMPTEURS = {
    'appel': 'call_clicks',
    'contact': 'contact_clicks',
    'vue': 'profile_views',
}


def definir_disponibilite(prestataire, disponible):
    """Rend le prestataire disponible ou indisponible pour de nouvelles demandes."""
    prestataire.is_available = bool(disponible)
    prestataire.save(update_fields=['is_available'])
    return prestataire.is_available


def enregistrer_clic(prestataire, type_clic):
    """Incrémente le compteur d'audience `appel` ou `contact`.

    L'incrément est fait en base (`F`) pour rester exact même si deux
    visiteurs cliquent en même temps, puis la valeur à jour est relue.
    """
    try:
        champ = CHAMPS_COMPTEURS[type_clic]
    except KeyError as exc:
        raise ValueError(f"Type de clic inconnu : {type_clic}") from exc

    Prestataire.objects.filter(pk=prestataire.pk).update(
        **{champ: F(champ) + 1}
    )
    prestataire.refresh_from_db(fields=[champ])
    return getattr(prestataire, champ)


def enregistrer_vue_profil(prestataire):
    """Compte une consultation de fiche prestataire (hors propriétaire)."""
    return enregistrer_clic(prestataire, 'vue')
