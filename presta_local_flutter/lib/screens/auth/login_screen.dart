import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../widgets/brand_mark.dart';
import '../../navigation/auth_navigation.dart';
import '../profile/profile_edit_screen.dart';
import 'password_reset_screen.dart';

part 'parts/login_form.dart';
part 'parts/register_form.dart';
part 'parts/login_form_actions.dart';
part 'parts/login_form_champs.dart';
part 'parts/login_form_habillage.dart';
part 'parts/register_form_actions.dart';
part 'parts/register_form_champs.dart';
part 'parts/register_form_etapes.dart';

/// Écran de connexion (maquette « connexion_lesprodufao »).
///
/// Deux modes : Téléphone (+226, visuel pour l'instant) et Email
/// (fonctionnel, JWT). Le reste (OTP, Google/Apple) est annoncé
/// « bientôt disponible ».

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}/// Écran d'inscription (maquette « inscription_lesprodufao »).
///
/// 2 étapes : formulaire (rôle, identité, zone, mot de passe) puis
/// vérification du code email. Le backend exige un email : le champ
/// est donc présent même s'il n'apparaît pas sur la maquette.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}
