import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../models/provider_model.dart';
import '../providers/favorites_provider.dart';
import 'badges.dart';

/// Carte prestataire « recommandés » de l'accueil.
///
/// Contenu demandé par la maquette : photo, nom, métier, zone, pastilles
/// (Vérifié / Disponible), note et bouton « Voir profil ».
///
/// Pas de prix : la plateforme met en relation (devis discuté en messagerie),
/// aucun tarif n'est affiché sur les cartes.
///
/// Toutes les rangées utilisent `Expanded`/`Flexible` + `Wrap` : la carte ne
/// peut plus déborder horizontalement (« right overflowed by X pixels »), même
/// avec un nom long ou une police agrandie par l'utilisateur.
class ProviderCard extends ConsumerWidget {
  final ProviderModel provider;
  final VoidCallback? onTap;

  const ProviderCard({super.key, required this.provider, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  // Nom : une seule ligne, tronquée si nécessaire.
                  Text(
                    provider.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.navy,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  // Métier
                  Text(
                    provider.title.isEmpty ? 'Prestataire local' : provider.title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Note + localisation sur une ligne souple (Wrap = zéro débordement).
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _ratingInline(),
                      _locationInline(),
                    ],
                  ),
                  const SizedBox(height: 8),
                  StatusPills(
                    isVerified: provider.isVerified,
                    availabilityLabel: provider.isOnline ? 'Disponible' : null,
                    compact: true,
                  ),
                  const SizedBox(height: 10),
                  _seeProfileButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ratingInline() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 15, color: AppTheme.primary),
        const SizedBox(width: 3),
        Text(
          '${provider.rating.toStringAsFixed(1)} (${provider.reviewCount})',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.navy,
          ),
        ),
      ],
    );
  }

  Widget _locationInline() {
    final zone = provider.locationZone.isNotEmpty
        ? provider.locationZone
        : provider.location;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 150),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.location_on_outlined,
            size: 13,
            color: AppTheme.muted,
          ),
          const SizedBox(width: 2),
          Flexible(
            child: Text(
              zone,
              style: const TextStyle(fontSize: 12, color: AppTheme.muted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
              child: const Icon(Icons.person_rounded, color: AppTheme.primary),
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
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
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

/// Carte de résultat de recherche : photo + badge, nom, métier, note, zone,
/// chips de services et 3 actions (devis / appel / chat).
///
/// Aucun prix affiché : la demande de devis se fait par messagerie.
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
                      Text(
                        provider.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.navy,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        provider.title.isEmpty
                            ? 'Prestataire local'
                            : provider.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // Pastilles et note en `Wrap` : jamais de débordement.
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _ratingInline(),
                          if (provider.isOnline)
                            const AvailablePill(label: 'En ligne', compact: true),
                          if (provider.isVerified)
                            const VerifiedPill(label: 'Vérifié'),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _locationInline(),
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
            const SizedBox(height: 12),
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
                _squareButton(
                  Icons.chat_bubble_outline_rounded,
                  onChat,
                  filled: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _ratingInline() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 15, color: AppTheme.primary),
        const SizedBox(width: 3),
        Text(
          '${provider.rating.toStringAsFixed(1)} (${provider.reviewCount} avis)',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.navy,
          ),
        ),
      ],
    );
  }

  Widget _locationInline() {
    final zone = provider.locationZone.isNotEmpty
        ? provider.locationZone
        : provider.location;
    return Row(
      children: [
        const Icon(
          Icons.navigation_rounded,
          size: 13,
          color: AppTheme.muted,
        ),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            zone,
            style: const TextStyle(fontSize: 12, color: AppTheme.muted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
              child: const Icon(Icons.person_rounded, color: AppTheme.primary),
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

  Widget _squareButton(
    IconData icon,
    VoidCallback? onTap, {
    bool filled = false,
  }) {
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
