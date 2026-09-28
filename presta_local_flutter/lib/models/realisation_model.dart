import '../utils/media.dart';

/// Modèle représentant une réalisation / photo d'un prestataire
///
/// Correspond aux photos des travaux effectués par le prestataire
/// dans sa galerie de réalisations.
class RealisationModel {
  final String id;
  final String imageUrl;
  final String title;

  const RealisationModel({
    required this.id,
    required this.imageUrl,
    required this.title,
  });

  /// Construit depuis la réponse Django (`{id, titre, image, date_ajout}`).
  factory RealisationModel.fromJson(Map<String, dynamic> json) {
    return RealisationModel(
      id: json['id'].toString(),
      // `image_url` (absolue) est renvoyée par l'API ; `image` reste le
      // chemin relatif historique — resolveMediaUrl gère les deux cas.
      imageUrl: resolveMediaUrl(
        (json['image_url'] ?? json['image'])?.toString(),
      ),
      title: json['titre']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'image_url': imageUrl,
      'title': title,
    };
  }
}
