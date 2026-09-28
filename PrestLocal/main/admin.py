from django.contrib import admin
from .models import Prestataire, Ville, CategoriePrestation, Prestation, Evaluation, Realisation, Favorite, Notification

class RealisationInline(admin.TabularInline):
    model = Realisation
    extra = 1

class EvaluationInline(admin.TabularInline):
    model = Evaluation
    fk_name = 'prestataire'
    extra = 0
    readonly_fields = ('date_evaluation',)

@admin.register(Prestataire)
class PrestataireAdmin(admin.ModelAdmin):
    list_display = ('email', 'first_name', 'last_name', 'metier', 'ville', 'est_verifie')
    list_filter = ('est_verifie', 'ville', 'metier')
    search_fields = ('email', 'first_name', 'last_name')
    inlines = [RealisationInline, EvaluationInline]
    fieldsets = (
        (None, {'fields': ('email', 'password')}),
        ('Informations Personnelles', {'fields': ('first_name', 'last_name', 'telephone', 'photo_profil', 'bio')}),
        ('Localisation', {'fields': ('ville', 'quartier')}),
        ('Professionnel', {'fields': ('metier', 'annee_experience', 'est_verifie')}),
        ('Permissions', {'fields': ('is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions')}),
    )

@admin.register(Ville)
class VilleAdmin(admin.ModelAdmin):
    list_display = ('nom',)

@admin.register(CategoriePrestation)
class CategoriePrestationAdmin(admin.ModelAdmin):
    list_display = ('nom',)

@admin.register(Prestation)
class PrestationAdmin(admin.ModelAdmin):
    list_display = ('nom', 'categorie', 'est_actif')
    list_filter = ('categorie', 'est_actif')
    prepopulated_fields = {'slug': ('nom',)}

@admin.register(Evaluation)
class EvaluationAdmin(admin.ModelAdmin):
    list_display = ('prestataire', 'client_nom', 'note', 'date_evaluation')
    list_filter = ('note', 'date_evaluation')

@admin.register(Realisation)
class RealisationAdmin(admin.ModelAdmin):
    list_display = ('prestataire', 'titre', 'date_ajout')

@admin.register(Favorite)
class FavoriteAdmin(admin.ModelAdmin):
    list_display = ('user', 'prestataire', 'created_at')
    list_filter = ('created_at',)

@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ('recipient', 'notification_type', 'is_read', 'created_at')
    list_filter = ('is_read', 'notification_type', 'created_at')
