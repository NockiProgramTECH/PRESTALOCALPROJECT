part of '../profile_screen.dart';

mixin _ProviderDetailActions on ConsumerState<_ProviderDetailView> {
  ScrollController get _scroll;
  GlobalKey<FormState> get _formKey;
  bool get _sending;
  set _sending(bool value);
  ProviderModel get provider;

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _scrollToQuote() {
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
  }

  /// Partage de la fiche prestataire (copie dans le presse-papiers).
  Future<void> _share() async {
    await Clipboard.setData(
      ClipboardData(
        text:
            '${provider.name} — ${provider.title} à ${provider.location}\n'
            'Découvert sur LesProduFao.',
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fiche copiée — collez-la pour partager')),
    );
  }

  /// Message affiché quand le prestataire n'est pas contactable faute
  /// d'abonnement actif.
  void _contactBloque() {
    _snack(
      "Profil non contactable : ce prestataire n'a pas d'abonnement actif.",
    );
  }

  /// Ouvre (ou crée) la conversation avec le prestataire.
  Future<void> _openChat() async {
    if (!provider.contactDisponible) {
      _contactBloque();
      return;
    }
    if (ref.read(authProvider).status != AuthStatus.authenticated) {
      _snack('Connectez-vous pour envoyer un message');
      return;
    }
    try {
      final convId = await ref
          .read(messageServiceProvider)
          .startConversation(provider.id);
      if (!mounted) return;
      if (widget.onMessageTap != null) {
        widget.onMessageTap!(convId);
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: convId,
              onBack: () => Navigator.of(context).pop(),
            ),
          ),
        );
      }
    } catch (_) {
      _snack('Impossible de démarrer la conversation');
    }
  }

  /// Ouvre WhatsApp sur le numéro du prestataire (format international).
  Future<void> _openWhatsApp() async {
    if (!provider.contactDisponible) {
      _contactBloque();
      return;
    }
    final raw = (provider.whatsapp?.isNotEmpty == true)
        ? provider.whatsapp!
        : provider.phone;
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      _snack('Numéro indisponible');
      return;
    }
    final uri = Uri.parse('https://wa.me/$digits');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _snack("Impossible d'ouvrir WhatsApp");
    }
  }

  /// Ouvre la recherche Facebook sur le nom du prestataire.
  Future<void> _openFacebook() async {
    final uri = Uri.parse(
      'https://www.facebook.com/search/top?q=${Uri.encodeComponent(provider.name)}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _snack("Impossible d'ouvrir Facebook");
    }
  }

  /// Envoie la demande : crée la conversation puis y poste le récapitulatif.
  Future<void> _sendQuote() async {
    if (!provider.contactDisponible) {
      _contactBloque();
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    if (ref.read(authProvider).status != AuthStatus.authenticated) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Connectez-vous pour envoyer un devis')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final service = ref.read(messageServiceProvider);
      final convId = await service.startConversation(provider.id);
      final recap =
          'Demande de devis — ${provider.name}\n'
          'Service : ${_selectedService ?? provider.title}\n'
          'Délai : $_delai\n'
          'Lieu : ${_quartierController.text.trim()}\n'
          'Tél : ${_phoneController.text.trim()}\n'
          'Besoin : ${_descController.text.trim()}';
      final selfId = ref.read(currentUserIdProvider);
      if (selfId != null) {
        await service.sendMessage(
          conversationId: convId,
          text: recap,
          selfUserId: selfId,
        );
      }
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Demande envoyée au prestataire')),
      );
      widget.onMessageTap?.call(convId);
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Envoi impossible — réessayez')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _call(String phone) async {
    if (phone.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Numéro indisponible')));
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone.trim());
    if (!await launchUrl(uri)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible de lancer l'appel")),
      );
    }
  }

  String _formatDate(DateTime date) {
    const months = [
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
    return 'Il y a ${DateTime.now().difference(date).inDays} j • ${date.day} ${months[date.month - 1]}';
  }
}
