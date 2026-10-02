from django.urls import path
from .views import plan_list, choisir_payement, simuler_otp, gestion_abonnement

app_name = 'Abonnement'

urlpatterns = [
    path('plans/', plan_list, name='plan_list'),
    # Cible des liens de relance envoyés par email : /abonnement/gestion/<id>/
    path('gestion/<uuid:prestataire_id>/', gestion_abonnement, name='gestion'),
    path('payer/<int:plan_id>/', choisir_payement, name='choisir_payement'),
    path('valider/<int:plan_id>/', simuler_otp, name='simuler_otp'),
]
