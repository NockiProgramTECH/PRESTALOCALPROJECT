part of '../login_screen.dart';

mixin _LoginScreenChamps on ConsumerState<LoginScreen> {
  TextEditingController get _emailController;
  TextEditingController get _phoneController;
  TextEditingController get _passwordController;
  bool get _obscurePassword;
  set _obscurePassword(bool value);
  bool get _byPhone;
  set _byPhone(bool value);
  void _openPasswordReset();
  void _soon(String feature);

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
}
