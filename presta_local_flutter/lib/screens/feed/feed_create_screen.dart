import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/theme.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';

/// Écran de publication d'une réalisation (portfolio prestataire).
///
/// Équivalent mobile de `add_realisation` côté web
/// (`POST /profile/realisation/add/`) : envoie `titre` + `image`
/// en multipart sur `POST /api/feed/`.
class FeedCreateScreen extends ConsumerStatefulWidget {
  const FeedCreateScreen({super.key});

  @override
  ConsumerState<FeedCreateScreen> createState() => _FeedCreateScreenState();
}

class _FeedCreateScreenState extends ConsumerState<FeedCreateScreen> {
  final _titreController = TextEditingController();
  final _picker = ImagePicker();
  Uint8List? _imageBytes;
  String? _filename;
  bool _sending = false;

  @override
  void dispose() {
    _titreController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _imageBytes = bytes;
      _filename = picked.name.isNotEmpty ? picked.name : 'realisation.jpg';
    });
  }

  Future<void> _publish() async {
    final titre = _titreController.text.trim();
    if (_imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez une photo à publier')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final service = ref.read(feedServiceProvider);
      await service.create(
        titre: titre,
        imageBytes: _imageBytes!,
        filename: _filename ?? 'realisation.jpg',
      );
      ref.invalidate(feedPostsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Réalisation publiée avec succès')),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publication impossible — réessayez')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isProvider =
        auth.status == AuthStatus.authenticated && auth.isProvider;

    return Scaffold(
      backgroundColor: AppTheme.surfaceLight,
      appBar: AppBar(title: const Text('Publier une réalisation')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isProvider)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Seuls les comptes prestataires peuvent publier des réalisations.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF92400E)),
                ),
              ),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: _imageBytes == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 44,
                            color: AppTheme.muted,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Touchez pour choisir une photo',
                            style: TextStyle(color: AppTheme.muted),
                          ),
                        ],
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(_imageBytes!, fit: BoxFit.cover),
                          const Positioned(
                            right: 8,
                            bottom: 8,
                            child: CircleAvatar(
                              backgroundColor: Colors.black54,
                              child: Icon(
                                Icons.edit_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titreController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Titre (optionnel)',
                hintText: 'Ex : Rénovation villa à Ouaga 2000',
                prefixIcon: Icon(Icons.title_rounded),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: (_sending || !isProvider) ? null : _publish,
              icon: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_upload_outlined, size: 20),
              label: Text(_sending ? 'Publication...' : 'Publier'),
            ),
          ],
        ),
      ),
    );
  }
}
