import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Chip de catégorie (ligne horizontale défilante) + carte de grille
/// « Catégories populaires » (maquette accueil : 2 colonnes, icône
/// pastel, nom + nombre d'artisans).
class CategoryChip extends StatelessWidget {
  final String name;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;
  final int? count;

  const CategoryChip({
    super.key,
    required this.name,
    required this.icon,
    this.isSelected = false,
    this.onTap,
    this.count,
  });

  factory CategoryChip.circle({
    required String name,
    required IconData icon,
    required bool isSelected,
    VoidCallback? onTap,
  }) {
    return CategoryChip(
      name: name,
      icon: icon,
      isSelected: isSelected,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.navy : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? AppTheme.navy : AppTheme.cardBorder,
          ),
        ),
        child: Text(
          name,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.navy,
          ),
        ),
      ),
    );
  }
}

/// Ligne horizontale de chips (recherche).
class CategoryChipsRow extends StatelessWidget {
  final List<Map<String, dynamic>> categories;
  final String? selectedId;
  final ValueChanged<String>? onCategorySelected;

  const CategoryChipsRow({
    super.key,
    required this.categories,
    this.selectedId,
    this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = categories[i];
          final id = '${c['id']}';
          return CategoryChip(
            name: '${c['name']}',
            icon: Icons.circle,
            isSelected: selectedId == id,
            onTap: () => onCategorySelected?.call(id),
          );
        },
      ),
    );
  }
}

/// Carte de catégorie en grille (accueil) : icône sur fond pastel,
///
/// nom en gras + « N artisans ».
class CategoryGridCard extends StatelessWidget {
  final String name;
  final IconData icon;
  final int count;
  final Color tint;
  final Color iconColor;
  final VoidCallback? onTap;

  const CategoryGridCard({
    super.key,
    required this.name,
    required this.icon,
    required this.count,
    required this.tint,
    required this.iconColor,
    this.onTap,
  });

  /// Teintes pastel alternées (spec maquette : pêche, bleu, vert...).
  static const List<(Color, Color)> tints = [
    (Color(0xFFFFE8D6), Color(0xFFB45309)),
    (Color(0xFFDCEAFE), Color(0xFF1D4ED8)),
    (Color(0xFFD9F7E8), Color(0xFF047857)),
    (Color(0xFFF3E8FF), Color(0xFF7E22CE)),
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorder),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.navy,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    count > 0 ? '$count artisans' : 'Voir les pros',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
