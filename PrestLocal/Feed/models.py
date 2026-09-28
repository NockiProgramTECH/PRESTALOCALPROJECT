from django.db import models
from django.conf import settings
from main.models import Realisation

class Like(models.Model):
    """
    Permet aux utilisateurs d'aimer une réalisation.
    """
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='likes')
    realisation = models.ForeignKey(Realisation, on_delete=models.CASCADE, related_name='likes')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'realisation')

    def __str__(self):
        return f"{self.user.first_name} aime {self.realisation.titre or 'une réalisation'}"

class Commentaire(models.Model):
    """
    Permet de commenter une réalisation.
    """
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='commentaires_feed')
    realisation = models.ForeignKey(Realisation, on_delete=models.CASCADE, related_name='commentaires')
    contenu = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Commentaire de {self.user.first_name} sur {self.realisation.titre or 'réalisation'}"
