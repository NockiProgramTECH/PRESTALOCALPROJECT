part of '../home_screen.dart';

/// Hero : badge, titre, carte de recherche + chips rapides.
class _HeroSection extends StatefulWidget {
  final void Function(String query, String zone, String categoryId)? onSearch;

  const _HeroSection(this.onSearch);

  @override
  State<_HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<_HeroSection> {
  final _serviceController = TextEditingController();
  String _zone = 'Toutes les zones';

  @override
  void dispose() {
    _serviceController.dispose();
    super.dispose();
  }

  void _submit() {
    widget.onSearch?.call(
      _serviceController.text.trim(),
      _zone,
      'all',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primarySoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_rounded,
                  size: 14,
                  color: AppTheme.primary,
                ),
                SizedBox(width: 5),
                Text(
                  'PLATEFORME N°1 À OUAGA',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1.2,
                color: AppTheme.navy,
                fontFamily: 'Plus Jakarta Sans',
              ),
              children: [
                TextSpan(text: 'Trouvez le bon\nprestataire, '),
                TextSpan(
                  text: 'près de chez\nvous',
                  style: TextStyle(color: AppTheme.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Des artisans qualifiés et rigoureusement vérifiés à Ouagadougou et ses environs immédiats.',
            style: TextStyle(fontSize: 13, color: AppTheme.muted, height: 1.5),
          ),
          const SizedBox(height: 14),
          // Carte de recherche blanche.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: AppTheme.cardDecoration,
            child: Column(
              children: [
                TextField(
                  controller: _serviceController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    hintText: 'Service (ex: Plomberie, Climatisation...)',
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: AppTheme.muted,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _zone,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(
                      Icons.location_on_outlined,
                      color: AppTheme.primary,
                    ),
                  ),
                  items: AppConstants.zones
                      .map(
                        (z) => DropdownMenuItem(value: z, child: Text(z)),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _zone = v ?? _zone),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.engineering_outlined, size: 20),
                    label: const Text('Rechercher un artisan'),
                  ),
                ),
                const SizedBox(height: 10),
                const _QuickChips(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Chips de services rapides sous le bouton de recherche.
class _QuickChips extends ConsumerWidget {
  const _QuickChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = context
        .findAncestorWidgetOfExactType<HomeScreen>()
        ?.onSearchSubmitted;
    final cats = ref.watch(categoriesProvider).valueOrNull ?? [];
    final quick = cats.take(5).toList();
    if (quick.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: quick
          .map(
            (c) => GestureDetector(
              onTap: () => home?.call('', 'Toutes les zones', c.id),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.inputFill,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _shortLabel(c.name),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.navy,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  String _shortLabel(String name) {
    if (name.contains('&')) return name.split('&').first.trim();
    final words = name.split(' ');
    return words.take(2).join(' ');
  }
}

/// Bandeau de garanties : identités vérifiées, paiement garanti, assistance.
class _TrustRow extends StatelessWidget {
  const _TrustRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _TrustItem(
              icon: Icons.verified_user_outlined,
              title: 'Identités vérifiées',
              subtitle: 'CNIB & Références',
            ),
          ),
          Expanded(
            child: _TrustItem(
              icon: Icons.lock_reset_rounded,
              title: 'Paiement garanti',
              subtitle: 'À la fin du travail',
            ),
          ),
          Expanded(
            child: _TrustItem(
              icon: Icons.support_agent_rounded,
              title: 'Assistance Ouaga',
              subtitle: 'Support direct',
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _TrustItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppTheme.successSoft,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Icon(
            icon,
            color: AppTheme.success,
            size: 22,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppTheme.navy,
          ),
        ),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, color: AppTheme.muted),
        ),
      ],
    );
  }
}

/// Grille 2 colonnes des catégories populaires.
class _CategoriesGrid extends ConsumerWidget {
  const _CategoriesGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = context
        .findAncestorWidgetOfExactType<HomeScreen>()
        ?.onSearchSubmitted;
    final catsAsync = ref.watch(categoriesProvider);
    return catsAsync.when(
      data: (cats) {
        final items = cats.take(8).toList();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 72,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final c = items[i];
              final tint = CategoryGridCard.tints[i % 4];
              return CategoryGridCard(
                name: c.name,
                icon: _getCategoryIcon(c.icon),
                count: c.providerCount,
                tint: tint.$1,
                iconColor: tint.$2,
                onTap: () => home?.call('', 'Toutes les zones', c.id),
              );
            },
          ),
        );
      },
      loading: () => Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: ShimmerBox(height: 160),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: EmptyState.error(
          message: 'Catégories indisponibles',
          onRetry: () => ref.invalidate(categoriesProvider),
        ),
      ),
    );
  }
}

/// Liste verticale des prestataires recommandés.
class _RecommendedList extends ConsumerWidget {
  const _RecommendedList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = context.findAncestorWidgetOfExactType<HomeScreen>();
    final featured = ref.watch(featuredProvidersProvider);
    return featured.when(
      data: (providers) {
        final items = providers.take(5).toList();
        if (items.isEmpty) return EmptyState.search();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                ProviderCard(
                  provider: items[i],
                  onTap: () => home?.onProviderTap?.call(items[i].id),
                ),
                if (i < items.length - 1) const SizedBox(height: 12),
              ],
            ],
          ),
        );
      },
      loading: () => Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            ShimmerBox(height: 130),
            SizedBox(height: 12),
            ShimmerBox(height: 130),
          ],
        ),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: EmptyState.error(
          message: AppConstants.errorLoading,
          onRetry: () => ref.invalidate(featuredProvidersProvider),
        ),
      ),
    );
  }
}
