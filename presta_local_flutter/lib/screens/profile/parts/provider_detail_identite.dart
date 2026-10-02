part of '../profile_screen.dart';

mixin _ProviderDetailIdentite on ConsumerState<_ProviderDetailView> {
  ProviderModel get provider;

  /// Photo de couverture + dégradé + photo de profil (en-tête de la fiche).
  ///
  /// Rendu dans le `flexibleSpace` du SliverAppBar : au scroll, la couverture
  /// se replie et le contenu (identité, actions, avis) défile par-dessus /
  /// derrière elle.
  Widget _coverBackground() {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: provider.banner,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(color: AppTheme.primarySoft),
          errorWidget: (_, __, ___) => Container(
            color: AppTheme.primary,
            child: const Icon(
              Icons.handyman_rounded,
              size: 64,
              color: Colors.white54,
            ),
          ),
        ),
        // Dégradé sombre : lisibilité des boutons ronds blancs et de la photo.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.35),
                Colors.transparent,
                Colors.black.withValues(alpha: 0.30),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        // Photo de profil + pastille de vérification.
        Positioned(
          left: 16,
          bottom: 16,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: AppTheme.inputFill,
                  backgroundImage: provider.avatar.isNotEmpty
                      ? CachedNetworkImageProvider(provider.avatar)
                      : null,
                  child: provider.avatar.isEmpty
                      ? const Icon(
                          Icons.person_rounded,
                          size: 36,
                          color: AppTheme.primary,
                        )
                      : null,
                ),
              ),
              if (provider.isVerified)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: AppTheme.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _roundIcon(IconData icon, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: color ?? AppTheme.navy),
      ),
    );
  }

  /// Carte identité : état, nom, métier, ville/quartier, note et description.
  ///
  /// Contenu demandé pour la fiche prestataire : Nom, Prénom, métier, ville,
  /// description + évaluation. Aucun prix n'est affiché.
  Widget _identityCard() {
    final zone = provider.locationZone.isNotEmpty
        ? '${provider.locationZone} · ${provider.location}'
        : provider.location;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (provider.isFeatured) const FeaturedPill(),
              if (provider.isOnline)
                const AvailablePill(label: 'Disponible'),
              if (provider.isVerified)
                const VerifiedPill(label: 'Vérifié LesProduFao'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            provider.name,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: AppTheme.navy,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            provider.title.isEmpty ? 'Prestataire local' : provider.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          if (zone.isNotEmpty)
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 15,
                  color: AppTheme.muted,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    zone,
                    style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 10),
          // Évaluation du prestataire (note + nombre d'avis)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primarySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 15,
                      color: AppTheme.primary,
                    ),
                    Text(
                      ' ${provider.rating.toStringAsFixed(1)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.navy,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${provider.reviewCount} avis clients',
                  style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                ),
              ),
            ],
          ),
          if (provider.about.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'À propos',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppTheme.navy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              provider.about.trim(),
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.muted,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Bandeau affiché quand le prestataire n'a pas d'abonnement actif.
  ///
  /// Ses publications restent visibles dans le fil, mais ses coordonnées sont
  /// masquées : impossible de le contacter pour un job.
  Widget _contactIndisponibleBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: AppTheme.primaryPressed,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Ce prestataire n'a pas d'abonnement actif : ses coordonnées "
              '(téléphone, email) sont masquées et la prise de contact est '
              'désactivée. Ses réalisations restent visibles dans le fil.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: AppTheme.navy,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Boutons d'action principaux : Message, Appel, WhatsApp, Facebook.
  ///
  /// Quatre boutons de largeur égale (`Expanded`) : aucun risque de
  /// débordement horizontal quelle que soit la largeur de l'écran.
  /// Sans abonnement actif chez le prestataire, les boutons sont désactivés
  /// (coordonnées masquées par l'API).
  Widget _ctaRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _actionButton(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Message',
              primary: true,
              onTap: provider.contactDisponible ? _openChat : _contactBloque,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _actionButton(
              icon: Icons.call_outlined,
              label: 'Appel',
              onTap: provider.contactDisponible
                  ? () => _call(provider.phone)
                  : _contactBloque,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _actionButton(
              icon: Icons.chat_rounded,
              label: 'WhatsApp',
              color: const Color(0xFF25D366),
              onTap: provider.contactDisponible ? _openWhatsApp : _contactBloque,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _actionButton(
              icon: Icons.facebook_rounded,
              label: 'Facebook',
              color: const Color(0xFF1877F2),
              onTap: _openFacebook,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool primary = false,
    Color? color,
  }) {
    final fg = primary ? Colors.white : (color ?? AppTheme.navy);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: primary ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: primary ? null : Border.all(color: AppTheme.cardBorder),
          boxShadow: primary ? null : AppTheme.cardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: primary ? Colors.white : AppTheme.navy,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Zone d'intervention (maquette).
  Widget _zoneSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Zone d'intervention",
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppTheme.navy,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Déplacement en moto équipée avec tout le matériel dans toute l\'agglomération de Ouagadougou.',
            style: TextStyle(fontSize: 12, color: AppTheme.muted, height: 1.5),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _zoneChip(
                '${provider.locationZone.isNotEmpty ? provider.locationZone : provider.location} & Rayon 25 km',
                highlighted: true,
              ),
              _zoneChip('Tout Ouagadougou'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _zoneChip(String label, {bool highlighted = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted ? AppTheme.navy : Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: highlighted ? null : Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.near_me_outlined,
            size: 14,
            color: highlighted ? Colors.white : AppTheme.primary,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: highlighted ? Colors.white : AppTheme.navy,
            ),
          ),
        ],
      ),
    );
  }
}
