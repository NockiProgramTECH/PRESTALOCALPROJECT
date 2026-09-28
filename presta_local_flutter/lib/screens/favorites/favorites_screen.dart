import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../providers/favorites_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/provider_card.dart';
import '../../widgets/shimmer_loading.dart';

/// Écran des favoris (style maquette) : en-tête + liste de cartes.
///
/// Les données sont persistées localement avec SharedPreferences.
class FavoritesScreen extends ConsumerWidget {
  final ValueChanged<String>? onProviderTap;

  const FavoritesScreen({super.key, this.onProviderTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoritesProvidersProvider);

    return favoritesAsync.when(
      data: (favorites) {
        if (favorites.isEmpty) {
          return EmptyState.favorites();
        }

        return RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () async => ref.invalidate(favoritesProvidersProvider),
          child: CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: AppHeader.slim(
                title: 'PrestLocal',
                subtitle: 'Favoris',
              )),
              // En-tête
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Text(
                    '${favorites.length} prestataire${favorites.length > 1 ? 's' : ''} favori${favorites.length > 1 ? 's' : ''}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.navy,
                    ),
                  ),
                ),
              ),

              // Liste des favoris
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: EdgeInsets.only(
                        bottom: index < favorites.length - 1 ? 12 : 0,
                      ),
                      child: ProviderCard(
                        provider: favorites[index],
                        onTap: () =>
                            onProviderTap?.call(favorites[index].id),
                      ),
                    ),
                    childCount: favorites.length,
                  ),
                ),
              ),

              // Espace de fin
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        );
      },
      loading: () => const CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: 16)),
          ShimmerProviderGrid(),
        ],
      ),
      error: (e, _) => EmptyState.error(
        message: 'Erreur lors du chargement des favoris',
        onRetry: () => ref.invalidate(favoritesProvidersProvider),
      ),
    );
  }
}
