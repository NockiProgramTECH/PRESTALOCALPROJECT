part of '../feed_composer_sheet.dart';

class _FeedComposerSheetState extends ConsumerState<FeedComposerSheet> with _ComposerMedias, _ComposerPublication {
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
  }  // ---- Interface ---------------------------------------------------------

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
