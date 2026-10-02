import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/feed_post_model.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/shimmer_loading.dart';
import '../../utils/feed_actions.dart';
import 'feed_composer_sheet.dart';

part 'parts/detail_body.dart';
part 'parts/detail_widgets.dart';
part 'parts/detail_body_actions.dart';
part 'parts/detail_body_interface.dart';

/// Page détail d'une publication.
///
/// Affiche l'auteur (tapable vers sa fiche), le texte complet, les médias
/// (galerie si plusieurs images), le lien, puis les **vraies** interactions :
/// J'aime, commentaires (chargés depuis l'API) et partage. L'auteur peut
/// modifier ou supprimer sa publication ; cette page renvoie alors `true`
/// au fil pour qu'il rafraîchisse la carte.

class FeedDetailScreen extends ConsumerStatefulWidget {
  final String realisationId;
  final ValueChanged<String>? onProviderTap;
  /// Ouvre la page avec le champ de commentaire déjà focalisé.
  final bool focusComment;

  const FeedDetailScreen({
    super.key,
    required this.realisationId,
    this.onProviderTap,
    this.focusComment = false,
  });

  @override
  ConsumerState<FeedDetailScreen> createState() => _FeedDetailScreenState();
}
