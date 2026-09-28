from django.db import models
from django.conf import settings
from django.utils import timezone
from datetime import timedelta

class PlanAbonnement(models.Model):
    """
    Types de plans disponibles (Mensuel, Annuel, etc.)
    """
    nom = models.CharField(max_length=100)
    prix = models.DecimalField(max_digits=10, decimal_places=2)
    duree_jours = models.PositiveIntegerField(default=30)
    description = models.TextField(blank=True)

    def __str__(self):
        return f"{self.nom} - {self.prix} FCFA"

class Abonnement(models.Model):
    """
    Gère les abonnements des prestataires.
    """
    prestataire = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='abonnement')
    plan = models.ForeignKey(PlanAbonnement, on_delete=models.SET_NULL, null=True)
    date_debut = models.DateTimeField(auto_now_add=True)
    date_fin = models.DateTimeField()
    est_actif = models.BooleanField(default=False)
    paye = models.BooleanField(default=False)
    transaction_id = models.CharField(max_length=100, blank=True, null=True)

    class Meta:
        verbose_name = "Abonnement"
        verbose_name_plural = "Abonnements"

    def __str__(self):
        return f"Abonnement de {self.prestataire.email}"

    @property
    def est_valide(self):
        """Vérifie si l'abonnement est payé, actif et non expiré."""
        return self.paye and self.est_actif and self.date_fin > timezone.now()

    @property
    def jours_restants(self):
        if self.date_fin > timezone.now():
            delta = self.date_fin - timezone.now()
            return delta.days
        return 0

    def notifier_expiration_proche(self):
        """Vérifie si l'expiration est dans 7 jours."""
        if self.jours_restants == 7:
            return True
        return False
