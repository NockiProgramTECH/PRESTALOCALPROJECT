import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../data/mock_data.dart';
import '../../models/provider_model.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/provider_card.dart';
import '../../widgets/shimmer_loading.dart';

/// Écran de recherche (maquette « recherche_résultats_prestlocal ») :
/// en-tête, carte de filtres, chips actifs, bannière carte,
/// tri, liste de résultats, appel à l'action Pro.
class SearchScreen extends ConsumerStatefulWidget {
  final ValueChanged<String>? onProviderTap;
  final ValueChanged<String>? onChatTap;
  final VoidCallback? onBecomePro;

  /// Pré-remplissage depuis l'accueil (ne s'applique qu'au montage
  /// et quand les valeurs changent).
  final String? initialQuery;
  final String? initialZone;
  final String? initialCategory;

  const SearchScreen({
    super.key,
    this.onProviderTap,
    this.onChatTap,
    this.onBecomePro,
    this.initialQuery,
    this.initialZone,
    this.initialCategory,
  });

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = 'all';
  String _selectedZone = 'Toutes les zones';
  String _sort = 'rating';

  // Filtres rapides (maquette) : cochés par défaut comme sur la maquette.
  bool _verifiedOnly = true;
  bool _availableOnly = true;
  bool _topRatedOnly = false;
  bool _budgetOnly = false;

  @override
  void initState() {
    super.initState();
    _applyInitial();
  }

  @override
  void didUpdateWidget(SearchScreen old) {
    super.didUpdateWidget(old);
    if (widget.initialQuery != old.initialQuery ||
        widget.initialZone != old.initialZone ||
        widget.initialCategory != old.initialCategory) {
      _applyInitial();
    }
  }

