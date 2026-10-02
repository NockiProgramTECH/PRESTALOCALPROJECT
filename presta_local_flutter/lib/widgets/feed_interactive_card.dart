import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/constants.dart';
import '../models/feed_post_model.dart';
import '../providers/app_state_provider.dart';
import '../providers/auth_provider.dart';
import '../screens/feed/feed_composer_sheet.dart';
import '../screens/feed/feed_detail_screen.dart';
import '../services/api_client.dart';
import '../utils/feed_actions.dart';
import 'feed_card.dart';

/// Carte du fil **branchée sur l'API** : gère elle-même J'aime, partage,
/// modification et suppression, puis prévient son parent via [onUpdated] /
/// [onDeleted] pour que la liste reste cohérente.
///
/// Utilisée par l'accueil et par la page « Fil d'actualité » : les deux
/// écrans partagent donc exactement les mêmes interactions.
class FeedInteractiveCard extends ConsumerStatefulWidget {
  final FeedPostModel post;
  final bool compact;
  final ValueChanged<String>? onProviderTap;
  /// Appelé après une modification (like, édition) avec la version à jour.
  final ValueChanged<FeedPostModel>? onUpdated;
  /// Appelé après suppression, pour retirer la carte de la liste.
  final VoidCallback? onDeleted;
  /// Ouvre directement la zone de commentaire du détail.
  final bool focusComment;

  const FeedInteractiveCard({
    super.key,
    required this.post,
    this.compact = false,
    this.onProviderTap,
    this.onUpdated,
    this.onDeleted,
    this.focusComment = false,
  });

  @override
  ConsumerState<FeedInteractiveCard> createState() =>
      _FeedInteractiveCardState();
}

class _FeedInteractiveCardState extends ConsumerState<FeedInteractiveCard> {
  late FeedPostModel _post;
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
  }

  @override
  void didUpdateWidget(covariant FeedInteractiveCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nouveau = widget.post;
    if (nouveau.id != _post.id ||
        nouveau.likeCount != _post.likeCount ||
        nouveau.commentCount != _post.commentCount ||
        nouveau.isLiked != _post.isLiked ||
        nouveau.contenu != _post.contenu ||
        nouveau.categorieNom != _post.categorieNom ||
        nouveau.lien != _post.lien) {
      _post = nouveau;
    }
  }

  bool _estConnecte() {
    if (ref.read(authProvider).status == AuthStatus.authenticated) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Connectez-vous pour interagir avec les publications'),
      ),
    );
    return false;
  }

  Future<void> _toggleLike() async {
    if (_enCours || !_estConnecte()) return;
    _enCours = true;
    try {
      final result = await ref.read(feedServiceProvider).toggleLike(_post.id);
      if (!mounted) return;
      setState(() {
        _post = _post.copyWith(
          isLiked: result.liked,
          likeCount: result.likeCount,
        );
      });
      widget.onUpdated?.call(_post);
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack(AppConstants.errorNetwork);
    } finally {
      _enCours = false;
    }
  }

  Future<void> _partager() => FeedActions.sharePost(context, _post);

  Future<void> _ouvrirDetail({bool focusComment = false}) async {
    final modifie = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FeedDetailScreen(
          realisationId: _post.id,
          onProviderTap: widget.onProviderTap,
          focusComment: focusComment || widget.focusComment,
        ),
      ),
    );
    if (modifie == true) await _recharger();
  }

  Future<void> _modifier() async {
    final ok = await showFeedComposerSheet(context, edition: _post);
    if (ok == true) await _recharger();
  }

  Future<void> _supprimer() async {
    final confirme = await FeedActions.confirmDelete(context);
    if (!confirme) return;
    try {
      final ok = await ref.read(feedServiceProvider).delete(_post.id);
      if (!ok) {
        _snack('Suppression impossible');
        return;
      }
      ref.invalidate(feedPostsProvider);
      ref.invalidate(myFeedPostsProvider);
      if (!mounted) return;
      _snack('Publication supprimée');
      widget.onDeleted?.call();
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack(AppConstants.errorNetwork);
    }
  }

  /// Recharge la publication depuis le backend (jamais de valeur inventée).
  Future<void> _recharger() async {
    try {
      final frais = await ref.read(feedServiceProvider).getDetail(_post.id);
      if (!mounted) return;
      setState(() => _post = frais);
      widget.onUpdated?.call(_post);
    } catch (_) {
      // Silencieux : la liste sera rafraîchie au prochain chargement.
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return FeedCard(
      post: _post,
      compact: widget.compact,
      onTap: () => _ouvrirDetail(),
      onProviderTap: widget.onProviderTap,
      onLike: _toggleLike,
      onComment: () => _ouvrirDetail(focusComment: true),
      onShare: _partager,
      onEdit: _post.canEdit ? _modifier : null,
      onDelete: _post.canDelete ? _supprimer : null,
    );
  }
}
