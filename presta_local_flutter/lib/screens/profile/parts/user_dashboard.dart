part of '../profile_screen.dart';

/// ============================================================================
/// MON PROFIL CLIENT
/// ============================================================================
class _UserDashboard extends ConsumerWidget with _UserDashboardAbonnement, _UserDashboardProfil, _UserDashboardMenu {
  final VoidCallback? onLoginTap;

  const _UserDashboard({this.onLoginTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final isLoggedIn = authState.status == AuthStatus.authenticated;

    void _snack(String message) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }

    if (!isLoggedIn) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppTheme.primarySoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 44,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Connectez-vous',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navy,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Accédez à votre profil, vos favoris et vos demandes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.muted),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onLoginTap,
                    child: const Text('Se connecter / S\'inscrire'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final user = ref.watch(authServiceProvider).currentUser;
    final favCount =
        ref.watch(favoritesProvidersProvider).valueOrNull?.length ?? 0;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppHeader.slim(
            title: 'LesProduFao',
            subtitle: 'Profil',
            onNotificationsTap: () =>
                _snack('Notifications — Bientôt disponible'),
            userName: authState.userName,
            userPhoto: authState.userPhoto,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: _roleToggle(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _profileCard(context, ref, user),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _statsRow(favCount),
          ),
          if (authState.isProvider)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _PortfolioSection(),
            ),
          if (authState.isProvider)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _abonnementCard(context, ref),
            ),
          if (!authState.isProvider)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _proBanner(context),
            ),
          if (authState.isProvider)
            _menuSection('MON ABONNEMENT', [
              _menuItem(
                icon: Icons.workspace_premium_rounded,
                iconBg: AppTheme.primarySoft,
                iconColor: AppTheme.primaryPressed,
                title: 'Abonnement & mise en avant',
                subtitle: authState.abonnementActif
                    ? 'Actif${authState.abonnementPlan != null ? ' — ${authState.abonnementPlan}' : ''}'
                        '${authState.abonnementJoursRestants > 0 ? ' · ${authState.abonnementJoursRestants} j restants' : ''}'
                    : 'Profil non mis en avant — choisir une offre',
                trailing: authState.abonnementActif
                    ? const FeaturedPill()
                    : const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: AppTheme.muted,
                      ),
                onTap: () => _openAbonnement(context),
              ),
            ]),
          _menuSection('MON ACTIVITÉ', [
            _menuItem(
              icon: Icons.receipt_long_outlined,
              iconBg: const Color(0xFFDCEAFE),
              iconColor: const Color(0xFF1D4ED8),
              title: 'Historique des interventions',
              subtitle: 'Factures & garanties SAV',
              onTap: () => _snack('Historique — Bientôt disponible'),
            ),
            _menuItem(
              icon: Icons.favorite_border_rounded,
              iconBg: const Color(0xFFFFDAD6),
              iconColor: AppTheme.danger,
              title: 'Artisans favoris',
              subtitle: '$favCount prestataire(s) enregistré(s)',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FavoritesScreen(
                    onProviderTap: (id) => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(providerId: id),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
          _menuSection('PAIEMENTS & SÉCURITÉ', [
            _menuItem(
              icon: Icons.account_balance_wallet_outlined,
              iconBg: AppTheme.inputFill,
              iconColor: AppTheme.navy,
              title: 'Moyens de paiement',
              subtitle: authState.isProvider
                  ? 'Orange Money, Moov Money, Wave'
                  : 'Orange Money, Moov, Espèces',
              onTap: authState.isProvider
                  ? () => _openAbonnement(context)
                  : () => _snack('Paiements — Bientôt disponible'),
            ),
            _menuItem(
              icon: Icons.badge_outlined,
              iconBg: AppTheme.successSoft,
              iconColor: AppTheme.success,
              title: "Vérification d'identité",
              subtitle: 'Pièce CNIB enregistrée',
              trailing: const VerifiedPill(label: 'Vérifié ✓'),
              onTap: () => _snack('Vérification — Bientôt disponible'),
            ),
            _menuItem(
              icon: Icons.lock_outline,
              iconBg: AppTheme.inputFill,
              iconColor: AppTheme.navy,
              title: 'Sécurité & Mot de passe',
              subtitle: 'Code PIN & biométrie',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PasswordResetScreen()),
              ),
            ),
          ]),
          _menuSection('PRÉFÉRENCES & SUPPORT', [
            _menuItem(
              icon: Icons.workspace_premium_rounded,
              iconBg: AppTheme.primarySoft,
              iconColor: AppTheme.primaryPressed,
              title: 'Abonnement',
              subtitle: authState.isProvider
                  ? 'Mettre mon profil en avant (application ou site web)'
                  : 'Offres de mise en avant pour les prestataires',
              onTap: () => _openAbonnement(context),
            ),
            _menuItem(
              icon: Icons.open_in_new_rounded,
              iconBg: AppTheme.inputFill,
              iconColor: AppTheme.navy,
              title: 'Gérer mon abonnement sur le site web',
              subtitle: AppConstants.subscriptionWebUrl.replaceFirst(
                RegExp(r'^https?://'),
                '',
              ),
              onTap: () => _ouvrirAbonnementWeb(context),
            ),
            _menuItem(
              icon: Icons.notifications_outlined,
              iconBg: AppTheme.inputFill,
              iconColor: AppTheme.navy,
              title: 'Notifications',
              subtitle: 'SMS, WhatsApp & Push',
              onTap: () =>
                  _snack('Notifications — Bientôt disponible'),
            ),
            _menuItem(
              icon: Icons.support_agent_rounded,
              iconBg: AppTheme.successSoft,
              iconColor: AppTheme.success,
              title: "Centre d'aide & Assistance locale",
              subtitle: 'Équipe dédiée à Ouagadougou',
              onTap: () =>
                  _snack("Centre d'aide — Bientôt disponible"),
            ),
            _menuItem(
              icon: Icons.translate_rounded,
              iconBg: AppTheme.inputFill,
              iconColor: AppTheme.navy,
              title: "Langue de l'application",
              subtitle: 'Français, Mooré, Dioula',
              trailing: const Text(
                'Français',
                style: TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
              onTap: () => _snack('Langues — Bientôt disponible'),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => ref.read(authProvider.notifier).logout(),
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text('Se déconnecter'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFFDE8E8),
                  foregroundColor: AppTheme.danger,
                  side: BorderSide.none,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 24),
            child: Center(
              child: Column(
                children: [
                  Text(
                    'LesProduFao v2.4.0 • Fait avec passion à Ouaga',
                    style: TextStyle(fontSize: 11, color: AppTheme.muted),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Conditions d'utilisation & Confidentialité",
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.primaryPressed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }}
