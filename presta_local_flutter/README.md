# LesProduFao — application Flutter

Application mobile **LesProduFao** : mise en relation entre des clients et des
prestataires de services locaux à Ouagadougou (Burkina Faso).

- Backend consommé : API Django REST (`/api/`) + WebSockets (`/ws/`) du dossier
  [`../PrestLocal`](../PrestLocal).
- Design : design system « Warm Kinetic Modern » (voir
  `stitch_refonte_plateforme_lesprodufao/stitch_refonte_plateforme_lesprodufao/warm_kinetic_modern/DESIGN.md`)
  — citrus `#FF8A3D`, navy `#1E293B`, émeraude `#10B981`, canevas sable `#FBF9F7`,
  typographie Plus Jakarta Sans. Le site web Django applique la même charte.

## Nom de l'application

| Élément | Valeur |
| --- | --- |
| Nom affiché (Android / iOS / Web / Desktop) | `LesProduFao` |
| Package Dart (`pubspec.yaml`) | `lesprodufao_flutter` |
| `applicationId` Android / bundle iOS | `bf.lesprodufao.app` |
| Namespace Kotlin | `bf.lesprodufao.app` |

## Démarrage

```bash
flutter pub get
flutter run                          # appareil/émulateur connecté
```

### URL de l'API

L'URL est injectable sans toucher au code (`lib/config/constants.dart`) :

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.85:8000
flutter build apk --dart-define=API_BASE_URL=https://lesprodufao.onrender.com
```

Sans `--dart-define`, la valeur par défaut dépend de la plateforme
(`10.0.2.2:8000` sur l'émulateur Android, `127.0.0.1:8000` ailleurs).

## Structure

```
lib/
├── config/       # constantes (AppConstants) et thème (AppTheme)
├── models/       # modèles Dart (prestataire, conversation, feed…)
├── navigation/   # coquille applicative + barre de navigation basse
├── providers/    # état Riverpod (auth, favoris, état global)
├── screens/      # écrans (auth, home, search, feed, messages, profile, favorites)
├── services/     # clients HTTP + WebSocket
└── widgets/      # composants réutilisables (BrandMark, AppHeader, badges…)
```

### Écrans longs : bibliothèque + `parts/`

Un écran qui dépasse ~500 lignes est découpé en **une bibliothèque** (le
fichier d'écran, qui garde l'état et les `build`) et des **`part`** rangés dans
`parts/` : widgets privés, sections, cartes, formulaires. Les imports restent
inchangés pour le reste de l'application — seul l'écran importé reste
`profile_screen.dart`.

```
screens/profile/
├── profile_screen.dart              # bibliothèque : imports + `part` + classes publiques
└── parts/
    ├── provider_detail.dart         # classe d'état + champs et @override
    ├── provider_detail_identite.dart
    ├── provider_detail_onglets.dart
    └── provider_detail_actions.dart
```

Trois règles à respecter pour ne rien casser :

1. **Les directives `part` vivent dans la bibliothèque**, jamais dans un part ;
   un part n'a pas d'`import` non plus (il hérite de ceux de la bibliothèque).
2. **`part of '../<écran>.dart';`** : l'URI se résout par rapport au fichier
   part, donc un cran au-dessus depuis `parts/`. Écrire `part of
   'profile_screen.dart';` ne compile pas.
3. **Les méthodes extraites deviennent des `mixin` `on <classe>`**, appliqués
   par une clause `with`, et non des `extension` ni des fonctions libres :
   `this`, `widget`, `setState` et les appels internes (`_servicesTab()`)
   continuent de fonctionner sans réécriture. Les champs, les `@override`
   (`initState`, `build`…) et les membres statiques restent dans la classe ; le
   mixin ne redéclare en abstrait que ce qu'il utilise (`Type get _x;`,
   `set _x(Type value);`). Une classe ne peut porter qu'**une** clause `with` :
   compléter celle qui existe, ne pas en ajouter une seconde.

Après un tel découpage, lancer `dart format` puis `flutter analyze`.

## Vérifications

```bash
flutter analyze
flutter test
```
