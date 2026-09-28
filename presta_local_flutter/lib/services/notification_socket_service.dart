import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/io.dart';

import 'api_client.dart';
import 'ws_helper.dart';

/// Connexion WebSocket au canal `/ws/notifications/`.
///
/// Le serveur pousse `{ "type": "notification.unread", "count": <int> }`
/// à la connexion puis à chaque nouveau message reçu. Remplace le polling
/// HTTP 30 s : le badge de messages non lus est mis à jour en temps réel.
class NotificationSocketService {
  final ApiClient _api = ApiClient();

  IOWebSocketChannel? _channel;
  Timer? _reconnectTimer;
  bool _shouldReconnect = false;

  /// Appelé à chaque événement `notification.unread`.
  void Function(int count)? onUnreadChanged;

  /// Ouvre la connexion (auth par JWT). Sans token, aucune connexion.
  Future<void> connect() async {
    disconnect();
    final access = await _api.getAccessToken();
    if (access == null) return;
    _shouldReconnect = true;
    await _open(access);
  }

  Future<void> _open(String access) async {
    try {
      // Connexion manuelle (pas `IOWebSocketChannel.connect`) : le handshake
      // HTTP Upgrade échoue si le backend tourne via `runserver` au lieu de
      // daphne (HttpException "Connection reset by peer"). Ici l'erreur est
      // catchée → reconnect silencieux, jamais d'exception non gérée.
      final ws = await WebSocket.connect(
        buildWsUri('/ws/notifications/').toString(),
        headers: wsHeaders(access),
      ).timeout(const Duration(seconds: 10));
      final channel = IOWebSocketChannel(ws);
      _channel = channel;
      channel.stream.listen(
        _onData,
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onData(dynamic data) {
    Map<String, dynamic> event;
    try {
      event = jsonDecode(data as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    if (event['type'] == 'notification.unread') {
      onUnreadChanged?.call((event['count'] as num?)?.toInt() ?? 0);
    }
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () async {
      final access = await _api.getAccessToken();
      if (access != null && _shouldReconnect) await _open(access);
    });
  }

  /// Ferme la connexion.
  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
  }
}
