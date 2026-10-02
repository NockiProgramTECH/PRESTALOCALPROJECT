part of '../feed_detail_screen.dart';

mixin _FeedDetailActions on ConsumerState<FeedDetailScreen> {
  TextEditingController get _commentController;
  ScrollController get _scrollController;
  FeedPostModel? get _post;
  bool get _liked;
  set _liked(bool value);
  int get _likeCount;
  set _likeCount(int value);
  int get _commentCount;
  set _commentCount(int value);
  List<FeedCommentModel> get _comments;
  bool get _newestFirst;
  bool get _sending;
  set _sending(bool value);
  bool get _modifie;
  set _modifie(bool value);
  Future<void> _load();

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

  bool _requireLogin(String action) {
    if (ref.read(authProvider).status == AuthStatus.authenticated) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Connectez-vous pour $action')),
    );
    return false;
  }
}
