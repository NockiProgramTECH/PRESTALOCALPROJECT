import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../widgets/brand_mark.dart';
import '../../navigation/auth_navigation.dart';
import '../profile/profile_edit_screen.dart';
import 'password_reset_screen.dart';

/// Écran de connexion (maquette « connexion_lesprodufao »).
///
/// Deux modes : Téléphone (+226, visuel pour l'instant) et Email
/// (fonctionnel, JWT). Le reste (OTP, Google/Apple) est annoncé
/// « bientôt disponible ».
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _byPhone = true;

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _wordmark(canPop),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              child: Column(
                children: [
                  _heroCard(),
                  const SizedBox(height: 14),
                  _formCard(authState),
                  const SizedBox(height: 18),
                  _divider(),
                  const SizedBox(height: 14),
                  _socialRow(),
                  const SizedBox(height: 14),
                  _secureNote(),
                  const SizedBox(height: 22),
                  _footer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Barre : retour + wordmark centré.
  Widget _wordmark(bool canPop) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
        child: Row(
          children: [
            if (canPop)
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppTheme.navy,
                ),
                onPressed: () => Navigator.of(context).pop(),
              )
            else
              const SizedBox(width: 48),
            const Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  BrandMark(size: 26, radius: 8, iconSize: 14),
                  SizedBox(width: 8),
                  Text(
                    'LesProduFao',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.navy,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  /// Carte hero pêche : pastille, titre, sous-titre.
  Widget _heroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primarySoft.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 9, color: AppTheme.success),
                SizedBox(width: 6),
                Text(
                  'Plateforme locale certifiée',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryPressed,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Bon retour parmi nous 👋',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppTheme.navy,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Connectez-vous pour gérer vos demandes et services locaux au Burkina Faso.',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.navy,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Carte blanche : toggle Téléphone/Email + champs + actions.
  Widget _formCard(AuthState authState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _modeToggle(),
            const SizedBox(height: 16),
            if (_byPhone) ..._phoneFields() else ..._emailFields(),
            const SizedBox(height: 8),
            _passwordField(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: authState.status == AuthStatus.loading
                    ? null
                    : _handleLogin,
                child: authState.status == AuthStatus.loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Se connecter', style: TextStyle(fontSize: 16)),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ),
              ),
            ),
            if (authState.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                authState.errorMessage!,
                style: const TextStyle(
                  color: AppTheme.danger,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _soon('Code OTP par SMS / WhatsApp'),
                icon: const Icon(
                  Icons.verified_user_outlined,
                  size: 20,
                  color: AppTheme.success,
                ),
                label: const Text(
                  'Recevoir un code OTP par SMS / WhatsApp',
                  style: TextStyle(fontSize: 13, color: AppTheme.navy),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppTheme.inputFill,
                  side: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sélecteur Téléphone / Email.
  Widget _modeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.inputFill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _modeOption(
            selected: _byPhone,
            icon: Icons.call_outlined,
            label: 'Téléphone (+226)',
            onTap: () => setState(() => _byPhone = true),
          ),
          _modeOption(
            selected: !_byPhone,
            icon: Icons.mail_outline_rounded,
            label: 'Email',
            onTap: () => setState(() => _byPhone = false),
          ),
        ],
      ),
    );
  }

  Widget _modeOption({
    required bool selected,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected ? AppTheme.cardShadow : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected
                    ? AppTheme.primaryPressed
                    : AppTheme.muted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppTheme.navy : AppTheme.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _phoneFields() {
    return [
      const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Numéro de mobile',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.navy,
            ),
          ),
          Text(
            'Orange / Moov / Telecel',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.success,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
            decoration: BoxDecoration(
              color: AppTheme.inputFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '🇧🇫 +226',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.navy,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: '70 12 34 56',
                suffixIcon: Icon(
                  Icons.phone_android_rounded,
                  color: AppTheme.muted,
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().length < 8) {
                  return 'Numéro invalide';
                }
                return null;
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      const Text(
        'Mot de passe',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppTheme.navy,
        ),
      ),
    ];
  }

  List<Widget> _emailFields() {
    return [
      const Text(
        'Adresse email',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppTheme.navy,
        ),
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        decoration: const InputDecoration(
          hintText: 'vous@exemple.com',
          prefixIcon: Icon(
            Icons.alternate_email_rounded,
            color: AppTheme.muted,
          ),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Veuillez entrer votre email';
          }
          if (!value.contains('@')) return 'Email invalide';
          return null;
        },
      ),
      const SizedBox(height: 14),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Mot de passe',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.navy,
            ),
          ),
          GestureDetector(
            onTap: _openPasswordReset,
            child: const Text(
              'Mot de passe oublié ?',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryPressed,
              ),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _passwordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          autofillHints: const [AutofillHints.password],
          decoration: InputDecoration(
            hintText: 'Votre code secret',
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppTheme.muted,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Veuillez entrer votre mot de passe';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _divider() {
    return const Row(
      children: [
        Expanded(child: Divider()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OU CONTINUER AVEC',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppTheme.muted,
            ),
          ),
        ),
        Expanded(child: Divider()),
      ],
    );
  }

  Widget _socialRow() {
    return Row(
      children: [
        Expanded(
          child: _socialButton('Google', () => _soon('Connexion Google')),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _socialButton('Apple', () => _soon('Connexion Apple')),
        ),
      ],
    );
  }

  Widget _socialButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.navy,
            ),
          ),
        ),
      ),
    );
  }

  Widget _secureNote() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.successSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined, size: 18, color: AppTheme.success),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Connexion sécurisée et données chiffrées',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.successText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Vous n'avez pas de compte ?  ",
          style: TextStyle(fontSize: 14, color: AppTheme.navy),
        ),
        GestureDetector(
          // `push` (et non `pushReplacement`) : après une inscription, l'écran
          // d'inscription est dépilé jusqu'à la racine et l'utilisateur est
          // connecté ; le retour simple ramène donc au formulaire de connexion.
          onTap: () => Navigator.of(context).push(
            authRoute((_) => const RegisterScreen()),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "S'inscrire",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryPressed,
                ),
              ),
              Icon(
                Icons.arrow_outward_rounded,
                size: 16,
                color: AppTheme.primaryPressed,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Écran d'inscription (maquette « inscription_lesprodufao »).
///
/// 2 étapes : formulaire (rôle, identité, zone, mot de passe) puis
/// vérification du code email. Le backend exige un email : le champ
/// est donc présent même s'il n'apparaît pas sur la maquette.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _codeController = TextEditingController();

  bool _asProvider = false;
  /// Mot de passe saisi à l'étape 1 : il sert à connecter l'utilisateur
  /// automatiquement dès que le code email est validé.
  String? _pendingPassword;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _hasIdDocument = false;
  bool _acceptCgu = false;

  String _zone = 'Ouaga 2000';

  // Étape 1 = formulaire, étape 2 = vérification du code.
  bool _stepForm = true;
  bool _loading = false;
  String? _error;

  List<String> get _zones =>
      AppConstants.zones.where((z) => z != 'Toutes les zones').toList();

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _codeController.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: SingleChildScrollView(
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
                child: Row(
                  children: [
                    if (canPop)
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppTheme.navy,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      )
                    else
                      const SizedBox(width: 48),
                    const Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          BrandMark(size: 26, radius: 8, iconSize: 14),
                          SizedBox(width: 8),
                          Text(
                            'LesProduFao',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.navy,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _stepForm
                      ? _buildFormStep()
                      : _buildVerifyStep(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFormStep() {
    return [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.success,
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 9, color: Colors.white),
            SizedBox(width: 6),
            Text(
              'Plateforme Certifiée 100% Locale',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'Rejoignez LesProduFao',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: AppTheme.navy,
          height: 1.2,
        ),
      ),
      const SizedBox(height: 6),
      const Text(
        'Trouvez un pro certifié ou développez votre clientèle en toute confiance à Ouagadougou.',
        style: TextStyle(fontSize: 13, color: AppTheme.navy, height: 1.5),
      ),
      const SizedBox(height: 16),
      const Text(
        'Vous souhaitez vous inscrire en tant que :',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppTheme.navy,
        ),
      ),
      const SizedBox(height: 10),
      _roleCard(
        selected: !_asProvider,
        icon: Icons.person_pin_circle_outlined,
        iconBg: AppTheme.inputFill,
        iconColor: AppTheme.navy,
        title: 'Je suis Client',
        subtitle:
            'Je cherche des artisans fiables et qualifiés pour mes projets et réparations.',
        onTap: () => setState(() => _asProvider = false),
      ),
      const SizedBox(height: 10),
      _roleCard(
        selected: _asProvider,
        icon: Icons.construction_rounded,
        iconBg: AppTheme.primary,
        iconColor: Colors.white,
        title: 'Je suis Prestataire',
        subtitle:
            'Je propose mon savoir-faire, je gère mes chantiers et booste mes revenus.',
        onTap: () => setState(() => _asProvider = true),
      ),
      const SizedBox(height: 12),
      _proofCard(),
      const SizedBox(height: 18),
      _label('Nom complet'),
      TextFormField(
        controller: _fullNameController,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          hintText: 'Ex: Salif Traoré',
          prefixIcon: Icon(Icons.badge_outlined, color: AppTheme.muted),
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) {
            return 'Veuillez entrer votre nom complet';
          }
          return null;
        },
      ),
      const SizedBox(height: 14),
      _label('Adresse email'),
      TextFormField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          hintText: 'vous@exemple.com',
          prefixIcon: Icon(
            Icons.alternate_email_rounded,
            color: AppTheme.muted,
          ),
        ),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Email requis';
          if (!v.contains('@')) return 'Email invalide';
          return null;
        },
      ),
      const SizedBox(height: 14),
      _label('Numéro de téléphone'),
      Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 15,
            ),
            decoration: BoxDecoration(
              color: AppTheme.inputFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '🇧🇫 +226',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.navy,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: '70 00 00 00',
                suffixIcon: Icon(
                  Icons.bolt_outlined,
                  color: AppTheme.success,
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().length < 8) {
                  return 'Numéro invalide';
                }
                return null;
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      _label('Quartier principal à Ouagadougou'),
      DropdownButtonFormField<String>(
        initialValue: _zone,
        decoration: const InputDecoration(
          prefixIcon: Icon(
            Icons.location_on_outlined,
            color: AppTheme.muted,
          ),
        ),
        items: _zones
            .map((z) => DropdownMenuItem(value: z, child: Text(z)))
            .toList(),
        onChanged: (v) => setState(() => _zone = v ?? _zone),
      ),
      const SizedBox(height: 14),
      _label('Mot de passe sécurisé'),
      TextFormField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        decoration: InputDecoration(
          hintText: '8 caractères minimum',
          prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.muted),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: AppTheme.muted,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        validator: (v) {
          if (v == null || v.length < 8) return 'Au moins 8 caractères';
          return null;
        },
      ),
      const SizedBox(height: 14),
      _label('Confirmer le mot de passe'),
      TextFormField(
        controller: _confirmController,
        obscureText: _obscureConfirm,
        decoration: InputDecoration(
          hintText: 'Répétez le mot de passe',
          prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.muted),
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirm
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: AppTheme.muted,
            ),
            onPressed: () =>
                setState(() => _obscureConfirm = !_obscureConfirm),
          ),
        ),
        validator: (v) {
          if (v != _passwordController.text) {
            return 'Les mots de passe ne correspondent pas';
          }
          return null;
        },
      ),
      const SizedBox(height: 14),
      _idCard(),
      const SizedBox(height: 12),
      _cguRow(),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(
          _error!,
          style: const TextStyle(color: AppTheme.danger, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ],
      const SizedBox(height: 14),
      ElevatedButton(
        onPressed: _loading ? null : _handleRegister,
        child: _loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Créer mon compte', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
      ),
      const SizedBox(height: 16),
      const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _MiniTrust(icon: Icons.lock_outline, label: 'Paiements\nsécurisés'),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Text('•', style: TextStyle(color: AppTheme.muted)),
          ),
          _MiniTrust(
            icon: Icons.verified_user_outlined,
            label: 'Artisans\naudités',
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Text('•', style: TextStyle(color: AppTheme.muted)),
          ),
          _MiniTrust(
            icon: Icons.support_agent_rounded,
            label: 'Support\nOuaga',
          ),
        ],
      ),
      const SizedBox(height: 18),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Vous avez déjà un compte ?  ',
            style: TextStyle(fontSize: 14, color: AppTheme.navy),
          ),
          GestureDetector(
            onTap: _backToLogin,
            child: const Text(
              'Se connecter',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryPressed,
              ),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppTheme.navy,
        ),
      ),
    );
  }

  /// Carte de choix de rôle (Client / Prestataire).
  Widget _roleCard({
    required bool selected,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primarySoft.withValues(alpha: 0.5) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.cardBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.navy,
                          ),
                        ),
                      ),
                      if (title.contains('Prestataire')) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.verified_rounded,
                          size: 16,
                          color: AppTheme.success,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.navy,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppTheme.primaryPressed : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? AppTheme.primaryPressed
                      : AppTheme.cardBorder,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  /// Preuve sociale (maquette).
  Widget _proofCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.handyman_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Plus de 1 200 artisans vérifiés',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navy,
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: AppTheme.primary,
                    ),
                    SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        '4.9/5 satisfaction client à Ouagadougou',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Carte verte « badge Vérifié » (visuel, non bloquant).
  Widget _idCard() {
    return GestureDetector(
      onTap: () => setState(() => _hasIdDocument = !_hasIdDocument),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.success,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _hasIdDocument ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: _hasIdDocument
                  ? const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: AppTheme.success,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 16,
                        color: Colors.white,
                      ),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Accélération du badge Vérifié',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    "J'ai un document d'identité burkinabè (CNIB / Passeport) ou un registre de commerce (RCCM) prêt pour vérification.",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cguRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _acceptCgu = !_acceptCgu),
          child: Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _acceptCgu ? AppTheme.primary : AppTheme.muted,
                width: 1.5,
              ),
              color: _acceptCgu ? AppTheme.primary : Colors.transparent,
            ),
            child: _acceptCgu
                ? const Icon(
                    Icons.check_rounded,
                    size: 15,
                    color: Colors.white,
                  )
                : null,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 13, color: AppTheme.navy, height: 1.5),
              children: [
                TextSpan(text: "J'accepte les "),
                TextSpan(
                  text: 'Conditions Générales',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryPressed,
                    decoration: TextDecoration.underline,
                  ),
                ),
                TextSpan(text: ' et la '),
                TextSpan(
                  text: 'Politique de Confidentialité',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryPressed,
                    decoration: TextDecoration.underline,
                  ),
                ),
                TextSpan(text: ' de LesProduFao.'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildVerifyStep() {
    return [
      const SizedBox(height: 24),
      Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: AppTheme.successSoft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Icon(
          Icons.mark_email_read_outlined,
          size: 44,
          color: AppTheme.success,
        ),
      ),
      const SizedBox(height: 16),
      const Text(
        'Vérifiez votre email',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: AppTheme.navy,
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 8),
      Text(
        'Un code de vérification a été envoyé à ${_emailController.text.trim()}. '
        'Saisissez-le pour activer votre compte.',
        style: const TextStyle(fontSize: 14, color: AppTheme.muted),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      TextFormField(
        controller: _codeController,
        decoration: const InputDecoration(
          hintText: 'Code à 6 chiffres',
          prefixIcon: Icon(Icons.pin_outlined, color: AppTheme.muted),
        ),
        keyboardType: TextInputType.number,
        maxLength: 6,
      ),
      const SizedBox(height: 16),
      if (_error != null) ...[
        Text(
          _error!,
          style: const TextStyle(color: AppTheme.danger, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
      ],
      ElevatedButton(
        onPressed: _loading ? null : _handleVerify,
        child: _loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text('Vérifier', style: TextStyle(fontSize: 16)),
      ),
    ];
  }
}

class _MiniTrust extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniTrust({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppTheme.success),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppTheme.navy,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}
