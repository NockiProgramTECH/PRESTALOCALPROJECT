import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../models/conversation_model.dart';
import '../../providers/app_state_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/shimmer_loading.dart';

/// ---------------------------------------------------------------------------
/// Écran de la liste des conversations
///
/// Affiche toutes les conversations de l'utilisateur avec :
/// - Avatar, nom et statut en ligne du prestataire
/// - Dernier message
/// - Badge de messages non lus
/// - Horodatage du dernier message
/// ---------------------------------------------------------------------------
class MessagesScreen extends ConsumerWidget {
  final ValueChanged<String>? onConversationTap;

  const MessagesScreen({super.key, this.onConversationTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);

    return conversationsAsync.when(
      data: (conversations) {
        if (conversations.isEmpty) {
          return const EmptyState(
            icon: Icons.message_outlined,
            title: 'Aucun message',
            subtitle: 'Contactez un prestataire pour démarrer une conversation',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(conversationsProvider),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: conversations.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 76, endIndent: 16),
            itemBuilder: (context, index) {
              return _ConversationTile(
                conversation: conversations[index],
                onTap: () => onConversationTap?.call(conversations[index].id),
              );
            },
          ),
        );
      },
      loading: () => ListView.builder(
        itemCount: 5,
        itemBuilder: (_, __) => const ShimmerConversationLine(),
      ),
      error: (e, _) => EmptyState.error(
        message: 'Erreur lors du chargement des messages',
        onRetry: () => ref.invalidate(conversationsProvider),
      ),
    );
  }
}

/// Tuile individuelle de conversation
class _ConversationTile extends StatelessWidget {
  final ConversationModel conversation;
  final VoidCallback? onTap;

  const _ConversationTile({
    required this.conversation,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final provider = conversation.provider;
    final lastMsg = conversation.lastMessage;
    final unread = conversation.unreadCount;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Stack(
        children: [
          // Avatar du prestataire
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: CachedNetworkImageProvider(provider.avatar),
          ),
          // Indicateur de statut en ligne
          if (conversation.isOnline)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Row(
        children: [
          // Nom du prestataire
          Expanded(
            child: Text(
              provider.name,
              style: TextStyle(
                fontSize: 15,
                fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Horodatage
          if (lastMsg != null)
            Text(
              _formatTime(lastMsg.timestamp),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
              ),
            ),
        ],
      ),
      subtitle: Row(
        children: [
          // Dernier message
          Expanded(
            child: Text(
              lastMsg?.text ?? 'Commencez la conversation',
              style: TextStyle(
                fontSize: 13,
                color: unread > 0 ? Colors.black87 : Colors.grey.shade600,
                fontWeight: unread > 0 ? FontWeight.w500 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Badge de messages non lus
          if (unread > 0)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.secondaryRed,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                unread > 9 ? '9+' : '$unread',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Formate l'heure pour l'affichage
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inHours < 1) return 'Il y a ${diff.inMinutes}min';
    if (diff.inDays < 1) return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    if (diff.inDays == 1) return 'Hier';
    if (diff.inDays < 7) {
      const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
      return days[time.weekday - 1];
    }
    return '${time.day}/${time.month}';
  }
}
