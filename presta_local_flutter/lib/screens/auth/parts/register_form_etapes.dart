part of '../login_screen.dart';

mixin _RegisterScreenEtapes on ConsumerState<RegisterScreen> {
  TextEditingController get _fullNameController;
  TextEditingController get _emailController;
  TextEditingController get _phoneController;
  TextEditingController get _passwordController;
  TextEditingController get _confirmController;
  TextEditingController get _codeController;
  bool get _asProvider;
  set _asProvider(bool value);
  bool get _obscurePassword;
  set _obscurePassword(bool value);
  bool get _obscureConfirm;
  set _obscureConfirm(bool value);
  String get _zone;
  set _zone(String value);
  bool get _loading;
  String? get _error;
  List<String> get _zones;
  Future<void> _handleRegister();
  Future<void> _handleVerify();
  void _backToLogin();
  Widget _label(String text);
  Widget _roleCard({ required bool selected, required IconData icon, required Color iconBg, required Color iconColor, required String title, required String subtitle, required VoidCallback onTap, });
  Widget _proofCard();
  Widget _idCard();
  Widget _cguRow();

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
