part of '../subscription_screen.dart';

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> with _SubscriptionCartes, _SubscriptionActions {
  List<PlanAbonnement> _plans = [];
  AbonnementStatut? _statut;
  int? _selectedPlanId;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }  @override
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
  }}
