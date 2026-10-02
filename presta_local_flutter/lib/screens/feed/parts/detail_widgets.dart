part of '../feed_detail_screen.dart';

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
