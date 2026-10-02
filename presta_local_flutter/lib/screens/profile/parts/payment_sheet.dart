part of '../subscription_screen.dart';

/// ============================================================================
/// Paiement Mobile Money : opérateur puis code OTP (paiement simulé)
/// ============================================================================
class _PaymentSheet extends ConsumerStatefulWidget {
  final PlanAbonnement plan;

  const _PaymentSheet({required this.plan});

  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  final _otpController = TextEditingController();

  String? _operateur;
  bool _envoi = false;
  String? _error;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _confirmer() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Entrez le code à 6 chiffres reçu par SMS.');
      return;
    }
    setState(() {
      _envoi = true;
      _error = null;
    });
    try {
      await ref.read(subscriptionServiceProvider).souscrire(
            planId: widget.plan.id,
            methode: _operateur!,
            otp: otp,
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _envoi = false;
        _error = e is Exception
            ? e.toString().replaceFirst('Exception: ', '')
            : 'Paiement refusé. Réessayez.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + keyboard),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.cardBorder,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _operateur == null ? 'Mode de paiement' : 'Confirmation Mobile Money',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppTheme.navy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.plan.nom} · ${widget.plan.prixLibelle}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryPressed,
            ),
          ),
          const SizedBox(height: 16),
          if (_operateur == null) ..._operateurs() else ..._otp(),
        ],
      ),
    );
  }

  /// Étape 1 : choix de l'opérateur.
  List<Widget> _operateurs() {
    return [
      for (final operateur in kMobileMoneyOperateurs)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _operateur = operateur),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppTheme.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.smartphone_rounded,
                      size: 20,
                      color: AppTheme.primaryPressed,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      operateur,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.navy,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.muted,
                  ),
                ],
              ),
            ),
          ),
        ),
      const SizedBox(height: 4),
      const Text(
        'Un code de confirmation vous sera demandé (paiement simulé).',
        style: TextStyle(fontSize: 11.5, color: AppTheme.muted),
      ),
    ];
  }

  /// Étape 2 : saisie du code OTP à 6 chiffres.
  List<Widget> _otp() {
    return [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.primarySoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: AppTheme.primaryPressed,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Composez le code reçu au nom de $_operateur pour '
                '${widget.plan.prixLibelle}.',
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  color: AppTheme.navy,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _otpController,
        keyboardType: TextInputType.number,
        maxLength: 6,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: 8,
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          hintText: '000000',
          counterText: '',
          labelText: 'Code de confirmation (6 chiffres)',
        ),
      ),
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12.5, color: AppTheme.danger),
        ),
      ],
      const SizedBox(height: 16),
      ElevatedButton(
        onPressed: _envoi ? null : _confirmer,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _envoi
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                'Payer ${widget.plan.prixLibelle}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
      const SizedBox(height: 6),
      TextButton(
        onPressed: _envoi ? null : () => setState(() => _operateur = null),
        child: const Text('Changer d\'opérateur'),
      ),
    ];
  }
}
