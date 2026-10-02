import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lesprodufao_flutter/models/provider_model.dart';
import 'package:lesprodufao_flutter/navigation/mobile_bottom_nav.dart';
import 'package:lesprodufao_flutter/screens/splash_screen.dart';
import 'package:lesprodufao_flutter/widgets/empty_state.dart';

/// Tests de fumée (smoke tests) de l'application.
///
/// Ces tests ne dépendent **pas du réseau** : ils vérifient les widgets
/// autonomes et la lecture des réponses de l'API (parsing), ce qui permet de
/// les exécuter avec `flutter test` sans backend lancé.
void main() {
  testWidgets('Écran de démarrage : logo + slogan', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    // Logo officiel (assets/images/logo.png) + phrase d'accroche de la marque.
    expect(find.byType(Image), findsOneWidget);
    expect(
      find.text('La communauté qui connecte les talents locaux'),
      findsOneWidget,
    );
  });

  testWidgets('Barre de navigation : 5 onglets et sélection', (tester) async {
    AppTab? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: MobileBottomNav(
            currentTab: AppTab.accueil,
            onTabSelected: (tab) => selected = tab,
          ),
        ),
      ),
    );

    expect(find.text('Accueil'), findsOneWidget);
    expect(find.text('Recherche'), findsOneWidget);
    expect(find.text('Favoris'), findsOneWidget);
    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);

    await tester.tap(find.text('Messages'));
    expect(selected, AppTab.messages);
  });

  testWidgets('Favoris vides : état vide affiché', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: EmptyState.favorites())),
    );

    expect(find.text('Aucun favori'), findsOneWidget);
  });

  test('ProviderModel.fromJson lit les champs renvoyés par l\'API', () {
    final provider = ProviderModel.fromJson({
      'id': 'p1',
      'first_name': 'Mamadou',
      'last_name': 'Traoré',
      'metier': {'nom': 'Plombier'},
      'ville': 'Ouagadougou',
      'quartier': 'Zogona',
      'moyenne_etoile': 4.5,
      'nombre_avis': 12,
      'annee_experience': 7,
      'est_verifie': true,
      'is_available': true,
      'telephone': '+226 70 00 00 00',
    });

    expect(provider.id, 'p1');
    expect(provider.name, 'Mamadou Traoré');
    expect(provider.title, 'Plombier');
    expect(provider.location, 'Ouagadougou');
    expect(provider.locationZone, 'Zogona');
    expect(provider.rating, 4.5);
    expect(provider.reviewCount, 12);
    expect(provider.experienceYears, 7);
    expect(provider.isVerified, isTrue);
    expect(provider.isOnline, isTrue);
    // Aucun prix affiché côté application (décision produit).
    expect(provider.priceText, isEmpty);
    expect(provider.priceValue, isNull);
  });
}
