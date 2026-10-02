"""Middlewares personnalisés (ASGI / Channels)."""

from channels.db import database_sync_to_async


class JWTAuthMiddleware:
    """
    Authentifie un client WebSocket via un token JWT (Bearer) présent dans
    l'en-tête `Authorization` du handshake.

    À placer À L'INTÉRIEUR d'`AuthMiddlewareStack` pour que le JWT prime sur la
    session : s'il y a un token valide, `scope['user']` est remplacé par
    l'utilisateur correspondant ; sinon (client navigateur) la session est utilisée.
    """

    def __init__(self, inner):
        self.inner = inner

    async def __call__(self, scope, receive, send):
        headers = {k.lower(): v for (k, v) in (scope.get('headers') or [])}
        auth = headers.get(b'authorization', b'')

        if auth and auth.lower().startswith(b'bearer '):
            token = auth[len(b'bearer '):].decode()
            user = await self._get_user(token)
            if user is not None:
                scope['user'] = user

        return await self.inner(scope, receive, send)

    @database_sync_to_async
    def _get_user(self, token):
        """Utilisateur du jeton, ou `None` si le jeton est invalide/expiré.

        En WebSocket, un jeton refusé signifie « visiteur anonyme » : on ne
        laisse pas remonter l'erreur, mais on ne masque pas non plus une panne
        inattendue (seules les erreurs de jeton sont interceptées).
        """
        from django.contrib.auth import get_user_model
        from rest_framework_simplejwt.exceptions import InvalidToken, TokenError
        from rest_framework_simplejwt.tokens import AccessToken

        User = get_user_model()
        try:
            access = AccessToken(token)
        except (InvalidToken, TokenError):
            return None
        try:
            return User.objects.get(pk=access['user_id'])
        except (User.DoesNotExist, KeyError):
            return None
