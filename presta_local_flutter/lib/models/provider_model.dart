import '../utils/media.dart';
import 'category_model.dart';
import 'realisation_model.dart';
import 'review_model.dart';

/// Modèle principal représentant un prestataire de service
///
/// Un prestataire peut être un plombier, électricien, coiffeur, développeur, etc.
/// Il possède un profil complet avec ses coordonnées, ses services,
/// ses réalisations et les avis de ses clients.
class ProviderModel {
  final String id;
  final String name;
  final String title; // Titre professionnel (ex: "Plombier professionnel")
  final CategoryModel category;
  final double rating;
  final int reviewCount;
  final String location;
  final String locationZone;
  final String avatar;
  final String banner;
  final String about;
  final int experienceYears; // Années d'expérience (API : `annee_experience`)
  final String priceText; // Texte affiché pour le prix (ex: "À partir de 5 000 CFA")
  final double? priceValue; // Valeur numérique du prix de base
  final List<String> services; // Liste des services proposés
  final List<RealisationModel> realisations; // Galerie de réalisations
  final List<ReviewModel> reviews; // Avis des clients
  final String phone;
  final String? whatsapp;
  final String? email;
  final bool isVerified;
  final bool isFeatured;
  /// Faux quand le prestataire n'a pas d'abonnement actif : sa fiche reste
  /// consultable (depuis une publication) mais ses coordonnées sont masquées.
  final bool contactDisponible;
  final bool isOnline;
  final DateTime? lastActive;

  const ProviderModel({
    required this.id,
    required this.name,
    required this.title,
    required this.category,
    required this.rating,
    required this.reviewCount,
    required this.location,
    required this.locationZone,
    required this.avatar,
    required this.banner,
    required this.about,
    this.experienceYears = 0,
    required this.priceText,
    this.priceValue,
    required this.services,
    required this.realisations,
    required this.reviews,
    required this.phone,
    this.whatsapp,
    this.email,
    this.isVerified = false,
    this.isFeatured = false,
    this.contactDisponible = true,
    this.isOnline = false,
    this.lastActive,
  });

  /// Calcule la distribution des notes (combien d'avis pour chaque étoile)
  Map<int, int> get ratingDistribution {
    final distribution = <int, int>{};
    for (var i = 1; i <= 5; i++) {
      distribution[i] = 0;
    }
    for (final review in reviews) {
      final star = review.rating.round();
      distribution[star] = (distribution[star] ?? 0) + 1;
    }
    return distribution;
  }

  /// Pourcentage d'avis positifs (4 étoiles et plus)
  double get positivityRate {
    if (reviews.isEmpty) return 0.0;
    final positive = reviews.where((r) => r.rating >= 4).length;
    return positive / reviews.length * 100;
  }

  /// Construit un [ProviderModel] à partir de la réponse de l'API Django
  /// (`GET /api/prestataire/` et `/api/prestataire/{id}/`).
  factory ProviderModel.fromJson(Map<String, dynamic> json) {
    final first = json['first_name']?.toString() ?? '';
    final last = json['last_name']?.toString() ?? '';
    final name = '$first $last'.trim();

    // `metier` est une chaîne dans la liste, un objet {nom} dans le détail.
    final metier = json['metier'];
    final String title;
    if (metier is String) {
      title = metier;
    } else if (metier is Map<String, dynamic>) {
      title = metier['nom']?.toString() ?? '';
    } else {
      title = '';
    }

    final realisations = (json['realisations'] as List<dynamic>? ?? [])
        .map((r) => RealisationModel.fromJson(r as Map<String, dynamic>))
        .toList();
    final reviews = (json['evaluations'] as List<dynamic>? ?? [])
        .map((r) => ReviewModel.fromJson(r as Map<String, dynamic>))
        .toList();

    return ProviderModel(
      id: json['id'].toString(),
      name: name,
      title: title,
      category: CategoryModel(
        id: '',
        name: title,
        icon: 'handyman',
        description: '',
      ),
      rating: (json['moyenne_etoile'] as num?)?.toDouble() ?? 0,
      reviewCount: (json['nombre_avis'] as num?)?.toInt() ?? 0,
      location: json['ville']?.toString() ?? '',
      locationZone: json['quartier']?.toString() ?? '',
      avatar: resolveMediaUrl(json['photo_profil']?.toString()),
      banner: realisations.isNotEmpty ? realisations.first.imageUrl : '',
      about: json['bio']?.toString() ?? '',
      experienceYears: (json['annee_experience'] as num?)?.toInt() ?? 0,
      priceText: '',
      priceValue: null,
      services: title.isNotEmpty ? [title] : const [],
      realisations: realisations,
      reviews: reviews,
      phone: json['telephone']?.toString() ?? '',
      whatsapp: null,
      email: json['email']?.toString(),
      isVerified: json['est_verifie'] == true,
      // `abonnement_actif` de l'API : abonnement payé, actif et non expiré.
      isFeatured: json['abonnement_actif'] == true,
      // Absent d'une ancienne réponse : on considère le contact disponible.
      contactDisponible: json['contact_disponible'] != false,
      isOnline: json['is_available'] == true,
      lastActive: null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'title': title,
      'category': category.toJson(),
      'rating': rating,
      'review_count': reviewCount,
      'location': location,
      'location_zone': locationZone,
      'avatar': avatar,
      'banner': banner,
      'about': about,
      'experience_years': experienceYears,
      'price_text': priceText,
      'price_value': priceValue,
      'services': services,
      'realisations': realisations.map((r) => r.toJson()).toList(),
      'reviews': reviews.map((r) => r.toJson()).toList(),
      'phone': phone,
      'whatsapp': whatsapp,
      'email': email,
      'is_verified': isVerified,
      'is_featured': isFeatured,
      'is_online': isOnline,
      'last_active': lastActive?.toIso8601String(),
    };
  }
}
