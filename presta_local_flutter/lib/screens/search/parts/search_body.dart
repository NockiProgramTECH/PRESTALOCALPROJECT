part of '../search_screen.dart';

class _SearchScreenState extends ConsumerState<SearchScreen> with _SearchScreenFiltres, _SearchScreenResultats {
  final TextEditingController _searchController = TextEditingController();

  String _selectedCategory = 'all';
  String _selectedZone = 'Toutes les zones';
  String _sort = 'rating';

  // Filtres rapides (maquette) : cochés par défaut comme sur la maquette.
  bool _verifiedOnly = true;
  bool _availableOnly = true;
  bool _topRatedOnly = false;

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
  }}
