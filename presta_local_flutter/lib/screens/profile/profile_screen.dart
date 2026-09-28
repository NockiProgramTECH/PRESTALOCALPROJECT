import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../models/provider_model.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_header.dart';
import '../../widgets/badges.dart';
import '../../widgets/rating_display.dart';
import '../auth/password_reset_screen.dart';
import '../favorites/favorites_screen.dart';
import '../feed/feed_create_screen.dart';
import '../messages/chat_screen.dart';
import 'profile_edit_screen.dart';

/// Écran de profil (double usage, maquettes « profil_prestataire_devis »
/// et « mon_profil ») :
///
/// 1. Détail d'un prestataire (quand [providerId] est fourni) : cover,
///    tarifs, réalisations, avis, zone d'intervention et formulaire de
///    devis (envoyé via la messagerie existante).
/// 2. Mon profil client (quand [providerId] est null).
class ProfileScreen extends ConsumerWidget {
  final String? providerId;
  final VoidCallback? onBack;
  final ValueChanged<String>? onMessageTap;
  final VoidCallback? onLoginTap;

  const ProfileScreen({
    super.key,
    this.providerId,
    this.onBack,
    this.onMessageTap,
    this.onLoginTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mode détail prestataire
    if (providerId != null) {
      final providerAsync = ref.watch(providerDetailProvider(providerId!));
      return providerAsync.when(
        data: (provider) {
          if (provider == null) {
            return Scaffold(
              appBar: AppBar(leading: const BackButton()),
              body: const Center(child: Text('Prestataire non trouvé')),
            );
          }
          return _ProviderDetailView(
            provider: provider,
            onBack: onBack,
            onMessageTap: onMessageTap,
          );
        },
        loading: () => Scaffold(
          appBar: AppBar(leading: const BackButton()),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(
          appBar: AppBar(leading: const BackButton()),
          body: Center(child: Text('Erreur : $e')),
        ),
      );
    }

    // Mode mon profil
    return _UserDashboard(onLoginTap: onLoginTap);
  }
}

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
    with SingleTickerProviderStateMixin {
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

  ProviderModel get provider => widget.provider;

  void _scrollToQuote() {
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
  }

  @override
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
          SliverToBoxAdapter(child: _ctaRow()),
          SliverToBoxAdapter(child: _tabsHeader()),
          SliverToBoxAdapter(child: _tabViews()),
          SliverToBoxAdapter(child: _zoneSection()),
          SliverToBoxAdapter(child: _quoteForm()),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

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
              if (provider.isOnline)
                const AvailablePill(label: 'Disponible'),
              if (provider.isVerified)
                const VerifiedPill(label: 'Vérifié PrestLocal'),
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

  /// Boutons d'action principaux : Message, Appel, WhatsApp, Facebook.
  ///
  /// Quatre boutons de largeur égale (`Expanded`) : aucun risque de
  /// débordement horizontal quelle que soit la largeur de l'écran.
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
              onTap: _openChat,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _actionButton(
              icon: Icons.call_outlined,
              label: 'Appel',
              onTap: () => _call(provider.phone),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _actionButton(
              icon: Icons.chat_rounded,
              label: 'WhatsApp',
              color: const Color(0xFF25D366),
              onTap: _openWhatsApp,
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

  /// Partage de la fiche prestataire (copie dans le presse-papiers).
  Future<void> _share() async {
    await Clipboard.setData(
      ClipboardData(
        text:
            '${provider.name} — ${provider.title} à ${provider.location}\n'
            'Découvert sur PrestA Local.',
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fiche copiée — collez-la pour partager')),
    );
  }

  /// Ouvre (ou crée) la conversation avec le prestataire.
  Future<void> _openChat() async {
    if (ref.read(authProvider).status != AuthStatus.authenticated) {
      _snack('Connectez-vous pour envoyer un message');
      return;
    }
    try {
      final convId = await ref
          .read(messageServiceProvider)
          .startConversation(provider.id);
      if (!mounted) return;
      if (widget.onMessageTap != null) {
        widget.onMessageTap!(convId);
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: convId,
              onBack: () => Navigator.of(context).pop(),
            ),
          ),
        );
      }
    } catch (_) {
      _snack('Impossible de démarrer la conversation');
    }
  }

  /// Ouvre WhatsApp sur le numéro du prestataire (format international).
  Future<void> _openWhatsApp() async {
    final raw = (provider.whatsapp?.isNotEmpty == true)
        ? provider.whatsapp!
        : provider.phone;
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      _snack('Numéro indisponible');
      return;
    }
    final uri = Uri.parse('https://wa.me/$digits');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _snack("Impossible d'ouvrir WhatsApp");
    }
  }

