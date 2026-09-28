import 'package:flutter_test/flutter_test.dart';
import 'package:presta_local_flutter/main.dart';

/// Test de base pour vérifier que l'application se lance sans erreur
void main() {
  testWidgets('Application PrestA Local - Test de démarrage',
      (WidgetTester tester) async {
    // Construit l'application et déclenche un frame
    await tester.pumpWidget(const PrestaLocalApp());

    // Vérifie que le titre de l'application est présent dans l'AppBar
    expect(find.text('PrestA Local BF'), findsOneWidget);

    // Vérifie que les éléments de navigation sont présents
    expect(find.text('Accueil'), findsOneWidget);
    expect(find.text('Rechercher'), findsOneWidget);
    expect(find.text('Favoris'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
  });
}
