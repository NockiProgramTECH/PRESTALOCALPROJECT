from urllib.parse import quote

from django.contrib import messages
from django.contrib.auth.decorators import login_required
from django.shortcuts import get_object_or_404, redirect, render
from django.urls import reverse

from .models import PlanAbonnement
from .services import assurer_plans_par_defaut, souscrire


def _reference_valide(request, prestataire_id):
    """Le paramètre ``?ref=`` correspond-il bien au prestataire connecté ?

    Le jeton est signé (aucune donnée sensible) : il personnalise le message
    d'accueil des liens de relance, sans donner de droit supplémentaire.
    """
    reference = request.GET.get('ref', '')
    if not reference:
        return False
    from Notifications.abonnement import prestataire_depuis_reference

    return prestataire_depuis_reference(reference) == request.user

@login_required
def plan_list(request):
    """
    Affiche la liste des plans d'abonnement disponibles.

    Accepte le lien personnalisé envoyé par email de relance
    (`/abonnement/plans/?ref=…`) : le message d'accueil rappelle au prestataire
    pourquoi il revient ici. Le jeton est signé et vérifié ; il ne remplace pas
    la connexion (page toujours réservée au compte connecté).
    """
    if not request.user.is_prestataire:
        return redirect('main:index')

    # Bandeau d'accueil : les messages Django ne sont affichés que sur les
    # pages d'authentification ; on expose donc l'information dans le contexte
    # de la page des offres.
    relance_abonnement = _reference_valide(request, request.user.pk)

    # Offres par défaut si la base est vide (source unique : services).
    assurer_plans_par_defaut()
    
    plans = PlanAbonnement.objects.all().order_by('prix')
    return render(
        request,
        'abonnement/plan_list.html',
        {'plans': plans, 'relance_abonnement': relance_abonnement},
    )

@login_required
def choisir_payement(request, plan_id):
    """
    Page de sélection de la méthode de paiement mobile.
    """
    plan = get_object_or_404(PlanAbonnement, id=plan_id)
    return render(request, 'abonnement/choisir_payement.html', {'plan': plan})

@login_required
def simuler_otp(request, plan_id):
    """
    Simulation de l'étape de saisie du code OTP après avoir choisi Mobile Money.
    """
    plan = get_object_or_404(PlanAbonnement, id=plan_id)
    methode = request.GET.get('methode', 'Orange Money')
    
    if request.method == 'POST':
        otp = request.POST.get('otp')
        if otp and len(otp) == 6:
            # Succès de la simulation de paiement : la règle d'activation est
            # partagée avec l'API mobile (`Abonnement.services.souscrire`).
            abonnement = souscrire(request.user, plan, prefixe="SIM")

            messages.success(
                request,
                f"Paiement réussi ! Votre abonnement '{plan.nom}' est maintenant "
                f"actif jusqu'au {abonnement.date_fin.strftime('%d/%m/%Y')}.",
            )
            return redirect('main:profile')
        else:
            messages.error(request, "Code OTP invalide. Veuillez entrer les 6 chiffres.")

    return render(request, 'abonnement/simuler_otp.html', {
        'plan': plan,
        'methode': methode
    })

@login_required
def activer_essai_gratuit(request):
    """
    Ancienne vue de test - Redirige vers la liste des plans.
    """
    return redirect('Abonnement:plan_list')


@login_required
def gestion_abonnement(request, prestataire_id):
    """Gestion de l'abonnement d'un prestataire (cible des emails de relance).

    Le lien reçu par email identifie le prestataire dans l'URL : la vue
    **vérifie** que le compte connecté correspond bien avant d'afficher quoi
    que ce soit, puis renvoie vers la page des offres. Aucune donnée d'un autre
    compte n'est jamais exposée, même si l'URL est partagée.
    """
    if not request.user.is_prestataire or request.user.pk != prestataire_id:
        messages.error(
            request,
            "Ce lien d'abonnement ne correspond pas à votre compte. "
            "Connectez-vous avec l'adresse email qui l'a reçu.",
        )
        return redirect('main:index')

    # On conserve le jeton signé : la page des offres affiche alors le bandeau
    # « vous revenez d'un rappel ».
    reference = request.GET.get('ref', '')
    cible = reverse('Abonnement:plan_list')
    if reference:
        cible = f"{cible}?ref={quote(reference)}"
    return redirect(cible)
