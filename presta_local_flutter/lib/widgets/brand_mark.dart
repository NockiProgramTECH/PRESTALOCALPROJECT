import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Marque LesProduFao — emblème officiel (`assets/images/logo_mark.png`) :
/// médaillon circulaire avec les artisans, le monument de Ouagadougou et
/// l'étoile.
///
/// En dessous de [_assetMinSize], l'illustration n'est plus lisible (cartes
/// de connexion, puces) : on retombe alors sur la pastille dégradée citrus
/// avec la clé à molette, visuellement cohérente.
class BrandMark extends StatelessWidget {
  /// Taille minimum (px) à partir de laquelle l'emblème illustré est utilisé.
  static const double _assetMinSize = 32;

  final double size;
  final double radius;
  final double iconSize;

  const BrandMark({super.key, this.size = 40, this.radius = 12, this.iconSize = 22});

  @override
  Widget build(BuildContext context) {
    if (size >= _assetMinSize) {
      return Image.asset(
        'assets/images/logo_mark.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        semanticLabel: 'LesProduFao',
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        Icons.handyman_rounded,
        size: iconSize,
        color: Colors.white,
      ),
    );
  }
}
