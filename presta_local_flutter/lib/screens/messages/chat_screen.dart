import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../models/message_model.dart';
import '../../providers/app_state_provider.dart';

/// ---------------------------------------------------------------------------
/// Écran de chat individuel avec un prestataire (temps réel)
///
/// Fonctionnalités :
/// - Affichage des messages dans des bulles
/// - Envoi de messages (optimiste + persistance via API)
/// - Réception **instantanée** via WebSocket (aucun rechargement)
/// - Présence en ligne du prestataire
/// ---------------------------------------------------------------------------
class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final VoidCallback onBack;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.onBack,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  List<MessageModel> _messages = [];
  String _providerName = '';
  String _providerAvatar = '';
  bool _isLoading = true;
  bool _isOnline = false;
  bool _wsConnected = false;

  int? get _conversationId => int.tryParse(widget.conversationId);

  @override
  void initState() {
    super.initState();
    _loadConversation();
  }

  @override
  void dispose() {
    // Ferme le WebSocket à la sortie de l'écran.
    ref.read(messageServiceProvider).disconnect();
    _messageController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadConversation() async {
    setState(() => _isLoading = true);
    try {
      final selfId = ref.read(currentUserIdProvider);
      final service = ref.read(messageServiceProvider);
      final convId = _conversationId;
      if (selfId == null || convId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final conv = await service.getConversation(widget.conversationId, selfId);
      if (!mounted) return;

      setState(() {
        _messages = conv.messages;
        _providerName = conv.provider.name;
        _providerAvatar = conv.provider.avatar;
        _isOnline = conv.isOnline;
        _isLoading = false;
      });

      // Branche le temps réel une fois la conversation chargée.
      await service.connect(
        conversationId: convId,
        selfUserId: selfId,
        onIncomingMessage: _onIncomingMessage,
        onPresence: _onPresence,
        onDisconnected: _onDisconnected,
      );
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Reçoit en temps réel un message du prestataire.
  void _onIncomingMessage(MessageModel message) {
    if (!mounted) return;
    // Évite les doublons (par id).
    if (_messages.any((m) => m.id == message.id)) return;
    setState(() {
      _messages = [..._messages, message];
    });
  }

  /// Reçoit un événement de présence (en ligne / hors ligne).
  void _onPresence(bool online, String userId) {
    if (!mounted) return;
    setState(() => _isOnline = online);
  }

  void _onDisconnected() {
    if (!mounted) return;
    setState(() => _wsConnected = false);
  }

  /// Envoie un message : affichage optimiste puis persistance via l'API
  /// (le serveur diffuse aussi au groupe WebSocket).
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final selfId = ref.read(currentUserIdProvider);
    if (text.isEmpty || selfId == null) {
      if (selfId == null) _promptLogin();
      return;
    }

    final tempId = 'local_${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = MessageModel(
      id: tempId,
      text: text,
      sender: MessageSender.user,
      timestamp: DateTime.now(),
    );

    // Optimiste : affiche immédiatement et vide le champ.
    _messageController.clear();
    setState(() => _messages = [..._messages, optimistic]);

    try {
      final service = ref.read(messageServiceProvider);
      final sent = await service.sendMessage(
        conversationId: widget.conversationId,
        text: text,
        selfUserId: selfId,
      );
      if (!mounted) return;
      // Remplace la bulle optimiste par le message confirmé (même texte).
      setState(() {
        _messages = _messages.map((m) => m.id == tempId ? sent : m).toList();
      });
      _setWsConnected();
    } catch (e) {
      if (!mounted) return;
      // Échec : retire la bulle, restaure le texte, informe l'utilisateur.
      setState(() {
        _messages = _messages.where((m) => m.id != tempId).toList();
        _messageController.text = text;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de l\'envoi : ${e.toString()}')),
      );
    }
  }

  /// Marque le WebSocket comme connecté (au premier envoi réussi on considère
  /// que le canal est actif, sinon la reconnexion gère le flux entrant).
  void _setWsConnected() {
    if (mounted && !_wsConnected) {
      setState(() => _wsConnected = true);
    }
  }

  void _promptLogin() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Connectez-vous pour envoyer un message')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          backgroundColor: AppTheme.primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: widget.onBack,
          ),
          titleSpacing: 0,
          title: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                backgroundImage: _providerAvatar.isNotEmpty
                    ? CachedNetworkImageProvider(_providerAvatar)
                    : null,
                child: _providerAvatar.isEmpty
                    ? const Icon(Icons.person, color: Colors.white, size: 20)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _providerName.isEmpty ? 'Conversation' : _providerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _statusText,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  String get _statusText {
    if (!_wsConnected) return 'Connexion...';
    return _isOnline ? 'En ligne' : 'Hors ligne';
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final selfId = ref.watch(currentUserIdProvider);
    if (selfId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                'Connectez-vous pour discuter avec ce prestataire',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _promptLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryGreen,
                ),
                child: const Text('Se connecter'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            itemCount: _messages.length,
            reverse: true,
            itemBuilder: (context, index) {
              final message =
                  _messages[_messages.length - 1 - index];
              return _MessageBubble(message: message);
            },
          ),
        ),

        // ---- Champ de saisie ----
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Écrivez un message...',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryGreen,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    splashRadius: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Bulle de message individuelle
class _MessageBubble extends StatelessWidget {
  final MessageModel message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == MessageSender.user;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: Colors.grey.shade300,
              child: const Icon(Icons.person, size: 16, color: Colors.grey),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? AppTheme.primaryGreen : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: isUser
                      ? const Radius.circular(18)
                      : const Radius.circular(4),
                  bottomRight: isUser
                      ? const Radius.circular(4)
                      : const Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: isUser ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: isUser
                              ? Colors.white.withValues(alpha: 0.7)
                              : Colors.grey.shade500,
                        ),
                      ),
                      if (isUser) ...[
                        const SizedBox(width: 4),
                        if (message.isFailed)
                          const Icon(
                            Icons.error_outline,
                            size: 14,
                            color: Colors.redAccent,
                          )
                        else
                          Icon(
                            message.isRead ? Icons.done_all : Icons.done,
                            size: 14,
                            color: isUser
                                ? Colors.white.withValues(alpha: 0.7)
                                : Colors.grey.shade400,
                          ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
