import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

/// ---------------------------------------------------------------------------
/// Service d'abonnement (côté application)
///
/// Permet à un prestataire de consulter les offres, de suivre l'état de son
/// abonnement et de souscrire via Mobile Money (Orange Money, Moov Money,
/// Wave). Le paiement est simulé, exactement comme sur le site web : un code
/// OTP à 6 chiffres active immédiatement l'abonnement, qui met le profil en
/// avant dans les recherches.
/// ---------------------------------------------------------------------------

/// Offre d'abonnement proposée par la plateforme.
class PlanAbonnement {
  final int id;
  final String nom;
  final double prix;
  final int dureeJours;
  final String description;

  const PlanAbonnement({
    required this.id,
    required this.nom,
    required this.prix,
    required this.dureeJours,
    required this.description,
  });

  factory PlanAbonnement.fromJson(Map<String, dynamic> json) {
    return PlanAbonnement(
      id: json['id'] is int ? json['id'] as int : int.parse('${json['id']}'),
      nom: json['nom']?.toString() ?? '',
      prix: json['prix'] == null
          ? 0
          : double.tryParse('${json['prix']}') ?? 0,
      dureeJours: json['duree_jours'] is int
          ? json['duree_jours'] as int
          : int.tryParse('${json['duree_jours']}') ?? 0,
      description: json['description']?.toString() ?? '',
    );
  }

  /// Prix formaté : « 25 000 FCFA ».
  String get prixLibelle {
    final entier = prix.round();
    final texte = entier.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < texte.length; i++) {
      if (i > 0 && (texte.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(texte[i]);
    }
    return '$buffer FCFA';
  }

  /// Durée lisible : « 1 mois », « 6 mois », « 1 an ».
  String get dureeLibelle {
    if (dureeJours >= 365) return '1 an';
    if (dureeJours % 30 == 0) {
      final mois = dureeJours ~/ 30;
      return mois <= 1 ? '1 mois' : '$mois mois';
    }
    return '$dureeJours jours';
  }
}

/// Abonnement en cours d'un prestataire.
class Abonnement {
  final int id;
  final PlanAbonnement? plan;
  final DateTime? dateFin;
  final bool estValide;
  final int joursRestants;
  final String? transactionId;

  const Abonnement({
    required this.id,
    this.plan,
    this.dateFin,
    this.estValide = false,
    this.joursRestants = 0,
    this.transactionId,
  });

  factory Abonnement.fromJson(Map<String, dynamic> json) {
    final planJson = json['plan'];
    return Abonnement(
      id: json['id'] is int ? json['id'] as int : int.parse('${json['id']}'),
      plan: planJson is Map<String, dynamic>
          ? PlanAbonnement.fromJson(planJson)
          : null,
      dateFin: DateTime.tryParse('${json['date_fin']}'),
      estValide: json['est_valide'] == true,
      joursRestants: json['jours_restants'] is int
          ? json['jours_restants'] as int
          : 0,
      transactionId: json['transaction_id']?.toString(),
    );
  }

  /// « 28/11/2026 » (ou chaîne vide si inconnue).
  String get dateFinLibelle {
    final date = dateFin;
    if (date == null) return '';
    final jour = date.day.toString().padLeft(2, '0');
    final mois = date.month.toString().padLeft(2, '0');
    return '$jour/$mois/${date.year}';
  }
}

/// État complet : abonnement actif (ou non) + éventuel abonnement enregistré.
class AbonnementStatut {
  final bool actif;
  final Abonnement? abonnement;

  const AbonnementStatut({required this.actif, this.abonnement});

  factory AbonnementStatut.fromJson(Map<String, dynamic> json) {
    final jsonAbo = json['abonnement'];
    return AbonnementStatut(
      actif: json['actif'] == true,
      abonnement:
          jsonAbo is Map<String, dynamic> ? Abonnement.fromJson(jsonAbo) : null,
    );
  }
}

/// Opérateurs Mobile Money acceptés par l'API (simulation).
const List<String> kMobileMoneyOperateurs = [
  'Orange Money',
  'Moov Money',
  'Wave',
];

/// Service d'abonnement.
class SubscriptionService {
  final ApiClient _api = ApiClient();

  /// Offres disponibles (endpoint public, aucune authentification requise).
  Future<List<PlanAbonnement>> fetchPlans() async {
    final raw = await _api.getList('/api/abonnement/plans/', authenticated: false);
    return raw
        .whereType<Map<String, dynamic>>()
        .map(PlanAbonnement.fromJson)
        .toList();
  }

  /// État de l'abonnement du prestataire connecté.
  Future<AbonnementStatut> fetchStatut() async {
    final data = await _api.get('/api/abonnement/mon-abonnement/');
    return AbonnementStatut.fromJson(data);
  }

  /// Souscrit à une offre après saisie du code Mobile Money.
  ///
  /// Retourne le message de confirmation renvoyé par le serveur.
  Future<String> souscrire({
    required int planId,
    required String methode,
    required String otp,
  }) async {
    final data = await _api.post(
      '/api/abonnement/souscrire/',
      body: {'plan': planId, 'methode': methode, 'otp': otp.trim()},
    );
    return data['detail']?.toString() ??
        'Votre abonnement est maintenant actif.';
  }
}


/// Instance partagée du service d'abonnement (Riverpod).
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService();
});
