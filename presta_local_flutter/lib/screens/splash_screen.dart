import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../widgets/brand_mark.dart';

/// Écran de démarrage affiché pendant la restauration de session.
///
/// Un logo central (BrandMark citrus) sur le fond navy de la marque,
/// avec un léger indicateur de chargement.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navy,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const BrandMark(size: 88, radius: 24, iconSize: 46),
            const SizedBox(height: 20),
            Text(
              'LesProduFao',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Trouvez les meilleurs prestataires locaux',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 36),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
