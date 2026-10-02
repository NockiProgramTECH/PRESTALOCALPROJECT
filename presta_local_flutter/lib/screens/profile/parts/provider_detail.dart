part of '../profile_screen.dart';

/// ============================================================================
/// VUE DÉTAIL D'UN PRESTATAIRE + DEVIS
/// ============================================================================
class _ProviderDetailView extends ConsumerStatefulWidget {
  final ProviderModel provider;
  final VoidCallback? onBack;
  final ValueChanged<String>? onMessageTap;

  const _ProviderDetailView({
    required this.provider,
    this.onBack,
    this.onMessageTap,
  });

  @override
  ConsumerState<_ProviderDetailView> createState() =>
      _ProviderDetailViewState();
}

class _ProviderDetailViewState extends ConsumerState<_ProviderDetailView>
    with SingleTickerProviderStateMixin, _ProviderDetailIdentite, _ProviderDetailOnglets, _ProviderDetailActions {
  late final TabController _tabs;
  final _scroll = ScrollController();
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _quartierController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _selectedService;
  String _delai = 'Urgent (Aujourd\'hui)';
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() {
      if (mounted) setState(() {});
    });
    final services = widget.provider.services;
    if (services.isNotEmpty) _selectedService = services.first;
    final phone = ref.read(authServiceProvider).currentUser?.telephone;
    if (phone != null) _phoneController.text = phone;
  }

  @override
  void dispose() {
    _tabs.dispose();
    _scroll.dispose();
    _descController.dispose();
    _quartierController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  ProviderModel get provider => widget.provider;  @override
  Widget build(BuildContext context) {
    final favIds =
        ref.watch(favoritesIdsProvider).valueOrNull ?? const <String>[];
    // En-tête = SliverAppBar : la photo de couverture se réduit au défilement
    // et les informations glissent DERRIÈRE elle (plus de barre opaque qui
    // « pousse » le contenu).
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 220,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: AppTheme.canvas,
            surfaceTintColor: Colors.transparent,
            foregroundColor: AppTheme.navy,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: widget.onBack ?? () => Navigator.of(context).maybePop(),
            ),
            actions: [
              _roundIcon(
                favIds.contains(provider.id)
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                () {
                  final actions = ref.read(favoritesActionsProvider);
                  if (favIds.contains(provider.id)) {
                    actions.remove(provider.id);
                  } else {
                    actions.add(provider.id);
                  }
                },
                color: favIds.contains(provider.id)
                    ? AppTheme.danger
                    : AppTheme.navy,
              ),
              const SizedBox(width: 8),
              _roundIcon(Icons.share_outlined, _share),
              const SizedBox(width: 12),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              // Image de couverture + dégradé + photo de profil :
              // au défilement, elle glisse derrière la barre d'outils.
              background: _coverBackground(),
            ),
          ),
          SliverToBoxAdapter(child: _identityCard()),
          if (!provider.contactDisponible)
            SliverToBoxAdapter(child: _contactIndisponibleBanner()),
          SliverToBoxAdapter(child: _ctaRow()),
          SliverToBoxAdapter(child: _tabsHeader()),
          SliverToBoxAdapter(child: _tabViews()),
          SliverToBoxAdapter(child: _zoneSection()),
          if (provider.contactDisponible)
            SliverToBoxAdapter(child: _quoteForm()),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }}