  void _applyInitial() {
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
    }
    if (widget.initialZone != null &&
        AppConstants.zones.contains(widget.initialZone)) {
      _selectedZone = widget.initialZone!;
    }
    if (widget.initialCategory != null) _selectedCategory = widget.initialCategory!;
    WidgetsBinding.instance.addPostFrameCallback((_) => _performSearch());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchResultsProvider);
    final auth = ref.watch(authProvider);
    final unread = ref.watch(liveUnreadCountProvider);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: AppHeader(
            onNotificationsTap: () => _snack('Notifications — Bientôt disponible'),
            hasNotification: unread > 0,
            userName: auth.userName,
            userPhoto: auth.userPhoto,
          ),
        ),
        SliverToBoxAdapter(child: _filterCard()),
        SliverToBoxAdapter(child: _activeFilters()),
        SliverToBoxAdapter(child: _mapBanner()),
        SliverToBoxAdapter(child: _resultsHeader()),
        searchState.when(
          data: (results) => _buildResultsList(_displayed(results)),
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  ShimmerBox(height: 210),
                  SizedBox(height: 12),
                  ShimmerBox(height: 210),
                ],
              ),
            ),
          ),
          error: (_, __) => SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState.error(
              message: AppConstants.errorLoading,
              onRetry: _performSearch,
            ),
          ),
        ),
        SliverToBoxAdapter(child: _proCta()),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  // ---- Carte de filtres ----

  Widget _filterCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: AppTheme.cardDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Service ou métier',
              style: TextStyle(fontSize: 11, color: AppTheme.muted),
            ),
            Row(
              children: [
                const Icon(
                  Icons.plumbing,
                  size: 18,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onChanged: (_) => _performSearch(),
                    onSubmitted: (_) => _performSearch(),
                    decoration: const InputDecoration(
                      hintText: 'Plomberie & Réparations',
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.navy,
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      _performSearch();
                    },
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppTheme.muted,
                    ),
                  ),
              ],
            ),
            const Divider(height: 20),
            const Text(
              'Localisation',
              style: TextStyle(fontSize: 11, color: AppTheme.muted),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedZone,
                      isExpanded: true,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.navy,
                      ),
                      items: AppConstants.zones
                          .map(
                            (z) => DropdownMenuItem(value: z, child: Text(z)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _selectedZone = v);
                        _performSearch();
                      },
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _snack('Géolocalisation — Bientôt disponible'),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppTheme.inputFill,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Icon(
                      Icons.my_location_rounded,
                      size: 16,
                      color: AppTheme.navy,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _snack('Filtres avancés — Bientôt disponible'),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                      if (_activeFilterCount > 0)
                        Positioned(
                          right: -5,
                          top: -5,
                          child: Container(
                            width: 19,
                            height: 19,
                            decoration: BoxDecoration(
                              color: AppTheme.navy,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '$_activeFilterCount',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int get _activeFilterCount {
    var n = 0;
    if (_verifiedOnly) n++;
    if (_availableOnly) n++;
    if (_topRatedOnly) n++;
    if (_budgetOnly) n++;
    return n;
  }

  // ---- Chips des filtres actifs ----

  Widget _activeFilters() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        children: [
          _darkPill('Filtres ($_activeFilterCount)', Icons.tune_rounded, null),
          const SizedBox(width: 8),
          if (_verifiedOnly)
            _removableChip(
              'Vérifiés',
              Icons.verified_outlined,
              () => setState(() => _verifiedOnly = false),
            ),
          if (_availableOnly)
            _removableChip(
              "Dispo aujourd'hui",
              null,
              () => setState(() => _availableOnly = false),
              dot: true,
            ),
          if (_topRatedOnly)
            _removableChip(
              '4.5+',
              Icons.star_rounded,
              () => setState(() => _topRatedOnly = false),
            ),
          if (_budgetOnly)
            _removableChip(
              '< 15 000 FCFA',
              null,
              () => setState(() => _budgetOnly = false),
            ),
          if (!_topRatedOnly) ...[
            const SizedBox(width: 8),
            _addChip('4.5+', () => setState(() => _topRatedOnly = true)),
          ],
          if (!_budgetOnly) ...[
            const SizedBox(width: 8),
            _addChip(
              '< 15 000 FCFA',
              () => setState(() => _budgetOnly = true),
            ),
          ],
        ],
      ),
    );
  }

  Widget _darkPill(String label, IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.navy,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _removableChip(
    String label,
    IconData? icon,
    VoidCallback onRemove, {
    bool dot = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dot)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.success,
                  shape: BoxShape.circle,
                ),
              )
            else if (icon != null)
              Icon(icon, size: 14, color: AppTheme.success),
            if (dot || icon != null) const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.navy,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(
                Icons.close_rounded,
                size: 14,
                color: AppTheme.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.inputFill,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.muted,
          ),
        ),
      ),
    );
  }

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
                    value: 'online',
                    child: Text('Réponse rapide ⚡'),
                  ),
                  DropdownMenuItem(
                    value: 'price',
                    child: Text('Prix croissant 💰'),
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
    var list = source;
    if (_searchController.text.isEmpty &&
        _selectedCategory == 'all' &&
        _selectedZone == 'Toutes les zones' &&
        source.isEmpty) {
      list = ref.watch(allProvidersProvider).valueOrNull ?? MockData.providers;
    }
    var out = list.where((p) {
      if (_verifiedOnly && !p.isVerified) return false;
      if (_availableOnly && !p.isOnline) return false;
      if (_topRatedOnly && p.rating < 4.5) return false;
      if (_budgetOnly && (p.priceValue == null || p.priceValue! > 15000)) {
        return false;
      }
      return true;
    }).toList();
    switch (_sort) {
      case 'price':
        out.sort((a, b) =>
            (a.priceValue ?? double.infinity).compareTo(
              b.priceValue ?? double.infinity,
            ));
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
            'Rejoignez les 650+ professionnels vérifiés de PrestLocal et recevez des demandes de chantiers tous les jours.',
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
