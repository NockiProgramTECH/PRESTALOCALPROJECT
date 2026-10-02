import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Écran de démarrage affiché pendant la restauration de session.
///
/// Logo officiel LesProduFao (`assets/images/logo.png`) sur le fond navy de la
/// marque, avec un léger indicateur de chargement.
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Image.asset(
                'assets/images/logo.png',
                width: 280,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                semanticLabel: 'LesProduFao',
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'La communauté qui connecte les talents locaux',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
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
