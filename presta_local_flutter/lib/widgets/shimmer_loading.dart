import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// ---------------------------------------------------------------------------
/// Widgets de chargement avec effet shimmer (squelette animé)
///
/// Affiche des boîtes grises animées pendant le chargement des données
/// pour améliorer l'expérience utilisateur (perception de performance).
/// ---------------------------------------------------------------------------

/// Boîte shimmer générique
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Carte shimmer pour les prestataires (pendant le chargement)
///
/// Ne fixe PAS de largeur explicite : le parent (SliverGrid) donne déjà
/// les contraintes via le GridDelegate. Évite les
/// `BoxConstraints(w=-24.0)` quand MediaQuery.size.width est 0 au premier frame.
class ShimmerProviderCard extends StatelessWidget {
  const ShimmerProviderCard({super.key});

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
          // Bannière
          const ShimmerBox(height: 90),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Row(
                  children: [
                    const ShimmerBox(width: 32, height: 32, borderRadius: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const ShimmerBox(height: 12),
                          const SizedBox(height: 4),
                          ShimmerBox(height: 8, width: 80),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Row(
                  children: [
                    ShimmerBox(width: 50, height: 10),
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

/// Grille de cartes shimmer (pour la page d'accueil)
class ShimmerProviderGrid extends StatelessWidget {
  final int itemCount;

  const ShimmerProviderGrid({super.key, this.itemCount = 4});

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.78,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => const ShimmerProviderCard(),
          childCount: itemCount,
        ),
      ),
    );
  }
}

/// Ligne de conversation shimmer
class ShimmerConversationLine extends StatelessWidget {
  const ShimmerConversationLine({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const ShimmerBox(width: 50, height: 50, borderRadius: 25),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerBox(height: 14),
                const SizedBox(height: 8),
                ShimmerBox(height: 12, width: 180),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
