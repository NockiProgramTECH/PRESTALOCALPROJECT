"""Vues d'authentification : connexion, inscription, vérification, mot de passe.

Les vues ne portent que l'interaction HTTP (formulaires, session, redirections
et messages). Les règles du cycle de vie du compte — création du code,
activation, réinitialisation, envoi des emails — sont dans
`main.services.comptes`.
"""

import logging

from django.contrib import messages
from django.contrib.auth import authenticate, login, logout
from django.shortcuts import redirect, render

from ..forms import (
    PasswordResetConfirmForm,
    PasswordResetRequestForm,
    PrestataireLoginForm,
    PrestataireSignupForm,
    VerifyEmailForm,
)
from ..models import Prestataire
from ..services import (
    CodeInvalide,
    EnvoiCodeImpossible,
    activer_compte,
    demarrer_inscription,
    demander_reinitialisation,
    envoyer_invitation_abonnement,
    reinitialiser_mot_de_passe,
)

logger = logging.getLogger(__name__)

MESSAGE_REINITIALISATION = (
    "Si un compte existe pour cette adresse, un code de réinitialisation vient "
    "d'être envoyé."
)


def _base_url(request):
    """URL absolue du site, pour les liens contenus dans les emails."""
    return request.build_absolute_uri('/')[:-1]


def _redirection_apres_connexion(request, utilisateur):
    """Destination adaptée à l'état du compte (profil incomplet → profil)."""
    if utilisateur.is_prestataire and not utilisateur.profile_completed:
        messages.info(
            request,
            "Complétez votre profil (métier, ville, quartier) pour apparaître "
            "dans les recherches.",
        )
        return redirect('main:profile')
    return redirect('main:index')


def login_view(request):
    if request.user.is_authenticated:
        return redirect('main:index')

    if request.method == 'POST':
        form = PrestataireLoginForm(data=request.POST)
        if form.is_valid():
            utilisateur = authenticate(
                email=form.cleaned_data.get('username'),
                password=form.cleaned_data.get('password'),
            )
            if utilisateur is not None:
                login(request, utilisateur)
                messages.success(request, f"Bienvenue, {utilisateur.first_name} !")
                return _redirection_apres_connexion(request, utilisateur)
            messages.error(request, "Email ou mot de passe incorrect.")
        else:
            messages.error(request, "Veuillez corriger les erreurs ci-dessous.")
    else:
        form = PrestataireLoginForm()

    return render(request, 'main/login.html', {'form': form})


def signup_view(request):
    """Inscription : crée un compte inactif et envoie le code de vérification."""
    if request.user.is_authenticated:
        return redirect('main:index')

    if request.method == 'POST':
        form = PrestataireSignupForm(request.POST, request.FILES)
        if form.is_valid():
            try:
                utilisateur = demarrer_inscription(
                    utilisateur=form.save(commit=False),
                    base_url=_base_url(request),
                    hote=request.get_host(),
                )
            except EnvoiCodeImpossible:
                # Compte non conservé (transaction annulée) : l'utilisateur
                # peut réessayer, aucun détail technique n'est exposé.
                logger.warning("Inscription : envoi du code impossible", exc_info=True)
                messages.error(
                    request,
                    "Erreur lors de l'envoi de l'email de vérification. "
                    "Veuillez réessayer.",
                )
                return render(request, 'main/signup.html', {'form': form})

            request.session['verification_user_id'] = str(utilisateur.id)
            messages.success(
                request, "Un code de vérification a été envoyé à votre adresse email."
            )
            return redirect('main:verify_email')

        messages.error(
            request, "Erreur lors de l'inscription. Vérifiez les informations."
        )
    else:
        form = PrestataireSignupForm()

    return render(request, 'main/signup.html', {'form': form})


def verify_email_view(request):
    """Saisie du code reçu : active le compte et connecte immédiatement."""
    user_id = request.session.get('verification_user_id')
    if not user_id:
        return redirect('main:signup')

    try:
        utilisateur = Prestataire.objects.get(id=user_id)
    except Prestataire.DoesNotExist:
        return redirect('main:signup')

    if request.method == 'POST':
        form = VerifyEmailForm(request.POST)
        if form.is_valid():
            try:
                activer_compte(utilisateur, form.cleaned_data.get('code'))
            except CodeInvalide as exc:
                messages.error(request, str(exc))
            else:
                login(request, utilisateur)
                envoyer_invitation_abonnement(
                    utilisateur,
                    base_url=_base_url(request),
                    hote=request.get_host(),
                )
                request.session.pop('verification_user_id', None)
                messages.success(
                    request,
                    "Votre compte a été activé et vous êtes maintenant connecté. "
                    "Bienvenue !",
                )
                if utilisateur.is_prestataire:
                    messages.info(
                        request,
                        "Dernière étape : renseignez votre métier, votre ville et "
                        "votre quartier, puis activez votre abonnement.",
                    )
                    return redirect('main:profile')
                return redirect('main:client_dashboard')
    else:
        form = VerifyEmailForm()

    return render(
        request, 'main/verify_email.html', {'form': form, 'email': utilisateur.email}
    )


def password_reset_request_view(request):
    """Demande de réinitialisation — réponse identique si l'adresse est inconnue."""
    if request.user.is_authenticated:
        return redirect('main:index')

    if request.method == 'POST':
        form = PasswordResetRequestForm(request.POST)
        if form.is_valid():
            utilisateur = demander_reinitialisation(
                form.cleaned_data.get('email'), hote=request.get_host()
            )
            if utilisateur is not None:
                request.session['reset_user_id'] = str(utilisateur.id)
            messages.success(request, MESSAGE_REINITIALISATION)
            return redirect('main:password_reset_confirm')
    else:
        form = PasswordResetRequestForm()

    return render(request, 'main/password_reset_request.html', {'form': form})


def password_reset_confirm_view(request):
    """Saisie du code + du nouveau mot de passe, puis connexion automatique."""
    user_id = request.session.get('reset_user_id')
    if not user_id:
        return redirect('main:password_reset_request')

    try:
        utilisateur = Prestataire.objects.get(id=user_id)
    except Prestataire.DoesNotExist:
        return redirect('main:password_reset_request')

    if request.method == 'POST':
        form = PasswordResetConfirmForm(request.POST)
        if form.is_valid():
            try:
                reinitialiser_mot_de_passe(
                    utilisateur,
                    form.cleaned_data.get('code'),
                    form.cleaned_data.get('new_password'),
                )
            except CodeInvalide as exc:
                messages.error(request, str(exc))
            else:
                login(request, utilisateur)
                request.session.pop('reset_user_id', None)
                messages.success(
                    request,
                    "Votre mot de passe a été réinitialisé avec succès. "
                    "Vous êtes maintenant connecté.",
                )
                return redirect('main:index')
    else:
        form = PasswordResetConfirmForm()

    return render(
        request,
        'main/password_reset_confirm.html',
        {'form': form, 'email': utilisateur.email},
    )


def logout_view(request):
    logout(request)
    messages.info(request, "Vous avez été déconnecté.")
    return redirect('main:index')
