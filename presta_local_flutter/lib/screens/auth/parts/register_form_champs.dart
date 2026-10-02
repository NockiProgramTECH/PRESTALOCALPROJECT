part of '../login_screen.dart';

mixin _RegisterScreenChamps on ConsumerState<RegisterScreen> {
  bool get _hasIdDocument;
  set _hasIdDocument(bool value);
  bool get _acceptCgu;
  set _acceptCgu(bool value);

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
}
