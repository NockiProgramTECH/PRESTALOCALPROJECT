part of '../feed_composer_sheet.dart';

/// Bouton compact de la barre d'outils médias.
class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _ToolButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon),
      color: AppTheme.primary,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Vignettes des médias choisis, avec bouton de retrait.
class _MediaPreview extends StatelessWidget {
  final List<FeedUpload> images;
  final FeedUpload? video;
  final ValueChanged<int>? onRemoveImage;
  final VoidCallback? onRemoveVideo;

  const _MediaPreview({
    required this.images,
    required this.video,
    required this.onRemoveImage,
    required this.onRemoveVideo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (images.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: images.length,
            itemBuilder: (context, index) => Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(images[index].bytes, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: onRemoveImage == null
                        ? null
                        : () => onRemoveImage!(index),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (video != null)
          Padding(
            padding: EdgeInsets.only(top: images.isEmpty ? 0 : 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.inputFill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.videocam_rounded,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      video!.filename,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.navy,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onRemoveVideo,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Avatar rond avec repli sur une icône.
class _Avatar extends StatelessWidget {
  final String? url;
  final double radius;

  const _Avatar({required this.url, this.radius = 18});

  @override
  Widget build(BuildContext context) {
    final value = url ?? '';
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.primarySoft,
      backgroundImage: value.isEmpty
          ? null
          : CachedNetworkImageProvider(value),
      child: value.isEmpty
          ? Icon(Icons.person, size: radius, color: AppTheme.primary)
          : null,
    );
  }
}
