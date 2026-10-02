"""Fragments partagés par les sérialiseurs : helpers et limites d'upload.

Ces fonctions ne sont pas des sérialiseurs : elles calculent une URL absolue,
masquent les coordonnées d'un prestataire non abonné ou contrôlent un fichier
envoyé. Elles sont regroupées ici parce que plusieurs sérialiseurs de domaines
différents les utilisent."""

import re

from rest_framework import serializers


PHONE_REGEX = re.compile(r'^(\+?226)?[\s.-]?\d{2}[\s.-]?\d{2}[\s.-]?\d{2}[\s.-]?\d{2}$')


def contact_visible(obj):
    """Règle produit : seuls les prestataires dont l'abonnement est payé, actif
    et non expiré sont **contactables**.

    Leur fiche reste consultable (utile depuis une publication du fil
    d'actualité), mais sans téléphone ni email : `contact_disponible` indique à
    l'application si elle doit afficher les boutons d'appel / message.
    """
    return bool(getattr(obj, 'has_active_subscription', False))


def is_favorite_for(request, prestataire):
    """Indique si `prestataire` est en favori pour l'utilisateur de `request`."""
    if request is None or not getattr(request, 'user', None):
        return False
    if not request.user.is_authenticated:
        return False
    from main.models import Favorite
    return Favorite.objects.filter(user=request.user, prestataire=prestataire).exists()


def absolute_media_url(request, file_field):
    """Retourne l'URL absolue d'un `ImageField` (ou None)."""
    if not file_field:
        return None
    try:
        url = file_field.url
    except ValueError:
        return None
    if request is not None:
        return request.build_absolute_uri(url)
    return url


MAX_PUBLICATION_IMAGES = 10
MAX_IMAGE_SIZE = 5 * 1024 * 1024          # 5 Mo par image
MAX_VIDEO_SIZE = 50 * 1024 * 1024         # 50 Mo par vidéo
ALLOWED_IMAGE_EXTENSIONS = ('jpg', 'jpeg', 'png', 'webp')
ALLOWED_VIDEO_EXTENSIONS = ('mp4', 'mov', 'm4v', 'webm')


def file_extension(upload):
    name = (getattr(upload, 'name', '') or '').lower()
    return name.rsplit('.', 1)[-1] if '.' in name else ''


def validate_upload(upload, *, allowed, max_size, label):
    """Contrôle le type et la taille d'un fichier envoyé."""
    extension = file_extension(upload)
    if extension not in allowed:
        raise serializers.ValidationError(
            f"{label} : format non pris en charge (autorisés : "
            f"{', '.join(allowed)})."
        )
    if upload.size > max_size:
        raise serializers.ValidationError(
            f"{label} : fichier trop volumineux "
            f"({upload.size // (1024 * 1024)} Mo, maximum "
            f"{max_size // (1024 * 1024)} Mo)."
        )
    return upload


def realisation_image_urls(obj, request):
    """URLs absolues des images d'une publication (principale puis extras)."""
    urls = []
    principale = absolute_media_url(request, obj.image)
    if principale:
        urls.append(principale)
    for extra in obj.images.all():
        url = absolute_media_url(request, extra.image)
        if url:
            urls.append(url)
    return urls
