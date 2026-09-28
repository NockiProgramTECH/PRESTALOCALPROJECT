/// Modèle représentant une catégorie de service
///
/// Chaque catégorie regroupe des prestataires offrant des services similaires
/// (ex: Plomberie, Électricité, Coiffure, etc.)
class CategoryModel {
  final String id;
  final String name;
  final String icon; // Nom de l'icône Material
  final String description;
  final int providerCount;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    this.providerCount = 0,
  });

  /// Crée une instance à partir d'un JSON (future API)
  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String,
      description: json['description'] as String,
      providerCount: (json['provider_count'] as int?) ?? 0,
    );
  }

  /// Convertit l'instance en JSON (pour envoi à l'API)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'description': description,
      'provider_count': providerCount,
    };
  }
}
