import 'dart:typed_data';

import '../models/feed_post_model.dart';
import 'api_client.dart';

/// Une page de fil d'actualité : éléments + indication de suite.
class FeedPage {
  final List<FeedPostModel> items;
  final bool hasMore;
  final int nextPage;

  const FeedPage({
    required this.items,
    required this.hasMore,
    this.nextPage = 1,
  });

  static const empty = FeedPage(items: [], hasMore: false);
}

/// Fichier local prêt à être publié (image ou vidéo).
class FeedUpload {
  final Uint8List bytes;
  final String filename;
  final bool isVideo;

  const FeedUpload({
    required this.bytes,
    required this.filename,
    this.isVideo = false,
  });
}

/// Service du fil d'actualité, branché sur l'API Django.
///
/// - `GET /api/feed/` : fil paginé (10 par page), trié du plus récent au plus
///   ancien ; filtres `mine`, `prestataire`, `categorie`, `search`.
/// - `POST /api/feed/` : publication (texte et/ou plusieurs images, vidéo,
///   lien, catégorie) — la réponse 201 contient la publication complète.
/// - `PATCH/DELETE /api/feed/<id>/` : modification par l'auteur, suppression
///   par l'auteur ou un modérateur.
/// - `POST /api/feed/<id>/like/` et `.../comment/` : interactions.
class FeedService {
  final ApiClient _api = ApiClient();

  /// Charge une page du fil.
  ///
  /// [page] commence à 1. Les filtres sont cumulables. [pageSize] reste borné
  /// par le backend (50 maximum).
  Future<FeedPage> getPage({
    int page = 1,
    int pageSize = 10,
    bool mine = false,
    String? prestataireId,
    int? categorieId,
    String? search,
  }) async {
    final params = <String>['page=$page', 'page_size=$pageSize'];
    if (mine) params.add('mine=1');
    if (prestataireId != null && prestataireId.isNotEmpty) {
      params.add('prestataire=${Uri.encodeQueryComponent(prestataireId)}');
    }
    if (categorieId != null) params.add('categorie=$categorieId');
    if (search != null && search.trim().isNotEmpty) {
      params.add('search=${Uri.encodeQueryComponent(search.trim())}');
    }
    final authenticated = await _api.hasSession();
    final data = await _api.get(
      '/api/feed/?${params.join('&')}',
      authenticated: authenticated,
    );
    return _toPage(data, page);
  }

  FeedPage _toPage(Map<String, dynamic> data, int page) {
    final raw = data['results'];
    final items = raw is List
        ? raw
              .whereType<Map<String, dynamic>>()
              .map(FeedPostModel.fromJson)
              .toList()
        : <FeedPostModel>[];
    final hasMore = data['next'] != null && items.isNotEmpty;
    return FeedPage(items: items, hasMore: hasMore, nextPage: page + 1);
  }

  /// Première page du fil (raccourci utilisé par l'accueil).
  Future<List<FeedPostModel>> getAll() async {
    final page = await getPage(pageSize: 10);
    return page.items;
  }

  /// Mon Portfolio : mes publications (`GET /api/feed/?mine=1`).
  ///
  /// Récupère jusqu'à 3 pages (30 publications) pour que le portfolio affiche
  /// l'essentiel sans charger tout l'historique.
  Future<List<FeedPostModel>> getMine() async {
    final items = <FeedPostModel>[];
    var page = 1;
    var hasMore = true;
    while (hasMore && page <= 3) {
      final result = await getPage(page: page, mine: true, pageSize: 10);
      items.addAll(result.items);
      hasMore = result.hasMore;
      page++;
    }
    return items;
  }

  /// Publications d'un prestataire donné (`?prestataire=<uuid>`).
  Future<List<FeedPostModel>> getByPrestataire(String prestataireId) async {
    final page = await getPage(prestataireId: prestataireId, pageSize: 10);
    return page.items;
  }

  /// Récupère le détail d'une publication (médias + commentaires).
  Future<FeedPostModel> getDetail(String id) async {
    final authenticated = await _api.hasSession();
    final data = await _api.get('/api/feed/$id/', authenticated: authenticated);
    return FeedPostModel.fromJson(data);
  }

  /// Commentaires d'une publication, du plus récent au plus ancien.
  Future<List<FeedCommentModel>> getComments(String id) async {
    final authenticated = await _api.hasSession();
    final data = await _api.getList(
      '/api/feed/$id/comment/',
      authenticated: authenticated,
    );
    return data
        .whereType<Map<String, dynamic>>()
        .map(FeedCommentModel.fromJson)
        .toList();
  }

  /// Publie une publication (`POST /api/feed/` en multipart).
  ///
  /// Retourne la publication complète renvoyée par le backend (201) : elle
  /// peut donc être insérée en tête du fil sans second appel.
  Future<FeedPostModel> createPublication({
    String contenu = '',
    String titre = '',
    List<FeedUpload> images = const [],
    FeedUpload? video,
    String lien = '',
    int? categorieId,
  }) async {
    final fields = <String, String>{};
    if (contenu.trim().isNotEmpty) fields['contenu'] = contenu.trim();
    if (titre.trim().isNotEmpty) fields['titre'] = titre.trim();
    if (lien.trim().isNotEmpty) fields['lien'] = lien.trim();
    if (categorieId != null) fields['categorie'] = categorieId.toString();

    final uploads = <MultipartUpload>[
      for (final image in images)
        MultipartUpload(
          field: 'images',
          bytes: image.bytes,
          filename: image.filename,
        ),
      if (video != null)
        MultipartUpload(
          field: 'video',
          bytes: video.bytes,
          filename: video.filename,
          isVideo: true,
        ),
    ];

    final data = await _api.postMultipartUploads(
      '/api/feed/',
      fields: fields,
      uploads: uploads,
    );
    return FeedPostModel.fromJson(data);
  }

  /// Modifie le texte, le lien ou la catégorie d'une publication
  /// (`PATCH /api/feed/<id>/`, réservé à l'auteur).
  Future<FeedPostModel> update(
    String id, {
    String? contenu,
    String? titre,
    String? lien,
    int? categorieId,
    bool clearCategorie = false,
  }) async {
    final body = <String, dynamic>{};
    if (contenu != null) body['contenu'] = contenu;
    if (titre != null) body['titre'] = titre;
    if (lien != null) body['lien'] = lien;
    if (categorieId != null) {
      body['categorie'] = categorieId;
    } else if (clearCategorie) {
      // L'auteur a retiré la catégorie : on la vide côté backend.
      body['categorie'] = null;
    }
    final data = await _api.patch('/api/feed/$id/', body: body);
    return FeedPostModel.fromJson(data);
  }

  /// Supprime une publication (`DELETE /api/feed/<id>/`).
  ///
  /// Réservé à l'auteur ou à un rôle de modération côté backend.
  Future<bool> delete(String id) {
    return _api.delete('/api/feed/$id/');
  }

  /// Aime ou retire le like d'une publication. Retourne le nouvel état et le
  /// nouveau compteur calculés par le backend.
  Future<({bool liked, int likeCount})> toggleLike(String id) async {
    final data = await _api.post('/api/feed/$id/like/');
    return (
      liked: data['liked'] == true,
      likeCount: (data['like_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// Ajoute un commentaire. Retourne le commentaire créé et le nouveau
  /// compteur.
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
