"""
URL configuration for the PrestLocal project (Django 5.2).

- `/`            : site web (templates + PWA)
- `/api/`        : API REST (DRF + JWT) consommée par l'app Flutter
- `/ws/`         : WebSockets (Channels) — chat et notifications
- `/media/`      : uploads utilisateurs (servis par nginx en production)
"""

from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path

from .views import healthcheck, service_worker

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', include('main.urls')),
    path('abonnement/', include('Abonnement.urls')),
    path('feed/', include('Feed.urls')),
    path('api/', include('api.urls')),
    path('messages/', include('Messagerie.urls')),
    path('sw.js', service_worker, name='service_worker'),
    path('healthz', healthcheck, name='healthcheck'),
]

# Médias (photos de profil, réalisations).
# - Développement : DEBUG=True -> servis par Django.
# - Production légère (sans nginx) : SERVE_MEDIA=True -> servis par Django.
# - Production recommandée : SERVE_MEDIA=False -> servis par nginx (voir docker/nginx.conf).
if settings.DEBUG or settings.SERVE_MEDIA:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
