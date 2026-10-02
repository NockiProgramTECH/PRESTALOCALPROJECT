import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/feed_post_model.dart';
import '../utils/feed_actions.dart';

part 'parts/feed_card_widgets.dart';

/// Carte sociale d'une publication du fil d'actualité.
///
/// Reprend les codes d'un fil d'actualité moderne (sans reprendre l'identité
/// graphique de Facebook) : en-tête auteur, texte, médias, compteurs réels et
/// barre d'actions **J'aime / Commenter / Partager**. Les actions sont
/// déléguées au parent via les rappels ([onLike], [onComment], [onShare],
/// [onEdit], [onDelete]) : la carte n'invente jamais un compteur elle-même.

class FeedCard extends StatelessWidget {
  final FeedPostModel post;
  /// Ouvre le détail de la publication.
  final VoidCallback? onTap;
  /// Aperçu compact (utilisé par l'accueil) : un seul média, texte limité.
  final bool compact;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final ValueChanged<String>? onProviderTap;

  const FeedCard({
    super.key,
    required this.post,
    this.onTap,
    this.compact = false,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onEdit,
    this.onDelete,
    this.onProviderTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.cardDecoration.copyWith(
        borderRadius: BorderRadius.circular(18),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(context),
                if (post.text.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                    child: _ExpandableText(
                      text: post.text,
                      collapsedLines: compact ? 4 : 8,
                    ),
                  ),
                _PostMedia(post: post, compact: compact),
                if (post.categorieNom.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: _CategoryChip(label: post.categorieNom),
                  ),
                if (post.lien.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                    child: _LinkPreview(url: post.lien),
                  ),
              ],
            ),
          ),
          _buildCounters(context),
          const Divider(height: 1),
          _buildActionBar(context),
        ],
      ),
    );
  }

  // ---- En-tête : auteur, métier, ville, date, menu -----------------------

  Widget _buildHeader(BuildContext context) {
    final author = post.author;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onProviderTap == null || author.id.isEmpty
                ? null
                : () => onProviderTap!(author.id),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: AppTheme.primarySoft,
              backgroundImage: author.avatar.isEmpty
                  ? null
                  : CachedNetworkImageProvider(author.avatar),
              child: author.avatar.isEmpty
                  ? const Icon(Icons.person, color: AppTheme.primary, size: 20)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: onProviderTap == null || author.id.isEmpty
                  ? null
                  : () => onProviderTap!(author.id),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          author.fullName.isNotEmpty
                              ? author.fullName
                              : 'Prestataire',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.navy,
                          ),
                        ),
                      ),
                      if (author.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified_rounded,
                          size: 15,
                          color: AppTheme.success,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _metaLigne(author),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onEdit != null || onDelete != null)
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_horiz_rounded,
                color: AppTheme.muted,
              ),
              tooltip: 'Actions',
              onSelected: (value) {
                if (value == 'edit') onEdit?.call();
                if (value == 'delete') onDelete?.call();
              },
              itemBuilder: (_) => [
                if (onEdit != null)
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_outlined, size: 20),
                      title: Text('Modifier'),
                    ),
                  ),
                if (onDelete != null)
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: AppTheme.danger,
                      ),
                      title: Text(
                        'Supprimer',
                        style: TextStyle(color: AppTheme.danger),
                      ),
                    ),
                  ),
              ],
            )
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }

  String _metaLigne(FeedAuthorModel author) {
    final morceaux = <String>[];
    if (author.metier.isNotEmpty) morceaux.add(author.metier);
    if (author.ville.isNotEmpty) morceaux.add(author.ville);
    final quand = formatFeedTime(post.date);
    if (quand.isNotEmpty) morceaux.add(quand);
    return morceaux.join(' · ');
  }

  // ---- Compteurs (données réelles du backend) ---------------------------

  Widget _buildCounters(BuildContext context) {
    final aDesCompteurs = post.likeCount > 0 || post.commentCount > 0;
    if (!aDesCompteurs && post.modifieLe == null) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Row(
        children: [
          if (post.likeCount > 0) ...[
            _Counter(
              icon: Icons.favorite_rounded,
              color: AppTheme.danger,
              label: '${post.likeCount}',
            ),
            const SizedBox(width: 14),
          ],
          if (post.commentCount > 0)
            _Counter(
              icon: Icons.mode_comment_rounded,
              color: AppTheme.muted,
              label: post.commentCount > 1
                  ? '${post.commentCount} commentaires'
                  : '${post.commentCount} commentaire',
            ),
          const Spacer(),
          if (post.modifieLe != null)
            const Text(
              'Modifiée',
              style: TextStyle(fontSize: 11.5, color: AppTheme.muted),
            ),
        ],
      ),
    );
  }

  // ---- Barre d'actions ---------------------------------------------------

  Widget _buildActionBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              icon: post.isLiked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              label: "J'aime",
              active: post.isLiked,
              onTap: onLike,
            ),
          ),
          Expanded(
            child: _ActionButton(
              icon: Icons.mode_comment_outlined,
              label: 'Commenter',
              onTap: onComment,
            ),
          ),
          Expanded(
            child: _ActionButton(
              icon: Icons.share_outlined,
              label: 'Partager',
              onTap: onShare,
            ),
          ),
        ],
      ),
    );
  }
}
