"""
ASGI config for Core project.

Expose la callable ASGI ``application`` avec le routage HTTP + WebSocket.
"""

import os

from django.core.asgi import get_asgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'Core.settings')

# Initialise Django AVANT d'importer les consumers (requis pour le registre d'apps)
django_asgi_app = get_asgi_application()

from channels.auth import AuthMiddlewareStack
from channels.routing import ProtocolTypeRouter, URLRouter

from Messagerie import routing as messagerie_routing
from .middleware import JWTAuthMiddleware

application = ProtocolTypeRouter({
    # HTTP classique -> reste géré par Django
    'http': django_asgi_app,
    # WebSocket -> auth par session OU par JWT (Bearer) + routage des consumers
    'websocket': AuthMiddlewareStack(
        JWTAuthMiddleware(
            URLRouter(
                messagerie_routing.websocket_urlpatterns
            )
        )
    ),
})
