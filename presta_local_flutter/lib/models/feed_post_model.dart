import '../utils/media.dart';

/// Auteur (prestataire) d'une réalisation dans le fil d'actualité.
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

/// Commentaire d'une réalisation.
///
/// Correspond à `CommentaireSerializer` du backend : contenu, date et nom du
/// commentateur.
class FeedCommentModel {
  final String id;
  final String userName;
  final String contenu;
  final DateTime date;

  const FeedCommentModel({
    required this.id,
    required this.userName,
    required this.contenu,
    required this.date,
  });

  factory FeedCommentModel.fromJson(Map<String, dynamic> json) {
    return FeedCommentModel(
      id: json['id'].toString(),
      userName: json['user']?.toString() ?? 'Utilisateur',
      contenu: json['contenu']?.toString() ?? '',
      date: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// Réalisation (post) du fil d'actualité.
///
/// Correspond à `FeedRealisationSerializer` : une photo de travaux effectuée
/// par un prestataire local, avec son auteur et les compteurs like/commentaire.
/// Les champs [comments] et [isLiked] ne sont présents que dans la réponse du
/// détail (`FeedDetailSerializer`).
class FeedPostModel {
  final String id;
  final String title;
  final String imageUrl;
  final DateTime date;
  final int likeCount;
  final int commentCount;
  final FeedAuthorModel author;
  final List<FeedCommentModel> comments;
  final bool isLiked;

  const FeedPostModel({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.date,
    required this.likeCount,
    required this.commentCount,
    required this.author,
    this.comments = const [],
    this.isLiked = false,
  });

  /// Construit depuis la réponse Django (`GET /api/feed/` et `/api/feed/<id>/`).
  factory FeedPostModel.fromJson(Map<String, dynamic> json) {
    return FeedPostModel(
      id: json['id'].toString(),
      title: json['titre']?.toString() ?? '',
      imageUrl: resolveMediaUrl(json['image']?.toString()),
      date: DateTime.tryParse(json['date_ajout']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
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
    );
  }
}
