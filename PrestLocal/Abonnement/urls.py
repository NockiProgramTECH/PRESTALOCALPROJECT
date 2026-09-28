from django.urls import path
from .views import plan_list, choisir_payement, simuler_otp

app_name = 'Abonnement'

urlpatterns = [
    path('plans/', plan_list, name='plan_list'),
    path('payer/<int:plan_id>/', choisir_payement, name='choisir_payement'),
    path('valider/<int:plan_id>/', simuler_otp, name='simuler_otp'),
]
