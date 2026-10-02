part of '../login_screen.dart';

mixin _LoginScreenActions on ConsumerState<LoginScreen> {
  GlobalKey<FormState> get _formKey;
  bool get _byPhone;

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    if (_byPhone) {
      // Le backend n'accepte que l'email pour l'instant.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connexion par téléphone — Bientôt disponible'),
        ),
      );
      return;
    }
    await ref
        .read(authProvider.notifier)
        .login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
    if (!mounted || ref.read(authProvider).status != AuthStatus.authenticated) {
      return;
    }

    final navigator = Navigator.of(context);
    final user = ref.read(authServiceProvider).currentUser;

    // L'écran racine (AuthGate) affiche désormais l'interface connectée ;
    // on dépile les écrans d'authentification empilés par-dessus pour que le
    // changement soit visible tout de suite (sans quoi la page reste figée
    // sur le formulaire de connexion).
    popAuthRoutes(navigator);

    // Un prestataire dont le profil est incomplet ne peut pas être trouvé par
    // les clients : on l'amène directement à la configuration de son profil.
    if (user != null && user.isProvider && !user.profileCompleted) {
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => const ProfileEditScreen(onboarding: true),
        ),
      );
    }
  }

  void _openPasswordReset() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PasswordResetScreen()),
    );
  }

  void _soon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature — Bientôt disponible')),
    );
  }
}
