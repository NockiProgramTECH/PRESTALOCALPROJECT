part of '../profile_screen.dart';

mixin _UserDashboardAbonnement on ConsumerWidget {
  /// Ouvre l'écran d'abonnement puis recharge l'état du profil.
  void _openAbonnement(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
  }

  /// Ouvre la page d'abonnement du **site web** dans le navigateur.
  ///
  /// Le site reste la référence pour le paiement Mobile Money et la gestion
  /// complète du profil prestataire ; l'application y renvoie explicitement.
  Future<void> _ouvrirAbonnementWeb(BuildContext context) async {
    final uri = Uri.parse(AppConstants.subscriptionWebUrl);
    final ouvert = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ouvert && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Site web : ${AppConstants.webBaseUrl}')),
      );
    }
  }

  /// Carte « abonnement » du tableau de bord prestataire.
  ///
  /// - abonnement actif  : rappel de l'offre et de l'échéance ;
  /// - sinon             : appel à l'action pour mettre le profil en avant.
  Widget _abonnementCard(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final actif = auth.abonnementActif;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _openAbonnement(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: actif
                ? const [Color(0xFF047857), AppTheme.success]
                : const [Color(0xFFB45309), AppTheme.primaryPressed],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              actif ? Icons.verified_rounded : Icons.rocket_launch_rounded,
              size: 26,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    actif
                        ? 'Profil mis en avant'
                        : 'Mettez votre profil en avant',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    actif
                        ? '${auth.abonnementPlan ?? 'Abonnement actif'}'
                            '${auth.abonnementJoursRestants > 0 ? ' · ${auth.abonnementJoursRestants} jour(s) restant(s)' : ''}'
                        : 'Sans abonnement actif, votre profil n\'apparaît pas '
                            'dans les recherches clients. Offres dès 5 000 FCFA.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  /// Bannière opportunité Pro (dégradé orange).
  Widget _proBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB45309), AppTheme.primaryPressed],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.construction_rounded, size: 16, color: Colors.white),
              SizedBox(width: 6),
              Text(
                'OPPORTUNITÉ LESPRODUFAO',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Gagnez des revenus avec vos talents',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Vous avez des compétences manuelles ou professionnelles ? Devenez prestataire LesProduFao : avec un abonnement, votre profil apparaît en tête des recherches et vous touchez des clients chaque jour à Ouagadougou.',
            style: TextStyle(fontSize: 12, color: Colors.white, height: 1.5),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.of(
              context,
            ).push(authRoute((_) => RegisterScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Activer mon profil Pro',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryPressed,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 17,
                    color: AppTheme.primaryPressed,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
