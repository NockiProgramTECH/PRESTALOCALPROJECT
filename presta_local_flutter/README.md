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

## Vérifications

```bash
flutter analyze
flutter test
```
