import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/feed_post_model.dart';

/// Carte d'une réalisation du fil d'actualité.
///
/// Affiche l'image du travail effectué, l'auteur (prestataire local) et les
/// compteurs like/commentaire. Réutilisée dans le carrousel de l'accueil et la
/// page « Fil d'actualité » dédiée.
class FeedCard extends StatelessWidget {
  final FeedPostModel post;
  final VoidCallback? onTap;
  final bool compact;

  const FeedCard({
    super.key,
    required this.post,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ---- Image de la réalisation ----
            AspectRatio(
              aspectRatio: 16 / 9,
              child: post.imageUrl.isEmpty
                  ? Container(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: AppTheme.primaryGreen.withValues(alpha: 0.4),
                        size: 36,
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: post.imageUrl,
                      fit: BoxFit.cover,
                      // Fond disparaît progressivement dès que l'image est prête.
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
                          size: 36,
                        ),
                      ),
                    ),
            ),

            // ---- Corps de la carte ----
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Titre de la réalisation (facultatif)
                  if (post.title.isNotEmpty) ...[
                    Text(
                      post.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Auteur : avatar + nom + métier
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppTheme.primaryGreen.withValues(
                          alpha: 0.15,
                        ),
                        backgroundImage: post.author.avatar.isEmpty
                            ? null
                            : CachedNetworkImageProvider(post.author.avatar),
                        child: post.author.avatar.isEmpty
                            ? Icon(
                                Icons.person,
                                size: 18,
                                color: AppTheme.primaryGreen,
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
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
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                if (post.author.isVerified) ...[
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.verified_rounded,
                                    size: 14,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ],
                              ],
                            ),
                            if (post.author.metier.isNotEmpty)
                              Text(
                                post.author.metier,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Statistiques : ville + like/commentaire
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          post.author.ville.isNotEmpty
                              ? post.author.ville
                              : 'Local',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      _Stat(
                        icon: Icons.favorite_rounded,
                        count: post.likeCount,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(width: 12),
                      _Stat(
                        icon: Icons.comment_rounded,
                        count: post.commentCount,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compteur statique (like / commentaire).
class _Stat extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;

  const _Stat({
    required this.icon,
    required this.count,
    this.color = Colors.grey,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}
