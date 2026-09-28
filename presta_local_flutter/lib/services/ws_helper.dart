import '../config/constants.dart';

/// Helpers pour la connexion WebSocket (messagerie temps réel Django Channels).
///
/// Le backend utilise deux sockets :
/// - `/ws/chat/<conversation_id>/` : messages + présence
/// - `/ws/notifications/` : compte de messages non lus (badge temps réel)
///
/// L'authentification se fait par JWT via l'en-tête `Authorization: Bearer`
/// du handshake (le middleware `JWTAuthMiddleware` côté Channels valide le token).
///
/// NB : `IOWebSocketChannel` est utilisé pour permettre l'envoi du header JWT
/// au handshake (mobile + desktop). Sur web, l'authentification se ferait via
/// les cookies de session (non couvert ici).
Uri buildWsUri(String path) {
  final base = Uri.parse(AppConstants.baseUrl);
  final scheme = base.scheme == 'https' ? 'wss' : 'ws';
  return Uri(scheme: scheme, host: base.host, port: base.port, path: path);
}

/// En-têtes de handshake WebSocket avec le token JWT d'accès.
Map<String, String> wsHeaders(String accessToken) {
  return {'Authorization': 'Bearer $accessToken'};
}
