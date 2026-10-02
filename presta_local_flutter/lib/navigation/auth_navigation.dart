import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// Navigation des écrans d'authentification
///
/// Les écrans de connexion et d'inscription sont empilés **au-dessus** de la
/// route racine (`AuthGate`). Quand l'utilisateur est connecté, la racine
/// reconstruit l'interface connectée… mais sous ces écrans, qui restent
/// affichés : d'où l'impression de page figée (« il faut balayer et rouvrir
/// l'app pour que ça apparaisse »).
///
/// En marquant ces routes d'un nom dédié, `AuthGate` peut les dépiler
/// automatiquement dès que la session s'ouvre — sans toucher aux autres
/// écrans, comme la configuration du profil poussée juste après une
/// inscription.
/// ---------------------------------------------------------------------------

/// Nom de route des écrans d'authentification.
const String kAuthRouteName = 'auth';

/// Empile un écran d'authentification en le marquant comme tel.
Route<T> authRoute<T>(WidgetBuilder builder) {
  return MaterialPageRoute<T>(
    builder: builder,
    settings: const RouteSettings(name: kAuthRouteName),
  );
}

/// Dépile les écrans d'authentification empilés au-dessus de la racine.
void popAuthRoutes(NavigatorState navigator) {
  navigator.popUntil(
    (route) => route.isFirst || route.settings.name != kAuthRouteName,
  );
}
