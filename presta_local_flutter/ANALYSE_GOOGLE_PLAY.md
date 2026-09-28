# Analyse de conformité Google Play — PrestA Local Flutter

**Date :** 2026-08-02
**Objectif :** identifier les anomalies (bugs invisibles) susceptibles de faire **rejeter** l'application lors de la soumission à Google Play, avec les références exactes des fichiers et les corrections étape par étape.

> ⚠️ **Priorité absolue :** les deux points CRITIQUES (n°1 et n°2) rendront l'application **inutilisable** ou **bloquée dès l'upload**. Corrigez-les en premier.

---

## 🔴 CRITIQUE — Blocage quasi-certain

### 1. Permission `INTERNET` absente du manifest principal → application sans réseau en production

**Référence :**
- `android/app/src/main/AndroidManifest.xml` (fichier complet, **aucune** `<uses-permission android:name="android.permission.INTERNET"/>`)
- `android/app/src/debug/AndroidManifest.xml` (ligne 6) → permission **présente uniquement en debug**
- `android/app/src/profile/AndroidManifest.xml` → permission présente uniquement en profil

**Le bug invisible :** Flutter ne met `INTERNET` que dans les manifests `debug` et `profile` par défaut. En **build release** (`flutter build appbundle`), seul le manifest `main` est fusionné : la permission `INTERNET` **disparaît**. Résultat : toutes les requêtes HTTP(S) (login, feed, messages, favoris, upload photo) et les WebSockets échouent avec `SocketException: Failed host lookup: 'prestalocal.onrender.com'`.

**Conséquence Google Play :** l'application ouvre un écran de connexion totalement non fonctionnel → rejet pour « application cassée / crash » dès le test de validation.

**Correction :**
1. Ouvrir `android/app/src/main/AndroidManifest.xml`.
2. Ajouter **avant** le bloc `<application>` :
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   ```
3. Recompiler un APK/AAB release et vérifier :
   ```bash
   flutter build appbundle --release
   # vérifier que la permission est bien dans le manifest fusionné :
   # décompressez le .aab ou vérifiez avec un émulateur en release
   ```

---

### 2. Build release signé avec la clé **debug** → Google Play refuse l'upload

**Référence :** `android/app/build.gradle.kts`, ligne 38 :
```kotlin
signingConfig = signingConfigs.getByName("debug")
```

**Le bug invisible :** l'APK/AAB release est signé avec la clé debug générée par le SDK. Google Play **rejette l'upload** : un AAB signé debug n'est pas accepté (Play attend une clé d'upload propre). En plus, la clé debug est connue de tous → risque de sécurité majeur.

**Correction :**
1. Générer une vraie clé de signature release (commande unique, à conserver précieusement) :
   ```bash
   keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA \
     -keysize 2048 -validity 10000 -alias upload
   ```
2. Créer le fichier `android/key.properties` (NE PAS committer) :
   ```
   storePassword=<mot-de-passe>
   keyPassword=<mot-de-passe>
   keyAlias=upload
   storeFile=<chemin absolu vers upload-keystore.jks>
   ```
3. Ajouter `.gitignore` : `android/key.properties` et `*.jks`.
4. Modifier `android/app/build.gradle.kts` en tête :
   ```kotlin
   import java.util.Properties
   import java.io.FileInputStream

   val keystoreProperties = Properties()
   val keystorePropertiesFile = rootProject.file("key.properties")
   if (keystorePropertiesFile.exists()) {
       keystoreProperties.load(FileInputStream(keystorePropertiesFile))
   }
   ```
5. Dans le bloc `android { }`, définir :
   ```kotlin
   signingConfigs {
       create("release") {
           keyAlias = keystoreProperties["keyAlias"] as String
           keyPassword = keystoreProperties["keyPassword"] as String
           storeFile = keystoreProperties["storeFile"]?.let { file(it) }
           storePassword = keystoreProperties["storePassword"] as String
       }
   }
   ```
6. Remplacer le `buildTypes.release` :
   ```kotlin
   buildTypes {
       release {
           signingConfig = signingConfigs.getByName("release")
           isMinifyEnabled = true
           isShrinkResources = true
           proguardFiles(
               getDefaultProguardFile("proguard-android-optimize.txt"),
               "proguard-rules.pro"
           )
       }
   }
   ```
7. Activer **Play App Signing** dans la Play Console : téléversez la clé `upload-keystore.jks` comme clé d'upload, Google gère la clé de signature d'app.

---

## 🟠 ÉLEVÉ — Crash fonctionnel / risque de rejet

### 3. iOS : `NSPhotoLibraryUsageDescription` manquant → crash au changement de photo

**Référence :**
- `ios/Runner/Info.plist` (fichier complet — aucune clé de permission photos/caméra)
- `lib/screens/profile/profile_edit_screen.dart`, ligne 97-98 : `ImagePicker().pickImage(source: ImageSource.gallery, ...)`

**Le bug invisible :** sur iOS, `image_picker` avec `ImageSource.gallery` exige `NSPhotoLibraryUsageDescription`. Sans cette clé, l'application **plante immédiatement** (Termination `SIGABRT` / `UIRequired...` `privacy - photo library usage description`) dès que l'utilisateur touche la vignette « changer la photo ».

> Note : côté Android, `image_picker` moderne utilise le Photo Picker (API 33+) qui ne demande aucune permission → Android n'est pas concerné. Mais corriger quand même pour l'iOS.

**Correction :** ajouter dans `ios/Runner/Info.plist`, dans le `<dict>` racine :
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>PrestA Local a besoin d'accéder à vos photos pour mettre à jour votre photo de profil.</string>
<key>NSCameraUsageDescription</key>
<string>PrestA Local utilise la caméra pour prendre une photo de profil.</string>
```

