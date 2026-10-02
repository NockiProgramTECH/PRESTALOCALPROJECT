import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/provider_model.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/provider_card.dart';
import '../../widgets/shimmer_loading.dart';

part 'parts/search_body.dart';
part 'parts/search_body_filtres.dart';
part 'parts/search_body_resultats.dart';

/// Écran de recherche (maquette « recherche_r_sultats_lesprodufao ») :
/// en-tête, carte de filtres, chips actifs, bannière carte,
/// tri, liste de résultats, appel à l'action Pro.

class SearchScreen extends ConsumerStatefulWidget {
  final ValueChanged<String>? onProviderTap;
  final ValueChanged<String>? onChatTap;
  final VoidCallback? onBecomePro;

  /// Pré-remplissage depuis l'accueil (ne s'applique qu'au montage
  /// et quand les valeurs changent).
  final String? initialQuery;
  final String? initialZone;
  final String? initialCategory;

  const SearchScreen({
    super.key,
    this.onProviderTap,
    this.onChatTap,
    this.onBecomePro,
    this.initialQuery,
    this.initialZone,
    this.initialCategory,
  });

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}
