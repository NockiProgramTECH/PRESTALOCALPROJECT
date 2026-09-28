import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../models/conversation_model.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/shimmer_loading.dart';

/// ---------------------------------------------------------------------------
/// Écran de la liste des conversations
///
/// - En-tête compact (logo, cloche, avatar) ;
/// - Avatar, nom et statut en ligne du destinataire ;
/// - Dernier message, horodatage, badge de messages non lus.
///
/// Correctifs apportés :
/// - tous les textes sont explicitement stylés (plus de « double trait jaune ») ;
/// - les lignes sont encapsulées dans un `Material` (plus d'erreur
///   « No Material widget found » avec les widgets Material/InkWell) ;
/// - chaque rangée utilise `Expanded`/`Flexible` : aucun débordement
///   horizontal possible, même avec un nom très long.
/// ---------------------------------------------------------------------------
class MessagesScreen extends ConsumerWidget {
  final ValueChanged<String>? onConversationTap;

  const MessagesScreen({super.key, this.onConversationTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);
    final auth = ref.watch(authProvider);
    final unread = ref.watch(liveUnreadCountProvider);

    return Material(
      color: AppTheme.canvas,
      child: Column(
        children: [
          AppHeader.slim(
            title: 'PrestLocal',
            subtitle: 'Messages',
            hasNotification: unread > 0,
            userName: auth.userName,
            userPhoto: auth.userPhoto,
            onNotificationsTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Notifications — Bientôt disponible')),
            ),
          ),
          Expanded(
            child: conversationsAsync.when(
              data: (conversations) {
                if (conversations.isEmpty) {
                  return const EmptyState(
                    icon: Icons.message_outlined,
                    title: 'Aucune conversation',
                    subtitle:
                        'Contactez un prestataire depuis sa fiche pour démarrer une discussion',
                  );
                }
                return RefreshIndicator(
                  color: AppTheme.primary,
                  onRefresh: () async => ref.invalidate(conversationsProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.only(top: 4, bottom: 24),
                    itemCount: conversations.length,
                    separatorBuilder: (_, __) => const Divider(
                      height: 1,
                      indent: 78,
                      endIndent: 16,
                      color: AppTheme.cardBorder,
                    ),
                    itemBuilder: (context, index) => _ConversationTile(
                      conversation: conversations[index],
                      onTap: () =>
                          onConversationTap?.call(conversations[index].id),
                    ),
                  ),
                );
              },
              loading: () => ListView.builder(
                itemCount: 6,
                itemBuilder: (_, __) => const ShimmerConversationLine(),
              ),
              error: (e, _) => EmptyState.error(
                message: 'Erreur lors du chargement des messages',
                onRetry: () => ref.invalidate(conversationsProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tuile individuelle de conversation.
class _ConversationTile extends StatelessWidget {
  final ConversationModel conversation;
  final VoidCallback? onTap;

  const _ConversationTile({required this.conversation, this.onTap});

  @override
  Widget build(BuildContext context) {
    final provider = conversation.provider;
    final lastMsg = conversation.lastMessage;
    final unread = conversation.unreadCount;

    return Material(
      // Un `Material` explicite garantit que ListTile/InkWell fonctionnent
      // même si l'écran est affiché hors d'un Scaffold (overlay, onglet…).
      type: MaterialType.transparency,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppTheme.inputFill,
              backgroundImage: provider.avatar.isNotEmpty
                  ? CachedNetworkImageProvider(provider.avatar)
                  : null,
              child: provider.avatar.isEmpty
                  ? const Icon(Icons.person_rounded, color: AppTheme.muted)
                  : null,
            ),
            if (conversation.isOnline)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: AppTheme.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                provider.name.isEmpty ? 'Prestataire' : provider.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w600,
                  color: AppTheme.navy,
                  decoration: TextDecoration.none,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (lastMsg != null) ...[
              const SizedBox(width: 8),
              Text(
                _formatTime(lastMsg.timestamp),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.muted,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  lastMsg?.text ?? 'Commencez la conversation',
                  style: TextStyle(
                    fontSize: 13,
                    color: unread > 0 ? AppTheme.navy : AppTheme.muted,
                    fontWeight:
                        unread > 0 ? FontWeight.w600 : FontWeight.w400,
                    decoration: TextDecoration.none,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unread > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.danger,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Formate l'horodatage du dernier message.
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inHours < 1) return 'Il y a ${diff.inMinutes} min';
    if (diff.inDays < 1) {
      return '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays == 1) return 'Hier';
    if (diff.inDays < 7) {
      const days = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
      return days[time.weekday - 1];
    }
    return '${time.day}/${time.month}';
  }
}
