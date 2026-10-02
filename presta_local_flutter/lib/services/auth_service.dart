import 'dart:typed_data';

import 'api_client.dart';

/// Représente le profil de l'utilisateur connecté (retourné par `/auth/me/`).
class AuthUser {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? telephone;
  final String role;
  final String? bio;
  final String? photoProfilUrl;
  final int? villeId;
  final String? villeNom;
  final int? metierId;
  final String? metierNom;
  final int anneeExperience;
  final String? quartier;
  final bool isAvailable;
  /// Vrai quand les informations indispensables au rôle sont renseignées
  /// (prestataire : métier + ville + quartier ; client : prénom + nom).
  final bool profileCompleted;

  const AuthUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.telephone,
    required this.role,
    this.bio,
    this.photoProfilUrl,
    this.villeId,
    this.villeNom,
    this.metierId,
    this.metierNom,
    this.anneeExperience = 0,
    this.quartier,
    this.isAvailable = true,
    this.profileCompleted = false,
  });

  String get fullName => '$firstName $lastName'.trim();
  bool get isProvider => role == 'prestataire';

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'].toString(),
      email: json['email']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      telephone: json['telephone']?.toString(),
      role: json['role']?.toString() ?? 'client',
      bio: json['bio']?.toString(),
      photoProfilUrl: json['photo_profil_url']?.toString(),
      villeId: json['ville'] is int ? json['ville'] as int : null,
      villeNom: json['ville_nom']?.toString(),
      metierId: json['metier'] is int ? json['metier'] as int : null,
      metierNom: json['metier_nom']?.toString(),
      anneeExperience:
          json['annee_experience'] is int ? json['annee_experience'] as int : 0,
      quartier: json['quartier']?.toString(),
      isAvailable: json['is_available'] == true,
      profileCompleted: json['profile_completed'] == true,
    );
  }
}

/// Option d'une liste (ville / métier) pour les menus déroulants du profil.
class ListOption {
  final int id;
  final String nom;

  const ListOption({required this.id, required this.nom});

  factory ListOption.fromJson(Map<String, dynamic> json) {
    return ListOption(
      id: json['id'] is int ? json['id'] as int : int.parse('${json['id']}'),
      nom: json['nom']?.toString() ?? '',
    );
  }
}

/// Service d'authentification connecté à l'API Django.
///
/// Remplace l'ancien service en mode simulation. Toutes les opérations
/// (login, logout, reset de mot de passe, profil) passent par [ApiClient].
class AuthService {
  final ApiClient _api = ApiClient();

  AuthUser? _currentUser;

  // ---- Getters ----

  AuthUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isProvider => _currentUser?.isProvider ?? false;
  String? get currentUserId => _currentUser?.id;
  String? get currentUserName => _currentUser?.fullName;
  String? get currentUserEmail => _currentUser?.email;
  String? get currentUserPhone => _currentUser?.telephone;

  /// Connexion avec email + mot de passe.
  ///
  /// Obtient un JWT via `/api/auth/token/` puis charge le profil via
  /// `/api/auth/me/`.
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    final tokenData = await _api.post(
      '/api/auth/token/',
      body: {'email': email.trim(), 'password': password},
      authenticated: false,
    );
    final access = tokenData['access'] as String;
    final refresh = tokenData['refresh'] as String;
    await _api.saveTokens(access: access, refresh: refresh);

