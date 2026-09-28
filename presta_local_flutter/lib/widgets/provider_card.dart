import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/constants.dart';
import '../config/theme.dart';
import '../models/provider_model.dart';
import '../providers/favorites_provider.dart';
import 'badges.dart';

/// Carte prestataire « recommandés » de l'accueil (maquette) :
/// photo, nom + note, spécialité, zone, pastilles, tarif + « Voir profil ».
class ProviderCard extends ConsumerWidget {
  final ProviderModel provider;
  final VoidCallback? onTap;

  const ProviderCard({super.key, required this.provider, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final price = provider.priceText.isNotEmpty
        ? provider.priceText
        : (provider.priceValue != null
              ? 'Dès ${AppConstants.formatFcfa(provider.priceValue!)}'
              : 'Sur devis');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: AppTheme.cardDecoration,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _photo(84),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          provider.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.navy,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: AppTheme.primary,
                      ),
                      Text(
                        ' ${provider.rating.toStringAsFixed(1)} (${provider.reviewCount})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.navy,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    provider.title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.muted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: AppTheme.muted,
                      ),
                      Expanded(
                        child: Text(
                          ' ${provider.locationZone.isNotEmpty ? provider.locationZone : provider.location}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.muted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  StatusPills(
                    isVerified: provider.isVerified,
                    availabilityLabel: provider.isOnline
                        ? 'Disponible'
                        : null,
                    compact: true,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TARIF INDICATIF',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: AppTheme.muted,
                              ),
                            ),
                            Text(
                              price,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _seeProfileButton(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photo(double size) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CachedNetworkImage(
            imageUrl: provider.avatar,
            width: size,
            height: size + 12,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              width: size,
              height: size + 12,
              color: AppTheme.inputFill,
            ),
            errorWidget: (_, __, ___) => Container(
              width: size,
              height: size + 12,
              color: AppTheme.primarySoft,
              child: const Icon(
                Icons.person_rounded,
                color: AppTheme.primary,
              ),
            ),
          ),
        ),
        Positioned(
          right: 6,
          bottom: 6,
          child: _FavoriteButton(providerId: provider.id),
        ),
      ],
    );
  }

  Widget _seeProfileButton() {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Voir profil',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

/// Carte de résultat de recherche (maquette) : photo + badge délai,
/// nom + vérifié, note, zone, chips de services, tarif et 3 actions
/// (devis / appel / chat).
class SearchResultCard extends ConsumerWidget {
  final ProviderModel provider;
  final VoidCallback? onTap;
  final VoidCallback? onQuote;
  final VoidCallback? onCall;
  final VoidCallback? onChat;
  final String quoteLabel;

  const SearchResultCard({
    super.key,
    required this.provider,
    this.onTap,
    this.onQuote,
    this.onCall,
    this.onChat,
    this.quoteLabel = 'Demander un devis',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final price = provider.priceText.isNotEmpty
        ? provider.priceText
        : (provider.priceValue != null
              ? 'À partir de ${AppConstants.formatFcfa(provider.priceValue!)}'
              : 'Sur devis');
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: AppTheme.cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _photo(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              provider.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.navy,
                              ),
                            ),
                          ),
                          if (provider.isVerified)
                            const VerifiedPill(label: 'Vérifié'),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        provider.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 15,
                            color: AppTheme.primary,
                          ),
                          Text(
                            ' ${provider.rating.toStringAsFixed(1)} (${provider.reviewCount} avis)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.navy,
                            ),
                          ),
                          if (provider.isOnline)
                            const Text(
                              '  • En ligne',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.success,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.navigation_rounded,
                            size: 13,
                            color: AppTheme.muted,
                          ),
                          Expanded(
                            child: Text(
                              ' ${provider.locationZone.isNotEmpty ? provider.locationZone : provider.location}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.muted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (provider.services.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: provider.services
                    .take(3)
                    .map(
                      (s) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.inputFill,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          s,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.navy,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tarif indicatif',
                        style: TextStyle(fontSize: 10, color: AppTheme.muted),
                      ),
                      Text(
                        price,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (provider.isOnline)
                  const AvailablePill(label: 'En ligne', compact: true),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onQuote,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.description_outlined,
                            size: 17,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              quoteLabel,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _squareButton(Icons.call_outlined, onCall),
                const SizedBox(width: 8),
                _squareButton(Icons.chat_bubble_outline_rounded, onChat,
                    filled: true),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _photo() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CachedNetworkImage(
            imageUrl: provider.avatar,
            width: 72,
            height: 84,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              width: 72,
              height: 84,
              color: AppTheme.inputFill,
            ),
            errorWidget: (_, __, ___) => Container(
              width: 72,
              height: 84,
              color: AppTheme.primarySoft,
              child: const Icon(
                Icons.person_rounded,
                color: AppTheme.primary,
              ),
            ),
          ),
        ),
        if (provider.isOnline)
          Positioned(
            left: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'En ligne',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _squareButton(IconData icon, VoidCallback? onTap,
      {bool filled = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: filled ? AppTheme.success : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: filled
              ? null
              : Border.all(color: AppTheme.cardBorder, width: 1.5),
        ),
        child: Icon(
          icon,
          size: 20,
          color: filled ? Colors.white : AppTheme.navy,
        ),
      ),
    );
  }
}

/// Bouton favori (cœur) superposé aux photos.
class _FavoriteButton extends ConsumerWidget {
  final String providerId;

  const _FavoriteButton({required this.providerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(favoritesIdsProvider).valueOrNull ?? const <String>[];
    final isFav = ids.contains(providerId);
    return GestureDetector(
      onTap: () {
        final actions = ref.read(favoritesActionsProvider);
        if (isFav) {
          actions.remove(providerId);
        } else {
          actions.add(providerId);
        }
      },
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: AppTheme.cardShadow,
        ),
        child: Icon(
          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: 16,
          color: isFav ? AppTheme.danger : AppTheme.navy,
        ),
      ),
    );
  }
}
