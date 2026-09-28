import 'package:shared_preferences/shared_preferences.dart';

/// Service de gestion des favoris
///
/// Permet à l'utilisateur de sauvegarder ses prestataires préférés.
/// Utilise SharedPreferences pour le stockage local persisté.
///
/// TODO: Quand l'API sera disponible, remplacer par des appels API
/// pour synchroniser les favoris sur tous les appareils.
class FavoritesService {
  static const String _storageKey = 'favorite_providers';

  /// Récupère la liste des IDs des prestataires favoris
  Future<List<String>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_storageKey) ?? [];
  }

  /// Ajoute un prestataire aux favoris
  Future<void> addFavorite(String providerId) async {
    final favorites = await getFavorites();
    if (!favorites.contains(providerId)) {
      favorites.add(providerId);
      await _saveFavorites(favorites);
    }
  }

  /// Retire un prestataire des favoris
  Future<void> removeFavorite(String providerId) async {
    final favorites = await getFavorites();
    favorites.remove(providerId);
    await _saveFavorites(favorites);
  }

  /// Vérifie si un prestataire est dans les favoris
  Future<bool> isFavorite(String providerId) async {
    final favorites = await getFavorites();
    return favorites.contains(providerId);
  }

  /// Vide la liste des favoris
  Future<void> clearFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  /// Sauvegarde la liste dans SharedPreferences
  Future<void> _saveFavorites(List<String> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_storageKey, favorites);
  }
}
