import 'package:flutter/material.dart';

/// Widget réutilisable pour afficher une note sous forme d'étoiles
///
/// Supporte différentes tailles (small, medium, large) et couleurs.
/// Utilise Material Icons (star, star_half, star_border).
class RatingDisplay extends StatelessWidget {
  final double rating;
  final double starSize;
  final Color? activeColor;
  final Color? inactiveColor;
  final bool showValue;
  final int? reviewCount;
  final double fontSize;

  const RatingDisplay({
    super.key,
    required this.rating,
    this.starSize = 16,
    this.activeColor,
    this.inactiveColor,
    this.showValue = true,
    this.reviewCount,
    this.fontSize = 12,
  });

  /// Version petite (pour les cartes)
  factory RatingDisplay.small({
    required double rating,
    int? reviewCount,
  }) {
    return RatingDisplay(
      rating: rating,
      starSize: 12,
      fontSize: 11,
      showValue: true,
      reviewCount: reviewCount,
    );
  }

  /// Version moyenne (pour les listes)
  factory RatingDisplay.medium({
    required double rating,
    int? reviewCount,
  }) {
    return RatingDisplay(
      rating: rating,
      starSize: 16,
      fontSize: 13,
      showValue: true,
      reviewCount: reviewCount,
    );
  }

  /// Version grande (pour les profils)
  factory RatingDisplay.large({
    required double rating,
    int? reviewCount,
  }) {
    return RatingDisplay(
      rating: rating,
      starSize: 22,
      fontSize: 16,
      showValue: true,
      reviewCount: reviewCount,
    );
  }

  @override
  Widget build(BuildContext context) {
    final starColor = activeColor ?? Colors.amber.shade700;
    final inColor = inactiveColor ?? Colors.grey.shade300;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Étoiles pleines
        ...List.generate(rating.floor(), (i) => Padding(
          padding: const EdgeInsets.only(right: 1),
          child: Icon(Icons.star, size: starSize, color: starColor),
        )),
        // Demi-étoile
        if (rating - rating.floor() >= 0.25 && rating - rating.floor() < 0.75)
          Padding(
            padding: const EdgeInsets.only(right: 1),
            child: Icon(Icons.star_half, size: starSize, color: starColor),
          ),
        // Étoiles vides restantes
        if (rating - rating.floor() >= 0.75)
          Padding(
            padding: const EdgeInsets.only(right: 1),
            child: Icon(Icons.star, size: starSize, color: starColor),
          ),
        ...List.generate(
          5 - (rating - rating.floor() >= 0.75 ? rating.ceil() : rating.floor()),
          (i) => Padding(
            padding: const EdgeInsets.only(right: 1),
            child: Icon(Icons.star_border, size: starSize, color: inColor),
          ),
        ),
        // Valeur numérique
        if (showValue) ...[
          const SizedBox(width: 6),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
        // Nombre d'avis
        if (reviewCount != null) ...[
          const SizedBox(width: 4),
          Text(
            '($reviewCount)',
            style: TextStyle(
              fontSize: fontSize - 1,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ],
    );
  }
}
