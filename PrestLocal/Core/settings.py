"""
Django settings for Core project (LesProduFao).

Backend : Django 5.2.5 · DRF 3.16 · Channels 4.3 (WebSockets) · PostgreSQL / Redis.

Toutes les valeurs sensibles (clé secrète, base de données, email, CORS…)
proviennent du fichier `.env` (jamais commité — voir `.env.example`).

Pour la documentation complète des réglages :
https://docs.djangoproject.com/en/5.2/ref/settings/
"""

import sys
from datetime import timedelta
from pathlib import Path

import environ
from django.core.exceptions import ImproperlyConfigured

# ---------------------------------------------------------------------------
# Chemins & variables d'environnement
# ---------------------------------------------------------------------------
BASE_DIR = Path(__file__).resolve().parent.parent

env = environ.Env(
    DEBUG=(bool, False),
)
environ.Env.read_env(BASE_DIR / '.env')


# ---------------------------------------------------------------------------
# Sécurité de base
# ---------------------------------------------------------------------------
DEBUG = env.bool('DEBUG', default=False)

# Clés connues comme « placeholder » : refusées en production.
_INSECURE_SECRET_KEYS = {
    '',
    'replace-with-a-long-random-secret',
    'django-insecure-change-me',
    'secret',
    'changeme',
}
SECRET_KEY = env('SECRET_KEY', default='')
if SECRET_KEY.strip().lower() in _INSECURE_SECRET_KEYS or len(SECRET_KEY) < 32:
    if DEBUG:
        # Repli de développement uniquement : ne jamais utiliser en production.
        SECRET_KEY = 'django-insecure-dev-only-secret-key-lesprodufao'
    else:
        raise ImproperlyConfigured(
            "SECRET_KEY manquante ou trop faible. Générez-en une nouvelle :\n"
            "  python -c \"from django.core.management.utils import "
            "get_random_secret_key as k; print(k())\"\n"
            "puis renseignez-la dans le fichier .env (SECRET_KEY=...)."
        )

if DEBUG:
    # En développement on accepte toutes les adresses (téléphone du réseau
    # local, émulateur Android 10.0.2.2, tests Django `testserver`).
    ALLOWED_HOSTS = ['*']
else:
    ALLOWED_HOSTS = env.list('ALLOWED_HOSTS', default=[])
    if not ALLOWED_HOSTS:
        raise ImproperlyConfigured(
            "ALLOWED_HOSTS est vide : renseignez le(s) domaine(s) de production "
            "dans .env (ex. ALLOWED_HOSTS=lesprodufao.onrender.com,www.lesprodufao.bf)."
        )


# ---------------------------------------------------------------------------
# Applications
# ---------------------------------------------------------------------------
INSTALLED_APPS = [
    'daphne',  # DOIT être en premier : sert le serveur ASGI (WebSockets) via runserver
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'channels',
    'corsheaders',
    'main',
    'Abonnement',
    'Feed',
    'api',
    'Messagerie',
    'Notifications',
    'rest_framework',
    'rest_framework_simplejwt',
    'rest_framework_simplejwt.token_blacklist',
    'django_filters',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'Core.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [BASE_DIR / 'templates'],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'Core.wsgi.application'

# ---- WebSockets / Channels ----
ASGI_APPLICATION = 'Core.asgi.application'

REDIS_URL = env('REDIS_URL', default='')

if REDIS_URL:
    CHANNEL_LAYERS = {
        'default': {
            'BACKEND': 'channels_redis.core.RedisChannelLayer',
            'CONFIG': {'hosts': [REDIS_URL]},
        },
    }
else:
    # Repli dev : In-Memory (single-process uniquement, pas multi-workers)
    CHANNEL_LAYERS = {
        'default': {
            'BACKEND': 'channels.layers.InMemoryChannelLayer',
        },
    }


# ---------------------------------------------------------------------------
# Base de données
# ---------------------------------------------------------------------------
# - `DATABASE_URL` défini (Neon, Postgres Docker, …)  -> utilisé tel quel
# - `DATABASE_URL` vide ou sqlite:///...              -> SQLite local (dev/tests)
# Ce repli évite les échecs « could not connect to server: db » en local.
DATABASE_URL = env('DATABASE_URL', default='')

if not DATABASE_URL or DATABASE_URL.startswith('sqlite'):
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.sqlite3',
            'NAME': BASE_DIR / 'db.sqlite3',
            'ATOMIC_REQUESTS': True,
        }
    }
else:
    DATABASES = {'default': env.db_url_config(DATABASE_URL)}
    DATABASES['default'].setdefault('CONN_MAX_AGE', env.int('DB_CONN_MAX_AGE', default=60))


# ---------------------------------------------------------------------------
# Mots de passe
# ---------------------------------------------------------------------------
AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
        'OPTIONS': {'min_length': 8},
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]


# ---------------------------------------------------------------------------
# Internationalisation
# ---------------------------------------------------------------------------
LANGUAGE_CODE = 'fr-fr'

