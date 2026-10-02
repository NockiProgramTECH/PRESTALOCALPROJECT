"""Journal des notifications envoyées.

Deux usages concrets (pas d'abstraction anticipée) :

- **idempotence** : un traitement planifié (relance d'abonnement) qui tourne
  tous les jours ne doit pas renvoyer plusieurs fois le même message au même
  prestataire — la clé ``(canal, cle_unique)`` l'en empêche ;
- **traçabilité** : savoir ce qui a été envoyé, ignoré ou en échec, et pourquoi.
"""

from django.conf import settings
from django.db import models


class JournalNotification(models.Model):
    """Trace d'une tentative d'envoi sur un canal donné."""

    STATUT_ENVOYE = "envoye"
    STATUT_IGNORE = "ignore"
    STATUT_ECHEC = "echec"
    STATUTS = [
        (STATUT_ENVOYE, "Envoyé"),
        (STATUT_IGNORE, "Ignoré"),
        (STATUT_ECHEC, "Échec"),
    ]

    destinataire = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name="notifications_envoyees",
        verbose_name="Destinataire",
    )
    type_notification = models.CharField(
        max_length=60, db_index=True, verbose_name="Type de notification"
    )
    canal = models.CharField(max_length=20, verbose_name="Canal")
    statut = models.CharField(max_length=10, choices=STATUTS, verbose_name="Statut")
    detail = models.CharField(max_length=500, blank=True, verbose_name="Détail")
    #: Clé d'idempotence (vide = pas de déduplication, ex. email de code).
    cle_unique = models.CharField(
        max_length=200, blank=True, db_index=True, verbose_name="Clé d'idempotence"
    )
    date_envoi = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-date_envoi"]
        verbose_name = "Journal de notification"
        verbose_name_plural = "Journal des notifications"
        constraints = [
            models.UniqueConstraint(
                fields=["canal", "cle_unique"],
                condition=~models.Q(cle_unique=""),
                name="notification_unique_par_canal_et_cle",
            )
        ]
        indexes = [
            models.Index(fields=["type_notification", "-date_envoi"]),
        ]

    def __str__(self):
        return f"[{self.canal}/{self.statut}] {self.type_notification}"
