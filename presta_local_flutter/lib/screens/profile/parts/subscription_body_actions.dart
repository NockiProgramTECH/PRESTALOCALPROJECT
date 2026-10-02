part of '../subscription_screen.dart';

mixin _SubscriptionActions on ConsumerState<SubscriptionScreen> {
  bool get _loading;
  set _loading(bool value);
  String? get _error;
  set _error(String? value);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final service = ref.read(subscriptionServiceProvider);
    try {
      final plans = await service.fetchPlans();
      AbonnementStatut? statut;
      try {
        statut = await service.fetchStatut();
      } catch (_) {
        // Un client (ou un compte sans abonnement) n'a pas d'état : on garde
        // simplement null et l'écran affiche les offres.
        statut = null;
      }
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _statut = statut;
        _selectedPlanId ??= plans.isNotEmpty ? plans.first.id : null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Impossible de charger les offres. Vérifiez votre connexion.';
      });
    }
  }

  /// Ouvre la page d'abonnement du site web dans le navigateur.
  Future<void> _ouvrirSiteWeb() async {
    final uri = Uri.parse(AppConstants.subscriptionWebUrl);
    final ouvert = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ouvert && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Site web : ${AppConstants.webBaseUrl}')),
      );
    }
  }

  /// Ouvre la feuille de paiement : opérateur Mobile Money → code OTP.
  Future<void> _payer(PlanAbonnement plan) async {
    final paye = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PaymentSheet(plan: plan),
    );

    if (paye == true && mounted) {
      // Le profil change (abonnement actif, badge, mise en avant) : on le
      // recharge pour que l'interface se mette à jour immédiatement.
      try {
        await ref.read(authProvider.notifier).refreshProfile();
      } catch (_) {
        // Rafraîchissement facultatif : l'écran affiche déjà le nouvel état.
      }
      await _load();
    }
  }
}
