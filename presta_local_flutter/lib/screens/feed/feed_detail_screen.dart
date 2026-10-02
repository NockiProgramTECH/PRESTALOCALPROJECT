import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/feed_post_model.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/shimmer_loading.dart';
import '../../utils/feed_actions.dart';
import 'feed_composer_sheet.dart';

/// Page détail d'une publication.
///
/// Affiche l'auteur (tapable vers sa fiche), le texte complet, les médias
/// (galerie si plusieurs images), le lien, puis les **vraies** interactions :
/// J'aime, commentaires (chargés depuis l'API) et partage. L'auteur peut
/// modifier ou supprimer sa publication ; cette page renvoie alors `true`
/// au fil pour qu'il rafraîchisse la carte.
class FeedDetailScreen extends ConsumerStatefulWidget {
  final String realisationId;
  final ValueChanged<String>? onProviderTap;
  /// Ouvre la page avec le champ de commentaire déjà focalisé.
  final bool focusComment;

  const FeedDetailScreen({
    super.key,
    required this.realisationId,
    this.onProviderTap,
    this.focusComment = false,
  });

  @override
  ConsumerState<FeedDetailScreen> createState() => _FeedDetailScreenState();
}

class _FeedDetailScreenState extends ConsumerState<FeedDetailScreen> {
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();
  final _commentFocus = FocusNode();

  bool _loading = true;
  String? _error;
  FeedPostModel? _post;

  bool _liked = false;
  int _likeCount = 0;
  int _commentCount = 0;
  List<FeedCommentModel> _comments = const [];
  bool _newestFirst = true;
  bool _sending = false;
  bool _focused = false;
  /// Vrai si la publication a été modifiée ou supprimée : le fil doit se
  /// rafraîchir au retour.
  bool _modifie = false;

  @override
  void initState() {
    super.initState();
    _commentFocus.addListener(() {
      if (mounted && _focused != _commentFocus.hasFocus) {
        setState(() => _focused = _commentFocus.hasFocus);
      }
    });
    _load();
  }

