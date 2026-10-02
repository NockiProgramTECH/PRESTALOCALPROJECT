part of '../search_screen.dart';

mixin _SearchScreenResultats on ConsumerState<SearchScreen> {
  TextEditingController get _searchController;
  String get _selectedCategory;
  String get _selectedZone;
  String get _sort;
  set _sort(String value);

  // ---- Bannière carte ----

  Widget _mapBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.inputFill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.map_outlined,
                color: AppTheme.navy,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Voir les plombiers sur la carte',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.navy,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: () => _snack('Carte — Bientôt disponible'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primarySoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ouvrir',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                    Icon(
                      Icons.expand_more_rounded,
                      size: 15,
                      color: AppTheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- En-tête des résultats + tri ----

  Widget _resultsHeader() {
    final count = _displayed(
      ref.watch(searchResultsProvider).valueOrNull ?? const [],
    ).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Résultats de recherche',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navy,
                  ),
                ),
                Text(
                  '$count artisans qualifiés trouvés',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  ),
                ),
                // Règle de visibilité : un prestataire sans abonnement actif
                // n'apparaît pas dans les résultats (ses publications restent
                // visibles dans le fil d'actualité).
                const Text(
                  'Seuls les prestataires avec un abonnement actif sont listés ici.',
                  style: TextStyle(fontSize: 10.5, color: AppTheme.muted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sort,
                isDense: true,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.navy,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'rating',
                    child: Text('Mieux notés ⭐'),
                  ),
                  DropdownMenuItem(
                    value: 'experience',
                    child: Text('Plus expérimentés 🛠️'),
                  ),
                  DropdownMenuItem(
                    value: 'online',
                    child: Text('Réponse rapide ⚡'),
                  ),
                ],
                onChanged: (v) => setState(() => _sort = v ?? 'rating'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Liste des résultats ----

  List<ProviderModel> _displayed(List<ProviderModel> source) {
    // Sans recherche active, on affiche la liste complète de l'API.
    // (Plus de repli sur des données fictives : MockData.providers.)
    var list = source;
    if (_searchController.text.isEmpty &&
        _selectedCategory == 'all' &&
        _selectedZone == 'Toutes les zones' &&
        source.isEmpty) {
      list = ref.watch(allProvidersProvider).valueOrNull ?? const [];
    }
    final out = list.where((p) {
      if (_verifiedOnly && !p.isVerified) return false;
      if (_availableOnly && !p.isOnline) return false;
      if (_topRatedOnly && p.rating < 4.5) return false;
      return true;
    }).toList();
    switch (_sort) {
      case 'experience':
        out.sort((a, b) => b.experienceYears.compareTo(a.experienceYears));
      case 'online':
        out.sort((a, b) {
          if (a.isOnline == b.isOnline) return b.rating.compareTo(a.rating);
          return a.isOnline ? -1 : 1;
        });
      default:
        out.sort((a, b) => b.rating.compareTo(a.rating));
    }
    return out;
  }

  Widget _buildResultsList(List<ProviderModel> providers) {
    if (providers.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyState.search(),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, i) {
          final p = providers[i];
          return Padding(
            padding: EdgeInsets.only(
              bottom: i < providers.length - 1 ? 12 : 0,
            ),
            child: SearchResultCard(
              provider: p,
              onTap: () => widget.onProviderTap?.call(p.id),
              onQuote: () => _startQuote(p),
              onCall: () => _call(p),
              onChat: () => _startQuote(p),
            ),
          );
        }, childCount: providers.length),
      ),
    );
  }

  // ---- Appel à l'action Pro ----

  Widget _proCta() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        children: [
          const Icon(
            Icons.handshake_outlined,
            size: 30,
            color: AppTheme.primary,
          ),
          const SizedBox(height: 8),
          const Text(
            'Vous êtes artisan à Ouagadougou ?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppTheme.navy,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Rejoignez les 650+ professionnels vérifiés de LesProduFao et recevez des demandes de chantiers tous les jours.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.muted, height: 1.5),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: widget.onBecomePro,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 13,
              ),
              decoration: BoxDecoration(
                color: AppTheme.navy,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Créer mon profil Pro',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Actions ----

  void _performSearch() {
    setState(() {});
    ref
        .read(searchResultsProvider.notifier)
        .search(
          query: _searchController.text,
          categoryId: _selectedCategory == 'all' ? null : _selectedCategory,
          zone: _selectedZone == 'Toutes les zones' ? null : _selectedZone,
        );
  }

  /// Demande de devis : ouvre (ou crée) la conversation avec le prestataire.
  Future<void> _startQuote(ProviderModel provider) async {
    final authed =
        ref.read(authProvider).status == AuthStatus.authenticated;
    if (!authed) {
      _snack('Connectez-vous pour contacter ce prestataire');
      return;
    }
    try {
      final convId = await ref
          .read(messageServiceProvider)
          .startConversation(provider.id);
      widget.onChatTap?.call(convId);
    } catch (_) {
      _snack('Impossible de démarrer la conversation');
    }
  }

  Future<void> _call(ProviderModel provider) async {
    final phone = provider.phone.trim();
    if (phone.isEmpty) {
      _snack('Numéro indisponible');
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri)) {
      _snack("Impossible de lancer l'appel");
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