  /// Ouvre la recherche Facebook sur le nom du prestataire.
  Future<void> _openFacebook() async {
    final uri = Uri.parse(
      'https://www.facebook.com/search/top?q=${Uri.encodeComponent(provider.name)}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _snack("Impossible d'ouvrir Facebook");
    }
  }

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

  /// Envoie la demande : crée la conversation puis y poste le récapitulatif.
  Future<void> _sendQuote() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    if (ref.read(authProvider).status != AuthStatus.authenticated) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Connectez-vous pour envoyer un devis')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final service = ref.read(messageServiceProvider);
      final convId = await service.startConversation(provider.id);
      final recap =
          'Demande de devis — ${provider.name}\n'
          'Service : ${_selectedService ?? provider.title}\n'
          'Délai : $_delai\n'
          'Lieu : ${_quartierController.text.trim()}\n'
          'Tél : ${_phoneController.text.trim()}\n'
          'Besoin : ${_descController.text.trim()}';
      final selfId = ref.read(currentUserIdProvider);
      if (selfId != null) {
        await service.sendMessage(
          conversationId: convId,
          text: recap,
          selfUserId: selfId,
        );
      }
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Demande envoyée au prestataire')),
      );
      widget.onMessageTap?.call(convId);
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Envoi impossible — réessayez')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _call(String phone) async {
    if (phone.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Numéro indisponible')));
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone.trim());
    if (!await launchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible de lancer l'appel")),
      );
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];
    return 'Il y a ${DateTime.now().difference(date).inDays} j • ${date.day} ${months[date.month - 1]}';
  }
}

/// ============================================================================
/// MON PROFIL CLIENT
/// ============================================================================
class _UserDashboard extends ConsumerWidget {
  final VoidCallback? onLoginTap;

  const _UserDashboard({this.onLoginTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final isLoggedIn = authState.status == AuthStatus.authenticated;

    if (!isLoggedIn) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppTheme.primarySoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 44,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Connectez-vous',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navy,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Accédez à votre profil, vos favoris et vos demandes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.muted),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onLoginTap,
                    child: const Text('Se connecter / S\'inscrire'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final user = ref.watch(authServiceProvider).currentUser;
    final favCount =
        ref.watch(favoritesProvidersProvider).valueOrNull?.length ?? 0;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppHeader.slim(
            title: 'PrestLocal',
            subtitle: 'Profil',
            onNotificationsTap: () =>
                _snack(context, 'Notifications — Bientôt disponible'),
            userName: authState.userName,
            userPhoto: authState.userPhoto,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: _roleToggle(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _profileCard(context, ref, user),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _statsRow(favCount),
          ),
          if (authState.isProvider)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _PortfolioSection(),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _proBanner(context),
          ),
          _menuSection('MON ACTIVITÉ', [
            _menuItem(
              icon: Icons.receipt_long_outlined,
              iconBg: const Color(0xFFDCEAFE),
              iconColor: const Color(0xFF1D4ED8),
              title: 'Historique des interventions',
              subtitle: 'Factures & garanties SAV',
              onTap: () => _snack(context, 'Historique — Bientôt disponible'),
            ),
            _menuItem(
              icon: Icons.favorite_border_rounded,
              iconBg: const Color(0xFFFFDAD6),
              iconColor: AppTheme.danger,
              title: 'Artisans favoris',
              subtitle: '$favCount prestataire(s) enregistré(s)',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FavoritesScreen(
                    onProviderTap: (id) => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(providerId: id),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ]),
          _menuSection('PAIEMENTS & SÉCURITÉ', [
            _menuItem(
              icon: Icons.account_balance_wallet_outlined,
              iconBg: AppTheme.inputFill,
              iconColor: AppTheme.navy,
              title: 'Moyens de paiement',
              subtitle: 'Orange Money, Moov, Espèces',
              onTap: () => _snack(context, 'Paiements — Bientôt disponible'),
            ),
            _menuItem(
              icon: Icons.badge_outlined,
              iconBg: AppTheme.successSoft,
              iconColor: AppTheme.success,
              title: "Vérification d'identité",
              subtitle: 'Pièce CNIB enregistrée',
              trailing: const VerifiedPill(label: 'Vérifié ✓'),
              onTap: () => _snack(context, 'Vérification — Bientôt disponible'),
            ),
            _menuItem(
              icon: Icons.lock_outline,
              iconBg: AppTheme.inputFill,
              iconColor: AppTheme.navy,
              title: 'Sécurité & Mot de passe',
              subtitle: 'Code PIN & biométrie',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PasswordResetScreen()),
              ),
            ),
          ]),
          _menuSection('PRÉFÉRENCES & SUPPORT', [
            _menuItem(
              icon: Icons.notifications_outlined,
              iconBg: AppTheme.inputFill,
              iconColor: AppTheme.navy,
              title: 'Notifications',
              subtitle: 'SMS, WhatsApp & Push',
              onTap: () =>
                  _snack(context, 'Notifications — Bientôt disponible'),
            ),
            _menuItem(
              icon: Icons.support_agent_rounded,
              iconBg: AppTheme.successSoft,
              iconColor: AppTheme.success,
              title: "Centre d'aide & Assistance locale",
              subtitle: 'Équipe dédiée à Ouagadougou',
              onTap: () =>
                  _snack(context, "Centre d'aide — Bientôt disponible"),
            ),
            _menuItem(
              icon: Icons.translate_rounded,
              iconBg: AppTheme.inputFill,
              iconColor: AppTheme.navy,
              title: "Langue de l'application",
              subtitle: 'Français, Mooré, Dioula',
              trailing: const Text(
                'Français',
                style: TextStyle(fontSize: 12, color: AppTheme.muted),
              ),
              onTap: () => _snack(context, 'Langues — Bientôt disponible'),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => ref.read(authProvider.notifier).logout(),
                icon: const Icon(Icons.logout_rounded, size: 20),
                label: const Text('Se déconnecter'),
                style: OutlinedButton.styleFrom(
                  backgroundColor: const Color(0xFFFDE8E8),
                  foregroundColor: AppTheme.danger,
                  side: BorderSide.none,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 24),
            child: Center(
              child: Column(
                children: [
                  Text(
                    'PrestLocal v2.4.0 • Fait avec passion à Ouaga',
                    style: TextStyle(fontSize: 11, color: AppTheme.muted),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Conditions d'utilisation & Confidentialité",
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.primaryPressed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

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
              ).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
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
                    const VerifiedPill(label: 'Client vérifié'),
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
                'OPPORTUNITÉ PRESTLOCAL',
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
            'Vous avez des compétences manuelles ou professionnelles ? Devenez prestataire PrestLocal et touchez des clients chaque jour à Ouagadougou.',
            style: TextStyle(fontSize: 12, color: Colors.white, height: 1.5),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
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

  Widget _menuSection(String title, List<Widget> items) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: AppTheme.muted,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(children: items),
          ),
        ],
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 21, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.navy,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: AppTheme.muted),
                  ),
                ],
              ),
            ),
            trailing ??
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppTheme.muted,
                ),
          ],
        ),
      ),
    );
  }

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

