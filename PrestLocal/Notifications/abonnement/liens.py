"""Liens signés vers l'espace d'abonnement d'un prestataire.

Le jeton ne contient qu'un identifiant, il est signé par Django et expire
(`RELANCE_LIEN_TTL_JOURS`). Aucun droit supplémentaire n'est accordé : la page
d'arrivée reste protégée par `login_required` et vérifie que le compte connecté
correspond bien au jeton.
"""

from django.conf import settings
from django.core import signing
from django.urls import reverse

from main.models import Prestataire

from .types import SEL_REFERENCE


def reference_relance(prestataire: Prestataire) -> str:
    """Jeton signé identifiant le prestataire (sans donnée sensible)."""
    return signing.dumps({"p": str(prestataire.pk)}, salt=SEL_REFERENCE, compress=True)


def prestataire_depuis_reference(reference: str):
    """Retrouve le prestataire d'un jeton de relance, ou ``None`` si invalide."""
    if not reference:
        return None
    age_max = getattr(settings, "RELANCE_LIEN_TTL_JOURS", 90) * 24 * 3600
    try:
        donnees = signing.loads(reference, salt=SEL_REFERENCE, max_age=age_max)
    except (signing.BadSignature, signing.SignatureExpired):
        return None
    return Prestataire.objects.filter(pk=donnees.get("p")).first()


def url_abonnement(prestataire: Prestataire, *, base_url: str = "") -> str:
    """URL absolue de l'espace d'abonnement du prestataire.

    Le lien identifie le prestataire dans l'URL **et** porte un jeton signé :
    la page vérifie que le compte connecté correspond avant d'afficher le
    message personnalisé (aucun droit supplémentaire n'est accordé).
    """
    base = (base_url or getattr(settings, "SITE_URL", "")).rstrip("/")
    chemin = reverse(
        "Abonnement:gestion", kwargs={"prestataire_id": prestataire.pk}
    )
    url = f"{chemin}?ref={reference_relance(prestataire)}"
    return f"{base}{url}" if base else url
