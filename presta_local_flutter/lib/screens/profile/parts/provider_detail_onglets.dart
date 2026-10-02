part of '../profile_screen.dart';

mixin _ProviderDetailOnglets on ConsumerState<_ProviderDetailView> {
  TabController get _tabs;
  GlobalKey<FormState> get _formKey;
  TextEditingController get _descController;
  TextEditingController get _quartierController;
  TextEditingController get _phoneController;
  String? get _selectedService;
  set _selectedService(String? value);
  String get _delai;
  set _delai(String value);
  bool get _sending;
  ProviderModel get provider;
  Future<void> _sendQuote();
  String _formatDate(DateTime date);

  /// Onglets Services / Réalisations / Avis.
  Widget _tabsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppTheme.inputFill,
          borderRadius: BorderRadius.circular(999),
        ),
        child: TabBar(
          controller: _tabs,
          dividerColor: Colors.transparent,
          indicator: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(999),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: Colors.white,
          unselectedLabelColor: AppTheme.muted,
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          tabs: [
            const Tab(text: 'Services'),
            const Tab(text: 'Réalisations'),
            Tab(text: 'Avis clients (${provider.reviewCount})'),
          ],
        ),
      ),
    );
  }

  Widget _tabViews() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: [_servicesTab(), _realisationsTab(), _reviewsTab()][_tabs.index],
    );
  }

  /// Services proposés par le prestataire (sans prix : devis en messagerie).
  Widget _servicesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Services proposés',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppTheme.navy,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Discutez du besoin et du budget directement avec le prestataire via la messagerie.',
          style: TextStyle(fontSize: 12, color: AppTheme.muted, height: 1.5),
        ),
        const SizedBox(height: 12),
        ...provider.services.map(
          (s) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.inputFill,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.handyman_outlined,
                    size: 19,
                    color: AppTheme.navy,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.navy,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SoftPill(label: 'Sur mesure'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Réalisations avant/après (maquette).
  Widget _realisationsTab() {
    if (provider.realisations.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Aucune réalisation publiée pour le moment.',
            style: TextStyle(color: AppTheme.muted),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chantiers récents avant / après',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppTheme.navy,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Travaux réalisés dans les villas et résidences de Ouagadougou.',
          style: TextStyle(fontSize: 12, color: AppTheme.muted),
        ),
        const SizedBox(height: 12),
        ...provider.realisations.map(
          (r) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: AppTheme.cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: r.imageUrl,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) =>
                        Container(height: 150, color: AppTheme.inputFill),
                    errorWidget: (_, __, ___) => Container(
                      height: 150,
                      color: AppTheme.inputFill,
                      child: const Icon(
                        Icons.image_outlined,
                        color: AppTheme.muted,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    r.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.navy,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Avis vérifiés (maquette).
  Widget _reviewsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Retours vérifiés',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppTheme.navy,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Basé sur ${provider.reviewCount} interventions certifiées',
          style: const TextStyle(fontSize: 12, color: AppTheme.muted),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.primarySoft.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Text(
                provider.rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.navy,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '/ 5',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.muted,
                ),
              ),
              const Spacer(),
              RatingDisplay(
                rating: provider.rating,
                starSize: 18,
                showValue: false,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (provider.reviews.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Aucun avis pour le moment.',
                style: TextStyle(color: AppTheme.muted),
              ),
            ),
          )
        else
          ...provider.reviews.map(
            (review) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.primarySoft,
                    backgroundImage: review.authorAvatar.isNotEmpty
                        ? CachedNetworkImageProvider(review.authorAvatar)
                        : null,
                    child: review.authorAvatar.isEmpty
                        ? Text(
                            review.authorName.isNotEmpty
                                ? review.authorName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryPressed,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                review.authorName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.navy,
                                ),
                              ),
                            ),
                            Text(
                              _formatDate(review.date),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.muted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        RatingDisplay(
                          rating: review.rating,
                          starSize: 13,
                          showValue: false,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          review.comment,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.navy,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _openReviewDialog,
            icon: const Icon(Icons.rate_review_outlined, size: 18),
            label: const Text('Évaluer ce prestataire'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryPressed,
              side: const BorderSide(color: AppTheme.primary),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Boîte de dialogue d'évaluation : note (1-5) + commentaire,
  /// puis `POST /api/prestataire/{id}/evaluer/`.
  Future<void> _openReviewDialog() async {
    final messenger = ScaffoldMessenger.of(context);
    if (ref.read(authProvider).status != AuthStatus.authenticated) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Connectez-vous pour laisser un avis')),
      );
      return;
    }

    var note = 5;
    final commentController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Évaluer ${provider.name}',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppTheme.navy,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Votre note',
                style: TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: List.generate(5, (index) {
                  final value = index + 1;
                  return IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    onPressed: () => setDialogState(() => note = value),
                    tooltip: '$value étoile${value > 1 ? 's' : ''}',
                    icon: Icon(
                      value <= note
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: AppTheme.warning,
                      size: 30,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: commentController,
                minLines: 2,
                maxLines: 4,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: 'Votre commentaire',
                  hintText: 'Qualité du travail, délais, accueil...',
                  filled: true,
                  fillColor: AppTheme.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Publier'),
            ),
          ],
        ),
      ),
    );

    final commentaire = commentController.text.trim();
    commentController.dispose();
    if (confirmed != true) return;

    try {
      await ref
          .read(providerServiceProvider)
          .evaluate(providerId: provider.id, note: note, commentaire: commentaire);
      // Recharge la fiche (nouvel avis + note recalculée) et les listes.
      ref.invalidate(providerDetailProvider(provider.id));
      ref.invalidate(allProvidersProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Merci ! Votre avis a été publié')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Avis non enregistré : $e')),
      );
    }
  }

  /// Formulaire de devis rapide (maquette) : l'envoi crée/ouvre la
  /// conversation avec le prestataire via la messagerie existante.
  Widget _quoteForm() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: AppTheme.primaryPressed,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Demander un devis rapide',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.navy,
                        ),
                      ),
                      Text(
                        'Réponse sous 15 minutes garantie',
                        style: TextStyle(fontSize: 12, color: AppTheme.muted),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.successSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Sans\nengagement',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.successText,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Service concerné',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.navy,
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _selectedService,
              items: provider.services
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedService = v),
            ),
            const SizedBox(height: 12),
            const Text(
              'Description de votre besoin',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.navy,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _descController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText:
                    'Expliquez brièvement votre panne, bruits, ou vos besoins matériels...',
              ),
              validator: (v) {
                if (v == null || v.trim().length < 10) {
                  return 'Décrivez votre besoin (10 caractères min.)';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            const Text(
              'Délai souhaité',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.navy,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children:
                  ['Urgent (Aujourd\'hui)', 'Demain matin', 'Cette semaine']
                      .map(
                        (d) => ChoiceChip(
                          label: Text(d),
                          selected: _delai == d,
                          onSelected: (_) => setState(() => _delai = d),
                          selectedColor: AppTheme.primary,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _delai == d ? Colors.white : AppTheme.navy,
                          ),
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                            side: BorderSide(
                              color: _delai == d
                                  ? AppTheme.primary
                                  : AppTheme.cardBorder,
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 12),
            const Text(
              "Lieu d'intervention (Ouagadougou)",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.navy,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _quartierController,
              decoration: const InputDecoration(
                hintText: 'Quartier (ex: Ouaga 2000, Patte d\'Oie...)',
                prefixIcon: Icon(
                  Icons.location_on_outlined,
                  color: AppTheme.primary,
                ),
                suffixIcon: Icon(
                  Icons.my_location_rounded,
                  color: AppTheme.muted,
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Indiquez le quartier';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            const Text(
              'Votre numéro de téléphone',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.navy,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                hintText: '+226 70 00 00 00',
                prefixIcon: Icon(Icons.call_outlined, color: AppTheme.muted),
              ),
              validator: (v) {
                if (v == null || v.trim().length < 8) {
                  return 'Numéro invalide';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _sending ? null : _sendQuote,
                icon: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_outlined, size: 20),
                label: Text(
                  'Envoyer la demande à ${provider.name.split(' ').first} (Gratuit)',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.verified_outlined,
                  size: 15,
                  color: AppTheme.success,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${provider.name.split(' ').first} s\'engage à vous rappeler pour confirmation immédiate',
                    style: const TextStyle(fontSize: 11, color: AppTheme.muted),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
