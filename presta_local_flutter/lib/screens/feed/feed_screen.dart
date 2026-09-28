import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/feed_card.dart';
import '../../widgets/shimmer_loading.dart';
import 'feed_create_screen.dart';
import 'feed_detail_screen.dart';

/// Page « Fil d'actualité » : réalisations des prestataires locaux.
///
/// Affiche en liste verticale toutes les réalisations issues de `GET /api/feed/`,
/// chacune ouvrant le détail du prestataire auteur via [onProviderTap].
class FeedScreen extends ConsumerWidget {
  final ValueChanged<String>? onProviderTap;

  const FeedScreen({super.key, this.onProviderTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(feedPostsProvider);
    final auth = ref.watch(authProvider);
    final canPublish =
        auth.status == AuthStatus.authenticated && auth.isProvider;

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(
        title: const Text('Fil d\'actualité'),
        elevation: 0,
      ),
      floatingActionButton: canPublish
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const FeedCreateScreen(),
                  ),
                );
                if (created == true) {
                  ref.invalidate(feedPostsProvider);
                }
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Publier'),
            )
          : null,
      body: feedAsync.when(
        data: (posts) {
          if (posts.isEmpty) {
            return const EmptyState(
              icon: Icons.photo_library_outlined,
              title: 'Aucune réalisation',
              subtitle: 'Les réalisations des prestataires locaux apparaîtront ici',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(feedPostsProvider);
              await ref.read(feedPostsProvider.future);
            },
            child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final post = posts[index];
              return FeedCard(
                post: post,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FeedDetailScreen(
                      realisationId: post.id,
                      onProviderTap: onProviderTap,
                    ),
                  ),
                ),
              );
            },
            ),
          );
        },
        loading: () => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: 4,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (_, __) => const _FeedCardShimmer(),
        ),
        error: (e, _) => EmptyState.error(
          message: AppConstants.errorLoading,
          onRetry: () => ref.invalidate(feedPostsProvider),
        ),
      ),
    );
  }
}

/// Squelette de carte de réalisation pendant le chargement.
class _FeedCardShimmer extends StatelessWidget {
  const _FeedCardShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerBox(height: 150, borderRadius: 0),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerBox(height: 12, width: 160),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const ShimmerBox(width: 32, height: 32, borderRadius: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const ShimmerBox(height: 12),
                          const SizedBox(height: 4),
                          ShimmerBox(height: 8, width: 90),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
