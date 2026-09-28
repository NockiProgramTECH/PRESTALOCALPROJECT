import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';

/// ---------------------------------------------------------------------------
/// Écran de configuration du profil
///
/// Permet de modifier les informations personnelles (prénom, nom, téléphone,
/// bio, quartier) + ville, métier et années d'expérience (prestataires),
/// et d'uploader la photo de profil. Enregistre via PATCH `/api/auth/me/`
/// (JSON pour les champs, multipart pour la photo) puis rafraîchit l'état.
/// ---------------------------------------------------------------------------
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _bioController;
  late final TextEditingController _quartierController;
  late final TextEditingController _anneeController;

  bool _saving = false;
  bool _uploadingPhoto = false;
  String? _error;

  // Options des menus déroulants
  List<ListOption> _villes = [];
  List<ListOption> _metiers = [];
  int? _selectedVilleId;
  int? _selectedMetierId;

  // Photo locale sélectionnée (à afficher avant upload)
  Uint8List? _localPhotoBytes;

  bool get _isProvider =>
      ref.read(authServiceProvider).currentUser?.isProvider ?? false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authServiceProvider).currentUser;
    _firstNameController = TextEditingController(text: user?.firstName ?? '');
    _lastNameController = TextEditingController(text: user?.lastName ?? '');
    _phoneController = TextEditingController(text: user?.telephone ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
    _quartierController = TextEditingController(text: user?.quartier ?? '');
    _anneeController = TextEditingController(
      text: (user?.anneeExperience ?? 0).toString(),
    );
    _selectedVilleId = user?.villeId;
    _selectedMetierId = user?.metierId;
    _loadLists();
  }

  Future<void> _loadLists() async {
    final service = ref.read(authServiceProvider);
    try {
      final villes = await service.fetchVilles();
      final metiers = await service.fetchMetiers();
      if (!mounted) return;
      setState(() {
        _villes = villes;
        _metiers = metiers;
      });
    } catch (_) {
      // Les listes restent vides si indisponibles ; le profil reste éditable.
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _quartierController.dispose();
    _anneeController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _localPhotoBytes = bytes;
      _error = null;
    });

    // Upload immédiat de la photo.
    setState(() => _uploadingPhoto = true);
    try {
      await ref.read(authProvider.notifier).updatePhoto(
            bytes,
            filename: picked.name,
          );
      if (!mounted) return;
      setState(() => _uploadingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo de profil mise à jour.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadingPhoto = false;
        _localPhotoBytes = null;
        _error = e.toString();
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).updateProfile(
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
            telephone: _phoneController.text.trim(),
            bio: _bioController.text.trim(),
            quartier: _quartierController.text.trim(),
            villeId: _selectedVilleId,
            metierId: _selectedMetierId,
            anneeExperience: int.tryParse(_anneeController.text.trim()),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil mis à jour avec succès.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authProvider).userEmail ?? '';
    final user = ref.watch(authServiceProvider).currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: const Text(
          'Mon profil',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Avatar cliquable
              Center(child: _buildAvatar(user)),
              const SizedBox(height: 8),
              Text(
                'Appuyez pour changer la photo',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 24),

              Text(
                'Email',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Text(
                email,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),

              // Prénom et nom
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'Prénom',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
                validator: _required('Veuillez entrer votre prénom'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Nom',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
                validator: _required('Veuillez entrer votre nom'),
              ),
              const SizedBox(height: 16),

              // Téléphone
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Téléphone',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              // Ville
              DropdownButtonFormField<int>(
                initialValue: _selectedVilleId,
                decoration: const InputDecoration(
                  labelText: 'Ville',
                  prefixIcon: Icon(Icons.location_city_outlined),
                ),
                items: _villes
                    .map((v) => DropdownMenuItem(
                          value: v.id,
                          child: Text(v.nom),
                        ))
                    .toList(),
                onChanged: _villes.isEmpty
                    ? null
                    : (value) => setState(() => _selectedVilleId = value),
              ),
              const SizedBox(height: 16),

              // Quartier
              TextFormField(
                controller: _quartierController,
                decoration: const InputDecoration(
                  labelText: 'Quartier / zone',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // Champs réservés aux prestataires
              if (_isProvider) ...[
                DropdownButtonFormField<int>(
                  initialValue: _selectedMetierId,
                  decoration: const InputDecoration(
                    labelText: 'Métier',
                    prefixIcon: Icon(Icons.handyman_outlined),
                  ),
                  items: _metiers
                      .map((m) => DropdownMenuItem(
                            value: m.id,
                            child: Text(m.nom),
                          ))
                      .toList(),
                  onChanged: _metiers.isEmpty
                      ? null
                      : (value) => setState(() => _selectedMetierId = value),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _anneeController,
                  decoration: const InputDecoration(
                    labelText: "Années d'expérience",
                    prefixIcon: Icon(Icons.work_outline),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    if (int.tryParse(value.trim()) == null) {
                      return 'Entrez un nombre';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Biographie
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: 'Biographie',
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
              ),

              const SizedBox(height: 24),

              if (_error != null) ...[
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ],

              // Enregistrer
              ElevatedButton(
                onPressed: (_saving || _uploadingPhoto) ? null : _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Enregistrer', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Avatar : photo locale sélectionnée, sinon photo distante, sinon initiales.
  Widget _buildAvatar(AuthUser? user) {
    final Widget child;
    if (_localPhotoBytes != null) {
      child = Image.memory(_localPhotoBytes!, fit: BoxFit.cover);
    } else if (user?.photoProfilUrl != null && user!.photoProfilUrl!.isNotEmpty) {
      child = CachedNetworkImage(
        imageUrl: user.photoProfilUrl!,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 250),
        errorWidget: (_, _, _) => _initialsChild(user),
      );
    } else {
      child = _initialsChild(user);
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        ClipOval(
          child: SizedBox(
            width: 110,
            height: 110,
            child: _uploadingPhoto
                ? Container(
                    color: Colors.black38,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  )
                : child,
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: InkWell(
            onTap: _uploadingPhoto ? null : _pickPhoto,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppTheme.primaryGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.camera_alt_rounded,
                  size: 18, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _initialsChild(AuthUser? user) {
    final name = user?.fullName ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return Container(
      color: AppTheme.primaryGreen,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 40,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  FormFieldValidator<String> _required(String message) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return message;
      }
      return null;
    };
  }
}
