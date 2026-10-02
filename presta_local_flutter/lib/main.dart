import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/theme.dart';
import 'navigation/main_shell.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/splash_screen.dart';

/// ============================================================================
/// LesProduFao - Application de mise en relation avec des prestataires
/// ============================================================================
///
/// Plateforme burkinabè qui connecte les clients aux prestataires de services
/// locaux (plomberie, électricité, coiffure, développement, etc.).
///
/// Architecture :
/// - State Management : Riverpod (flutter_riverpod)
/// - Navigation : Bottom Navigation + superposition d'écrans
/// - Données : Mock data en attendant l'API
/// - Thème : Material 3 avec palette vert/rouge/or (drapeau du Burkina Faso)
///
/// TODO: Quand le backend sera prêt :
///   1. Remplacer les services dans lib/services/ par des appels API HTTP
///   2. Mettre à jour les modèles dans lib/models/ si la structure change
///   3. Configurer l'URL de base dans lib/config/constants.dart
///   4. Implémenter l'authentification réelle (JWT)
/// ============================================================================

void main() {
  // Configuration système
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Lancement avec Riverpod (ProviderScope = conteneur d'état global)
  runApp(
    const ProviderScope(
      child: LesProduFaoApp(),
    ),
  );
}

/// Widget racine de l'application
///
/// Configure le thème Material 3, l'écran principal, et restaure la session
/// utilisateur au démarrage (checkSession via JWT stocké localement).
class LesProduFaoApp extends ConsumerStatefulWidget {
  const LesProduFaoApp({super.key});

  @override
  ConsumerState<LesProduFaoApp> createState() => _LesProduFaoAppState();
}

class _LesProduFaoAppState extends ConsumerState<LesProduFaoApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LesProduFao',
      debugShowCheckedModeBanner: false,

      // Thème clair Material 3 personnalisé (voir config/theme.dart)
      theme: AppTheme.lightTheme,

      // Filet de sécurité UI appliqué à TOUTE l'application :
      //
      // 1. `DefaultTextStyle` avec `decoration: none` — sans style par défaut,
      //    Flutter dessine un « double trait jaune » sous les textes rendus
      //    hors d'un `Material` (overlays, transitions, tooltips…). C'est la
      //    cause du double trait jaune signalé sur le détail prestataire et
      //    sur le nom du destinataire dans la messagerie.
      // 2. Taille de police bornée (0.9 → 1.2) — évite les débordements
      //    (« right/bottom overflowed ») quand l'utilisateur agrandit la
      //    police de son téléphone.
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(
              minScaleFactor: 0.9,
              maxScaleFactor: 1.2,
            ),
          ),
          child: DefaultTextStyle(
            style: const TextStyle(
              decoration: TextDecoration.none,
              color: AppTheme.navy,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },

      // Écran racine : détermine la destination selon l'état de session.
      // - session en cours de restauration  -> écran de démarrage
      // - utilisateur connecté              -> navigation principale
      // - non connecté                      -> écran de connexion (automatique)
      home: const AuthGate(),
    );
  }
}

/// Aiguille l'utilisateur vers l'écran adapté à son état de session.
///
/// À chaque ouverture de l'application, [AuthNotifier.initialize] restaure la
/// session depuis le stockage sécurisé : si un token valide existe, l'utilisateur
/// est redirigé vers [MainShell] ; sinon, vers [LoginScreen] automatiquement.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    switch (auth.status) {
      case AuthStatus.initial:
      case AuthStatus.loading:
        return const SplashScreen();
      case AuthStatus.authenticated:
        return const MainShell();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}
