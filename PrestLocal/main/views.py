from django.views.generic import DetailView, ListView, TemplateView
from django.shortcuts import render, redirect, get_object_or_404
from django.contrib.auth import login, authenticate, logout
from django.contrib import messages
from django.http import JsonResponse
from django.views.decorators.http import require_POST
from django.contrib.auth.decorators import login_required
from django.db import models
from django.core.mail import EmailMultiAlternatives
from django.template.loader import render_to_string
import random
from .forms import PrestataireSignupForm, PrestataireLoginForm, PrestataireProfileForm, RealisationForm, VerifyEmailForm, PasswordResetRequestForm, PasswordResetConfirmForm
from .models import Prestataire, CategoriePrestation, Prestation, Ville, Evaluation, Realisation, Favorite, Notification


class OfflineView(TemplateView):
    """Page affichée lorsque l'utilisateur est hors ligne."""
    template_name = 'main/offline.html'

class AboutView(TemplateView):
    template_name = 'main/about.html'
    



@login_required
def profile_view(request):

    """
    Page de gestion du profil pour le prestataire connecté.
    """
    prestataire = request.user
    if not prestataire.is_prestataire:
        messages.error(request, "Cet espace est réservé aux prestataires.")
        return redirect('main:index')

    realisations = prestataire.realisations.all().order_by('-date_ajout')
    profile_form = PrestataireProfileForm(instance=prestataire)
    stats = {
        'profile_views': prestataire.profile_views,
        'call_clicks': prestataire.call_clicks,
        'contact_clicks': prestataire.contact_clicks,
        'average_rating': prestataire.average_rating,
        'review_count': prestataire.review_count,
    }
    
    return render(request, 'main/profile.html', {
        'prestataire': prestataire,
        'realisations': realisations,
        'form': RealisationForm(),
        'profile_form': profile_form,
        'stats': stats
    })

@require_POST
@login_required
def update_profile(request):
    if not request.user.is_prestataire:
        return JsonResponse({'status': 'error', 'message': 'Cet espace est réservé aux prestataires.'}, status=403)

    form = PrestataireProfileForm(request.POST, request.FILES, instance=request.user)
    if form.is_valid():
        form.save()
        return JsonResponse({'status': 'success', 'message': 'Profil mis à jour avec succès.'})
    else:
        return JsonResponse({'status': 'error', 'errors': form.errors.as_json()}, status=400)

@require_POST
@login_required
def toggle_availability(request):
    if not request.user.is_prestataire:
        return JsonResponse({'status': 'error', 'message': 'Cet espace est réservé aux prestataires.'}, status=403)

    is_available = request.POST.get('is_available')
    if is_available is None:
        return JsonResponse({'status': 'error', 'message': 'Valeur de disponibilité manquante.'}, status=400)

    request.user.is_available = is_available == 'true'
    request.user.save(update_fields=['is_available'])
    return JsonResponse({'status': 'success', 'is_available': request.user.is_available})

@require_POST
def record_call_click(request, pk):
    try:
        prestataire = Prestataire.objects.get(pk=pk)
    except Prestataire.DoesNotExist:
        return JsonResponse({'status': 'error', 'message': 'Prestataire introuvable.'}, status=404)

    Prestataire.objects.filter(pk=prestataire.pk).update(call_clicks=models.F('call_clicks') + 1)
    prestataire.refresh_from_db(fields=['call_clicks'])
    return JsonResponse({'status': 'success', 'call_clicks': prestataire.call_clicks})

@require_POST
def record_contact_click(request, pk):
    try:
        prestataire = Prestataire.objects.get(pk=pk)
    except Prestataire.DoesNotExist:
        return JsonResponse({'status': 'error', 'message': 'Prestataire introuvable.'}, status=404)

    Prestataire.objects.filter(pk=prestataire.pk).update(contact_clicks=models.F('contact_clicks') + 1)
    return JsonResponse({'status': 'success'})

