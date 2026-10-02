import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/provider_model.dart';
import '../../navigation/auth_navigation.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/app_header.dart';
import '../../widgets/badges.dart';
import '../../widgets/rating_display.dart';
import '../auth/password_reset_screen.dart';
import '../favorites/favorites_screen.dart';
import '../feed/feed_composer_sheet.dart';
import '../messages/chat_screen.dart';
import '../auth/login_screen.dart';
import 'profile_edit_screen.dart';
import 'subscription_screen.dart';

part 'parts/provider_detail.dart';
part 'parts/user_dashboard.dart';
part 'parts/portfolio_section.dart';
part 'parts/provider_detail_actions.dart';
part 'parts/provider_detail_identite.dart';
part 'parts/provider_detail_onglets.dart';
part 'parts/user_dashboard_abonnement.dart';
part 'parts/user_dashboard_menu.dart';
part 'parts/user_dashboard_profil.dart';

/// Écran de profil (double usage, maquettes « profil_prestataire_devis »
/// et « mon_profil ») :
///
/// 1. Détail d'un prestataire (quand [providerId] est fourni) : cover,
///    tarifs, réalisations, avis, zone d'intervention et formulaire de
///    devis (envoyé via la messagerie existante).
/// 2. Mon profil client (quand [providerId] est null).

class ProfileScreen extends ConsumerWidget {
  final String? providerId;
  final VoidCallback? onBack;
  final ValueChanged<String>? onMessageTap;
  final VoidCallback? onLoginTap;

  const ProfileScreen({
    super.key,
    this.providerId,
    this.onBack,
    this.onMessageTap,
    this.onLoginTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mode détail prestataire
    if (providerId != null) {
      final providerAsync = ref.watch(providerDetailProvider(providerId!));
      return providerAsync.when(
        data: (provider) {
          if (provider == null) {
            return Scaffold(
              appBar: AppBar(leading: const BackButton()),
              body: const Center(child: Text('Prestataire non trouvé')),
            );
          }
          return _ProviderDetailView(
            provider: provider,
            onBack: onBack,
            onMessageTap: onMessageTap,
          );
        },
        loading: () => Scaffold(
          appBar: AppBar(leading: const BackButton()),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(
          appBar: AppBar(leading: const BackButton()),
          body: Center(child: Text('Erreur : $e')),
        ),
      );
    }

    // Mode mon profil
    return _UserDashboard(onLoginTap: onLoginTap);
  }
}
