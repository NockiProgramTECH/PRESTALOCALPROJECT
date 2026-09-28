import '../models/category_model.dart';
import '../models/provider_model.dart';
import 'api_client.dart';

/// Service de gestion des prestataires, branché sur l'API Django.
///
/// Les endpoints `GET /api/prestataire/` et `GET /api/prestataire/{id}/`
/// nécessitent une session JWT. La liste est paginée (clé `results`).
class ProviderService {
  final ApiClient _api = ApiClient();

  /// Récupère tous les prestataires (accueil / recherche sans critère).
  ///
  /// [forceRefresh] conservé pour la compatibilité de l'API d'appel.
  Future<List<ProviderModel>> getAll({bool forceRefresh = false}) async {
    final data = await _api.get('/api/prestataire/');
    return _extractList(data);
  }

  /// Récupère les prestataires en vedette (page d'accueil).
  ///
  /// L'API n'a pas de notion "vedette" : on renvoie la liste complète,
  /// triée par note décroissante pour mettre en avant les mieux notés.
  Future<List<ProviderModel>> getFeatured() async {
    final providers = await getAll();
    providers.sort((a, b) => b.rating.compareTo(a.rating));
    return providers;
  }

  /// Récupère un prestataire par son ID.
  Future<ProviderModel?> getById(String id) async {
    final data = await _api.get('/api/prestataire/$id/');
    return ProviderModel.fromJson(data);
  }

  /// Recherche des prestataires selon des critères.
  ///
  /// [query] → recherche texte (`search`), [categoryId] → métier (`metier`).
  Future<List<ProviderModel>> search({
    String? query,
    String? categoryId,
    String? zone,
  }) async {
    final params = <String, String>{};
    final q = query?.trim() ?? '';
    if (q.isNotEmpty) params['search'] = q;
    if (categoryId != null && categoryId.isNotEmpty) {
      // `categoryId` = identifiant de catégorie (CategoriePrestation) renvoyé
      // par `GET /api/categories/`.
      params['categorie'] = categoryId;
    }
    final data = await _api.get(_buildQueryPath('/api/prestataire/', params));
    return _extractList(data);
  }

  /// Récupère les prestataires d'une catégorie spécifique.
  Future<List<ProviderModel>> getByCategory(String categoryId) async {
    return search(query: categoryId);
  }

  /// Publie (ou met à jour) l'évaluation du client connecté
  /// (`POST /api/prestataire/{id}/evaluer/`).
  ///
  /// [note] : 1 à 5. [commentaire] : texte libre (facultatif).
  /// Le backend réalise un `update_or_create` : un client n'a qu'un avis par
  /// prestataire, un second envoi remplace donc le précédent.
  Future<void> evaluate({
    required String providerId,
    required int note,
    String commentaire = '',
  }) async {
    await _api.post(
      '/api/prestataire/$providerId/evaluer/',
      body: {'note': note, 'commentaire': commentaire},
    );
  }

  /// Récupère les catégories de prestations depuis l'API.
  ///
  /// Endpoint public `GET /api/categories/` → `[{id, nom, description,
  /// provider_count}, ...]`. L'icône Material est déduite du nom via
  /// [_iconForName]. Repli sur `GET /api/prestations/` si l'endpoint
  /// catégories est indisponible (ancien backend).
  Future<List<CategoryModel>> getCategories() async {
    try {
      final data = await _api.getList('/api/categories/', authenticated: false);
      final categories = data.whereType<Map<String, dynamic>>().map((e) {
        final name = e['nom']?.toString() ?? '';
        return CategoryModel(
          id: e['id'].toString(),
          name: name,
          icon: _iconForName(name),
          description: e['description']?.toString() ?? '',
          providerCount: (e['provider_count'] as num?)?.toInt() ?? 0,
        );
      }).toList();
      if (categories.isNotEmpty) return categories;
    } catch (_) {
      // Repli ci-dessous.
    }

    final data = await _api.getList('/api/prestations/', authenticated: false);
    return data.whereType<Map<String, dynamic>>().map((e) {
      final name = e['nom']?.toString() ?? '';
      return CategoryModel(
        id: e['id'].toString(),
        name: name,
        icon: _iconForName(name),
        description: '',
      );
    }).toList();
  }

  /// Associe un nom de catégorie à une clé d'icône Material.
  static String _iconForName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('plomb')) return 'plumbing';
    if (lower.contains('électri') || lower.contains('electri')) {
      return 'electrical_services';
    }
    if (lower.contains('coiff') ||
        lower.contains('beauté') ||
        lower.contains('esthet')) {
      return 'content_cut';
    }
    if (lower.contains('développ') ||
        lower.contains('develop') ||
        lower.contains('informat')) {
      return 'code';
    }
    if (lower.contains('répar') || lower.contains('repar')) return 'handyman';
    if (lower.contains('maçon') ||
        lower.contains('macon') ||
        lower.contains('bât') ||
        lower.contains('bat')) {
      return 'construction';
    }
    if (lower.contains('nettoy') || lower.contains('propr')) {
      return 'cleaning_services';
    }
    if (lower.contains('transport') || lower.contains('livra')) {
      return 'local_shipping';
    }
    if (lower.contains('santé') ||
        lower.contains('sante') ||
        lower.contains('médic') ||
        lower.contains('medic')) {
      return 'local_hospital';
    }
    if (lower.contains('cours') ||
        lower.contains('formation') ||
        lower.contains('école') ||
        lower.contains('ecole')) {
      return 'school';
    }
    if (lower.contains('photo') ||
        lower.contains('vidéo') ||
        lower.contains('video')) {
      return 'camera_alt';
    }
    if (lower.contains('ménag') ||
        lower.contains('menag') ||
        lower.contains('travaux')) {
      return 'build';
    }
    return 'work_outline';
  }

  List<ProviderModel> _extractList(Map<String, dynamic> data) {
    final raw = data['results'] as List? ?? [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ProviderModel.fromJson)
        .toList();
  }

  String _buildQueryPath(String base, Map<String, String> params) {
    if (params.isEmpty) return base;
    final qs = params.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return '$base?$qs';
  }
}
