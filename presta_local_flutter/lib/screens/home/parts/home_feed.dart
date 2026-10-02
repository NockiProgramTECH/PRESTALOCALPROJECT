part of '../home_screen.dart';

/// Aperçu du fil d'actualité : les 3 dernières publications, avec les mêmes
/// interactions que la page complète (J'aime, Commenter, Partager).
class _FeedSection extends ConsumerStatefulWidget {
  final ValueChanged<String>? onProviderTap;

  const _FeedSection(this.onProviderTap);

  @override
  ConsumerState<_FeedSection> createState() => _FeedSectionState();
}

class _FeedSectionState extends ConsumerState<_FeedSection> {
  void _invalider() {
    ref.invalidate(feedPostsProvider);
  }

  /// Ouvre le panneau de rédaction (identique à la page « Fil d'actualité »).
  Future<void> _rediger() async {
    final publie = await showFeedComposerSheet(context);
    if (publie == true) _invalider();
  }

  /// Zone « Quoi de neuf ? » affichée en haut de l'aperçu du fil.
  Widget _composerAccueil() {
    final auth = ref.watch(authProvider);
    if (auth.status != AuthStatus.authenticated || !auth.isProvider) {
      return const SizedBox.shrink();
    }
    final photo = auth.userPhoto ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: AppTheme.cardDecoration.copyWith(
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 19,
              backgroundColor: AppTheme.primarySoft,
              backgroundImage: photo.isEmpty
                  ? null
                  : CachedNetworkImageProvider(photo),
              child: photo.isEmpty
                  ? const Icon(Icons.person, size: 19, color: AppTheme.primary)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: _rediger,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.inputFill,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    auth.userName?.isNotEmpty == true
                        ? 'Quoi de neuf, ${auth.userName!.split(' ').first} ?'
                        : 'Quoi de neuf dans votre activité ?',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppTheme.muted,
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: _rediger,
              icon: const Icon(Icons.photo_library_outlined),
              color: AppTheme.primary,
              tooltip: 'Ajouter une publication',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(feedPostsProvider);
    return feed.when(
      data: (posts) {
        final items = posts.take(3).toList();
        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                _composerAccueil(),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: AppTheme.cardDecoration.copyWith(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.dynamic_feed_outlined,
                        color: AppTheme.muted,
                        size: 30,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Aucune publication pour le moment',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.navy,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Les actualités des prestataires apparaîtront ici.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              _composerAccueil(),
              for (var i = 0; i < items.length; i++) ...[
                FeedInteractiveCard(
                  key: ValueKey('accueil-${items[i].id}'),
                  post: items[i],
                  compact: true,
                  onProviderTap: widget.onProviderTap,
                  onUpdated: (_) {},
                  onDeleted: _invalider,
                ),
                if (i < items.length - 1) const SizedBox(height: 12),
              ],
            ],
          ),
        );
      },
      loading: () => Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            ShimmerBox(height: 180),
            SizedBox(height: 12),
            ShimmerBox(height: 180),
          ],
        ),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: EmptyState.error(
          message: AppConstants.errorLoading,
          onRetry: () => ref.invalidate(feedPostsProvider),
        ),
      ),
    );
  }
}

IconData _getCategoryIcon(String iconName) {
  switch (iconName) {
    case 'plumbing':
      return Icons.plumbing;
    case 'electrical_services':
      return Icons.electrical_services;
    case 'content_cut':
      return Icons.content_cut;
    case 'code':
      return Icons.code;
    case 'handyman':
      return Icons.handyman;
    case 'construction':
      return Icons.construction;
    case 'cleaning_services':
      return Icons.cleaning_services;
    case 'local_shipping':
      return Icons.local_shipping;
    case 'local_hospital':
      return Icons.local_hospital;
    case 'school':
      return Icons.school;
    case 'camera_alt':
      return Icons.camera_alt;
    case 'build':
      return Icons.build;
    default:
      return Icons.work_outline;
  }
}
