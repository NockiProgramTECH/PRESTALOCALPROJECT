part of '../search_screen.dart';

mixin _SearchScreenFiltres on ConsumerState<SearchScreen> {
  TextEditingController get _searchController;
  String get _selectedZone;
  set _selectedZone(String value);
  bool get _verifiedOnly;
  set _verifiedOnly(bool value);
  bool get _availableOnly;
  set _availableOnly(bool value);
  bool get _topRatedOnly;
  set _topRatedOnly(bool value);
  void _performSearch();
  void _snack(String message);

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
                  onTap: _openFilters,
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
    return n;
  }

  /// Panneau de filtres (bouton « tune » de la carte de filtres).
  ///
  /// Les trois filtres rapides sont modifiables ici : ils étaient jusqu'ici
  /// seulement supprimables (chips), sans moyen de les réactiver.
  Future<void> _openFilters() async {
    var verified = _verifiedOnly;
    var available = _availableOnly;
    var topRated = _topRatedOnly;

    final applied = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.cardBorder,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Filtres',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navy,
                  ),
                ),
                const SizedBox(height: 4),
                SwitchListTile.adaptive(
                  value: verified,
                  onChanged: (v) => setSheetState(() => verified = v),
                  title: const Text('Prestataires vérifiés'),
                  subtitle: const Text('Identité et métier contrôlés'),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile.adaptive(
                  value: available,
                  onChanged: (v) => setSheetState(() => available = v),
                  title: const Text("Disponibles aujourd'hui"),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile.adaptive(
                  value: topRated,
                  onChanged: (v) => setSheetState(() => topRated = v),
                  title: const Text('Mieux notés (4.5+)'),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setSheetState(() {
                          verified = false;
                          available = false;
                          topRated = false;
                        }),
                        child: const Text('Réinitialiser'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            Navigator.of(sheetContext).pop(true),
                        child: const Text('Appliquer'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (applied != true || !mounted) return;
    setState(() {
      _verifiedOnly = verified;
      _availableOnly = available;
      _topRatedOnly = topRated;
    });
    _performSearch();
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
          if (!_topRatedOnly) ...[
            const SizedBox(width: 8),
            _addChip('4.5+', () => setState(() => _topRatedOnly = true)),
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
}
