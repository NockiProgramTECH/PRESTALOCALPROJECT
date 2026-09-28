import 'dart:typed_data';

import '../models/feed_post_model.dart';
import 'api_client.dart';

/// Service du fil d'actualité, branché sur l'API Django.
///
/// L'endpoint `GET /api/feed/` est public (lecture sans authentification) et
/// renvoie la liste paginée (clé `results`) des réalisations des prestataires.
class FeedService {
  final ApiClient _api = ApiClient();

  /// Récupère les réalisations du fil d'actualité.
  Future<List<FeedPostModel>> getAll() async {
    final data = await _api.get('/api/feed/', authenticated: false);
    return _extractList(data);
  }

  /// Mon Portfolio (comme l'onglet Portfolio web) : réalisations du compte
  /// connecté via `GET /api/feed/?mine=1`.
  Future<List<FeedPostModel>> getMine() async {
    final data = await _api.get('/api/feed/?mine=1');
    return _extractList(data);
  }

  /// Réalisations d'un prestataire donné (`?prestataire=<uuid>`).
  Future<List<FeedPostModel>> getByPrestataire(String prestataireId) async {
    final data = await _api.get(
      '/api/feed/?prestataire=${Uri.encodeQueryComponent(prestataireId)}',
      authenticated: false,
    );
    return _extractList(data);
  }

  List<FeedPostModel> _extractList(Map<String, dynamic> data) {
    final raw = data['results'] as List? ?? [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(FeedPostModel.fromJson)
        .toList();
  }

  /// Récupère le détail d'une réalisation (image, auteur, commentaires).
  Future<FeedPostModel> getDetail(String id) async {
    final data = await _api.get('/api/feed/$id/');
    return FeedPostModel.fromJson(data);
  }

  /// Publie une réalisation (`POST /api/feed/` en multipart).
  ///
  /// Réservé aux prestataires connectés (comme `add_realisation` côté web).
  /// Retourne le détail de la réalisation créée.
  Future<FeedPostModel> create({
    required String titre,
    required Uint8List imageBytes,
    required String filename,
  }) async {
    final data = await _api.postMultipart(
      '/api/feed/',
      fields: {'titre': titre},
      fileBytes: imageBytes,
      filename: filename,
      fileField: 'image',
    );
    // L'endpoint renvoie le serializer de création ; on recharge le détail
    // pour obtenir auteur + compteurs au format `FeedPostModel`.
    final id = data['id']?.toString();
    if (id == null || id.isEmpty) {
      throw ApiException('Publication enregistrée, mais réponse invalide.');
    }
    return getDetail(id);
  }

  /// Supprime une réalisation du compte connecté
  /// (`DELETE /api/feed/<id>/`, comme `delete_realisation` côté web).
  Future<bool> delete(String id) {
    return _api.delete('/api/feed/$id/');
  }

  /// Aime ou retire le like d'une réalisation. Retourne le nouvel état et le
  /// nouveau compteur.
  Future<({bool liked, int likeCount})> toggleLike(String id) async {
    final data = await _api.post('/api/feed/$id/like/');
    return (
      liked: data['liked'] == true,
      likeCount: (data['like_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// Ajoute un commentaire à une réalisation. Retourne le commentaire créé et
  /// le nouveau compteur.
  Future<({FeedCommentModel comment, int commentCount})> addComment(
    String id,
    String contenu,
  ) async {
    final data = await _api.post(
      '/api/feed/$id/comment/',
      body: {'contenu': contenu},
    );
    return (
      comment: FeedCommentModel.fromJson(
        data['comment'] as Map<String, dynamic>? ?? const {},
      ),
      commentCount: (data['comment_count'] as num?)?.toInt() ?? 0,
    );
  }
}
