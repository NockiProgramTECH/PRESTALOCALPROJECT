import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/feed_post_model.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/feed_interactive_card.dart';
import '../../widgets/shimmer_loading.dart';
import 'feed_composer_sheet.dart';

/// Page « Fil d'actualité » : publications de la communauté, du plus récent au
/// plus ancien, chargées **page par page** (10 à la fois) avec défilement
/// infini.
class FeedScreen extends ConsumerStatefulWidget {
  final ValueChanged<String>? onProviderTap;

  const FeedScreen({super.key, this.onProviderTap});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _scrollController = ScrollController();

  final List<FeedPostModel> _posts = [];
  int _page = 1;
  bool _hasMore = true;
  bool _loadingInitial = true;
  bool _loadingMore = false;
  String? _error;

  bool get _peutPublier {
    final auth = ref.read(authProvider);
    return auth.status == AuthStatus.authenticated && auth.isProvider;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_surDefilement);
    _chargerPremierePage();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_surDefilement);
    _scrollController.dispose();
    super.dispose();
  }

  void _surDefilement() {
    if (!_scrollController.hasClients || _loadingMore || !_hasMore) return;
    final position = _scrollController.position;
    // Précharge la page suivante 400 px avant la fin : le fil paraît continu.
    if (position.pixels >= position.maxScrollExtent - 400) {
      _chargerPageSuivante();
    }
  }

  Future<void> _chargerPremierePage({bool discret = false}) async {
    if (!discret) {
      setState(() {
        _loadingInitial = true;
        _error = null;
      });
    }
    try {
      final result = await ref
          .read(feedServiceProvider)
          .getPage(page: 1, pageSize: 10);
      if (!mounted) return;
      setState(() {
        _posts
          ..clear()
          ..addAll(result.items);
        _page = result.nextPage;
        _hasMore = result.hasMore;
        _loadingInitial = false;
        _loadingMore = false;
        _error = null;
      });
    } on ApiException catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingInitial = false;
        if (_posts.isEmpty) _error = AppConstants.errorLoading;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingInitial = false;
        if (_posts.isEmpty) _error = AppConstants.errorLoading;
      });
    }
  }

  Future<void> _chargerPageSuivante() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final result = await ref
          .read(feedServiceProvider)
          .getPage(page: _page, pageSize: 10);
      if (!mounted) return;
      setState(() {
        // Évite les doublons si une publication a été ajoutée entre-temps.
        final connus = _posts.map((p) => p.id).toSet();
        _posts.addAll(result.items.where((p) => !connus.contains(p.id)));
        _page = result.nextPage;
        _hasMore = result.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _hasMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppConstants.errorNetwork)),
      );
    }
  }

  Future<void> _rafraichir() async {
    ref.invalidate(feedPostsProvider);
    await _chargerPremierePage(discret: true);
  }

  Future<void> _ouvrirCompositeur() async {
    final publie = await showFeedComposerSheet(context);
    if (publie == true) await _chargerPremierePage(discret: true);
  }

  void _majPublication(FeedPostModel post) {
    final index = _posts.indexWhere((p) => p.id == post.id);
    if (index >= 0) setState(() => _posts[index] = post);
  }

  void _retirerPublication(FeedPostModel post) {
    setState(() => _posts.removeWhere((p) => p.id == post.id));
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final estConnecte = auth.status == AuthStatus.authenticated;

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      appBar: AppBar(
        title: const Text("Fil d'actualité"),
        actions: [
          IconButton(
            onPressed: _rafraichir,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Rafraîchir',
          ),
        ],
      ),
      floatingActionButton: _peutPublier
          ? FloatingActionButton.extended(
              onPressed: _ouvrirCompositeur,
              icon: const Icon(Icons.edit_rounded),
              label: const Text('Publier'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _rafraichir,
        color: AppTheme.primary,
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
          children: [
            // ---- Zone de création (style « Quoi de neuf ? ») ----
            if (_peutPublier)
              _ComposerEntete(
                userName: auth.userName,
                userPhoto: auth.userPhoto,
                onTap: _ouvrirCompositeur,
                onPhoto: _ouvrirCompositeur,
                onVideo: _ouvrirCompositeur,
              ),
            if (_peutPublier) const SizedBox(height: 12),
            if (!estConnecte) ...[
              const _InvitationConnexion(),
              const SizedBox(height: 12),
            ],

            // ---- État d'erreur (première page) ----
            if (_error != null && _posts.isEmpty)
              EmptyState.error(message: _error, onRetry: _rafraichir)
            // ---- Chargement initial ----
            else if (_loadingInitial && _posts.isEmpty)
              const _FeedShimmerList()
            // ---- État vide ----
            else if (_posts.isEmpty)
              EmptyState(
                icon: Icons.dynamic_feed_outlined,
                title: 'Aucune publication pour le moment',
                subtitle:
                    'Partagez votre première actualité : vos réalisations, '
                    'vos nouveautés, vos disponibilités…',
                actionLabel: _peutPublier ? 'Publier une actualité' : null,
                actionIcon: Icons.edit_rounded,
                onAction: _peutPublier ? _ouvrirCompositeur : null,
              )
            // ---- Publications ----
            else
              for (final post in _posts) ...[
                FeedInteractiveCard(
                  key: ValueKey(post.id),
                  post: post,
                  onProviderTap: widget.onProviderTap,
                  onUpdated: _majPublication,
                  onDeleted: () => _retirerPublication(post),
                ),
                const SizedBox(height: 12),
              ],

            // ---- Pied de liste ----
            if (_loadingMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            else if (!_hasMore && _posts.isNotEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Vous êtes à jour',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// En-tête de création : photo de profil + champ « Quoi de neuf… ».
class _ComposerEntete extends StatelessWidget {
  final String? userName;
  final String? userPhoto;
  final VoidCallback onTap;
  final VoidCallback onPhoto;
  final VoidCallback onVideo;

  const _ComposerEntete({
    required this.userName,
    required this.userPhoto,
    required this.onTap,
    required this.onPhoto,
    required this.onVideo,
  });

  @override
  Widget build(BuildContext context) {
    final photo = userPhoto ?? '';
    return Container(
      decoration: AppTheme.cardDecoration.copyWith(
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.primarySoft,
                backgroundImage: photo.isEmpty
                    ? null
                    : CachedNetworkImageProvider(photo),
                child: photo.isEmpty
                    ? const Icon(
                        Icons.person,
                        size: 20,
                        color: AppTheme.primary,
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.inputFill,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      userName?.isNotEmpty == true
                          ? 'Quoi de neuf, ${userName!.split(' ').first} ?'
                          : 'Quoi de neuf dans votre activité ?',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          Row(
            children: [
              Expanded(
                child: _RaccourciComposer(
                  icon: Icons.photo_library_outlined,
                  label: 'Photos',
                  onTap: onPhoto,
                ),
              ),
              Expanded(
                child: _RaccourciComposer(
                  icon: Icons.videocam_outlined,
                  label: 'Vidéo',
                  onTap: onVideo,
                ),
              ),
              Expanded(
                child: _RaccourciComposer(
                  icon: Icons.edit_note_rounded,
                  label: 'Rédiger',
                  onTap: onTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RaccourciComposer extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _RaccourciComposer({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: AppTheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.navy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bandeau invitant un visiteur à se connecter pour interagir.
class _InvitationConnexion extends StatelessWidget {
  const _InvitationConnexion();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration.copyWith(
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(14),
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, color: AppTheme.primary, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Connectez-vous pour aimer, commenter et publier dans le fil.',
              style: TextStyle(fontSize: 13, color: AppTheme.navy),
            ),
          ),
        ],
      ),
    );
  }
}

/// Squelettes de cartes pendant le premier chargement.
class _FeedShimmerList extends StatelessWidget {
  const _FeedShimmerList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 3; i++) ...[
          Container(
            decoration: AppTheme.cardDecoration.copyWith(
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Row(
                  children: [
                    ShimmerBox(width: 40, height: 40, borderRadius: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerBox(height: 13),
                          SizedBox(height: 6),
                          ShimmerBox(height: 10, width: 140),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14),
                ShimmerBox(height: 12),
                SizedBox(height: 8),
                ShimmerBox(height: 12, width: 200),
                SizedBox(height: 14),
                ShimmerBox(height: 170),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
