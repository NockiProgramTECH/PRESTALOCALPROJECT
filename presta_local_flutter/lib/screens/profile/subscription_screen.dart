import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/subscription_service.dart';

part 'parts/subscription_body.dart';
part 'parts/payment_sheet.dart';
part 'parts/subscription_body_actions.dart';
part 'parts/subscription_body_cartes.dart';

/// ---------------------------------------------------------------------------
/// Écran « Abonnement » (prestataires)
///
/// Reprend le parcours du site web, entièrement dans l'application :
///  1. état de l'abonnement (actif ou non, échéance, jours restants) ;
///  2. bénéfices de la mise en avant ;
///  3. choix d'une offre ;
///  4. paiement Mobile Money simulé (opérateur puis code OTP à 6 chiffres).
///
/// Un abonnement actif met le profil en avant : il est renvoyé en tête par le
/// filtre « abonnés » de l'API et porte le badge « Profil mis en avant ».
/// ---------------------------------------------------------------------------

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}
