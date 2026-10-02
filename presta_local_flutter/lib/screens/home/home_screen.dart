import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/badges.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/feed_interactive_card.dart';
import '../../widgets/provider_card.dart';
import '../../widgets/section_header.dart';
import '../../widgets/shimmer_loading.dart';
import '../feed/feed_composer_sheet.dart';
import '../feed/feed_screen.dart';

part 'parts/home_sections.dart';
part 'parts/home_feed.dart';

/// Écran d'accueil (maquette « accueil_lesprodufao ») :
/// en-tête, hero + recherche, garanties, catégories en grille,
/// prestataires recommandés, fil d'actualité.

class HomeScreen extends ConsumerWidget {
  final ValueChanged<String>? onProviderTap;
  final ValueChanged<String>? onMessagesTap;

  /// Recherche lancée depuis le hero (query, zone, categoryId).
  final void Function(String query, String zone, String categoryId)?
  onSearchSubmitted;

  const HomeScreen({
    super.key,
    this.onProviderTap,
    this.onMessagesTap,
    this.onSearchSubmitted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final unread = ref.watch(liveUnreadCountProvider);
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        ref.invalidate(feedPostsProvider);
        ref.invalidate(categoriesProvider);
        ref.invalidate(featuredProvidersProvider);
        await Future.wait([
          ref.read(feedPostsProvider.future),
          ref.read(categoriesProvider.future),
          ref.read(featuredProvidersProvider.future),
        ]);
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: AppHeader(
              onNotificationsTap: () => _comingSoon(context, 'Notifications'),
              hasNotification: unread > 0,
              userName: auth.userName,
              userPhoto: auth.userPhoto,
            ),
          ),
          SliverToBoxAdapter(child: _HeroSection(onSearchSubmitted)),
          const SliverToBoxAdapter(child: _TrustRow()),
          SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Catégories populaires',
              subtitle: 'Services disponibles immédiatement',
              actionLabel: 'Tout voir',
              onAction: () => onSearchSubmitted?.call('', 'Toutes les zones', 'all'),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            ),
          ),
          const SliverToBoxAdapter(child: _CategoriesGrid()),
          SliverToBoxAdapter(
            child: Row(
              children: [
                const Expanded(
                  child: SectionHeader(
                    title: 'Prestataires recommandés',
                    subtitle: 'Artisans disponibles à Ouagadougou',
                    padding: EdgeInsets.fromLTRB(16, 20, 8, 12),
                  ),
                ),
                const SoftPill(label: 'Proximité'),
                const SizedBox(width: 16),
              ],
            ),
          ),
          const SliverToBoxAdapter(child: _RecommendedList()),
          SliverToBoxAdapter(
            child: SectionHeader(
              title: "Fil d'actualité",
              actionLabel: 'Voir tout',
              onAction: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FeedScreen(onProviderTap: onProviderTap),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            ),
          ),
          SliverToBoxAdapter(child: _FeedSection(onProviderTap)),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  void _comingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature — Bientôt disponible')),
    );
  }
}
