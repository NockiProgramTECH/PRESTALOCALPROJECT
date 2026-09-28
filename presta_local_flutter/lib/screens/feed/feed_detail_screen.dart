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

/// Page détail d'une réalisation.
///
/// Affiche l'image, l'auteur (tapable vers son profil), le titre, un bouton
/// like, et la liste des commentaires avec tri (plus récents / plus anciens).
/// Une zone de saisie en bas permet d'ajouter un commentaire (style Facebook).
class FeedDetailScreen extends ConsumerStatefulWidget {
  final String realisationId;
  final ValueChanged<String>? onProviderTap;

  const FeedDetailScreen({
    super.key,
    required this.realisationId,
    this.onProviderTap,
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

  /// Le champ de saisie est-il focalisé (clavier ouvert) ?
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    // Agrandit le champ (largeur + hauteur) dès qu'on commence à écrire.
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
      final post = await ref
          .read(feedServiceProvider)
          .getDetail(widget.realisationId);
      if (!mounted) return;
      setState(() {
        _post = post;
        _liked = post.isLiked;
        _likeCount = post.likeCount;
        _commentCount = post.commentCount;
        // Le backend renvoie les commentaires du plus récent au plus ancien.
        _comments = List.of(post.comments);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppConstants.errorLoading;
      });
    }
  }

  /// Vrai si l'utilisateur est connecté (les likes/commentaires l'exigent).
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
    if (!_requireLogin('aimer une réalisation')) return;
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
    if (!_requireLogin('commenter une réalisation')) return;
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
      });
      _commentController.clear();
      // Remonte vers le haut pour voir le nouveau commentaire (si tri récents).
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(title: const Text('Réalisation'), elevation: 0),
      // La zone de saisie est dans le body : quand le clavier s'ouvre, le
      // keyboard inset resserre la Column et l'Expanded, donc l'entrée reste
      // visible au-dessus du clavier (au lieu d'être masquée).
      body: _post == null
          ? _buildBody()
          : Column(
              children: [
                Expanded(child: _buildBody()),
                _buildCommentInput(),
              ],
            ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const _DetailShimmer();
    }
    if (_error != null || _post == null) {
      return EmptyState.error(message: _error, onRetry: _load);
    }
    final post = _post!;
    final displayed = _newestFirst ? _comments : _comments.reversed.toList();

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        // ---- Grande image ----
        AspectRatio(
          aspectRatio: 16 / 9,
          child: post.imageUrl.isEmpty
              ? Container(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    size: 48,
                    color: AppTheme.primaryGreen.withValues(alpha: 0.4),
                  ),
                )
              : CachedNetworkImage(
                  imageUrl: post.imageUrl,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 250),
                  placeholder: (context, url) => Container(
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey.shade200,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.grey.shade400,
                      size: 48,
                    ),
                  ),
                ),
        ),

        // ---- Auteur (tapable → profil prestataire) ----
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: InkWell(
            onTap: widget.onProviderTap == null
                ? null
                : () => widget.onProviderTap?.call(post.author.id),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppTheme.primaryGreen.withValues(
                      alpha: 0.15,
                    ),
                    backgroundImage: post.author.avatar.isEmpty
                        ? null
                        : CachedNetworkImageProvider(post.author.avatar),
                    child: post.author.avatar.isEmpty
                        ? Icon(Icons.person, color: AppTheme.primaryGreen)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                post.author.fullName.isNotEmpty
                                    ? post.author.fullName
                                    : 'Prestataire',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            if (post.author.isVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified_rounded,
                                size: 16,
                                color: AppTheme.primaryGreen,
                              ),
                            ],
                          ],
                        ),
                        if (post.author.metier.isNotEmpty)
                          Text(
                            post.author.metier,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),
        ),

        // ---- Titre ----
        if (post.title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              post.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
                height: 1.3,
              ),
            ),
          ),

        // ---- Actions : like + compteur ----
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              IconButton(
                onPressed: _toggleLike,
                icon: Icon(
                  _liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: _liked ? Colors.redAccent : Colors.grey.shade500,
                  size: 26,
                ),
                tooltip: 'J\'aime',
              ),
              Text(
                '$_likeCount',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 20),
              Icon(
                Icons.comment_rounded,
                size: 24,
                color: Colors.grey.shade500,
              ),
              const SizedBox(width: 6),
              Text(
                '$_commentCount',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 24),

        // ---- En-tête commentaires + tri ----
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Commentaires',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _newestFirst = !_newestFirst),
                icon: Icon(
                  _newestFirst
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  size: 16,
                ),
                label: Text(_newestFirst ? 'Plus récents' : 'Plus anciens'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
        ),

        // ---- Commentaires ----
        if (displayed.isEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Aucun commentaire pour le moment. Soyez le premier !',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          )
        else
          ...displayed.map((c) => _CommentTile(comment: c)),
      ],
    );
  }

  /// Zone de saisie de commentaire en bas (style Facebook).
  ///
  /// Compacte au repos ; s'élargit et gagne en hauteur **dès que l'on commence
  /// à écrire** (focus → [AnimatedContainer] + `minLines`/`maxLines`).
  Widget _buildCommentInput() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      padding: EdgeInsets.symmetric(
        // Moins de marges quand focalisé → champ plus large.
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
                minLines: _focused ? 3 : 1,
                maxLines: _focused ? 6 : 2,
                style: const TextStyle(fontSize: 16, height: 1.3),
                decoration: InputDecoration(
                  hintText: 'Ajouter un commentaire…',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  filled: true,
                  fillColor: AppTheme.surfaceLight,
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
              color: AppTheme.primaryGreen,
              tooltip: 'Envoyer',
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte d'un commentaire.
class _CommentTile extends StatelessWidget {
  final FeedCommentModel comment;

  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.primaryGreen.withValues(alpha: 0.12),
            child: Icon(Icons.person, size: 18, color: AppTheme.primaryGreen),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    comment.userName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    comment.contenu,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.3,
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
