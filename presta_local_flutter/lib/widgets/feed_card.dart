import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/feed_post_model.dart';
import '../utils/feed_actions.dart';

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

/// Texte repliable : « Voir plus » au-delà de [collapsedLines] lignes.
class _ExpandableText extends StatefulWidget {
  final String text;
  final int collapsedLines;

  const _ExpandableText({required this.text, this.collapsedLines = 8});

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    // Les textes courts s'affichent entièrement, sans lien inutile.
    if (widget.text.length < 220) {
      return Text(
        widget.text,
        style: const TextStyle(fontSize: 14.5, height: 1.35, color: AppTheme.navy),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.text,
          maxLines: _expanded ? null : widget.collapsedLines,
          overflow: _expanded ? null : TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14.5,
            height: 1.35,
            color: AppTheme.navy,
          ),
        ),
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _expanded ? 'Voir moins' : 'Voir plus',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.muted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Médias de la publication : images (1, 2 ou plusieurs), vidéo.
class _PostMedia extends StatelessWidget {
  final FeedPostModel post;
  final bool compact;

  const _PostMedia({required this.post, required this.compact});

  @override
  Widget build(BuildContext context) {
    final images = post.images;
    if (images.isEmpty && post.videoUrl.isEmpty) return const SizedBox.shrink();

    if (images.isEmpty) {
      return _VideoTile(url: post.videoUrl, compact: compact);
    }

    if (compact) {
      return _SingleImage(
        url: images.first,
        remaining: images.length - 1,
        aspectRatio: 16 / 9,
      );
    }

    if (images.length == 1) {
      return _SingleImage(url: images.first, aspectRatio: 4 / 3);
    }

    if (images.length == 2) {
      return SizedBox(
        height: 200,
        child: Row(
          children: [
            Expanded(child: _GridImage(url: images[0])),
            const SizedBox(width: 2),
            Expanded(child: _GridImage(url: images[1])),
          ],
        ),
      );
    }

    // 3 images et plus : grille 2 colonnes, 4 vignettes maximum, la dernière
    // affichant le nombre de photos restantes.
    final visibles = images.take(4).toList();
    final restantes = images.length - visibles.length;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: visibles.length,
      itemBuilder: (context, index) => _GridImage(
        url: visibles[index],
        overlayLabel: index == visibles.length - 1 && restantes > 0
            ? '+$restantes'
            : null,
      ),
    );
  }
}

class _SingleImage extends StatelessWidget {
  final String url;
  final int remaining;
  final double aspectRatio;

  const _SingleImage({
    required this.url,
    this.remaining = 0,
    this.aspectRatio = 4 / 3,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _GridImage(url: url),
          if (remaining > 0)
            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '+$remaining photos',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GridImage extends StatelessWidget {
  final String url;
  final String? overlayLabel;

  const _GridImage({required this.url, this.overlayLabel});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          fadeInDuration: const Duration(milliseconds: 200),
          placeholder: (context, url) => Container(
            color: AppTheme.inputFill,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: AppTheme.inputFill,
            child: const Icon(
              Icons.broken_image_outlined,
              color: AppTheme.muted,
            ),
          ),
        ),
        if (overlayLabel != null)
          Container(
            color: Colors.black45,
            alignment: Alignment.center,
            child: Text(
              overlayLabel!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

/// Vignette vidéo : lance la lecture dans l'application externe.
class _VideoTile extends StatelessWidget {
  final String url;
  final bool compact;

  const _VideoTile({required this.url, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: compact ? 16 / 9 : 4 / 3,
      child: GestureDetector(
        onTap: () => FeedActions.openExternal(
          context,
          url,
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
                  size: 58,
                  color: Colors.white,
                ),
                SizedBox(height: 6),
                Text(
                  'Lire la vidéo',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Aperçu du lien externe joint à la publication.
class _LinkPreview extends StatelessWidget {
  final String url;

  const _LinkPreview({required this.url});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => FeedActions.openExternal(context, url),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.inputFill,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.link_rounded, color: AppTheme.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    feedLinkHost(url),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.navy,
                    ),
                  ),
                  Text(
                    url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: AppTheme.muted),
                  ),
                ],
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
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;

  const _CategoryChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: AppTheme.primaryPressed,
        ),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _Counter({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppTheme.muted,
          ),
        ),
      ],
    );
  }
}

/// Bouton de la barre d'actions (J'aime / Commenter / Partager).
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _ActionButton({
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
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
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
