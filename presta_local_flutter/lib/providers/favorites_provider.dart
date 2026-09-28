import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/provider_model.dart';
import '../services/favorites_service.dart';
import 'app_state_provider.dart';

/// ---------------------------------------------------------------------------
/// Provider des favoris
///
/// Gère la liste des prestataires favoris de l'utilisateur
/// avec persistance locale via SharedPreferences.
/// ---------------------------------------------------------------------------

final favoritesServiceProvider = Provider<FavoritesService>((ref) {
  return FavoritesService();
});

/// Provider qui expose la liste des IDs favoris
final favoritesIdsProvider = FutureProvider<List<String>>((ref) async {
  final service = ref.watch(favoritesServiceProvider);
  return service.getFavorites();
});

/// Provider qui expose les objets ProviderModel complets des favoris
final favoritesProvidersProvider = FutureProvider<List<ProviderModel>>((ref) async {
  final favoriteIds = await ref.watch(favoritesIdsProvider.future);
  final providerService = ref.watch(providerServiceProvider);
  final allProviders = await providerService.getAll();

  return allProviders.where((p) => favoriteIds.contains(p.id)).toList();
});

/// Notifier pour gérer les actions sur les favoris
final favoritesActionsProvider = Provider<FavoritesActions>((ref) {
  final service = ref.watch(favoritesServiceProvider);
  ref.onDispose(() {});
  return FavoritesActions(service, ref);
});

/// Classe d'actions sur les favoris
class FavoritesActions {
  final FavoritesService _service;
  final Ref _ref;

  FavoritesActions(this._service, this._ref);

  /// Ajoute un prestataire aux favoris
  Future<void> add(String providerId) async {
    await _service.addFavorite(providerId);
    _invalidate();
  }

  /// Retire un prestataire des favoris
  Future<void> remove(String providerId) async {
    await _service.removeFavorite(providerId);
    _invalidate();
  }

  /// Vérifie si un prestataire est favori
  Future<bool> isFavorite(String providerId) async {
    return _service.isFavorite(providerId);
  }

  /// Invalide les providers liés pour forcer le rafraîchissement
  void _invalidate() {
    _ref.invalidate(favoritesIdsProvider);
    _ref.invalidate(favoritesProvidersProvider);
  }
}
