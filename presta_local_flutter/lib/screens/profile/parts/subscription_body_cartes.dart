part of '../subscription_screen.dart';

mixin _SubscriptionCartes on ConsumerState<SubscriptionScreen> {
  List<PlanAbonnement> get _plans;
  int? get _selectedPlanId;
  set _selectedPlanId(int? value);
  String? get _error;
  Future<void> _load();

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
