import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/subscription_service.dart';

/// ---------------------------------------------------------------------------
/// Écran « Abonnement » (prestataires)
///
/// Reprend le parcours du site web, entièrement dans l'application :
///  1. état de l'abonnement (actif ou non, échéance, jours restants) ;
///  2. bénéfices de la mise en avant ;
///  3. choix d'une offre ;
///  4. paiement Mobile Money simulé (opérateur puis code OTP à 6 chiffres).
///
/// Un abonnement actif met le profil en avant : il est renvoyé en tête par le
/// filtre « abonnés » de l'API et porte le badge « Profil mis en avant ».
/// ---------------------------------------------------------------------------
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  List<PlanAbonnement> _plans = [];
  AbonnementStatut? _statut;
  int? _selectedPlanId;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authServiceProvider).currentUser;
    final estPrestataire = user?.isProvider ?? false;
    final actif = _statut?.actif ?? user?.abonnementActif ?? false;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.navy,
        title: const Text(
          'Abonnement',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _etatCard(actif),
              const SizedBox(height: 18),
              const Text(
                'CE QUE VOTRE ABONNEMENT APPORTE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: AppTheme.muted,
                ),
              ),
              const SizedBox(height: 8),
              _beneficesCard(),
              const SizedBox(height: 18),
              Text(
                actif ? 'RENOUVELER OU CHANGER D\'OFFRE' : 'CHOISISSEZ VOTRE OFFRE',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: AppTheme.muted,
                ),
              ),
              const SizedBox(height: 8),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _errorCard()
              else
                ..._plans.map(_planCard),
              if (!_loading && _error == null && _plans.isNotEmpty) ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: estPrestataire
                      ? () {
                          final plan = _plans.firstWhere(
                            (p) => p.id == _selectedPlanId,
                            orElse: () => _plans.first,
                          );
                          _payer(plan);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    estPrestataire
                        ? (actif ? 'Renouveler cet abonnement' : 'S\'abonner maintenant')
                        : 'Réservé aux prestataires',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _ouvrirSiteWeb,
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Gérer sur le site web'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Paiement Mobile Money simulé (Orange Money, Moov Money, Wave) : '
                  'un code de confirmation à 6 chiffres active immédiatement '
                  'l\'abonnement — aucun montant réel n\'est prélevé.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: AppTheme.muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Carte d'état : abonnement actif (vert) ou invitation (orange).
  Widget _etatCard(bool actif) {
    final abo = _statut?.abonnement;
    final gradient = actif
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF047857), AppTheme.success],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFB45309), AppTheme.primaryPressed],
          );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                actif
                    ? Icons.verified_rounded
                    : Icons.rocket_launch_rounded,
                size: 18,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                actif ? 'PROFIL MIS EN AVANT' : 'PROFIL NON MIS EN AVANT',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            actif
                ? (abo?.plan?.nom ?? 'Abonnement actif')
                : 'Gagnez en visibilité dès aujourd\'hui',
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            actif
                ? 'Actif jusqu\'au ${abo?.dateFinLibelle.isEmpty ?? true ? '—' : abo!.dateFinLibelle}'
                    '${(abo?.joursRestants ?? 0) > 0 ? ' · ${abo!.joursRestants} jour(s) restant(s)' : ''}'
                : 'Les clients voient d\'abord les profils abonnés. '
                    'Choisissez une offre pour apparaître en tête des recherches.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
        ],
      ),
    );
  }

  Widget _beneficesCard() {
    const benefices = [
      (
        Icons.trending_up_rounded,
        'Mise en avant dans les recherches',
        'Votre profil remonte en tête du filtre « abonnés ».',
      ),
      (
        Icons.badge_rounded,
        'Badge « Profil mis en avant »',
        'Un repère de confiance visible par les clients.',
      ),
      (
        Icons.workspace_premium_rounded,
        'Accès aux fonctionnalités Pro',
        'Portfolio, réalisations et statistiques de contact.',
      ),
      (
        Icons.schedule_rounded,
        'Activation immédiate',
        'Le paiement Mobile Money active l\'offre tout de suite.',
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        children: [
          for (final (icon, titre, sousTitre) in benefices)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 19, color: AppTheme.primaryPressed),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titre,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.navy,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          sousTitre,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppTheme.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _planCard(PlanAbonnement plan) {
    final selectionne = plan.id == _selectedPlanId;
    final recommande = _plans.length > 1 && plan.id == _plans[1].id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => setState(() => _selectedPlanId = plan.id),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selectionne ? AppTheme.primary : AppTheme.cardBorder,
              width: selectionne ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    selectionne
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    size: 20,
                    color: selectionne ? AppTheme.primary : AppTheme.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      plan.nom,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.navy,
                      ),
                    ),
                  ),
                  if (recommande)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.successSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'RECOMMANDÉ',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: AppTheme.successText,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    plan.prixLibelle,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryPressed,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      '/ ${plan.dureeLibelle}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.muted,
                      ),
                    ),
                  ),
                ],
              ),
              if (plan.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  plan.description,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded, color: AppTheme.muted, size: 28),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Erreur inconnue',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppTheme.navy),
          ),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: _load, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}

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