TIME_ZONE = 'UTC'

USE_I18N = True

USE_TZ = True


# ---------------------------------------------------------------------------
# Fichiers statiques & média
# ---------------------------------------------------------------------------
STATIC_URL = 'static/'
STATICFILES_DIRS = [BASE_DIR / 'static']
STATIC_ROOT = BASE_DIR / 'staticfiles'
STORAGES = {
    'default': {
        'BACKEND': 'django.core.files.storage.FileSystemStorage',
    },
    'staticfiles': {
        # Le manifeste (empreintes + compression) n'est activé qu'en
        # production, une fois `collectstatic` exécuté. En développement et
        # pendant les tests, il provoquerait « Missing staticfiles manifest
        # entry » dès qu'un fichier récent n'a pas encore été collecté.
        'BACKEND': (
            'django.contrib.staticfiles.storage.StaticFilesStorage'
            if DEBUG
            else 'whitenoise.storage.CompressedManifestStaticFilesStorage'
        ),
    },
}

MEDIA_URL = '/media/'
MEDIA_ROOT = BASE_DIR / 'media'

# Sert les médias (photos de profil, réalisations) via Django/WhiteNoise.
# En production, c'est nginx qui s'en charge (voir docker/nginx.conf) :
# laisser SERVE_MEDIA=false pour éviter de faire transiter les images
# par Python (lent et coûteux).
SERVE_MEDIA = env.bool('SERVE_MEDIA', default=DEBUG)

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# Modèle utilisateur personnalisé (connexion par email)
AUTH_USER_MODEL = 'main.Prestataire'


# ---------------------------------------------------------------------------
# Email
# ---------------------------------------------------------------------------
EMAIL_BACKEND = env(
    'EMAIL_BACKEND',
    default='django.core.mail.backends.smtp.EmailBackend',
)
EMAIL_HOST = env('EMAIL_HOST', default='smtp.gmail.com')
EMAIL_PORT = env.int('EMAIL_PORT', default=587)
EMAIL_USE_TLS = env.bool('EMAIL_USE_TLS', default=True)
EMAIL_HOST_USER = env('EMAIL_HOST_USER', default='')
EMAIL_HOST_PASSWORD = env('EMAIL_HOST_PASSWORD', default='')

# Expéditeur par défaut : plus d'adresse codée en dur dans les sérialiseurs.
DEFAULT_FROM_EMAIL = env(
    'DEFAULT_FROM_EMAIL',
    default=EMAIL_HOST_USER or 'LesProduFao <no-reply@lesprodufao.bf>',
)
SERVER_EMAIL = DEFAULT_FROM_EMAIL

# Délai d'expiration des codes de vérification / réinitialisation (minutes)
EMAIL_CODE_TTL_MINUTES = env.int('EMAIL_CODE_TTL_MINUTES', default=30)


# ---------------------------------------------------------------------------
# Notifications (canaux interchangeables : email, WhatsApp, push…)
# ---------------------------------------------------------------------------
# URL publique du site : sert aux liens des emails (abonnement, échéances).
SITE_URL = env('SITE_URL', default='http://localhost:8000')

# Canaux actifs à l'envoi. Les canaux « whatsapp » et « push » sont déjà
# branchés mais inactifs tant que leurs clés ne sont pas fournies : il suffit
# de les ajouter ici (et de renseigner les clés ci-dessous) pour les activer,
# sans modifier les services ni les vues.
NOTIFICATIONS_CHANNELS = env.list(
    'NOTIFICATIONS_CHANNELS', default=['email']
)

# Canal WhatsApp (implémentation future : API WhatsApp Business / fournisseur).
NOTIFICATIONS_WHATSAPP_ENABLED = env.bool(
    'NOTIFICATIONS_WHATSAPP_ENABLED', default=False
)
WHATSAPP_API_URL = env('WHATSAPP_API_URL', default='')
WHATSAPP_API_TOKEN = env('WHATSAPP_API_TOKEN', default='')

# Canal push (implémentation future : FCM / OneSignal).
NOTIFICATIONS_PUSH_ENABLED = env.bool('NOTIFICATIONS_PUSH_ENABLED', default=False)
PUSH_API_KEY = env('PUSH_API_KEY', default='')

# Relances d'abonnement : jours avant expiration et ancienneté minimale des
# prestataires jamais abonnés avant de les relancer ; validité du lien signé.
RELANCE_ABONNEMENT_JOURS_AVANT = env.int('RELANCE_ABONNEMENT_JOURS_AVANT', default=7)
RELANCE_SANS_ABONNEMENT_DELAI_JOURS = env.int(
    'RELANCE_SANS_ABONNEMENT_DELAI_JOURS', default=3
)
RELANCE_LIEN_TTL_JOURS = env.int('RELANCE_LIEN_TTL_JOURS', default=90)