---

### 4. `flutter_secure_storage` : `encryptedSharedPreferences` déprécié en 9.x

**Référence :** `lib/services/api_client.dart`, ligne 39-41 :
```dart
static const FlutterSecureStorage _secure = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);
```

**Le bug invisible :** `encryptedSharedPreferences` est **déprécié** à partir de flutter_secure_storage 9.0 et sera retiré. Les tokens JWT pourraient être stockés dans un format non pérenne → **déconnexions silencieuses inexpliquées** lors d'une mise à jour de l'app.

**Correction :** retirer l'option `encryptedSharedPreferences` (la classe `FlutterSecureStorage` utilise déjà le Keystore natif par défaut) :
```dart
static const FlutterSecureStorage _secure = FlutterSecureStorage(
  aOptions: AndroidOptions(),
);
```

---

## 🟡 MOYEN — Risques de rejet / bonnes pratiques Google Play

### 5. `google_fonts` télécharge les polices à l'exécution

**Référence :** `pubspec.yaml` (dépendance `google_fonts: ^6.2.1`), usage dans les écrans (`Theme.of(context).textTheme...`).

**Le bug invisible :** le package `google_fonts` **télécharge les polices depuis Internet au premier rendu**. Sans connexion, les textes apparaissent avec la police de secours, et pendant le téléchargement l'UI peut flicker. Google Play peut l'interpréter comme un rendu incohérent.

**Correction (recommandé) :** déclarer la police en local dans `pubspec.yaml` (`fonts:`) et utiliser `GoogleFonts.<police>` avec `fonts: <Police>` local, ou plus simplement vérifier que le backend/App sont stables pour éviter de dépendre d'une connexion au démarrage. Si le rendu est acceptable hors-ligne, ce point est non bloquant.

### 6. `baseUrl` en dur vers `prestalocal.onrender.com` (plan gratuit qui « dort »)

**Référence :** `lib/config/constants.dart`, lignes 17-18 :
```dart
static const String baseUrl = 'https://prestalocal.onrender.com';
static const String assetBaseUrl = 'https://prestalocal.onrender.com';
```

**Le bug invisible :** Render (plan gratuit) **endort** l'instance après 15 min d'inactivité → la 1ʳᵉ requête après réveil met 30-60 s à répondre. Le testeur Google Play voit des écrans « Erreur serveur » / temps de chargement infinis → **risque de rejet pour « application lente / ne fonctionne pas »**.

**Correction :**
- Activer un keep-alive (ping) côté hébergement, OU passer à un plan payant/non-dormant.
- Ajouter une gestion de timeout + retry dans `lib/services/api_client.dart` (le client `http.Client()` n'a pas de timeout par défaut → risque de blocage infini) :
  ```dart
  final _client = http.Client();
  Future<http.Response> _send(...) async {
    final uri = ...;
    // Envelopper avec un timeout explicite :
    return _client.get(uri, headers: headers)
        .timeout(const Duration(seconds: 15));
  }
  ```
- Ne pas bloquer le démarrage de l'app sur le réseau (l'écran Splash/checkSession doit avoir un timeout pour ne pas rester bloqué en `loading`).

### 7. `AuthGate` : écran de démarrage bloqué si `checkSession` pend

**Référence :** `lib/providers/auth_provider.dart`, ligne 89-96 (`initialize`) ; `lib/main.dart`, ligne 103-106.

