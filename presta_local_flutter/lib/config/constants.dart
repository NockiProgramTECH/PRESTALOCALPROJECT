/// Constantes globales de l'application PrestA Local
///
/// Contient les chaînes de caractères, URLs, et configurations
/// utilisées à travers toute l'application.
class AppConstants {
  AppConstants._();

  // ---- Informations générales ----
  static const String appName = 'PrestA Local';
  static const String appTagline = 'Trouvez les meilleurs prestataires locaux autour de vous';
  static const String appLocation = 'Ouagadougou, Burkina Faso';
  static const String appCurrency = 'CFA';

  // ---- URLs (à configurer selon l'environnement) ----
  // IP LAN de la machine de dev (backend Django). Pour un émulateur Android
  // utiliser 10.0.2.2, pour le web/desktop 127.0.0.1.
  static const String baseUrl = 'http://192.168.1.67:8000';
  // static const String baseUrl = 'https://prestalocal.onrender.com';
  // static const String assetBaseUrl = 'https://prestalocal.onrender.com';
  static const String assetBaseUrl = 'http://192.168.1.67:8000';

  // ---- Zones géographiques (Ouagadougou) ----
  static const List<String> zones = [
    'Toutes les zones',
    'Zone 1',
    'Zone 2',
    'Zone 3',
    'Zone 4',
    'Zone 5',
    'Ouaga 2000',
    'Secteur 15',
    'Secteur 20',
    'Secteur 25',
    'Centre',
    'Pissy',
    'Karpala',
    'Dassasgho',
    'Cissin',
  ];

  // ---- Catégories par défaut ----
  static const List<Map<String, String>> defaultCategories = [
    {'name': 'Tous', 'icon': 'apps'},
    {'name': 'Plomberie', 'icon': 'plumbing'},
    {'name': 'Électricité', 'icon': 'electrical_services'},
    {'name': 'Coiffure & Beauté', 'icon': 'content_cut'},
    {'name': 'Développement', 'icon': 'code'},
    {'name': 'Réparation', 'icon': 'handyman'},
    {'name': 'Maçonnerie', 'icon': 'construction'},
    {'name': 'Nettoyage', 'icon': 'cleaning_services'},
    {'name': 'Transport', 'icon': 'local_shipping'},
    {'name': 'Santé', 'icon': 'local_hospital'},
    {'name': 'Cours & Formation', 'icon': 'school'},
    {'name': 'Photographie', 'icon': 'camera_alt'},
  ];

  // ---- Messages d'erreur ----
  static const String errorNetwork = 'Erreur réseau. Veuillez vérifier votre connexion.';
  static const String errorServer = 'Erreur serveur. Veuillez réessayer plus tard.';
  static const String errorUnknown = 'Une erreur inattendue est survenue.';
  static const String errorEmptySearch = 'Aucun résultat trouvé.';
  static const String errorLoading = 'Erreur lors du chargement des données.';

  // ---- Messages de succès ----
  static const String successRegister = 'Inscription réussie ! Bienvenue sur PrestA Local.';
  static const String successMessage = 'Message envoyé avec succès.';
  static const String successFavoriteAdded = 'Ajouté aux favoris.';
  static const String successFavoriteRemoved = 'Retiré des favoris.';

  /// Formate un montant selon la spec design : `12 500 FCFA`
  /// (espaces insécables fines entre milliers).
  static String formatFcfa(num value) {
    final rounded = value.round();
    final digits = rounded.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('\u202f');
      buffer.write(digits[i]);
    }
    return '${rounded < 0 ? '-' : ''}${buffer}FCFA'.replaceFirst(
      'FCFA',
      '\u202fFCFA',
    );
  }
}