# ---------------------------------------------------------------------------
# Django REST Framework
# ---------------------------------------------------------------------------
REST_FRAMEWORK = {
    'DEFAULT_FILTER_BACKENDS': [
        'django_filters.rest_framework.DjangoFilterBackend',
        'rest_framework.filters.SearchFilter',
        'rest_framework.filters.OrderingFilter',
    ],
    'DEFAULT_AUTHENTICATION_CLASSES': [
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ],
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 10,
    # Anti brute-force / anti-abus (voir `throttle_scope` dans api/views.py)
    'DEFAULT_THROTTLE_CLASSES': [
        'rest_framework.throttling.AnonRateThrottle',
        'rest_framework.throttling.UserRateThrottle',
    ],
    'DEFAULT_THROTTLE_RATES': {
        'anon': env('THROTTLE_ANON', default='240/hour'),
        'user': env('THROTTLE_USER', default='4000/hour'),
        'auth': env('THROTTLE_AUTH', default='12/hour'),
        'review': env('THROTTLE_REVIEW', default='30/day'),
    },
}

# Configuration JWT (djangorestframework-simplejwt)
SIMPLE_JWT = {
    # Access court + refresh automatique côté client (ApiClient Flutter).
    'ACCESS_TOKEN_LIFETIME': timedelta(
        minutes=env.int('ACCESS_TOKEN_MINUTES', default=120)
    ),
    'REFRESH_TOKEN_LIFETIME': timedelta(
        days=env.int('REFRESH_TOKEN_DAYS', default=14)
    ),
    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': True,
    'AUTH_HEADER_TYPES': ('Bearer',),
}


# ---------------------------------------------------------------------------
# CORS (clients mobiles Flutter / WebSocket cross-origin)
# ---------------------------------------------------------------------------
# Les applications mobiles natives n'ont pas besoin de CORS : on ne l'ouvre
# largement qu'en développement. En production, renseigner CORS_ALLOWED_ORIGINS.
CORS_ALLOW_ALL_ORIGINS = DEBUG and env.bool('CORS_ALLOW_ALL_ORIGINS', default=False)
CORS_ALLOWED_ORIGINS = env.list('CORS_ALLOWED_ORIGINS', default=[])
CORS_ALLOWED_ORIGIN_REGEXES = env.list(
    'CORS_ALLOWED_ORIGIN_REGEXES',
    default=[r'^https?://(localhost|127\.0\.0\.1)(:\d+)?$'] if DEBUG else [],
)
CORS_ALLOW_CREDENTIALS = True
CORS_ALLOW_HEADERS = [
    'authorization',
    'content-type',
    'x-requested-with',
    'x-csrftoken',
]
CORS_ALLOW_METHODS = ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS']

CSRF_TRUSTED_ORIGINS = env.list('CSRF_TRUSTED_ORIGINS', default=[])
if DEBUG:
    CSRF_TRUSTED_ORIGINS += ['http://localhost:8000', 'http://127.0.0.1:8000']


# ---------------------------------------------------------------------------
# Durcissement production (DEBUG=False)
# ---------------------------------------------------------------------------
if not DEBUG:
    # Derrière un reverse proxy (nginx, Render, …) qui termine le TLS.
    SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
    # À activer quand le HTTPS est en place (évite les boucles de redirection).
    SECURE_SSL_REDIRECT = env.bool('SECURE_SSL_REDIRECT', default=False)
    SESSION_COOKIE_SECURE = env.bool('SESSION_COOKIE_SECURE', default=True)
    CSRF_COOKIE_SECURE = env.bool('CSRF_COOKIE_SECURE', default=True)
    SESSION_COOKIE_HTTPONLY = True
    SECURE_HSTS_SECONDS = env.int('SECURE_HSTS_SECONDS', default=0)
    SECURE_HSTS_INCLUDE_SUBDOMAINS = SECURE_HSTS_SECONDS > 0
    SECURE_HSTS_PRELOAD = SECURE_HSTS_SECONDS > 0
    SECURE_CONTENT_TYPE_NOSNIFF = True
    SECURE_REFERRER_POLICY = 'same-origin'
    X_FRAME_OPTIONS = 'DENY'

# Taille maximale des uploads (photos de profil / réalisations) : 5 Mo.
DATA_UPLOAD_MAX_MEMORY_SIZE = env.int('DATA_UPLOAD_MAX_MEMORY_SIZE', default=5 * 1024 * 1024)
FILE_UPLOAD_MAX_MEMORY_SIZE = DATA_UPLOAD_MAX_MEMORY_SIZE

# Journalisation minimale (visibilité en production)
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'simple': {'format': '[{levelname}] {asctime} {name}: {message}', 'style': '{'},
    },
    'handlers': {
        'console': {'class': 'logging.StreamHandler', 'formatter': 'simple'},
    },
    'root': {'handlers': ['console'], 'level': env('LOG_LEVEL', default='INFO')},
    'loggers': {
        'django.request': {'handlers': ['console'], 'level': 'WARNING', 'propagate': False},
        'api': {'handlers': ['console'], 'level': 'INFO', 'propagate': False},
        'Notifications': {'handlers': ['console'], 'level': 'INFO', 'propagate': False},
    },
}
