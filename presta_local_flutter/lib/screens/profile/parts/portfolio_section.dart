part of '../profile_screen.dart';

/// ============================================================================
/// MON PORTFOLIO (comme l'onglet Portfolio web : grille + ajout + suppression)
/// ============================================================================
class _PortfolioSection extends ConsumerWidget {
  const _PortfolioSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mineAsync = ref.watch(myFeedPostsProvider);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Mon Portfolio',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navy,
                  ),
                ),
              ),
              // Thème global : minimumSize infini en largeur → dans un Row
              // (largeur non bornée) ça crash. On surcharge en taille compacte.
              ElevatedButton.icon(
                onPressed: () async {
                  // Même panneau de rédaction que le fil d'actualité
                  // (texte et/ou plusieurs photos, vidéo, lien, catégorie).
                  final created = await showFeedComposerSheet(context);
                  if (created == true) {
                    ref.invalidate(myFeedPostsProvider);
                    ref.invalidate(feedPostsProvider);
                  }
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Ajouter'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          mineAsync.when(
            data: (posts) {
              if (posts.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.inputFill,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        size: 32,
                        color: AppTheme.muted,
                      ),
                      SizedBox(height: 6),
                      Text(
                        "Vous n'avez pas encore de réalisations dans votre portfolio.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppTheme.muted),
                      ),
                    ],
                  ),
                );
              }
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: posts.length,
                itemBuilder: (context, i) {
                  final post = posts[i];
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: post.imageUrl.isEmpty
                            ? Container(
                                color: AppTheme.inputFill,
                                alignment: Alignment.center,
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  post.text.isEmpty
                                      ? 'Publication'
                                      : post.text,
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.navy,
                                  ),
                                ),
                              )
                            : CachedNetworkImage(
                          imageUrl: post.imageUrl,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: AppTheme.inputFill,
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: AppTheme.inputFill,
                            child: const Icon(
                              Icons.image_outlined,
                              color: AppTheme.muted,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _confirmDelete(context, ref, post.id),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
            // Pas de `Center` ici : dans un SingleChildScrollView la hauteur
            // est non bornée → "Cannot hit test a render box with no size"
            // + page blanche. Hauteur fixe à la place.
            loading: () => const SizedBox(
              height: 120,
              child: Align(
                alignment: Alignment.center,
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, __) => const Text(
              'Portfolio indisponible.',
              style: TextStyle(color: AppTheme.muted),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: const Text(
          'Voulez-vous supprimer cette réalisation ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(feedServiceProvider).delete(id);
      ref.invalidate(myFeedPostsProvider);
      ref.invalidate(feedPostsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Réalisation supprimée.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Suppression impossible — réessayez')),
        );
      }
    }
  }
}
