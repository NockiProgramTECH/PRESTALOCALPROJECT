import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import '../providers/app_state_provider.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/favorites/favorites_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/messages/chat_screen.dart';
import '../screens/messages/messages_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/search/search_screen.dart';
import 'auth_navigation.dart';
import 'mobile_bottom_nav.dart';

/// Écran principal : onglets + barre de navigation inférieure.
///
/// Chaque écran dessine son propre en-tête (maquette Warm Kinetic) :
/// pas d'AppBar ni de drawer globaux. Les écrans de détail prestataire
/// et de chat s'ouvrent via [Navigator.push].
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  // Onglet actif dans la barre de navigation
  AppTab _currentTab = AppTab.accueil;

  // Recherche pré-remplie depuis l'accueil (consommée par SearchScreen).
  String? _pendingQuery;
  String? _pendingZone;
  String? _pendingCategory;

  @override
  void initState() {
    super.initState();
    // Synchronise le socket de notifications (badge temps réel) avec la session.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncNotificationSocket(ref.read(authProvider));
    });
  }

  @override
  void dispose() {
    ref.read(notificationSocketServiceProvider).disconnect();
    super.dispose();
  }

  /// Connecte/déconnecte le WebSocket de notifications selon l'état d'auth,
  /// et relie chaque compte non-lu poussé au provider du badge.
  void _syncNotificationSocket(AuthState auth) {
    final socket = ref.read(notificationSocketServiceProvider);
    if (auth.status == AuthStatus.authenticated) {
      socket.onUnreadChanged = (count) {
        if (mounted) {
          ref.read(liveUnreadCountProvider.notifier).setCount(count);
        }
      };
      socket.connect();
    } else {
      socket.onUnreadChanged = null;
      socket.disconnect();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(
      authProvider,
      (previous, next) => _syncNotificationSocket(next),
    );
    final unreadCount = ref.watch(liveUnreadCountProvider);

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: _buildBody(),
      bottomNavigationBar: MobileBottomNav(
        currentTab: _currentTab,
        onTabSelected: _onTabSelected,
        unreadCount: unreadCount,
      ),
    );
  }

  /// Corps de la page selon l'onglet actif.
  Widget _buildBody() {
    switch (_currentTab) {
      case AppTab.accueil:
        return HomeScreen(
          onProviderTap: _openProviderDetail,
          onMessagesTap: _openConversation,
          onSearchSubmitted: _onHomeSearch,
        );
      case AppTab.rechercher:
        return SearchScreen(
          onProviderTap: _openProviderDetail,
          onChatTap: _openConversation,
          onBecomePro: () => _openRegisterScreen(),
          initialQuery: _pendingQuery,
          initialZone: _pendingZone,
          initialCategory: _pendingCategory,
        );
      case AppTab.favoris:
        return FavoritesScreen(onProviderTap: _openProviderDetail);
      case AppTab.messages:
        return MessagesScreen(onConversationTap: _openConversation);
      case AppTab.profil:
        return ProfileScreen(onLoginTap: () => _openLoginScreen());
    }
  }

  /// Recherche depuis l'accueil : bascule sur l'onglet Recherche
  /// avec les critères pré-remplis.
  void _onHomeSearch(String query, String zone, String categoryId) {
    setState(() {
      _pendingQuery = query;
      _pendingZone = zone;
      _pendingCategory = categoryId;
      _currentTab = AppTab.rechercher;
    });
  }

  /// Navigue vers le détail d'un prestataire (route indépendante).
  void _openProviderDetail(String id) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(
          providerId: id,
          onBack: () => Navigator.of(context).pop(),
          onMessageTap: (convId) {
            // Chat empilé par-dessus le détail
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  conversationId: convId,
                  onBack: () => Navigator.of(context).pop(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Navigue vers une conversation (route indépendante).
  void _openConversation(String convId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: convId,
          onBack: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  /// Ouvre l'écran de connexion plein écran.
  void _openLoginScreen() {
    Navigator.of(context).push(authRoute((_) => const LoginScreen()));
  }

  /// Ouvre l'écran d'inscription plein écran.
  void _openRegisterScreen() {
    Navigator.of(context).push(authRoute((_) => const RegisterScreen()));
  }

  /// Gère le changement d'onglet dans la barre de navigation.
  void _onTabSelected(AppTab tab) {
    setState(() => _currentTab = tab);
  }
}