  @override
  void dispose() {
    _commentFocus.dispose();
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(feedServiceProvider);
      final post = await service.getDetail(widget.realisationId);
      // Commentaires réels (endpoint dédié) : source unique de vérité.
      List<FeedCommentModel> commentaires;
      try {
        commentaires = await service.getComments(widget.realisationId);
      } catch (_) {
        commentaires = post.comments;
      }
      if (!mounted) return;
      setState(() {
        _post = post;
        _liked = post.isLiked;
        _likeCount = post.likeCount;
        _commentCount = commentaires.isNotEmpty
            ? commentaires.length
            : post.commentCount;
        _comments = commentaires;
        _loading = false;
      });
      if (widget.focusComment) {
        // Laisse la page se poser avant d'ouvrir le clavier.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _commentFocus.requestFocus();
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppConstants.errorLoading;
      });
    }
  }

  bool _requireLogin(String action) {
    if (ref.read(authProvider).status == AuthStatus.authenticated) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Connectez-vous pour $action')),
    );
    return false;
  }

  Future<void> _toggleLike() async {
    final post = _post;
    if (post == null) return;
    if (!_requireLogin('aimer une publication')) return;
    try {
      final result = await ref.read(feedServiceProvider).toggleLike(post.id);
      if (!mounted) return;
      setState(() {
        _liked = result.liked;
        _likeCount = result.likeCount;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppConstants.errorNetwork)));
    }
  }

  Future<void> _sendComment() async {
    final post = _post;
    final text = _commentController.text.trim();
    if (post == null || text.isEmpty || _sending) return;
    if (!_requireLogin('commenter une publication')) return;
    setState(() => _sending = true);
    try {
      final result = await ref
          .read(feedServiceProvider)
          .addComment(post.id, text);
      if (!mounted) return;
      setState(() {
        _comments = [result.comment, ..._comments];
        _commentCount = result.commentCount;
        _sending = false;
        _modifie = true;
      });
      _commentController.clear();
      if (_newestFirst && _scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppConstants.errorNetwork)));
    }
  }

  Future<void> _partager() async {
    final post = _post;
    if (post == null) return;
    await FeedActions.sharePost(context, post);
  }

  Future<void> _modifier() async {
    final post = _post;
    if (post == null) return;
    final ok = await showFeedComposerSheet(context, edition: post);
    if (ok == true) {
      _modifie = true;
      await _load();
    }
  }

  Future<void> _supprimer() async {
    final post = _post;
    if (post == null) return;
    final confirme = await FeedActions.confirmDelete(context);
    if (!confirme) return;
    try {
      final ok = await ref.read(feedServiceProvider).delete(post.id);
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Suppression impossible')));
        return;
      }
      ref.invalidate(feedPostsProvider);
      ref.invalidate(myFeedPostsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publication supprimée')),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppConstants.errorNetwork)));
    }
  }

  Future<void> _ouvrirImage(String url) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_modifie);
      },
      child: Scaffold(
        backgroundColor: AppTheme.canvas,
        appBar: AppBar(
          title: const Text('Publication'),
          actions: [
            if (_post?.canEdit == true)
              IconButton(
                onPressed: _modifier,
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Modifier',
              ),
            if (_post?.canDelete == true)
              IconButton(
                onPressed: _supprimer,
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'Supprimer',
              ),
          ],
        ),
        body: _post == null
            ? _buildBody()
            : Column(
                children: [
                  Expanded(child: _buildBody()),
                  _buildCommentInput(),
                ],
              ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const _DetailShimmer();
    if (_error != null || _post == null) {
      return EmptyState.error(message: _error, onRetry: _load);
    }
    final post = _post!;
    final displayed = _newestFirst ? _comments : _comments.reversed.toList();

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        // ---- Auteur ----
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.primarySoft,
                backgroundImage: post.author.avatar.isEmpty
                    ? null
                    : CachedNetworkImageProvider(post.author.avatar),
                child: post.author.avatar.isEmpty
                    ? const Icon(Icons.person, color: AppTheme.primary)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            post.author.fullName.isNotEmpty
                                ? post.author.fullName
                                : 'Prestataire',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.navy,
                            ),
                          ),
                        ),
                        if (post.author.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: AppTheme.success,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (post.author.metier.isNotEmpty) post.author.metier,
                        if (post.author.ville.isNotEmpty) post.author.ville,
                        formatFeedTime(post.date),
                      ].join(' · '),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.muted,
                      ),
                    ),
                    if (!post.author.contactDisponible) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFFED7AA)),
                        ),
                        child: const Text(
                          'Non contactable — abonnement inactif',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryPressed,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.onProviderTap != null && post.author.id.isNotEmpty)
                TextButton(
                  onPressed: () => widget.onProviderTap!(post.author.id),
                  child: const Text('Voir la fiche'),
                ),
            ],
          ),
        ),

        // ---- Texte complet ----
        if (post.text.trim().isNotEmpty)
          Container(
            color: Colors.white,
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.text,
                  style: const TextStyle(
                    fontSize: 15.5,
                    height: 1.4,
                    color: AppTheme.navy,
                  ),
                ),
                if (post.modifieLe != null)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Publication modifiée',
                      style: TextStyle(fontSize: 11.5, color: AppTheme.muted),
                    ),
                  ),
              ],
            ),
          ),

        // ---- Médias ----
        if (post.images.isNotEmpty)
          _GalerieImages(urls: post.images, onTap: _ouvrirImage),
        if (post.videoUrl.isNotEmpty)
          AspectRatio(
            aspectRatio: 4 / 3,
            child: GestureDetector(
              onTap: () => FeedActions.openExternal(
                context,
                post.videoUrl,
                errorMessage: 'Lecture vidéo impossible sur cet appareil',
              ),
              child: Container(
                color: const Color(0xFF0F172A),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.play_circle_fill_rounded,
                        size: 62,
                        color: Colors.white,
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Lire la vidéo',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // ---- Catégorie + lien ----
        if (post.categorieNom.isNotEmpty || post.lien.isNotEmpty)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.categorieNom.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primarySoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      post.categorieNom,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryPressed,
                      ),
                    ),
                  ),
                if (post.lien.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(
                      top: post.categorieNom.isNotEmpty ? 10 : 0,
                    ),
                    child: InkWell(
                      onTap: () => FeedActions.openExternal(context, post.lien),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.inputFill,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.link_rounded,
                              color: AppTheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                feedLinkHost(post.lien),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.navy,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.open_in_new_rounded,
                              size: 16,
                              color: AppTheme.muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

        // ---- Compteurs + actions ----
        Container(
          color: Colors.white,
          margin: const EdgeInsets.only(top: 8),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      size: 16,
                      color: AppTheme.danger,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$_likeCount',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.muted,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Icon(
                      Icons.mode_comment_rounded,
                      size: 16,
                      color: AppTheme.muted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$_commentCount',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Row(
                children: [
                  Expanded(
                    child: _ActionDetail(
                      icon: _liked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      label: "J'aime",
                      active: _liked,
                      onTap: _toggleLike,
                    ),
                  ),
                  Expanded(
                    child: _ActionDetail(
                      icon: Icons.mode_comment_outlined,
                      label: 'Commenter',
                      onTap: () => _commentFocus.requestFocus(),
                    ),
                  ),
                  Expanded(
                    child: _ActionDetail(
                      icon: Icons.share_outlined,
                      label: 'Partager',
                      onTap: _partager,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ---- Commentaires ----
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Commentaires',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.navy,
                ),
              ),
              if (_comments.length > 1)
                TextButton.icon(
                  onPressed: () => setState(() => _newestFirst = !_newestFirst),
                  icon: Icon(
                    _newestFirst
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                    size: 16,
                  ),
                  label: Text(_newestFirst ? 'Plus récents' : 'Plus anciens'),
                ),
            ],
          ),
        ),
        if (displayed.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Aucun commentaire pour le moment. Soyez le premier !',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.muted, fontSize: 13),
            ),
          )
        else
          ...displayed.map(
            (c) => _CommentTile(comment: c, postAuthorId: post.author.id),
          ),
      ],
    );
  }

  /// Zone de saisie de commentaire (s'agrandit au focus).
  Widget _buildCommentInput() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      padding: EdgeInsets.symmetric(
        horizontal: _focused ? 8 : 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                focusNode: _commentFocus,
                enabled: !_sending,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendComment(),
                minLines: _focused ? 2 : 1,
                maxLines: _focused ? 5 : 2,
                style: const TextStyle(fontSize: 15.5, height: 1.3),
                decoration: InputDecoration(
                  hintText: 'Ajouter un commentaire…',
                  filled: true,
                  fillColor: AppTheme.canvas,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: _focused ? 14 : 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(_focused ? 16 : 24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _sending ? null : _sendComment,
              icon: _sending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              color: AppTheme.primary,
              tooltip: 'Envoyer',
            ),
          ],
        ),
      ),
    );
  }
}

