part of '../feed_detail_screen.dart';

mixin _FeedDetailInterface on ConsumerState<FeedDetailScreen> {
  ScrollController get _scrollController;
  FocusNode get _commentFocus;
  bool get _loading;
  String? get _error;
  FeedPostModel? get _post;
  bool get _liked;
  List<FeedCommentModel> get _comments;
  bool get _newestFirst;
  set _newestFirst(bool value);
  Future<void> _load();
  Future<void> _toggleLike();
  Future<void> _partager();
  Future<void> _ouvrirImage(String url);

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
