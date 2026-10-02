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

class _FeedComposerSheetState extends ConsumerState<FeedComposerSheet> {
  final _contenuController = TextEditingController();
  final _titreController = TextEditingController();
  final _lienController = TextEditingController();
  final _picker = ImagePicker();

  final List<FeedUpload> _images = [];
  FeedUpload? _video;
  int? _categorieId;
  String _categorieNom = '';

  bool _sending = false;
  String? _error;

  bool get _isEdition => widget.edition != null;

  @override
  void initState() {
    super.initState();
    final edition = widget.edition;
    if (edition != null) {
      _contenuController.text = edition.contenu.isNotEmpty
          ? edition.contenu
          : edition.title;
      _titreController.text = edition.title;
      _lienController.text = edition.lien;
      _categorieNom = edition.categorieNom;
    }
  }

  @override
  void dispose() {
    _contenuController.dispose();
    _titreController.dispose();
    _lienController.dispose();
    super.dispose();
  }

  // ---- Sélection des médias -------------------------------------------

  String _extension(String filename) {
    final parts = filename.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  Future<void> _pickImages() async {
    if (_images.length >= kMaxPublicationImages) {
      _showError(
        'Maximum $kMaxPublicationImages images par publication.',
      );
      return;
    }
    try {
      final picked = await _picker.pickMultiImage(
        maxWidth: 1800,
        imageQuality: 85,
      );
      if (picked.isEmpty) return;
      final ajouts = <FeedUpload>[];
      for (final file in picked) {
        final nom = file.name.isNotEmpty ? file.name : 'photo.jpg';
        if (!kImageExtensions.contains(_extension(nom))) {
          _showError('Format d\'image non accepté : $nom (JPG, PNG ou WEBP).');
          continue;
        }
        final bytes = await file.readAsBytes();
        if (bytes.lengthInBytes > kMaxImageBytes) {
          _showError('« $nom » dépasse 5 Mo.');
          continue;
        }
        if (_images.length + ajouts.length >= kMaxPublicationImages) {
          _showError('Maximum $kMaxPublicationImages images par publication.');
          break;
        }
        ajouts.add(FeedUpload(bytes: bytes, filename: nom));
      }
      if (ajouts.isEmpty) return;
      setState(() {
        _images.addAll(ajouts);
        _error = null;
      });
    } catch (_) {
      _showError('Sélection d\'images impossible.');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final picked = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 3),
      );
      if (picked == null) return;
      final nom = picked.name.isNotEmpty ? picked.name : 'video.mp4';
      if (!kVideoExtensions.contains(_extension(nom))) {
        _showError('Format vidéo non accepté : $nom (MP4, MOV, M4V ou WEBM).');
        return;
      }
      final bytes = await picked.readAsBytes();
      if (bytes.lengthInBytes > kMaxVideoBytes) {
        _showError('La vidéo dépasse 50 Mo.');
        return;
      }
      setState(() {
        _video = FeedUpload(bytes: bytes, filename: nom, isVideo: true);
        _error = null;
      });
    } catch (_) {
      _showError('Sélection de vidéo impossible.');
    }
  }

  Future<void> _pickCategorie() async {
    List<CategoryModel> categories;
    try {
      categories = await ref.read(categoriesProvider.future);
    } catch (_) {
      _showError('Catégories indisponibles pour le moment.');
      return;
    }
    if (!mounted || categories.isEmpty) return;
    final choix = await showModalBottomSheet<CategoryModel>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Catégorie de la publication',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          for (final categorie in categories)
            ListTile(
              title: Text(categorie.name),
              leading: Icon(
                _categorieId != null &&
                        _categorieId.toString() == categorie.id
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: _categorieId != null &&
                        _categorieId.toString() == categorie.id
                    ? AppTheme.primary
                    : AppTheme.muted,
              ),
              onTap: () => Navigator.of(sheetContext).pop(categorie),
            ),
          ListTile(
            leading: const Icon(Icons.clear_rounded),
            title: const Text('Aucune catégorie'),
            onTap: () => Navigator.of(sheetContext).pop(
              const CategoryModel(
                id: '',
                name: '',
                icon: '',
                description: '',
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
    if (choix == null) return;
    setState(() {
      _categorieId = int.tryParse(choix.id);
      _categorieNom = choix.name;
    });
  }

  // ---- Publication ------------------------------------------------------

  bool get _vide =>
      _contenuController.text.trim().isEmpty &&
      _images.isEmpty &&
      _video == null &&
      _lienController.text.trim().isEmpty;

  Future<void> _publier() async {
    if (_sending) return;
    if (_vide) {
      setState(
        () => _error =
            'Ajoutez un texte, une photo, une vidéo ou un lien avant de publier.',
      );
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final service = ref.read(feedServiceProvider);
    try {
      if (_isEdition) {
        await service.update(
          widget.edition!.id,
          contenu: _contenuController.text.trim(),
          lien: _lienController.text.trim(),
          categorieId: _categorieId,
          clearCategorie:
              _categorieId == null && widget.edition!.categorieNom.isNotEmpty,
        );
      } else {
        await service.createPublication(
          contenu: _contenuController.text,
          titre: _titreController.text,
          images: List.of(_images),
          video: _video,
          lien: _lienController.text,
          categorieId: _categorieId,
        );
      }
      // Rafraîchit le fil et le portfolio : la publication vient du backend.
      ref.invalidate(feedPostsProvider);
      ref.invalidate(myFeedPostsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdition
                ? 'Publication modifiée avec succès'
                : 'Publication ajoutée à votre fil',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      // Échec serveur : on ne prétend jamais que la publication est enregistrée.
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'Publication impossible — vérifiez votre connexion.';
      });
    }
  }

  Future<void> _fermer() async {
    final brouillon =
        _contenuController.text.trim().isNotEmpty ||
        _images.isNotEmpty ||
        _video != null;
    if (!brouillon || _isEdition) {
      Navigator.of(context).pop(false);
      return;
    }
    final quitter = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Abandonner la publication ?'),
        content: const Text('Le texte et les médias sélectionnés seront perdus.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Continuer la rédaction'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('Abandonner'),
          ),
        ],
      ),
    );
    if (quitter == true && mounted) Navigator.of(context).pop(false);
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
  }

  // ---- Interface ---------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;

    return ConstrainedBox(
      // Le panneau ne dépasse jamais 92 % de l'écran, clavier ouvert compris.
      constraints: BoxConstraints(
        maxHeight: media.size.height * 0.92 - bottomInset,
      ),
      child: Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ---- Barre de titre ----
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
            child: Row(
              children: [
                IconButton(
                  onPressed: _sending ? null : _fermer,
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Fermer',
                ),
                Expanded(
                  child: Text(
                    _isEdition ? 'Modifier la publication' : 'Créer une publication',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.navy,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // ---- Contenu ----
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Auteur
                  Row(
                    children: [
                      _Avatar(url: auth.userPhoto, radius: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.userName?.isNotEmpty == true
                                  ? auth.userName!
                                  : 'Vous',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.navy,
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(top: 3),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.inputFill,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.public_rounded,
                                    size: 12,
                                    color: AppTheme.muted,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Publique',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Texte multiligne
                  TextField(
                    controller: _contenuController,
                    autofocus: !_isEdition,
                    minLines: 3,
                    maxLines: 12,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(fontSize: 16, height: 1.35),
                    decoration: const InputDecoration(
                      hintText: 'Quoi de neuf dans votre activité ?',
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                  ),
                  // Aperçu des médias sélectionnés
                  if (_images.isNotEmpty || _video != null) ...[
                    const SizedBox(height: 12),
                    _MediaPreview(
                      images: _images,
                      video: _video,
                      onRemoveImage: _sending
                          ? null
                          : (index) => setState(() => _images.removeAt(index)),
                      onRemoveVideo: _sending
                          ? null
                          : () => setState(() => _video = null),
                    ),
                  ],
                  // Lien externe
                  const SizedBox(height: 12),
                  TextField(
                    controller: _lienController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Lien externe (optionnel)',
                      hintText: 'https://…',
                      prefixIcon: Icon(Icons.link_rounded),
                    ),
                  ),
                  // Catégorie choisie
                  if (_categorieNom.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Chip(
                        avatar: const Icon(
                          Icons.label_outline_rounded,
                          size: 16,
                          color: AppTheme.primary,
                        ),
                        label: Text(_categorieNom),
                        onDeleted: _sending
                            ? null
                            : () => setState(() {
                                _categorieId = null;
                                _categorieNom = '';
                              }),
                      ),
                    ),
                  // Erreur de validation / d'envoi
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 18,
                            color: AppTheme.danger,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.danger,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Barre d'outils médias (création seulement : PATCH ne
                  // remplace pas les fichiers déjà en ligne).
                  if (!_isEdition) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.cardBorder),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Ajouter à votre publication',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.navy,
                              ),
                            ),
                          ),
                          _ToolButton(
                            icon: Icons.photo_library_outlined,
                            tooltip: 'Photos',
                            onTap: _sending ? null : _pickImages,
                          ),
                          _ToolButton(
                            icon: Icons.videocam_outlined,
                            tooltip: 'Vidéo',
                            onTap: _sending ? null : _pickVideo,
                          ),
                          _ToolButton(
                            icon: Icons.label_outline_rounded,
                            tooltip: 'Catégorie',
                            onTap: _sending ? null : _pickCategorie,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // ---- Bouton Publier ----
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _sending ? null : _publier,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  _sending
                      ? 'Envoi en cours…'
                      : (_isEdition ? 'Enregistrer' : 'Publier'),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

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
