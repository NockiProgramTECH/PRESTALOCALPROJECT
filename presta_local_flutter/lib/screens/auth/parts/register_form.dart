part of '../login_screen.dart';

class _RegisterScreenState extends ConsumerState<RegisterScreen> with _RegisterScreenEtapes, _RegisterScreenChamps, _RegisterScreenActions {
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
  }  @override
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
  }}

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