    _currentUser = await fetchProfile();
    return true;
  }

  /// Déconnexion : révoque le refresh token côté serveur puis nettoie
  /// les tokens locaux.
  Future<void> logout() async {
    final refresh = await _api.getRefreshToken();
    if (refresh != null) {
      try {
        await _api.post(
          '/api/auth/token/logout/',
          body: {'refresh': refresh},
        );
      } catch (_) {
        // La révocation serveur échoue : on nettoie quand même côté local.
      }
    }
    await _api.clearTokens();
    _currentUser = null;
  }

  /// Vérifie si une session est encore valide (au démarrage de l'app).
  ///
  /// Si des tokens existent, recharge le profil ; sinon retourne `false`.
  Future<bool> checkSession() async {
    if (!await _api.hasTokens()) {
      return false;
    }
    try {
      _currentUser = await fetchProfile();
      return true;
    } catch (_) {
      await _api.clearTokens();
      _currentUser = null;
      return false;
    }
  }

  /// Charge le profil de l'utilisateur connecté depuis `/api/auth/me/`.
  Future<AuthUser> fetchProfile() async {
    final data = await _api.get('/api/auth/me/');
    _currentUser = AuthUser.fromJson(data);
    return _currentUser!;
  }

  /// Met à jour le profil (champs textuels) via PATCH `/api/auth/me/`.
  Future<AuthUser> updateProfile({
    String? firstName,
    String? lastName,
    String? telephone,
    String? bio,
    String? quartier,
    int? villeId,
    int? metierId,
    int? anneeExperience,
  }) async {
    final body = <String, dynamic>{
      'first_name': ?firstName,
      'last_name': ?lastName,
      'telephone': ?telephone,
      'bio': ?bio,
      'quartier': ?quartier,
      'ville': ?villeId,
      'metier': ?metierId,
      'annee_experience': ?anneeExperience,
    };
    final data = await _api.patch('/api/auth/me/', body: body);
    _currentUser = AuthUser.fromJson(data);
    return _currentUser!;
  }

  /// Upload de la photo de profil (multipart) via PATCH `/api/auth/me/`.
  Future<AuthUser> updatePhoto(
    Uint8List bytes, {
    required String filename,
  }) async {
    final data = await _api.patchMultipart(
      '/api/auth/me/',
      fileBytes: bytes,
      filename: filename,
      fileField: 'photo_profil',
    );
    _currentUser = AuthUser.fromJson(data);
    return _currentUser!;
  }

  /// Liste des villes pour le menu déroulant du profil.
  Future<List<ListOption>> fetchVilles() async {
    final data = await _api.get('/api/villes/');
    return _parseList(data);
  }

  /// Liste des métiers/prestations pour le menu déroulant du profil.
  Future<List<ListOption>> fetchMetiers() async {
    final data = await _api.get('/api/prestations/');
    return _parseList(data);
  }

  List<ListOption> _parseList(Map<String, dynamic> data) {
    // L'API pagine les listes sous la clé "results".
    final raw = data['results'] as List? ?? [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(ListOption.fromJson)
        .toList();
  }

  /// Demande l'envoi d'un code de réinitialisation par email.
  Future<void> requestPasswordReset(String email) async {
    await _api.post(
      '/api/auth/password-reset/',
      body: {'email': email.trim()},
      authenticated: false,
    );
  }

  /// Confirme la réinitialisation avec le code reçu et le nouveau mot de passe.
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _api.post(
      '/api/auth/password-reset/confirm/',
      body: {
        'email': email.trim(),
        'code': code.trim(),
        'new_password': newPassword,
      },
      authenticated: false,
    );
  }

  /// Inscription : crée un compte inactif et envoie un code de vérification
  /// par email. Le compte ne devient actif qu'après [verifyEmail].
  Future<void> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? telephone,
    bool asProvider = false,
  }) async {
    await _api.post(
      '/api/auth/register/',
      body: {
        'email': email.trim(),
        'password': password,
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'telephone': telephone?.trim() ?? '',
        'role': asProvider ? 'prestataire' : 'client',
      },
      authenticated: false,
    );
  }

  /// Vérifie l'email avec le code reçu pour activer le compte.
  ///
  /// Le backend connecte l'utilisateur immédiatement : la réponse contient
  /// les jetons JWT et le profil. Ils sont enregistrés ici, ce qui évite de
  /// redemander les identifiants juste après l'inscription.
  ///
  /// Retourne l'utilisateur authentifié.
  Future<AuthUser> verifyEmail({
    required String email,
    required String code,
  }) async {
    final data = await _api.post(
      '/api/auth/verify-email/',
      body: {'email': email.trim(), 'code': code.trim()},
      authenticated: false,
    );
    final access = data['access'] as String?;
    final refresh = data['refresh'] as String?;
    if (access == null || refresh == null) {
      // Réponse d'un ancien backend (simple message) : on ne peut pas
      // connecter automatiquement, l'appelant devra se rabattre sur le login.
      throw ApiException(
        "Connexion automatique impossible : vérifiez votre email puis connectez-vous.",
      );
    }
    await _api.saveTokens(access: access, refresh: refresh);

    final userJson = data['user'];
    if (userJson is Map) {
      _currentUser = AuthUser.fromJson(userJson.cast<String, dynamic>());
      return _currentUser!;
    }
    // Repli : le profil n'était pas dans la réponse, on le récupère.
    final user = await fetchProfile();
    _currentUser = user;
    return user;
  }
}
