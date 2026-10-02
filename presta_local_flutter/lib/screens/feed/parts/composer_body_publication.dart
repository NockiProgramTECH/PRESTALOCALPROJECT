part of '../feed_composer_sheet.dart';

mixin _ComposerPublication on ConsumerState<FeedComposerSheet> {
  TextEditingController get _contenuController;
  TextEditingController get _titreController;
  TextEditingController get _lienController;
  List<FeedUpload> get _images;
  FeedUpload? get _video;
  int? get _categorieId;
  bool get _sending;
  set _sending(bool value);
  String? get _error;
  set _error(String? value);
  bool get _isEdition;
  bool get _vide;

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
}
