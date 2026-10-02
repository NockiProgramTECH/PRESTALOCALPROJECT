part of '../feed_composer_sheet.dart';

mixin _ComposerMedias on ConsumerState<FeedComposerSheet> {
  TextEditingController get _contenuController;
  TextEditingController get _lienController;
  ImagePicker get _picker;
  List<FeedUpload> get _images;
  FeedUpload? get _video;
  set _video(FeedUpload? value);
  int? get _categorieId;
  set _categorieId(int? value);
  String get _categorieNom;
  set _categorieNom(String value);
  String? get _error;
  set _error(String? value);

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

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
  }
}