@require_POST
@login_required
def add_realisation(request):
    """
    Vue AJAX pour ajouter une réalisation au portfolio.
    """
    form = RealisationForm(request.POST, request.FILES)
    if form.is_valid():
        realisation = form.save(commit=False)
        realisation.prestataire = request.user
        realisation.save()
        
        return JsonResponse({
            'status': 'success',
            'message': 'Réalisation ajoutée avec succès !',
            'realisation': {
                'id': realisation.id,
                'titre': realisation.titre,
                'image_url': realisation.image.url
            }
        })
    else:
        return JsonResponse({
            'status': 'error',
            'errors': form.errors.as_json()
        }, status=400)

@require_POST
@login_required
def delete_realisation(request, pk):
    """
    Vue AJAX pour supprimer une réalisation.
    """
    try:
        realisation = Realisation.objects.get(pk=pk, prestataire=request.user)
        realisation.delete()
        return JsonResponse({'status': 'success', 'message': 'Réalisation supprimée.'})
    except Realisation.DoesNotExist:
        return JsonResponse({'status': 'error', 'message': 'Réalisation introuvable.'}, status=404)

@require_POST
def submit_evaluation(request, pk):
    if not request.user.is_authenticated:
        return JsonResponse({'status': 'error', 'message': 'Vous devez être connecté pour évaluer.'}, status=403)
    
    try:
        prestataire = Prestataire.objects.get(pk=pk)
    except Prestataire.DoesNotExist:
        return JsonResponse({'status': 'error', 'message': 'Prestataire introuvable.'}, status=404)

    # if request.user.role != Prestataire.ROLE_CLIENT:
    #     return JsonResponse({'status': 'error', 'message': 'Seuls les clients peuvent laisser un avis.'}, status=403)

    if prestataire.role != Prestataire.ROLE_PRESTATAIRE:
        return JsonResponse({'status': 'error', 'message': 'Vous ne pouvez évaluer que des prestataires.'}, status=400)

    if Evaluation.objects.filter(prestataire=prestataire, client=request.user).exists():
        return JsonResponse({'status': 'error', 'message': 'Vous avez déjà évalué ce prestataire.'}, status=400)

    note = request.POST.get('note')
    commentaire = request.POST.get('commentaire')

    if not note or not commentaire:
        return JsonResponse({'status': 'error', 'message': 'Note et commentaire requis.'}, status=400)

    try:
        evaluation = Evaluation.objects.create(
            prestataire=prestataire,
            client=request.user,
            client_nom=request.user.last_name,
            client_prenom=request.user.first_name,
            client_email=request.user.email,
            note=int(note),
            commentaire=commentaire
        )
        
        # Envoi de l'email de notification au prestataire
        try:
            subject = f"Nouvel avis reçu ({note}/5) - PrestLocal"
            # Rendu du template HTML pour l'email
            html_content = render_to_string('emails/evaluation.html', {
                'prestataire': prestataire,
                'client': request.user,
                'note': int(note),
                'commentaire': commentaire,
                'domain': request.get_host()
            })
            text_content = f"Bonjour {prestataire.first_name}, vous avez reçu un nouvel avis de {request.user.get_full_name()} : {note}/5 étoiles."
            
            msg = EmailMultiAlternatives(
                subject, 
                text_content, 
                'lankoandeenock002@gmail.com', 
                [prestataire.email]
            )
            msg.attach_alternative(html_content, "text/html")
            msg.send()
        except Exception as e:
            print(f"Error sending email: {e}")
            # On ne bloque pas la réponse si l'email échoue

        # Créer une notification pour le prestataire
        try:
            Notification.objects.create(
                recipient=prestataire,
                actor=request.user,
                notification_type='evaluation',
                message=f"{request.user.first_name} a laissé un avis de {note}/5",
                link=f"/prestataire/{prestataire.pk}/"
            )
        except Exception:
            pass

        return JsonResponse({'status': 'success', 'message': 'Votre avis a été pris en compte.'})

    except Exception as e:
        return JsonResponse({'status': 'error', 'message': str(e)}, status=500)

