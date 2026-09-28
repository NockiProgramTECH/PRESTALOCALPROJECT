from django.contrib import admin
from .models import PlanAbonnement, Abonnement

@admin.register(PlanAbonnement)
class PlanAbonnementAdmin(admin.ModelAdmin):
    list_display = ('nom', 'prix', 'duree_jours')

@admin.register(Abonnement)
class AbonnementAdmin(admin.ModelAdmin):
    list_display = ('prestataire', 'plan', 'date_fin', 'est_actif', 'paye')
    list_filter = ('est_actif', 'paye', 'plan')
    search_fields = ('prestataire__email', 'prestataire__first_name')
