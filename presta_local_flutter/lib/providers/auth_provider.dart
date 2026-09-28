import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';

/// ---------------------------------------------------------------------------
/// Provider d'authentification
///
/// Gère l'état de connexion de l'utilisateur (connecté/déconnecté)
/// et les opérations d'authentification via l'API réelle.
/// ---------------------------------------------------------------------------

/// Instance unique du service d'authentification
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// État de l'authentification exposé aux widgets
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final service = ref.watch(authServiceProvider);
  return AuthNotifier(service);
});

/// États possibles de l'authentification
enum AuthStatus { initial, authenticated, unauthenticated, loading }

/// État complet de l'authentification
class AuthState {
  final AuthStatus status;
  final String? userId;
  final String? userName;
  final String? userEmail;
  final String? userPhone;
  final String? role;
  final bool isProvider;
  final String? userPhoto;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.userId,
    this.userName,
    this.userEmail,
    this.userPhone,
    this.role,
    this.isProvider = false,
    this.userPhoto,
    this.errorMessage,
  });

  /// Factory pour l'état initial
  factory AuthState.initial() => const AuthState();

  /// Factory pour l'état connecté à partir d'un [AuthUser].
  factory AuthState.authenticated(AuthUser user) {
    return AuthState(
      status: AuthStatus.authenticated,
      userId: user.id,
      userName: user.fullName,
      userEmail: user.email,
      userPhone: user.telephone,
      role: user.role,
      isProvider: user.isProvider,
      userPhoto: user.photoProfilUrl,
    );
  }

  /// Factory pour l'état déconnecté
  factory AuthState.unauthenticated({String? error}) {
    return AuthState(
      status: AuthStatus.unauthenticated,
      errorMessage: error,
    );
  }

  /// Factory pour l'état de chargement
  factory AuthState.loading() => const AuthState(status: AuthStatus.loading);
}

/// Notifier qui gère les opérations d'authentification
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(AuthState.initial());

  /// Restaure la session au démarrage de l'app.
  ///
  /// Ne bloque jamais le démarrage : si `checkSession` pend (réseau mort,
  /// backend endormi), on bascule sur non-connecté après 10 s au lieu de
  /// rester figé sur le SplashScreen.
  Future<void> initialize() async {
    state = AuthState.loading();
    try {
      final ok = await _authService
          .checkSession()
          .timeout(const Duration(seconds: 10));
      final user = _authService.currentUser;
      state = ok && user != null
          ? AuthState.authenticated(user)
          : AuthState.unauthenticated();
    } catch (_) {
      state = AuthState.unauthenticated();
    }
  }

  /// Connecte l'utilisateur avec email + mot de passe.
  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = AuthState.loading();
    try {
      await _authService.login(email: email, password: password);
      final user = _authService.currentUser!;
      state = AuthState.authenticated(user);
    } catch (e) {
      state = AuthState.unauthenticated(
        error: e is ApiException ? e.message : e.toString(),
      );
    }
  }

  /// Inscription : crée le compte (inactif) et envoie le code de vérification.
  ///
  /// Ne connecte pas l'utilisateur : il doit d'abord vérifier son email via
  /// [verifyEmail], puis se connecter.
  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? phone,
    bool asProvider = false,
  }) async {
    await _authService.register(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      telephone: phone,
      asProvider: asProvider,
    );
  }

  /// Vérifie l'email avec le code reçu pour activer le compte.
  Future<void> verifyEmail({
    required String email,
    required String code,
  }) async {
    await _authService.verifyEmail(email: email, code: code);
  }

  /// Déconnecte l'utilisateur (révocation serveur + nettoyage local).
  Future<void> logout() async {
    await _authService.logout();
    state = AuthState.unauthenticated();
  }

  /// Demande l'envoi d'un code de réinitialisation par email.
  Future<void> requestPasswordReset(String email) {
    return _authService.requestPasswordReset(email);
  }

  /// Confirme la réinitialisation du mot de passe.
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) {
    return _authService.confirmPasswordReset(
      email: email,
      code: code,
      newPassword: newPassword,
    );
  }

  /// Met à jour le profil et rafraîchit l'état.
  Future<void> updateProfile({
    String? firstName,
    String? lastName,
    String? telephone,
    String? bio,
    String? quartier,
    int? villeId,
    int? metierId,
    int? anneeExperience,
  }) async {
    final user = await _authService.updateProfile(
      firstName: firstName,
      lastName: lastName,
      telephone: telephone,
      bio: bio,
      quartier: quartier,
      villeId: villeId,
      metierId: metierId,
      anneeExperience: anneeExperience,
    );
    if (state.status == AuthStatus.authenticated) {
      state = AuthState.authenticated(user);
    }
  }

  /// Upload de la photo de profil et rafraîchit l'état.
  Future<void> updatePhoto(
    Uint8List bytes, {
    required String filename,
  }) async {
    final user = await _authService.updatePhoto(bytes, filename: filename);
    if (state.status == AuthStatus.authenticated) {
      state = AuthState.authenticated(user);
    }
  }
}