from Feed.models import Realisation

def index(request):
    categorie = CategoriePrestation.objects.all()
    # Filtrer par rôle prestataire, disponibilité ET abonnement actif
    prestataires = [p for p in Prestataire.objects.filter(role=Prestataire.ROLE_PRESTATAIRE, is_available=True) if p.has_active_subscription]
    
    # Flux social : les 10 dernières réalisations
    feed_items = Realisation.objects.all().order_by('-date_ajout')[:10]

    context = {
        'categorie': categorie,
        'prestataires': prestataires[:8],
        'feed_items': feed_items
    }
    return render(request, 'main/index.html', context)


def login_view(request):
    if request.user.is_authenticated:
        return redirect('main:index')
    
    if request.method == 'POST':
        form = PrestataireLoginForm(data=request.POST)
        if form.is_valid():
            email = form.cleaned_data.get('username')
            password = form.cleaned_data.get('password')
            user = authenticate(email=email, password=password)
            if user is not None:
                login(request, user)
                messages.success(request, f"Bienvenue, {user.first_name} !")
                return redirect('main:index')
            else:
                messages.error(request, "Email ou mot de passe incorrect.")
        else:
            messages.error(request, "Veuillez corriger les erreurs ci-dessous.")
    else:
        form = PrestataireLoginForm()
    return render(request, 'main/login.html', {'form': form})

def signup_view(request):
    if request.user.is_authenticated:
        return redirect('main:index')
        
    if request.method == 'POST':
        form = PrestataireSignupForm(request.POST, request.FILES)
        if form.is_valid():
            user = form.save(commit=False)
            user.is_active = False  # Désactivé jusqu'à la vérification de l'email
            code = str(random.randint(100000, 999999))
            user.code_verification = code
            user.save()
        
            subject = "Code de vérification - PrestLocal"
            text_content = f"Votre code de vérification est : {code}"
            # Rendu du template HTML pour l'email
            html_content = render_to_string('emails/verification_code.html', {
                'user': user,
                'code': code
            })
            
            # Utilisation de l'email fourni dans le formulaire
            msg = EmailMultiAlternatives(subject, text_content, 'lankoandeenock002@gmail.com', [user.email])

            msg.attach_alternative(html_content, "text/html")
            
            try:
                msg.send()
                request.session['verification_user_id'] = str(user.id)
                messages.success(request, "Un code de vérification a été envoyé à votre adresse email.")
                return redirect('main:verify_email')
            except Exception as e:
                # Si l'envoi échoue, on peut choisir de supprimer l'utilisateur ou de lui permettre de réessayer
                user.delete() 
                messages.error(request, "Erreur lors de l'envoi de l'email de vérification. Veuillez réessayer.")
                print(f"Error sending email: {e}")
        else:
            messages.error(request, "Erreur lors de l'inscription. Vérifiez les informations.")
    else:
        form = PrestataireSignupForm()
    return render(request, 'main/signup.html', {'form': form})

def verify_email_view(request):
    user_id = request.session.get('verification_user_id')
    if not user_id:
        return redirect('main:signup')
    
    try:
        user = Prestataire.objects.get(id=user_id)
    except Prestataire.DoesNotExist:
        return redirect('main:signup')
    
    if request.method == 'POST':
        form = VerifyEmailForm(request.POST)
        if form.is_valid():
            code_entre = form.cleaned_data.get('code')
            if code_entre == user.code_verification:
                user.is_active = True
                user.code_verification = None  # Effacer le code après vérification
                user.save()
                
                # Connecter l'utilisateur
                login(request, user)
                
                # Envoyer l'email de demande d'abonnement
                try:
                    subject = "Activez votre profil sur PrestLocal"
                    html_content = render_to_string('emails/subscription_request.html', {
                        'user': user,
                        'domain': request.get_host()
                    })
                    text_content = f"Bienvenue {user.first_name}, activez votre abonnement pour être visible."
                    msg = EmailMultiAlternatives(subject, text_content, 'lankoandeenock002@gmail.com', [user.email])
                    msg.attach_alternative(html_content, "text/html")
                    msg.send()
                except Exception as e:
                    print(f"Error sending subscription email: {e}")

                # Nettoyer la session
                # del request.session['verification_user_id']
                
                messages.success(request, "Votre compte a été activé avec succès ! Bienvenue.")
                return redirect('main:index')
            else:
                messages.error(request, "Code de vérification incorrect.")
    else:
        form = VerifyEmailForm()
    
    return render(request, 'main/verify_email.html', {'form': form, 'email': user.email})

