"""Sérialiseurs de l'API, organisés par domaine.

Le paquet remplace l'ancien `api/serializers.py` (1100+ lignes, six domaines
mélangés). **Tous les noms publics restent importables de la même façon** :

.. code-block:: python

    from api.serializers import PrestataireSerializers

Les vues (`api/views/`) et les tests ne changent donc pas leurs imports."""

from .commun import (
    MAX_PUBLICATION_IMAGES,
    PHONE_REGEX,
    absolute_media_url,
    contact_visible,
    file_extension,
    is_favorite_for,
    realisation_image_urls,
    validate_upload,
)

from .reference import (
    CategorieSerializer,
    PrestationListSerializer,
    PrestationSerializer,
    RealisationSerializer,
    VilleSerializer,
)

from .prestataires import (
    EvaluationCreateSerializer,
    EvaluationSerializer,
    FeedPrestataireSerializer,
    PrestataireSerializers,
    PrestatireDetailSerialzer,
)

from .feed import (
    CommentaireSerializer,
    FeedCreateSerializer,
    FeedDetailSerializer,
    FeedRealisationSerializer,
    FeedUpdateSerializer,
)

from .comptes import (
    PasswordResetConfirmSerializer,
    PasswordResetRequestSerializer,
    RegisterSerializer,
    UserSerializer,
    VerifyEmailSerializer,
    send_code_email,
)

from .abonnement import (
    AbonnementSerializer,
    MOBILE_MONEY_OPERATORS,
    PlanAbonnementSerializer,
    SouscriptionAbonnementSerializer,
)

__all__ = [
    'MAX_PUBLICATION_IMAGES',
    'PHONE_REGEX',
    'absolute_media_url',
    'contact_visible',
    'file_extension',
    'is_favorite_for',
    'realisation_image_urls',
    'validate_upload',
    'CategorieSerializer',
    'PrestationListSerializer',
    'PrestationSerializer',
    'RealisationSerializer',
    'VilleSerializer',
    'EvaluationCreateSerializer',
    'EvaluationSerializer',
    'FeedPrestataireSerializer',
    'PrestataireSerializers',
    'PrestatireDetailSerialzer',
    'CommentaireSerializer',
    'FeedCreateSerializer',
    'FeedDetailSerializer',
    'FeedRealisationSerializer',
    'FeedUpdateSerializer',
    'PasswordResetConfirmSerializer',
    'PasswordResetRequestSerializer',
    'RegisterSerializer',
    'UserSerializer',
    'VerifyEmailSerializer',
    'send_code_email',
    'AbonnementSerializer',
    'MOBILE_MONEY_OPERATORS',
    'PlanAbonnementSerializer',
    'SouscriptionAbonnementSerializer',
]