**Le bug invisible :** si la requête `/api/auth/me/` ne répond jamais (réseau mort, backend endormi), `checkSession` reste en attente → l'app reste **bloquée sur le SplashScreen** indéfiniment. Un testeur Google Play qui ouvre l'app sans réseau voit un écran figé → rejet « l'app ne se lance pas ».

**Correction :** ajouter un timeout dans `checkSession` (`lib/services/auth_service.dart`, ligne 142-154) ou dans `initialize` :
```dart
Future<void> initialize() async {
  state = AuthState.loading();
  try {
    final ok = await _authService.checkSession()
        .timeout(const Duration(seconds: 10));
    ...
  } catch (_) {
    state = AuthState.unauthenticated();
  }
}
```

---

## 🔵 BAS — À faire avant soumission (non bloquant)

### 8. `applicationId` générique + versionCode

**Référence :** `android/app/build.gradle.kts`, lignes 24 et 29 :
```kotlin
applicationId = "com.presta.presta_local_flutter"
versionCode = flutter.versionCode   // = 1
versionName = flutter.versionName   // = 1.0.0
```

- L'ID `com.presta.presta_local_flutter` est générique ; s'il n'est pas **unique dans le Play Store**, l'upload est refusé. Corrigez-le avant le premier téléversement (il ne pourra plus changer ensuite) :
  ```kotlin
  applicationId = "bf.presta.local"
  ```
- Incrémentez `versionCode` à chaque build (ex. `2`, `3`…). Déclarez la version dans `pubspec.yaml` (`version: 1.0.0+1`) et vérifiez que `versionCode`/`versionName` remontent bien.

### 9. Sauvegarde automatique Android (`android:allowBackup`)

**Référence :** `android/app/src/main/AndroidManifest.xml`, bloc `<application>` (lignes 2-5).

**Le bug invisible :** `android:allowBackup` n'est pas défini → **défaut `true`**. Les données (dont des données de session) peuvent être sauvegardées dans le cloud Android. Google Play exige une déclaration « Data safety » cohérente.

**Correction :**
```xml
<application
    android:allowBackup="false"
    ...
>
```
ou configurez des règles de sauvegarde ciblées (`dataExtractionRules`).

### 10. Préparer les documents Play Console obligatoires

En amont de l'upload, préparez dans la Play Console :
- **Politique de confidentialité (URL publique)** — exigée pour toute app qui collecte des données (email, téléphone, photo). L'app collecte ces données → obligatoire.
- **Formulaire « Déclaration de sécurité des données »** : indiquez que l'app collecte les informations de compte (email, nom, téléphone), la photo, et les données réseau (adresse IP). Utilisez HTTPS (déjà en place).
- **Licence cible 13+ / formulaire de contact** pour l'équipe de révision.
- Règles pour les comptes : le formulaire d'identification doit fournir une méthode de suppression de compte — **ajoutez une fonctionnalité « Supprimer mon compte »** dans l'app (référence : `lib/screens/profile/profile_screen.dart`) avant la soumission.

---

## 📌 Récapitulatif des fichiers à modifier

| Fichier | Action |
|---|---|
| `android/app/src/main/AndroidManifest.xml` | Ajouter `INTERNET`, `allowBackup="false"` |
| `android/app/build.gradle.kts` | Vraie clé release + minify, `applicationId` unique |
| `android/key.properties` (créer) | Clés de signature (ne pas committer) |
| `.gitignore` | Ignorer `key.properties` et `*.jks` |
| `ios/Runner/Info.plist` | `NSPhotoLibraryUsageDescription`, `NSCameraUsageDescription` |
| `lib/services/api_client.dart` | Retirer `encryptedSharedPreferences`, ajouter timeouts |
| `lib/services/auth_service.dart` | Timeout sur `checkSession` |
| `lib/config/constants.dart` | (optionnel) finaliser `baseUrl` de production |
| `lib/screens/profile/profile_screen.dart` | Ajouter « Supprimer mon compte » |

## ✅ Ordre de correction recommandé

1. **N°1** — Permission `INTERNET` dans le manifest principal (blocage total sinon).
2. **N°2** — Clé de signature release (blocage de l'upload sinon).
3. **N°4** — Retirer `encryptedSharedPreferences` (stabilité des sessions).
4. **N°3** — Clés photos iOS (crash au changement de photo).
5. **N°6 + N°7** — Timeouts réseau (éviter écrans figés / rejet « app lente »).
6. **N°8, N°9, N°10** — `applicationId`, `allowBackup`, documents Play Console, suppression de compte.
