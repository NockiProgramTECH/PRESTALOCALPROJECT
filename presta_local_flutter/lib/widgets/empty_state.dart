import 'package:flutter/material.dart';

import '../config/constants.dart';

/// Widget d'état vide
///
/// Affiche un message et une icône quand une liste est vide
/// ou quand une recherche ne donne aucun résultat.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isSearch;

  const EmptyState({
    super.key,
    this.icon = Icons.search_off_rounded,
    this.title = AppConstants.errorEmptySearch,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.isSearch = false,
  });

  /// État vide pour une recherche sans résultat
  factory EmptyState.search() {
    return const EmptyState(
      icon: Icons.search_off_rounded,
      title: 'Aucun résultat trouvé',
      subtitle: 'Essayez de modifier vos critères de recherche',
      isSearch: true,
    );
  }

  /// État vide pour une liste de favoris vide
  factory EmptyState.favorites() {
    return const EmptyState(
      icon: Icons.favorite_border_rounded,
      title: 'Aucun favori',
      subtitle: 'Ajoutez des prestataires à vos favoris pour les retrouver rapidement',
    );
  }

  /// État vide pour un chargement qui a échoué
  factory EmptyState.error({String? message, VoidCallback? onRetry}) {
    return EmptyState(
      icon: Icons.error_outline_rounded,
      title: message ?? AppConstants.errorUnknown,
      actionLabel: onRetry != null ? 'Réessayer' : null,
      onAction: onRetry,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 72,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 10),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
