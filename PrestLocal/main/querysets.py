"""QuerySets du domaine « prestataires ».

Les règles de lecture partagées (visibilité, relations à précharger, notes
annotées) sont écrites **une seule fois** ici. Elles restent des QuerySets
Django ordinaires — pas de couche « repository » — donc composables, chaînables
et testables comme n'importe quel queryset.
"""

from django.db import models
from django.db.models import Avg, Count
from django.utils import timezone


class PrestataireQuerySet(models.QuerySet):
    """Filtres et annotations réutilisables sur les comptes/prestataires."""

    def prestataires(self):
        """Comptes ayant le rôle prestataire (exclut les clients)."""
        # Valeur de `Prestataire.ROLE_PRESTATAIRE` : littéral assumé pour
        # éviter un import circulaire (main.models importe ce module).
        return self.filter(role='prestataire')

    def visibles(self):
        """Prestataires réellement visibles et contactables.

        Même règle que :attr:`main.models.Prestataire.has_active_subscription`,
        mais **en base** (un seul `WHERE` au lieu d'une requête par ligne) :
        abonnement payé, actif et non expiré.
        """
        return self.prestataires().filter(
            abonnement__paye=True,
            abonnement__est_actif=True,
            abonnement__date_fin__gt=timezone.now(),
        )

    def avec_relations(self):
        """Relations nécessaires aux fiches (recherche, détail, favoris)."""
        return self.select_related('ville', 'metier', 'abonnement').prefetch_related(
            'realisations__likes',
            'realisations__commentaires',
            'evaluations',
        )

    def avec_note_moyenne(self):
        """Annote `average_note` (note moyenne des avis), pour trier/filtrer."""
        return self.annotate(average_note=Avg('evaluations__note'))

    def avec_note_et_avis(self):
        """Annote `average_note` et `nombre_avis` en une seule requête.

        Évite que chaque carte d'une liste déclenche deux requêtes
        (`average_rating` + `review_count`) : les propriétés du modèle
        utilisent ces annotations lorsqu'elles sont présentes.
        """
        return self.annotate(
            average_note=Avg('evaluations__note'),
            nombre_avis=Count('evaluations', distinct=True),
        )
