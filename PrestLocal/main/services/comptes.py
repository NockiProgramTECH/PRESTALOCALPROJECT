"""Services du cycle de vie d'un compte : inscription, vérification, mot de passe.

Règles portées ici (elles n'ont rien à voir avec HTTP) :

- un compte reste **inactif** tant que son code de vérification n'est pas validé ;
- inscription et envoi du code sont **atomiques** : si l'email ne part pas, le
  compte n'est pas conservé (même comportement qu'avant, sans `delete()` manuel) ;
- la demande de réinitialisation ne révèle jamais l'existence d'un compte
  (protection contre l'énumération des adresses) ;
- la validation des saisies reste dans les formulaires / sérialiseurs : ces
  services reçoivent des données déjà validées et ne connaissent pas la requête.
"""

import logging
import random

from django.db import transaction

from Notifications.abonnement import url_abonnement
from Notifications.service import envoyer_email

from ..models import Prestataire

logger = logging.getLogger(__name__)

#: Longueur du code de vérification envoyé par email.
LONGUEUR_CODE = 6


class EnvoiCodeImpossible(Exception):
    """Le code n'a pas pu être envoyé : l'inscription ne doit pas être conservée."""


class CodeInvalide(Exception):
    """Le code saisi ne correspond pas (ou plus) à celui du compte."""


def _code_aleatoire() -> str:
    """Code numérique à usage unique envoyé par email."""
    return str(random.randint(10 ** (LONGUEUR_CODE - 1), 10**LONGUEUR_CODE - 1))


@transaction.atomic
def demarrer_inscription(*, utilisateur, base_url='', hote=''):
    """Rend le compte inactif, lui attribue un code et envoie ce code.

    :param utilisateur: compte **non enregistré** construit par le formulaire
        d'inscription (`form.save(commit=False)`), validé en frontière.
    :raises EnvoiCodeImpossible: si aucun canal n'a pu délivrer le code ; la
        transaction est annulée, donc aucun compte à moitié créé ne subsiste.
    """
    code = _code_aleatoire()
    utilisateur.is_active = False
    utilisateur.code_verification = code
    utilisateur.save()

    rapport = envoyer_email(
        utilisateur,
        sujet="Code de vérification - LesProduFao",
        texte=f"Votre code de vérification est : {code}",
        template='emails/verification_code.html',
        contexte={'user': utilisateur, 'code': code, 'domain': hote},
        type_notification='code_verification',
        cle_unique=f"inscription:{utilisateur.pk}",
    )
    if not rapport.envoye:
        logger.warning(
            "Inscription %s : code non délivré (%s)", utilisateur.pk, rapport.details
        )
        raise EnvoiCodeImpossible(
            "L'email de vérification n'a pas pu être envoyé."
        )
    return utilisateur


def activer_compte(utilisateur, code):
    """Active le compte si `code` correspond, puis efface le code.

    :raises CodeInvalide: code absent ou différent.
    """
    if not code or code != utilisateur.code_verification:
        raise CodeInvalide("Code de vérification incorrect.")

    utilisateur.is_active = True
    utilisateur.code_verification = None
    utilisateur.save(update_fields=['is_active', 'code_verification'])
    return utilisateur


def envoyer_invitation_abonnement(utilisateur, *, base_url='', hote=''):
    """Invite le nouvel inscrit à activer son profil / son abonnement.

    Un prestataire reçoit un lien direct vers son espace d'abonnement ; un
    client est renvoyé vers l'accueil. Idempotent (`cle_unique`), et l'échec
    d'envoi ne remonte pas : l'inscription est déjà terminée.
    """
    if utilisateur.is_prestataire:
        lien = url_abonnement(utilisateur, base_url=base_url)
    else:
        lien = f"{base_url}/" if base_url else '/'

    return envoyer_email(
        utilisateur,
        sujet="Activez votre profil sur LesProduFao",
        texte=(
            f"Bienvenue {utilisateur.first_name}, activez votre abonnement "
            "pour être visible."
        ),
        template='emails/subscription_request.html',
        contexte={
            'user': utilisateur,
            'domain': hote,
            'url_abonnement': lien,
        },
        type_notification='activation_profil',
        cle_unique=f"activation:{utilisateur.pk}",
    )


def demander_reinitialisation(email, *, hote=''):
    """Envoie un code de réinitialisation si `email` correspond à un compte.

    Retourne le compte concerné, ou ``None`` si l'adresse est inconnue : dans
    les deux cas, l'appelant affiche le **même** message générique.
    """
    try:
        utilisateur = Prestataire.objects.get(email__iexact=email.strip())
    except (Prestataire.DoesNotExist, Prestataire.MultipleObjectsReturned):
        logger.info("Réinitialisation demandée pour une adresse inconnue")
        return None

    code = _code_aleatoire()
    utilisateur.code_verification = code
    utilisateur.save(update_fields=['code_verification'])

    envoyer_email(
        utilisateur,
        sujet="Réinitialisation de mot de passe - LesProduFao",
        texte=f"Votre code de réinitialisation est : {code}",
        template='emails/password_reset_code.html',
        contexte={'user': utilisateur, 'code': code, 'domain': hote},
        type_notification='code_reinitialisation',
        # Pas de `cle_unique` : l'utilisateur doit pouvoir redemander un code.
        # Le code lui-même n'est jamais journalisé (secret à usage unique).
    )
    return utilisateur


def reinitialiser_mot_de_passe(utilisateur, code, nouveau_mot_de_passe):
    """Change le mot de passe après vérification du code.

    :raises CodeInvalide: code absent ou différent.
    """
    if not code or code != utilisateur.code_verification:
        raise CodeInvalide("Code de vérification incorrect.")

    utilisateur.set_password(nouveau_mot_de_passe)
    utilisateur.code_verification = None
    utilisateur.save(update_fields=['password', 'code_verification'])
    return utilisateur
