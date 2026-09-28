import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../models/message_model.dart';
import '../../providers/app_state_provider.dart';

/// ---------------------------------------------------------------------------
/// Écran de chat individuel avec un prestataire (temps réel)
///
/// - Affichage des messages dans des bulles ;
/// - Envoi optimiste + persistance via l'API ;
/// - Réception instantanée via WebSocket (`/ws/chat/<id>/`) ;
/// - Présence en ligne du prestataire.
///
/// Correctifs apportés :
/// - `Material` + `Scaffold` explicites (plus d'erreur
///   « No Material widget found ») ;
/// - mise en page strictement bornée : la liste est dans un `Expanded`,
///   les bulles dans des `Flexible` → plus de « bottom overflowed by X pixels » ;
/// - styles de texte explicites (`decoration: none`) → plus de double trait
///   jaune sous le nom du destinataire ;
/// - la barre de saisie reste au-dessus du clavier (`SafeArea` + `Material`).
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
    if (_messages.any((m) => m.id == message.id)) return;
    setState(() {
      _messages = [..._messages, message];
    });
  }

  void _onPresence(bool online, String userId) {
    if (!mounted) return;
    setState(() {
      _isOnline = online;
      _wsConnected = true;
    });
  }

  void _onDisconnected() {
    if (!mounted) return;
    setState(() => _wsConnected = false);
  }

  /// Envoie un message : affichage optimiste puis persistance via l'API.
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
      setState(() {
        _messages = _messages.map((m) => m.id == tempId ? sent : m).toList();
        _wsConnected = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages = _messages.where((m) => m.id != tempId).toList();
        _messageController.text = text;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de l\'envoi : ${e.toString()}')),
      );
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
      color: AppTheme.canvas,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: AppTheme.canvas,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.navy,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: widget.onBack,
          ),
          titleSpacing: 0,
          title: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.inputFill,
                backgroundImage: _providerAvatar.isNotEmpty
                    ? CachedNetworkImageProvider(_providerAvatar)
                    : null,
                child: _providerAvatar.isEmpty
                    ? const Icon(
                        Icons.person_rounded,
                        color: AppTheme.muted,
                        size: 20,
                      )
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
                        color: AppTheme.navy,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.none,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _statusText,
                      style: TextStyle(
                        color: _isOnline ? AppTheme.success : AppTheme.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.none,
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
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 56,
                color: AppTheme.muted,
              ),
              const SizedBox(height: 16),
              const Text(
                'Connectez-vous pour discuter avec ce prestataire',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.muted,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _promptLogin,
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
          child: _messages.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Aucun message pour le moment.\n'
                      'Écrivez le premier message à ce prestataire.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.muted,
                        fontSize: 14,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  // `reverse: true` : la liste est ancrée en bas, les nouveaux
                  // messages apparaissent au-dessus du champ de saisie et le
                  // clavier ne provoque aucun débordement.
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[_messages.length - 1 - index];
                    return _MessageBubble(message: message);
                  },
                ),
        ),
        _inputBar(),
      ],
    );
  }

  /// Barre de saisie : reste collée au clavier, sans débordement.
  Widget _inputBar() {
    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  focusNode: _focusNode,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: 'Écrivez un message...',
                    hintStyle: const TextStyle(color: AppTheme.muted),
                    filled: true,
                    fillColor: AppTheme.inputFill,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: _sendMessage,
                  tooltip: 'Envoyer',
                  icon: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bulle de message individuelle (largeur bornée : pas de débordement).
class _MessageBubble extends StatelessWidget {
  final MessageModel message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == MessageSender.user;
    // Largeur maximale : 78 % de l'écran (le reste respire).
    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.78;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              radius: 14,
              backgroundColor: AppTheme.inputFill,
              child: Icon(
                Icons.person_rounded,
                size: 16,
                color: AppTheme.muted,
              ),
            ),
            const SizedBox(width: 6),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isUser ? AppTheme.primary : Colors.white,
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
                border: isUser
                    ? null
                    : Border.all(color: AppTheme.cardBorder),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      color: isUser ? Colors.white : AppTheme.navy,
                      decoration: TextDecoration.none,
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
                              ? Colors.white.withValues(alpha: 0.85)
                              : AppTheme.muted,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      if (isUser) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.isFailed
                              ? Icons.error_outline
                              : (message.isRead
                                    ? Icons.done_all
                                    : Icons.done),
                          size: 14,
                          color: message.isFailed
                              ? Colors.redAccent
                              : Colors.white.withValues(alpha: 0.85),
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
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }
}