/// ============================================================================
/// MON PORTFOLIO (comme l'onglet Portfolio web : grille + ajout + suppression)
/// ============================================================================
class _PortfolioSection extends ConsumerWidget {
  const _PortfolioSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mineAsync = ref.watch(myFeedPostsProvider);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Mon Portfolio',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navy,
                  ),
                ),
              ),
              // Thème global : minimumSize infini en largeur → dans un Row
              // (largeur non bornée) ça crash. On surcharge en taille compacte.
              ElevatedButton.icon(
                onPressed: () async {
                  final created = await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const FeedCreateScreen(),
                    ),
                  );
                  if (created == true) {
                    ref.invalidate(myFeedPostsProvider);
                    ref.invalidate(feedPostsProvider);
                  }
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Ajouter'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          mineAsync.when(
            data: (posts) {
              if (posts.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.inputFill,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        size: 32,
                        color: AppTheme.muted,
                      ),
                      SizedBox(height: 6),
                      Text(
                        "Vous n'avez pas encore de réalisations dans votre portfolio.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppTheme.muted),
                      ),
                    ],
                  ),
                );
              }
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: posts.length,
                itemBuilder: (context, i) {
                  final post = posts[i];
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: post.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: AppTheme.inputFill,
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: AppTheme.inputFill,
                            child: const Icon(
                              Icons.image_outlined,
                              color: AppTheme.muted,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _confirmDelete(context, ref, post.id),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
            // Pas de `Center` ici : dans un SingleChildScrollView la hauteur
            // est non bornée → "Cannot hit test a render box with no size"
            // + page blanche. Hauteur fixe à la place.
            loading: () => const SizedBox(
              height: 120,
              child: Align(
                alignment: Alignment.center,
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, __) => const Text(
              'Portfolio indisponible.',
              style: TextStyle(color: AppTheme.muted),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: const Text(
          'Voulez-vous supprimer cette réalisation ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(feedServiceProvider).delete(id);
      ref.invalidate(myFeedPostsProvider);
      ref.invalidate(feedPostsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Réalisation supprimée.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Suppression impossible — réessayez')),
        );
      }
    }
  }
}
