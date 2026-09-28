/// Modèle représentant un avis/client sur un prestataire
///
/// Contient la notation, le commentaire et les informations
/// de l'auteur de l'avis.
class ReviewModel {
  final String id;
  final String authorName;
  final String authorAvatar;
  final double rating;
  final DateTime date;
  final String comment;

  const ReviewModel({
    required this.id,
    required this.authorName,
    required this.authorAvatar,
    required this.rating,
    required this.date,
    required this.comment,
  });

  /// Construit depuis une évaluation Django
  /// (`{id, client_prenom, client_nom, note, commentaire, date_evaluation}`).
  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    final first = json['client_prenom']?.toString() ?? '';
    final last = json['client_nom']?.toString() ?? '';
    return ReviewModel(
      id: json['id'].toString(),
      authorName: '$first $last'.trim(),
      authorAvatar: '',
      rating: (json['note'] as num?)?.toDouble() ?? 0,
      date: DateTime.tryParse(json['date_evaluation']?.toString() ?? '') ??
          DateTime.now(),
      comment: json['commentaire']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author_name': authorName,
      'author_avatar': authorAvatar,
      'rating': rating,
      'date': date.toIso8601String(),
      'comment': comment,
    };
  }
}
