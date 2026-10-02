part of '../login_screen.dart';

mixin _RegisterScreenActions on ConsumerState<RegisterScreen> {
  GlobalKey<FormState> get _formKey;
  TextEditingController get _emailController;
  TextEditingController get _codeController;
  bool get _acceptCgu;
  bool get _loading;
  set _loading(bool value);
  String? get _error;
  set _error(String? value);

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptCgu) {
      setState(
        () => _error = 'Veuillez accepter les Conditions Générales.',
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    // La maquette demande un nom complet unique : on le découpe pour l'API.
    final parts = _fullNameController.text.trim().split(RegExp(r'\s+'));
    final firstName = parts.first;
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : parts.first;
    // Conservé pour la connexion automatique après vérification du code.
    _pendingPassword = _passwordController.text;
    try {
      await ref
          .read(authProvider.notifier)
          .register(
            firstName: firstName,
            lastName: lastName,
            email: _emailController.text.trim(),
            password: _passwordController.text,
            phone: _phoneController.text.trim(),
            asProvider: _asProvider,
          );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _stepForm = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyError(e);
      });
    }
  }

  Future<void> _handleVerify() async {
    if (_codeController.text.trim().length != 6) {
      setState(() => _error = 'Entrez le code à 6 chiffres.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // La vérification du code active le compte **et** connecte
      // l'utilisateur (l'API renvoie les jetons JWT) : plus besoin de le
      // renvoyer vers l'écran de connexion.
      AuthUser user;
      try {
        user = await ref
            .read(authProvider.notifier)
            .verifyEmailAndLogin(
              email: _emailController.text.trim(),
              code: _codeController.text.trim(),
            );
      } on ApiException catch (error) {
        // Repli pour un backend qui n'activerait le compte qu'en renvoyant un
        // simple message (sans jetons) : on se connecte avec les identifiants
        // saisis à l'étape 1. Les autres erreurs (code invalide…) remontent.
        final password = _pendingPassword;
        if (password == null ||
            !error.message.contains('Connexion automatique impossible')) {
          rethrow;
        }
        await ref.read(authProvider.notifier).login(
              email: _emailController.text.trim(),
              password: password,
            );
        final connected = ref.read(authServiceProvider).currentUser;
        if (ref.read(authProvider).status != AuthStatus.authenticated ||
            connected == null) {
          rethrow;
        }
        user = connected;
      }
      if (!mounted) return;

      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);

      // Retour à la racine : AuthGate affiche l'interface connectée.
      popAuthRoutes(navigator);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            user.isProvider
                ? 'Compte créé ! Dernière étape : configurez votre profil.'
                : 'Email vérifié. Bienvenue sur LesProduFao !',
          ),
        ),
      );

      // Le mot de passe n'a plus besoin de rester en mémoire.
      _pendingPassword = null;

      // Un prestataire doit configurer son profil pour être visible.
      if (user.isProvider) {
        await navigator.push(
          MaterialPageRoute(
            builder: (_) => const ProfileEditScreen(onboarding: true),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyError(e);
      });
    }
  }

  /// Revient à l'écran de connexion : on dépile l'inscription si elle a été
  /// ouverte depuis la connexion, sinon on la pousse.
  void _backToLogin() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.push(authRoute((_) => const LoginScreen()));
  }

  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('ApiException')) return 'Une erreur est survenue.';
    return s;
  }
}