def password_reset_request_view(request):
    if request.user.is_authenticated:
        return redirect('main:index')
    
    if request.method == 'POST':
        form = PasswordResetRequestForm(request.POST)
        if form.is_valid():
            email = form.cleaned_data.get('email')
            try:
                user = Prestataire.objects.get(email=email)
                code = str(random.randint(100000, 999999))
                user.code_verification = code
                user.save()
                
                subject = "Réinitialisation de mot de passe - PrestLocal"
                text_content = f"Votre code de réinitialisation est : {code}"
                html_content = render_to_string('emails/password_reset_code.html', {
                    'user': user,
                    'code': code
                })
                
                msg = EmailMultiAlternatives(subject, text_content, 'lankoandeenock002@gmail.com', [user.email])
                msg.attach_alternative(html_content, "text/html")
                msg.send()
                
                request.session['reset_user_id'] = str(user.id)
                messages.success(request, "Un code de réinitialisation a été envoyé à votre adresse email.")
                return redirect('main:password_reset_confirm')
            except Prestataire.DoesNotExist:
                messages.error(request, "Aucun compte n'est associé à cette adresse email.")
    else:
        form = PasswordResetRequestForm()
    
    return render(request, 'main/password_reset_request.html', {'form': form})

def password_reset_confirm_view(request):
    user_id = request.session.get('reset_user_id')
    if not user_id:
        return redirect('main:password_reset_request')
    
    try:
        user = Prestataire.objects.get(id=user_id)
    except Prestataire.DoesNotExist:
        return redirect('main:password_reset_request')
    
    if request.method == 'POST':
        form = PasswordResetConfirmForm(request.POST)
        if form.is_valid():
            code_entre = form.cleaned_data.get('code')
            if code_entre == user.code_verification:
                new_password = form.cleaned_data.get('new_password')
                user.set_password(new_password)
                user.code_verification = None
                user.save()
                
                # Connecter l'utilisateur automatiquement après le changement de mot de passe
                login(request, user)
                
                # Nettoyer la session
                del request.session['reset_user_id']
                
                messages.success(request, "Votre mot de passe a été réinitialisé avec succès. Vous êtes maintenant connecté.")
                return redirect('main:index')
            else:

                messages.error(request, "Code de vérification incorrect.")
    else:
        form = PasswordResetConfirmForm()
    
    return render(request, 'main/password_reset_confirm.html', {'form': form, 'email': user.email})

def logout_view(request):


    logout(request)
    messages.info(request, "Vous avez été déconnecté.")
    return redirect('main:index')


from django.utils import timezone

class PrestataireDetailView(DetailView):
    model = Prestataire
    template_name = 'main/prestataire_detail.html'
    context_object_name = 'prestataire'

    def get_object(self, queryset=None):
        prestataire = super().get_object(queryset=queryset)
        
        # Vérifier l'abonnement : Seul le propriétaire peut voir son profil s'il n'est pas abonné
        if not prestataire.has_active_subscription and self.request.user != prestataire:
            from django.http import Http404
            raise Http404("Ce prestataire n'est pas disponible pour le moment.")

        if not self.request.user.is_authenticated or self.request.user != prestataire:
            Prestataire.objects.filter(pk=prestataire.pk).update(profile_views=models.F('profile_views') + 1)
            prestataire.refresh_from_db(fields=['profile_views'])
        return prestataire

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        prestataire = self.object
        if self.request.user.is_authenticated:
            context['is_favori'] = Favorite.objects.filter(user=self.request.user, prestataire=prestataire).exists()
        else:
            context['is_favori'] = False
        return context

