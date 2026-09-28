import 'package:shared_preferences/shared_preferences.dart';

import '../models/provider_model.dart';
import 'api_client.dart';

/// Service de gestion des favoris.
///
/// Fonctionnement :
/// - **utilisateur connecté** : les favoris sont lus/écrits sur le serveur
///   (`GET /api/me/favorites/`, `POST /api/prestataire/{id}/toggle_favorite/`)
///   puis mis en cache localement (SharedPreferences) ;
/// - **hors ligne ou non connecté** : le cache local est utilisé, ce qui
///   permet de consulter ses favoris même sans réseau. La prochaine
///   synchronisation rétablit l'état du serveur.
class FavoritesService {
  static const String _storageKey = 'favorite_providers';

  final ApiClient _api = ApiClient();

  /// Liste des identifiants favoris (API si possible, sinon cache local).
  Future<List<String>> getFavorites() async {
    try {
      if (await _api.hasTokens()) {
        final list = await _api.getList('/api/me/favorites/');
        final ids = list
            .whereType<Map<String, dynamic>>()
            .map((p) => p['id'].toString())
            .toList();
        await _saveFavorites(ids);
        return ids;
      }
    } catch (_) {
      // Serveur indisponible / hors ligne : on retombe sur le cache local.
    }
    return _readCache();
  }

  /// Prestataires favoris complets, directement depuis l'API.
  ///
  /// Retourne `null` si l'utilisateur n'est pas connecté ou si l'API est
  /// injoignable (l'appelant utilise alors le cache local).
  Future<List<ProviderModel>?> getFavoriteProviders() async {
    try {
      if (!await _api.hasTokens()) return null;
      final list = await _api.getList('/api/me/favorites/');
      final providers = list
          .whereType<Map<String, dynamic>>()
          .map(ProviderModel.fromJson)
          .toList();
      await _saveFavorites(providers.map((p) => p.id).toList());
      return providers;
    } catch (_) {
      return null;
    }
  }

  /// Ajoute un prestataire aux favoris (cache local + serveur).
  Future<void> addFavorite(String providerId) async {
    final favorites = await _readCache();
    if (!favorites.contains(providerId)) {
      favorites.add(providerId);
      await _saveFavorites(favorites);
    }
    await _toggleOnServer(providerId, expectedFavorite: true);
  }

  /// Retire un prestataire des favoris (cache local + serveur).
  Future<void> removeFavorite(String providerId) async {
    final favorites = await _readCache();
    favorites.remove(providerId);
    await _saveFavorites(favorites);
    await _toggleOnServer(providerId, expectedFavorite: false);
  }

  /// Vérifie si un prestataire est dans les favoris.
  Future<bool> isFavorite(String providerId) async {
    final favorites = await getFavorites();
    return favorites.contains(providerId);
  }

  /// Vide la liste des favoris (cache local).
  Future<void> clearFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  // -------------------------------------------------------------------------
  // Interne
  // -------------------------------------------------------------------------

  /// Synchronise l'état avec le serveur (silencieux : le favori local est
  /// conservé même si le réseau échoue).
  Future<void> _toggleOnServer(
    String providerId, {
    required bool expectedFavorite,
  }) async {
    try {
      if (!await _api.hasTokens()) return;
      final data = await _api.post(
        '/api/prestataire/$providerId/toggle_favorite/',
      );
      final isFavorite = data['is_favorite'] == true;
      if (isFavorite != expectedFavorite) {
        // Le serveur et le client divergent (ex. appui hors ligne antérieur) :
        // on réaligne le cache local sur l'état serveur.
        final ids = await _readCache();
        if (isFavorite) {
          if (!ids.contains(providerId)) ids.add(providerId);
        } else {
          ids.remove(providerId);
        }
        await _saveFavorites(ids);
      }
    } catch (_) {
      // Pas de réseau : la synchronisation aura lieu au prochain chargement.
    }
  }

  Future<List<String>> _readCache() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_storageKey) ?? <String>[];
  }

  Future<void> _saveFavorites(List<String> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_storageKey, favorites);
  }
}
