from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth.decorators import login_required
from django.contrib import messages
from .models import Abonnement, PlanAbonnement
from django.utils import timezone
from datetime import timedelta
import uuid

@login_required
def plan_list(request):
    """
    Affiche la liste des plans d'abonnement disponibles.
    """
    if not request.user.is_prestataire:
        return redirect('main:index')
        
    # S'assurer qu'il y a au moins quelques plans par défaut
    if not PlanAbonnement.objects.exists():
        PlanAbonnement.objects.create(nom="Découverte (1 mois)", prix=5000, duree_jours=30, description="Idéal pour commencer et tester la plateforme.")
        PlanAbonnement.objects.create(nom="Professionnel (6 mois)", prix=25000, duree_jours=180, description="Pour les pros qui veulent une visibilité durable.")
        PlanAbonnement.objects.create(nom="Premium (1 an)", prix=45000, duree_jours=365, description="La meilleure valeur pour une présence continue toute l'année.")
        
    plans = PlanAbonnement.objects.all().order_by('prix')
    return render(request, 'abonnement/plan_list.html', {'plans': plans})

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
            # Succès de la simulation de paiement
            date_fin = timezone.now() + timedelta(days=plan.duree_jours)
            
            # Créer ou mettre à jour l'abonnement
            abo, created = Abonnement.objects.get_or_create(
                prestataire=request.user,
                defaults={
                    'plan': plan,
                    'date_fin': date_fin,
                    'est_actif': True,
                    'paye': True,
                    'transaction_id': f"SIM-{uuid.uuid4().hex[:8].upper()}"
                }
            )
            
            if not created:
                abo.plan = plan
                abo.date_fin = date_fin
                abo.est_actif = True
                abo.paye = True
                abo.transaction_id = f"SIM-{uuid.uuid4().hex[:8].upper()}"
                abo.save()
            
            messages.success(request, f"Paiement réussi ! Votre abonnement '{plan.nom}' est maintenant actif jusqu'au {date_fin.strftime('%d/%m/%Y')}.")
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
