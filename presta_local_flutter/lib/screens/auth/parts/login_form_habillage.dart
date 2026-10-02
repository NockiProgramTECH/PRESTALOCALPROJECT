part of '../login_screen.dart';

mixin _LoginScreenHabillage on ConsumerState<LoginScreen> {
  GlobalKey<FormState> get _formKey;
  bool get _byPhone;
  Future<void> _handleLogin();
  void _soon(String feature);
  Widget _modeToggle();
  Widget _passwordField();

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