class PrestataireListView(ListView):
    model = Prestataire
    template_name = 'main/prestataire_list.html'
    context_object_name = 'prestataires'
    paginate_by = 12

    def get_queryset(self):
        queryset = super().get_queryset()
        # Filtrer par rôle prestataire, disponibilité ET abonnement actif
        queryset = queryset.filter(
            role=Prestataire.ROLE_PRESTATAIRE, 
            is_available=True,
            abonnement__paye=True,
            abonnement__est_actif=True,
            abonnement__date_fin__gt=timezone.now()
        )
        q = self.request.GET.get('q')
        ville_id = self.request.GET.get('ville')
        categorie_id = self.request.GET.get('categorie')

        if q:
            queryset = queryset.filter(
                models.Q(first_name__icontains=q) | 
                models.Q(last_name__icontains=q) | 
                models.Q(metier__nom__icontains=q)
            )
        if ville_id:
            queryset = queryset.filter(ville_id=ville_id)
        if categorie_id:
            queryset = queryset.filter(metier__categorie_id=categorie_id)
            
        return queryset.order_by('-date_inscription')

    def get(self, request, *args, **kwargs):
        if request.headers.get('x-requested-with') == 'XMLHttpRequest':
            self.object_list = self.get_queryset()
            context = self.get_context_data()
            return render(request, 'includes/prestataire_list_partial.html', context)
        return super().get(request, *args, **kwargs)

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context['villes'] = Ville.objects.all()
        context['categories'] = CategoriePrestation.objects.all()
        context['search_query'] = self.request.GET.get('q', '')
        context['current_ville'] = self.request.GET.get('ville', '')
        context['current_categorie'] = self.request.GET.get('categorie', '')
        context['total_count'] = self.get_queryset().count()
        return context


# ===== FAVORIS =====

@require_POST
@login_required
def toggle_favorite(request, pk):
    prestataire = get_object_or_404(Prestataire, pk=pk)
    fav, created = Favorite.objects.get_or_create(user=request.user, prestataire=prestataire)
    if not created:
        fav.delete()
    return JsonResponse({
        'status': 'favori' if created else 'retire',
        'count': Favorite.objects.filter(prestataire=prestataire).count()
    })


# ===== NOTIFICATIONS =====

@login_required
def notification_list(request):
    notifications = request.user.notifications.all()[:50]
    return render(request, 'main/notifications.html', {'notifications': notifications})


@require_POST
@login_required
def mark_notification_read(request, pk):
    notification = get_object_or_404(Notification, pk=pk, recipient=request.user)
    notification.is_read = True
    notification.save()
    return JsonResponse({'status': 'ok'})


@require_POST
@login_required
def mark_all_notifications_read(request):
    request.user.notifications.filter(is_read=False).update(is_read=True)
    return JsonResponse({'status': 'ok'})


@login_required
def unread_notification_count(request):
    count = request.user.notifications.filter(is_read=False).count()
    return JsonResponse({'count': count})


# ===== CLIENT DASHBOARD =====

@login_required
def client_dashboard(request):
    if not request.user.is_client:
        messages.error(request, "Cet espace est réservé aux clients.")
        return redirect('main:index')
    context = {
        'avis_donnes': Evaluation.objects.filter(client=request.user).select_related('prestataire', 'prestataire__metier').order_by('-date_evaluation'),
        'favoris': Favorite.objects.filter(user=request.user).select_related('prestataire', 'prestataire__metier'),
    }
    return render(request, 'main/client_dashboard.html', context)
