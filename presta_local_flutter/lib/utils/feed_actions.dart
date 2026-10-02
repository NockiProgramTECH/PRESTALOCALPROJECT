import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/constants.dart';
import '../config/theme.dart';
import '../models/feed_post_model.dart';

const List<String> _moisFr = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

/// Heure locale au format `14:05` (sans dépendance de locale intl).
String _heure(DateTime date) {
  final h = date.hour.toString().padLeft(2, '0');
  final m = date.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// Date relative « style réseau social » : « À l'instant », « Il y a 12 min »,
/// « Hier à 14:05 », « 3 septembre ».
///
/// Écrit à la main (mois français) pour ne dépendre d'aucune donnée de locale
/// `intl` initialisée au démarrage.
String formatFeedTime(DateTime date) {
  if (date.millisecondsSinceEpoch == 0) return '';
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.inMinutes < 1) return "À l'instant";
  if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
  if (diff.inHours < 24 && now.day == date.day) {
    return "Aujourd'hui à ${_heure(date)}";
  }
  final hier = now.subtract(const Duration(days: 1));
  if (hier.day == date.day && hier.month == date.month) {
    return 'Hier à ${_heure(date)}';
  }
  final mois = _moisFr[date.month - 1];
  if (date.year == now.year) return '${date.day} $mois';
  return '${date.day} $mois ${date.year}';
}

/// Domaine lisible d'une URL (pour l'aperçu du lien externe).
String feedLinkHost(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.host.isEmpty) return url;
  return uri.host.replaceFirst('www.', '');
}

/// Actions transverses du fil d'actualité.
///
/// Regroupées ici pour que l'accueil, la page « Fil d'actualité », la carte
/// et le détail d'une publication partagent exactement le même comportement
/// (J'aime, partage, lien externe).
class FeedActions {
  FeedActions._();

  /// Lien public d'une publication : la fiche du prestataire sur le site.
  static String postLink(FeedPostModel post) {
    if (post.author.id.isEmpty) return AppConstants.webBaseUrl;
    return '${AppConstants.webBaseUrl}/prestataire/${post.author.id}/';
  }

  /// Texte proposé lors d'un partage.
  static String shareText(FeedPostModel post) {
    final extrait = post.text.trim();
    final court = extrait.length > 120 ? '${extrait.substring(0, 120)}…' : extrait;
    final entete = post.author.fullName.isEmpty
        ? 'Découvrez cette publication sur LesProduFao'
        : 'Publication de ${post.author.fullName} sur LesProduFao';
    return court.isEmpty ? entete : '$entete : $court';
  }

  /// Ouvre la feuille de partage : copier le lien ou partager via WhatsApp.
  static Future<void> sharePost(
    BuildContext context,
    FeedPostModel post,
  ) async {
    final lien = postLink(post);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [
                    Icon(Icons.share_rounded, color: AppTheme.primary),
                    SizedBox(width: 10),
                    Text(
                      'Partager la publication',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.navy,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.link_rounded),
                title: const Text('Copier le lien'),
                subtitle: Text(
                  lien,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: lien));
                  if (!sheetContext.mounted) return;
                  Navigator.of(sheetContext).pop();
                  _snack(context, 'Lien copié dans le presse-papiers');
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.chat_rounded,
                  color: Color(0xFF25D366),
                ),
                title: const Text('Partager via WhatsApp'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final texte = Uri.encodeComponent(
                    '${shareText(post)}\n$lien',
                  );
                  await openExternal(
                    context,
                    'https://wa.me/?text=$texte',
                    errorMessage: 'WhatsApp indisponible sur cet appareil',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.open_in_new_rounded),
                title: const Text('Ouvrir la fiche du prestataire'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  openExternal(context, lien);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  /// Ouvre une URL externe (navigateur / application) avec message d'erreur.
  static Future<bool> openExternal(
    BuildContext context,
    String url, {
    String errorMessage = 'Impossible d\'ouvrir ce lien',
  }) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) {
      _snack(context, 'Lien invalide');
      return false;
    }
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) _snack(context, errorMessage);
      return ok;
    } catch (_) {
      if (context.mounted) _snack(context, errorMessage);
      return false;
    }
  }

  /// Confirmation de suppression d'une publication.
  static Future<bool> confirmDelete(
    BuildContext context, {
    String message =
        'Cette publication sera définitivement supprimée. Continuer ?',
  }) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer la publication'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    return confirme == true;
  }

  /// Message court affiché en bas de l'écran.
  static void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
