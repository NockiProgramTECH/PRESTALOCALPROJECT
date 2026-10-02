import '../utils/media.dart';

/// Auteur (prestataire) d'une publication du fil d'actualité.
///
/// Correspond à `FeedPrestataireSerializer` du backend : identité compacte
/// (nom complet, photo, métier, ville) + note/avis pour l'affichage.
class FeedAuthorModel {
  final String id;
  final String fullName;
  final String avatar;
  final String metier;
  final String ville;
  final String quartier;
  final bool isVerified;
  /// Faux si l'auteur n'a pas d'abonnement actif : sa publication reste
  /// visible, mais il n'est pas contactable.
  final bool contactDisponible;
  final double rating;
  final int reviewCount;

  const FeedAuthorModel({
    required this.id,
    required this.fullName,
    required this.avatar,
    required this.metier,
    required this.ville,
    required this.quartier,
    required this.isVerified,
    this.contactDisponible = true,
    required this.rating,
    required this.reviewCount,
  });

  /// Construit depuis la réponse Django du fil d'actualité.
  factory FeedAuthorModel.fromJson(Map<String, dynamic> json) {
    return FeedAuthorModel(
      id: json['id'].toString(),
      fullName: json['nom_complet']?.toString() ?? '',
      avatar: resolveMediaUrl(json['photo_profil']?.toString()),
      metier: json['metier']?.toString() ?? '',
      ville: json['ville']?.toString() ?? '',
      quartier: json['quartier']?.toString() ?? '',
      isVerified: json['est_verifie'] == true,
      contactDisponible: json['contact_disponible'] != false,
      rating: (json['moyenne_etoile'] as num?)?.toDouble() ?? 0,
      reviewCount: (json['nombre_avis'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Commentaire d'une publication.
///
/// Correspond à `CommentaireSerializer` du backend : contenu, date, nom,
/// photo et identifiant du commentateur. [isAuthor] signifie « commentaire
/// rédigé par l'utilisateur connecté » (et non « rédigé par l'auteur de la
/// publication ») : le badge « Auteur » de l'interface se calcule en
/// comparant [userId] avec l'identifiant de l'auteur de la publication.
class FeedCommentModel {
  final String id;
  final String userId;
  final String userName;
  final String userPhoto;
  final String contenu;
  final DateTime date;
  /// Vrai si le commentaire a été écrit par l'utilisateur connecté.
  final bool isAuthor;

  const FeedCommentModel({
    required this.id,
    this.userId = '',
    required this.userName,
    this.userPhoto = '',
    required this.contenu,
    required this.date,
    this.isAuthor = false,
  });

  factory FeedCommentModel.fromJson(Map<String, dynamic> json) {
    return FeedCommentModel(
      id: json['id'].toString(),
      userId: json['user_id']?.toString() ?? '',
      userName: json['user']?.toString() ?? 'Utilisateur',
      userPhoto: resolveMediaUrl(json['user_photo']?.toString()),
      contenu: json['contenu']?.toString() ?? '',
      date: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isAuthor: json['is_author'] == true,
    );
  }
}

/// Publication du fil d'actualité.
///
/// Correspond à `FeedRealisationSerializer` : texte, une ou plusieurs images,
/// vidéo facultative, lien externe, catégorie, auteur et compteurs réels
/// (J'aime / commentaires) calculés par le backend.
class FeedPostModel {
  final String id;
  /// Titre court facultatif (portfolio).
  final String title;
  /// Texte principal de la publication.
  final String contenu;
  /// Toutes les images de la publication (0, 1 ou plusieurs), URLs absolues.
  final List<String> images;
  /// Vidéo facultative (URL absolue).
  final String videoUrl;
  /// Lien externe facultatif.
  final String lien;
  final String categorieNom;
  final DateTime date;
  final DateTime? modifieLe;
  final int likeCount;
  final int commentCount;
  final FeedAuthorModel author;
  final List<FeedCommentModel> comments;
  final bool isLiked;
  /// L'utilisateur connecté peut-il modifier / supprimer cette publication ?
  final bool canEdit;
  final bool canDelete;

  const FeedPostModel({
    required this.id,
    required this.title,
    this.contenu = '',
    this.images = const [],
    this.videoUrl = '',
    this.lien = '',
    this.categorieNom = '',
    required this.date,
    this.modifieLe,
    required this.likeCount,
    required this.commentCount,
    required this.author,
    this.comments = const [],
    this.isLiked = false,
    this.canEdit = false,
    this.canDelete = false,
  });

  /// Texte à afficher : le contenu, sinon le titre (anciennes publications).
  String get text => contenu.isNotEmpty ? contenu : title;

  /// Image principale (première de la liste), ou chaîne vide.
  String get imageUrl => images.isNotEmpty ? images.first : '';

  /// Vrai si la publication ne contient que des médias (aucun texte).
  bool get hasMedia =>
      images.isNotEmpty || videoUrl.isNotEmpty || lien.isNotEmpty;

  /// Copie avec les compteurs / le texte mis à jour.
  ///
  /// Après un « J'aime » ou une modification, l'interface affiche les valeurs
  /// **renvoyées par le backend** (jamais un compteur inventé localement).
  FeedPostModel copyWith({
    String? title,
    String? contenu,
    List<String>? images,
    String? videoUrl,
    String? lien,
    String? categorieNom,
    int? likeCount,
    int? commentCount,
    List<FeedCommentModel>? comments,
    bool? isLiked,
    bool? canEdit,
    bool? canDelete,
  }) {
    return FeedPostModel(
      id: id,
      title: title ?? this.title,
      contenu: contenu ?? this.contenu,
      images: images ?? this.images,
      videoUrl: videoUrl ?? this.videoUrl,
      lien: lien ?? this.lien,
      categorieNom: categorieNom ?? this.categorieNom,
      date: date,
      modifieLe: modifieLe,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      author: author,
      comments: comments ?? this.comments,
      isLiked: isLiked ?? this.isLiked,
      canEdit: canEdit ?? this.canEdit,
      canDelete: canDelete ?? this.canDelete,
    );
  }

  /// Construit depuis la réponse Django (`GET /api/feed/` et `/api/feed/<id>/`).
  factory FeedPostModel.fromJson(Map<String, dynamic> json) {
    // `images` est la liste complète ; on retombe sur l'ancien champ `image`
    // pour rester compatible avec les versions antérieures du backend.
    final images = <String>[];
    final rawImages = json['images'];
    if (rawImages is List) {
      for (final item in rawImages) {
        final url = resolveMediaUrl(item?.toString());
        if (url.isNotEmpty) images.add(url);
      }
    }
    if (images.isEmpty) {
      final legacy = resolveMediaUrl(json['image']?.toString());
      if (legacy.isNotEmpty) images.add(legacy);
    }

    return FeedPostModel(
      id: json['id'].toString(),
      title: json['titre']?.toString() ?? '',
      contenu: json['contenu']?.toString() ?? '',
      images: images,
      videoUrl: resolveMediaUrl(json['video_url']?.toString()),
      lien: json['lien']?.toString() ?? '',
      categorieNom: json['categorie_nom']?.toString() ?? '',
      date: DateTime.tryParse(json['date_ajout']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      modifieLe: DateTime.tryParse(json['modifie_le']?.toString() ?? ''),
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
      author: FeedAuthorModel.fromJson(
        json['prestataire'] as Map<String, dynamic>? ?? const {},
      ),
      comments: (json['commentaires'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(FeedCommentModel.fromJson)
          .toList(),
      isLiked: json['is_liked'] == true,
      canEdit: json['can_edit'] == true,
      canDelete: json['can_delete'] == true,
    );
  }
}
