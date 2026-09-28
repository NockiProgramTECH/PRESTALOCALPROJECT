import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/io.dart';

import '../models/conversation_model.dart';
import '../models/message_model.dart';
import 'api_client.dart';
import 'ws_helper.dart';

/// Service de messagerie branché sur l'API réelle + WebSocket temps réel.
///
/// - **REST** : liste des conversations, historique, envoi, démarrage.
/// - **WebSocket** (`/ws/chat/<id>/`) : réception **instantanée** des messages
///   et de la **présence**, avec reconnexion automatique en cas de coupure.
///
/// L'envoi se fait via l'API (persiste + diffuse au groupe), la réception
/// temps réel via le WebSocket. L'utilisateur reçoit ainsi les messages du
/// prestataire sans rechargement.
class MessageService {
  final ApiClient _api = ApiClient();

  // ---- WebSocket (temps réel) ----
  IOWebSocketChannel? _channel;
  Timer? _reconnectTimer;
  bool _shouldReconnect = false;
  int _conversationId = 0;
  String? _selfUserId;

  // Callbacks renseignés par l'écran de chat.
  void Function(MessageModel message)? onIncomingMessage;
  void Function(bool online, String userId)? onPresence;
  void Function()? onDisconnected;

  // =========================================================================
  // REST
  // =========================================================================

  /// Liste des conversations de l'utilisateur connecté.
  Future<List<ConversationModel>> getConversations(String selfUserId) async {
    final list = await _api.getList('/api/messagerie/conversations/');
    return list
        .whereType<Map<String, dynamic>>()
        .map((c) =>
            ConversationModel.fromListJson(c, selfUserId: selfUserId))
        .toList();
  }

  /// Historique complet des messages d'une conversation.
  Future<ConversationModel> getConversation(
    String conversationId,
    String selfUserId,
  ) async {
    final data = await _api.get('/api/messagerie/conversations/$conversationId/');
    return ConversationModel.fromJson(data, selfUserId: selfUserId);
  }

  /// Envoie un message via l'API (le serveur le diffuse aussi au groupe WS).
  Future<MessageModel> sendMessage({
    required String conversationId,
    required String text,
    required String selfUserId,
  }) async {
    final data = await _api.post(
      '/api/messagerie/conversations/$conversationId/messages/',
      body: {'content': text},
    );
    return MessageModel.fromJson(data, selfUserId: selfUserId);
  }

  /// Crée ou retrouve une conversation avec un prestataire, renvoie son id.
  Future<String> startConversation(String prestataireId) async {
    final data = await _api.post(
      '/api/messagerie/conversations/start/$prestataireId/',
      body: const {},
    );
    return data['conversation_id'].toString();
  }

  // =========================================================================
  // WebSocket temps réel
  // =========================================================================

  /// Ouvre la connexion WebSocket d'une conversation (auth par JWT).
  Future<void> connect({
    required int conversationId,
    required String selfUserId,
    void Function(MessageModel message)? onIncomingMessage,
    void Function(bool online, String userId)? onPresence,
    void Function()? onDisconnected,
  }) async {
    disconnect();
    _conversationId = conversationId;
    _selfUserId = selfUserId;
    this.onIncomingMessage = onIncomingMessage;
    this.onPresence = onPresence;
    this.onDisconnected = onDisconnected;
    _shouldReconnect = true;
    await _open();
  }

  Future<void> _open() async {
    final access = await _api.getAccessToken();
    if (access == null) {
      _shouldReconnect = false;
      return;
    }
    try {
      // Voir notification_socket_service : connexion manuelle pour catcher
      // le refus de handshake (runserver sans WS) en reconnect silencieux.
      final ws = await WebSocket.connect(
        buildWsUri('/ws/chat/$_conversationId/').toString(),
        headers: wsHeaders(access),
      ).timeout(const Duration(seconds: 10));
      final channel = IOWebSocketChannel(ws);
      _channel = channel;
      channel.stream.listen(
        _onData,
        onDone: _handleClosed,
        onError: (_) => _handleClosed(),
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

    switch (event['type']) {
      case 'chat.message':
        final message = event['message'] as Map<String, dynamic>;
        final senderId = message['sender_id']?.toString();
        // Ignore notre propre écho (l'expéditeur affiche déjà sa bulle).
        if (senderId == _selfUserId) return;
        onIncomingMessage?.call(
          MessageModel.fromJson(message, selfUserId: _selfUserId ?? ''),
        );
      case 'chat.presence':
        onPresence?.call(
          event['online'] == true,
          event['user_id']?.toString() ?? '',
        );
    }
  }

  /// Envoie un message via le WebSocket (rapide, sans confirmation immédiate).
  /// Préféré à [sendMessage] pour l'envoi instantané ; le serveur persiste et
  /// diffuse. À utiliser comme repli/amélioration du POST REST.
  void sendViaSocket(String content) {
    final ch = _channel;
    if (ch == null || content.trim().isEmpty) return;
    ch.sink.add(jsonEncode({'type': 'chat.message', 'content': content.trim()}));
  }

  bool get isConnected => _channel != null;

  void _handleClosed() {
    _channel = null;
    onDisconnected?.call();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), _open);
  }

  /// Ferme la connexion WebSocket (appelé à la sortie de l'écran de chat).
  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
  }
}
