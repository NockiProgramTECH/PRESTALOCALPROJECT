part of '../feed_detail_screen.dart';

class _FeedDetailScreenState extends ConsumerState<FeedDetailScreen> with _FeedDetailActions, _FeedDetailInterface {
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
  }  @override
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
  }}
