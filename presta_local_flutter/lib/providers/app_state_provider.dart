import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category_model.dart';
import '../models/conversation_model.dart';
import '../models/feed_post_model.dart';
import '../models/provider_model.dart';
import '../services/feed_service.dart';
import '../services/message_service.dart';
import '../services/notification_socket_service.dart';
import '../services/provider_service.dart';
import 'auth_provider.dart';

/// ---------------------------------------------------------------------------
/// Providers Riverpod pour l'état global de l'application
///
/// Riverpod est un système de gestion d'état moderne et type-safe.
/// Chaque provider expose des données et notifie les widgets des changements.
/// ---------------------------------------------------------------------------

// ---- Service instances (singletons) ----
final providerServiceProvider = Provider<ProviderService>((ref) {
  return ProviderService();
});

final feedServiceProvider = Provider<FeedService>((ref) {
  return FeedService();
});

final messageServiceProvider = Provider<MessageService>((ref) {
  return MessageService();
});

final notificationSocketServiceProvider =
    Provider<NotificationSocketService>((ref) {
  return NotificationSocketService();
});

/// UUID de l'utilisateur connecté (null si non authentifié).
final currentUserIdProvider = Provider<String?>((ref) {
  final auth = ref.watch(authProvider);
  return auth.status == AuthStatus.authenticated ? auth.userId : null;
});

// ---- Providers de données asynchrones ----

/// Liste complète des prestataires
final allProvidersProvider = FutureProvider<List<ProviderModel>>((ref) async {
  final service = ref.watch(providerServiceProvider);
  return service.getAll();
});

/// Prestataires en vedette (page d'accueil)
final featuredProvidersProvider = FutureProvider<List<ProviderModel>>((ref) async {
  final service = ref.watch(providerServiceProvider);
  return service.getFeatured();
});

/// Catégories/métiers de services (récupérées depuis l'API).
final categoriesProvider = FutureProvider<List<CategoryModel>>((ref) async {
  final service = ref.watch(providerServiceProvider);
  return service.getCategories();
});

/// Fil d'actualité : réalisations des prestataires locaux.
final feedPostsProvider = FutureProvider<List<FeedPostModel>>((ref) async {
  final service = ref.watch(feedServiceProvider);
  return service.getAll();
});

/// Mon Portfolio (onglet Portfolio web) : réalisations du compte connecté.
final myFeedPostsProvider = FutureProvider<List<FeedPostModel>>((ref) async {
  final auth = ref.watch(authProvider);
  if (auth.status != AuthStatus.authenticated) return const [];
  final service = ref.watch(feedServiceProvider);
  return service.getMine();
});

/// Liste des conversations (temps réel via badge + refresh).
final conversationsProvider =
    FutureProvider<List<ConversationModel>>((ref) async {
  final service = ref.watch(messageServiceProvider);
  final selfId = ref.watch(currentUserIdProvider);
  if (selfId == null) return const [];
  return service.getConversations(selfId);
});

/// Provider pour les résultats de recherche
final searchResultsProvider =
    StateNotifierProvider<SearchResultsNotifier, AsyncValue<List<ProviderModel>>>(
  (ref) => SearchResultsNotifier(ref),
);

/// Notifier pour gérer les résultats de recherche
class SearchResultsNotifier extends StateNotifier<AsyncValue<List<ProviderModel>>> {
  final Ref _ref;

  SearchResultsNotifier(this._ref) : super(const AsyncValue.data([]));

  /// Effectue une recherche avec les critères donnés
  Future<void> search({
    String? query,
    String? categoryId,
    String? zone,
  }) async {
    state = const AsyncValue.loading();
    try {
      final service = _ref.read(providerServiceProvider);
      final results = await service.search(
        query: query,
        categoryId: categoryId,
        zone: zone,
      );
      state = AsyncValue.data(results);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Réinitialise les résultats
  void clear() {
    state = const AsyncValue.data([]);
  }
}

/// Provider pour un prestataire spécifique par ID
final providerDetailProvider =
    FutureProvider.family<ProviderModel?, String>((ref, id) async {
  final service = ref.watch(providerServiceProvider);
  return service.getById(id);
});

/// Nombre total de messages non lus (badge de l'onglet Messages).
///
/// Mis à jour en **temps réel** par le serveur via `/ws/notifications/`
/// (événement `notification.unread`). Valeur initiale calculée depuis la liste
/// des conversations tant que le socket n'a pas transmis son compte.
final liveUnreadCountProvider =
    StateNotifierProvider<LiveUnreadCountNotifier, int>((ref) {
  return LiveUnreadCountNotifier(ref);
});

class LiveUnreadCountNotifier extends StateNotifier<int> {
  final Ref _ref;

  LiveUnreadCountNotifier(this._ref) : super(0) {
    _seed();
  }

  Future<void> _seed() async {
    try {
      final conversations = await _ref.read(conversationsProvider.future);
      if (state == 0) {
        state = conversations.fold<int>(0, (sum, c) => sum + c.unreadCount);
      }
    } catch (_) {
      // Le seed échoue (réseau) : le socket fournira le compte à la connexion.
    }
  }

  /// Applique le compte poussé par le WebSocket.
  void setCount(int count) => state = count;
}
