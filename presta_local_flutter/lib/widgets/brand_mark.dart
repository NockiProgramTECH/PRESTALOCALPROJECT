import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Logo LesProduFao : carré arrondi dégradé orange, glyph blanc.
class BrandMark extends StatelessWidget {
  final double size;
  final double radius;
  final double iconSize;

  const BrandMark({super.key, this.size = 40, this.radius = 12, this.iconSize = 22});

  @override
  Widget build(BuildContext context) {
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
