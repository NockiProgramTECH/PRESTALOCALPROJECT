Pour faire cela proprement avec [Django REST Framework](https://www.django-rest-framework.org/?utm_source=chatgpt.com), il faut :

1. créer les serializers
2. créer un `ViewSet`
3. filtrer les prestataires :

   * qui ont un abonnement actif
   * par ville
   * par métier
   * par note moyenne
   * etc.
4. utiliser `django-filter`

Je vais te montrer une structure propre et scalable.

---

# 1. Installer django-filter

Installe :

```bash
pip install django-filter
```

Dans `settings.py` :

```python
INSTALLED_APPS = [
    ...
    'django_filters',
]
```

Puis :

```python
REST_FRAMEWORK = {
    'DEFAULT_FILTER_BACKENDS': [
        'django_filters.rest_framework.DjangoFilterBackend',
        'rest_framework.filters.SearchFilter',
        'rest_framework.filters.OrderingFilter',
    ]
}
```

---

# 2. Serializer

## serializers.py

```python
from rest_framework import serializers
from .models import Prestataire


class PrestataireSerializer(serializers.ModelSerializer):

    moyenne_etoile = serializers.FloatField(
        source='average_rating',
        read_only=True
    )

    nombre_avis = serializers.IntegerField(
        source='review_count',
        read_only=True
    )

    abonnement_actif = serializers.BooleanField(
        source='has_active_subscription',
        read_only=True
    )

    metier = serializers.StringRelatedField()
    ville = serializers.StringRelatedField()

    class Meta:
        model = Prestataire

        fields = [
            'id',
            'first_name',
            'last_name',
            'email',
            'telephone',
            'photo_profil',
            'bio',
            'metier',
            'ville',
            'quartier',
            'annee_experience',
            'est_verifie',
            'is_available',
            'moyenne_etoile',
            'nombre_avis',
            'abonnement_actif',
        ]
```

---

# Explication

## source='average_rating'

Appelle automatiquement :

```python
@property
def average_rating(self):
```

Donc :

```json
"moyenne_etoile": 4.5
```

---

## StringRelatedField()

Affiche :

```python
str(objet)
```

Exemple :

```json
"ville": "Ouagadougou"
```

au lieu de :

```json
"ville": 1
```

---

# 3. Filtre personnalisé

Le problème :

`average_rating` est une propriété Python.

Donc Django ne peut pas faire :

```python
.filter(average_rating=4)
```

Il faut annoter la moyenne SQL.

---

# 4. ViewSet complet

## views.py

```python
from django.db.models import Avg
from django.utils import timezone

from rest_framework import viewsets
from rest_framework.permissions import AllowAny

from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.filters import SearchFilter, OrderingFilter

from .models import Prestataire
from .serializers import PrestataireSerializer


class PrestataireViewSet(viewsets.ReadOnlyModelViewSet):
    """
    API publique des prestataires.
    """

    serializer_class = PrestataireSerializer
    permission_classes = [AllowAny]

    filter_backends = [
        DjangoFilterBackend,
        SearchFilter,
        OrderingFilter
    ]

    # filtres simples
    filterset_fields = [
        'ville',
        'metier',
        'est_verifie',
        'is_available',
    ]

    # recherche texte
    search_fields = [
        'first_name',
        'last_name',
        'bio',
        'quartier',
    ]

    # tri
    ordering_fields = [
        'date_inscription',
        'annee_experience',
        'average_note',
    ]

    def get_queryset(self):

        queryset = Prestataire.objects.filter(
            role='prestataire',
            abonnement__paye=True,
            abonnement__est_actif=True,
            abonnement__date_fin__gt=timezone.now()
        ).select_related(
            'ville',
            'metier',
            'abonnement'
        ).annotate(
            average_note=Avg('evaluations__note')
        )

        # filtre étoile personnalisé
        etoile = self.request.query_params.get('etoile')

        if etoile:
            queryset = queryset.filter(
                average_note__gte=float(etoile)
            )

        return queryset
```

---

# Pourquoi cette méthode est bonne ?

## abonnement__paye=True

Filtre directement via relation :

```python
Prestataire -> Abonnement
```

---

## annotate()

Ajoute une colonne SQL virtuelle :

```python
average_note
```

Tu peux maintenant filtrer dessus.

---

## select_related()

Optimise les performances SQL.

Très important.

---

# 5. URLs

## urls.py

```python
from rest_framework.routers import DefaultRouter
from .views import PrestataireViewSet

router = DefaultRouter()
router.register(
    r'prestataires',
    PrestataireViewSet,
    basename='prestataire'
)

urlpatterns = router.urls
```

---

# 6. Utilisation API

---

## Tous les prestataires actifs

```http
GET /api/prestataires/
```

---

## Ville uniquement

```http
GET /api/prestataires/?ville=1
```

---

## Métier uniquement

```http
GET /api/prestataires/?metier=2
```

---

## Ville + métier

```http
GET /api/prestataires/?ville=1&metier=2
```

---

## Ville + métier + étoile

```http
GET /api/prestataires/?ville=1&metier=2&etoile=4
```

Ici :

```python
average_note >= 4
```

---

## Prestataires vérifiés

```http
GET /api/prestataires/?est_verifie=true
```

---

## Recherche texte

```http
GET /api/prestataires/?search=plomberie
```

---

## Trier par expérience

```http
GET /api/prestataires/?ordering=-annee_experience
```

---

## Trier par note

```http
GET /api/prestataires/?ordering=-average_note
```

---

# 7. Exemple réponse JSON

```json
[
    {
        "id": "uuid",
        "first_name": "Ali",
        "last_name": "Sawadogo",
        "email": "ali@gmail.com",
        "telephone": "70000000",
        "photo_profil": "/media/...",
        "bio": "Plombier professionnel",
        "metier": "Plombier",
        "ville": "Ouagadougou",
        "quartier": "Tampouy",
        "annee_experience": 5,
        "est_verifie": true,
        "is_available": true,
        "moyenne_etoile": 4.7,
        "nombre_avis": 23,
        "abonnement_actif": true
    }
]
```

---

# 8. Amélioration professionnelle recommandée

Au lieu de :

```python
filterset_fields = [...]
```

tu peux créer un vrai `FilterSet`.

Exemple :

## filters.py

```python
import django_filters

from .models import Prestataire


class PrestataireFilter(django_filters.FilterSet):

    etoile = django_filters.NumberFilter(
        method='filter_etoile'
    )

    class Meta:
        model = Prestataire

        fields = [
            'ville',
            'metier',
            'est_verifie',
            'is_available',
        ]

    def filter_etoile(self, queryset, name, value):
        return queryset.filter(
            average_note__gte=value
        )
```

Puis dans le ViewSet :

```python
from .filters import PrestataireFilter

filterset_class = PrestataireFilter
```

C'est plus propre pour les gros projets.

---

# 9. Point important

Ton système suppose que :

```python
evaluations__note
```

existe réellement.

Donc il faut un modèle similaire :

```python
class Evaluation(models.Model):
    prestataire = models.ForeignKey(
        Prestataire,
        related_name='evaluations',
        on_delete=models.CASCADE
    )

    note = models.IntegerField()
```

Sinon `Avg('evaluations__note')` ne fonctionnera pas.

------
-----
----

Pour le détail d’un prestataire, l’idée est de créer :

* un serializer détaillé
* des sous-serializers :

  * réalisations
  * prestation
* un endpoint :

  ```http
  /api/prestataires/<uuid>/
  ```

qui retourne :

* infos du prestataire
* métier
* ville
* statistiques
* portfolio/réalisations
* notes
* abonnement actif
* etc.

---

# 1. Serializer des réalisations

## serializers.py

```python id="h0g5lr"
from rest_framework import serializers
from .models import (
    Prestataire,
    Realisation,
    Prestation
)
```

---

## Serializer Realisation

```python id="jlwmmy"
class RealisationSerializer(serializers.ModelSerializer):

    image = serializers.ImageField(read_only=True)

    class Meta:
        model = Realisation

        fields = [
            'id',
            'titre',
            'image',
            'date_ajout'
        ]
```

---

# 2. Serializer prestation

```python id="s9chqv"
class PrestationSerializer(serializers.ModelSerializer):

    class Meta:
        model = Prestation

        fields = [
            'id',
            'nom',
            'slug',
            'description',
            'image_couverture',
            'icone',
        ]
```

---

# 3. Serializer détaillé du prestataire

```python id="w0i4az"
class PrestataireDetailSerializer(serializers.ModelSerializer):

    moyenne_etoile = serializers.FloatField(
        source='average_rating',
        read_only=True
    )

    nombre_avis = serializers.IntegerField(
        source='review_count',
        read_only=True
    )

    abonnement_actif = serializers.BooleanField(
        source='has_active_subscription',
        read_only=True
    )

    realisations = RealisationSerializer(
        many=True,
        read_only=True
    )

    metier = PrestationSerializer(
        read_only=True
    )

    ville = serializers.StringRelatedField()

    class Meta:
        model = Prestataire

        fields = [
            'id',
            'first_name',
            'last_name',
            'email',
            'telephone',
            'photo_profil',
            'bio',

            'metier',

            'ville',
            'quartier',

            'annee_experience',

            'est_verifie',
            'is_available',

            'profile_views',
            'call_clicks',
            'contact_clicks',

            'moyenne_etoile',
            'nombre_avis',

            'abonnement_actif',

            'date_inscription',

            'realisations',
        ]
```

---

# Explication importante

---

## realisations = RealisationSerializer(many=True)

Grâce à :

```python id="rsvd0y"
related_name='realisations'
```

Django peut faire automatiquement :

```python id="6gqz9s"
prestataire.realisations.all()
```

Donc DRF retourne automatiquement :

```json id="a4b31n"
"realisations": [
   ...
]
```

---

# 4. Modifier le ViewSet

Tu peux utiliser :

* serializer simple pour la liste
* serializer détaillé pour retrieve()

---

## views.py

```python id="phh0ic"
from django.db.models import Avg
from django.utils import timezone

from rest_framework import viewsets
from rest_framework.permissions import AllowAny

from django_filters.rest_framework import DjangoFilterBackend
from rest_framework.filters import SearchFilter, OrderingFilter

from .models import Prestataire
from .serializers import (
    PrestataireSerializer,
    PrestataireDetailSerializer
)
```

---

## ViewSet complet

```python id="g2gcln"
class PrestataireViewSet(viewsets.ReadOnlyModelViewSet):

    permission_classes = [AllowAny]

    filter_backends = [
        DjangoFilterBackend,
        SearchFilter,
        OrderingFilter
    ]

    filterset_fields = [
        'ville',
        'metier',
        'est_verifie',
        'is_available',
    ]

    search_fields = [
        'first_name',
        'last_name',
        'bio',
        'quartier',
    ]

    ordering_fields = [
        'date_inscription',
        'annee_experience',
        'average_note',
    ]

    def get_serializer_class(self):

        # DETAIL
        if self.action == 'retrieve':
            return PrestataireDetailSerializer

        # LISTE
        return PrestataireSerializer

    def get_queryset(self):

        queryset = Prestataire.objects.filter(
            role='prestataire',
            abonnement__paye=True,
            abonnement__est_actif=True,
            abonnement__date_fin__gt=timezone.now()
        ).select_related(
            'ville',
            'metier',
            'abonnement'
        ).prefetch_related(
            'realisations'
        ).annotate(
            average_note=Avg('evaluations__note')
        )

        etoile = self.request.query_params.get('etoile')

        if etoile:
            queryset = queryset.filter(
                average_note__gte=float(etoile)
            )

        return queryset
```

---

# 5. Résultat API

## Endpoint

```http id="s5dbjlwm"
GET /api/prestataires/<uuid>/
```

---

# 6. Exemple JSON retourné

```json id="vgutog"
{
    "id": "uuid",

    "first_name": "Ali",
    "last_name": "Sawadogo",

    "email": "ali@gmail.com",

    "telephone": "70000000",

    "photo_profil": "/media/photo.jpg",

    "bio": "Plombier professionnel",

    "metier": {
        "id": 1,
        "nom": "Plombier",
        "slug": "plombier",
        "description": "Travaux de plomberie",
        "image_couverture": "/media/plombier.jpg",
        "icone": "/media/icon.png"
    },

    "ville": "Ouagadougou",

    "quartier": "Tampouy",

    "annee_experience": 5,

    "est_verifie": true,

    "is_available": true,

    "profile_views": 123,

    "call_clicks": 45,

    "contact_clicks": 10,

    "moyenne_etoile": 4.8,

    "nombre_avis": 35,

    "abonnement_actif": true,

    "date_inscription": "2026-05-01T12:00:00Z",

    "realisations": [
        {
            "id": 1,
            "titre": "Installation sanitaire",
            "image": "/media/realisations/test.jpg",
            "date_ajout": "2026-05-20T10:00:00Z"
        },
        {
            "id": 2,
            "titre": "Salle de bain",
            "image": "/media/realisations/test2.jpg",
            "date_ajout": "2026-05-21T11:00:00Z"
        }
    ]
}
```

---

# 7. Optimisation importante

Dans ton `PrestataireSerializer` de liste, évite de mettre :

```python id="n5d8ai"
realisations
```

Sinon la liste complète deviendra lourde.

Bonne pratique :

* liste = données légères
* détail = données complètes

---

# 8. Amélioration professionnelle

Tu peux aussi ajouter :

## top prestataires

```python id="vzwz4g"
GET /api/prestataires/?ordering=-average_note
```

---

## uniquement vérifiés

```python id="wmh50o"
GET /api/prestataires/?est_verifie=true
```

---

## disponibles uniquement

```python id="6q8kkw"
GET /api/prestataires/?is_available=true
```

---

## filtre métier + ville + étoile

```http id="7s1z8o"
GET /api/prestataires/?ville=1&metier=2&etoile=4
```

---

# 9. Très important (performance)

Ton code est déjà bien structuré grâce à :

```python id="vyg6w3"
select_related()
prefetch_related()
```

Ça évite le problème :

# N+1 Queries

Très fréquent dans DRF.