/// Galerie d'images : défilement horizontal si plusieurs photos.
class _GalerieImages extends StatefulWidget {
  final List<String> urls;
  final ValueChanged<String> onTap;

  const _GalerieImages({required this.urls, required this.onTap});

  @override
  State<_GalerieImages> createState() => _GalerieImagesState();
}

class _GalerieImagesState extends State<_GalerieImages> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.urls.length == 1) {
      return AspectRatio(
        aspectRatio: 4 / 3,
        child: GestureDetector(
          onTap: () => widget.onTap(widget.urls.first),
          child: CachedNetworkImage(
            imageUrl: widget.urls.first,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: AppTheme.inputFill),
            errorWidget: (_, __, ___) => Container(
              color: AppTheme.inputFill,
              child: const Icon(
                Icons.broken_image_outlined,
                color: AppTheme.muted,
              ),
            ),
          ),
        ),
      );
    }
    return Stack(
      children: [
        SizedBox(
          height: 320,
          child: PageView.builder(
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, index) => GestureDetector(
              onTap: () => widget.onTap(widget.urls[index]),
              child: CachedNetworkImage(
                imageUrl: widget.urls[index],
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: AppTheme.inputFill),
                errorWidget: (_, __, ___) => Container(
                  color: AppTheme.inputFill,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: AppTheme.muted,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${_index + 1}/${widget.urls.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Bouton de la barre d'actions du détail.
class _ActionDetail extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _ActionDetail({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final couleur = active ? AppTheme.primary : AppTheme.navy;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: couleur),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: couleur,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte d'un commentaire (photo, nom, date, badge auteur).
class _CommentTile extends StatelessWidget {
  final FeedCommentModel comment;
  /// Identifiant de l'auteur de la publication : sert au badge « Auteur ».
  final String postAuthorId;

  const _CommentTile({required this.comment, required this.postAuthorId});

  @override
  Widget build(BuildContext context) {
    final photo = comment.userPhoto;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: AppTheme.primarySoft,
            backgroundImage: photo.isEmpty
                ? null
                : CachedNetworkImageProvider(photo),
            child: photo.isEmpty
                ? const Icon(Icons.person, size: 17, color: AppTheme.primary)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          comment.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.navy,
                          ),
                        ),
                      ),
                      if (comment.userId.isNotEmpty &&
                          comment.userId == postAuthorId) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primarySoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Auteur',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryPressed,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    comment.contenu,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppTheme.navy,
                      height: 1.3,
                    ),
                  ),
                  if (comment.date.millisecondsSinceEpoch != 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      formatFeedTime(comment.date),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Squelette de chargement de la page détail.
class _DetailShimmer extends StatelessWidget {
  const _DetailShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        ShimmerBox(height: 220, borderRadius: 0),
        Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ShimmerBox(width: 44, height: 44, borderRadius: 22),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(height: 14),
                        SizedBox(height: 6),
                        ShimmerBox(height: 10, width: 120),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              ShimmerBox(height: 16, width: 240),
              SizedBox(height: 24),
              ShimmerBox(height: 14),
              SizedBox(height: 12),
              ShimmerBox(height: 14),
              SizedBox(height: 12),
              ShimmerBox(height: 14, width: 180),
            ],
          ),
        ),
      ],
    );
  }
}
