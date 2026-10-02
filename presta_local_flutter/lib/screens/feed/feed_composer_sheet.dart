import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/theme.dart';
import '../../models/category_model.dart';
import '../../models/feed_post_model.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../services/feed_service.dart';

part 'parts/composer_body.dart';
part 'parts/composer_widgets.dart';
part 'parts/composer_body_medias.dart';
part 'parts/composer_body_publication.dart';

/// Limites d'envoi, identiques à celles validées par le backend.

const int kMaxPublicationImages = 10;
const int kMaxImageBytes = 5 * 1024 * 1024; // 5 Mo
const int kMaxVideoBytes = 50 * 1024 * 1024; // 50 Mo
const Set<String> kImageExtensions = {'jpg', 'jpeg', 'png', 'webp'};
const Set<String> kVideoExtensions = {'mp4', 'mov', 'm4v', 'webm'};

/// Ouvre l'interface de rédaction (panneau modal) type « Quoi de neuf ? ».
///
/// [edition] non nul = modification d'une publication existante (texte, lien,
/// catégorie). Retourne `true` si une publication a été créée ou modifiée.
Future<bool?> showFeedComposerSheet(
  BuildContext context, {
  FeedPostModel? edition,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => FeedComposerSheet(edition: edition),
  );
}

/// Panneau de création / modification d'une publication.
///
/// Valide les médias **côté application** (nombre, taille, extension) avant
/// l'envoi, et n'affiche un message de réussite que si le backend a bien
/// répondu 2xx : en cas d'échec, la publication reste ouverte avec l'erreur.
class FeedComposerSheet extends ConsumerStatefulWidget {
  final FeedPostModel? edition;

  const FeedComposerSheet({super.key, this.edition});

  @override
  ConsumerState<FeedComposerSheet> createState() => _FeedComposerSheetState();
}
