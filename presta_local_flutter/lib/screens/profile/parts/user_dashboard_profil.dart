part of '../profile_screen.dart';

mixin _UserDashboardProfil on ConsumerWidget {
  /// Sélecteur Espace Client / Passer en Pro.
  Widget _roleToggle(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primarySoft.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    size: 17,
                    color: AppTheme.primaryPressed,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Espace Client',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryPressed,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.of(
                context,
              ).push(authRoute((_) => RegisterScreen())),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.engineering_outlined,
                    size: 17,
                    color: AppTheme.muted,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Passer en Pro',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.muted,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.circle, size: 7, color: AppTheme.primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Carte identité client.
  Widget _profileCard(BuildContext context, WidgetRef ref, AuthUser? user) {
    final auth = ref.read(authProvider);
    final photo = auth.userPhoto?.isNotEmpty == true ? auth.userPhoto! : null;
    final initial = (auth.userName?.isNotEmpty == true
        ? auth.userName![0]
        : 'U');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppTheme.primarySoft,
                backgroundImage: photo != null
                    ? CachedNetworkImageProvider(photo)
                    : null,
                child: photo == null
                    ? Text(
                        initial.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryPressed,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      auth.userName ?? 'Utilisateur',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        const VerifiedPill(label: 'Vérifié LesProduFao'),
                        if (auth.isProvider && auth.abonnementActif)
                          const FeaturedPill(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if ((user?.telephone?.isNotEmpty == true))
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_iphone_rounded,
                            size: 13,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            user!.telephone!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.navy,
                            ),
                          ),
                        ],
                      ),
                    if ((user?.quartier?.isNotEmpty == true))
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: AppTheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${user!.quartier}, Ouagadougou',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.navy,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileEditScreen()),
              ),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Modifier mon profil'),
              style: OutlinedButton.styleFrom(
                backgroundColor: AppTheme.inputFill,
                side: BorderSide.none,
                minimumSize: const Size.fromHeight(46),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Statistiques : demandes (en attente backend), favoris (réel), note.
  Widget _statsRow(int favCount) {
    return Row(
      children: [
        Expanded(child: _statCard('—', 'Demandes\npassées')),
        const SizedBox(width: 10),
        Expanded(child: _statCard('$favCount', 'Artisans\nfavoris')),
        const SizedBox(width: 10),
        Expanded(child: _statCard('—', 'Note\nclient', star: true)),
      ],
    );
  }

  Widget _statCard(String value, String label, {bool star = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryPressed,
                ),
              ),
              if (star)
                const Padding(
                  padding: EdgeInsets.only(left: 3),
                  child: Icon(
                    Icons.star_rounded,
                    size: 18,
                    color: AppTheme.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.navy,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
