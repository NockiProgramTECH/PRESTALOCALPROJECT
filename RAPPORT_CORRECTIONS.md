# Rapport de corrections — LesProduFao (API Django + application Flutter)

> Ce rapport recense les instructions trouvées dans les fichiers du dépôt
> (`presta_local_flutter/prompt.md`, `presta_local_flutter/ROADMAP.md`,
> `CONTEXT_PROJET.md`, `LesProduFao/SUGGESTIONS.md`,
> `LesProduFao/ROADMAP_OPTIMISATION.md`) et ce qui a été mis en place, corrigé
> ou volontairement écarté.
>
> Branche de travail : `arena/01a0e780-lesprodufaoproject`.

---

## 1. API Django (`PrestLocal/`)

### 1.1 Sécurité et configuration (items 1 à 5, 10, 13 de `CONTEXT_PROJET.md`)

| Problème initial | Correction apportée |
|---|---|
| `.env` avec secrets en clair, `.gitignore` incomplet | `.gitignore` réécrit (`.env`, `media/`, `staticfiles/`, `db.sqlite3`…) + `.env.example` documenté, `git check-ignore` confirme que `.env`/`media/` ne sont plus suivis |
| `SECRET_KEY` placeholder | `settings.py` **exige** `SECRET_KEY` hors `DEBUG` (levée `ImproperlyConfigured` vérifiée) ; valeurs lues via `django-environ` |
| `CORS_ALLOW_ALL_ORIGINS = True` en toutes circonstances | CORS ouvert uniquement si `DEBUG=True` ; en production, liste d'origines explicite |
| Fuite d'information sur le reset de mot de passe | Réponse identique que l'e-mail existe ou non (testé) |
| E-mail expéditeur codé en dur | `api/serializers.py` utilise `settings.DEFAULT_FROM_EMAIL` via l'helper `send_code_email()` |
| Import inutilisé `from os import read` | Supprimé ; `ruff`/`check` OK |
| `staticfiles/` commité | Ignoré par Git (reste généré par `collectstatic`) |

### 1.2 Tests automatisés (items 11, 12)

- `api/tests.py` : **30 tests** répartis en 6 classes (auth, prestataires,
  évaluations, favoris, fil d'actualité, messagerie).
- Désactivation des throttles en mode test pour des exécutions déterministes.
- **Dernière exécution : `Ran 30 tests in 12.615s — OK`.**

### 1.3 Docker / production (items 7, 8)

- `docker-compose.yml` : service **PostgreSQL 16**, **Redis 7**, `web` (daphne,
  `migrate` + `collectstatic` au démarrage) et **nginx 1.27** en frontal.
- `docker/nginx.conf` : sert `/static/` et `/media/`, proxy `/ws/` avec
  *Upgrade*, *timeouts* longs (WebSocket) — les médias ne dépendent plus de
  `DEBUG=True`.

### 1.4 Endpoints ajoutés / complétés (section 1 et 2 du `ROADMAP.md`)

| Endpoint | Rôle |
|---|---|
| `POST /api/prestataire/{id}/evaluer/` | Évaluer un prestataire (1 avis par client, `update_or_create`, throttle `review`) |
| `POST /api/prestataire/{id}/toggle_favorite/` | Ajouter/retirer un favori |
| `GET /api/me/favorites/` | Liste des prestataires favoris de l'utilisateur |
| `GET /api/prestataire/{id}/realisations/` | Réalisations d'un prestataire |
| `GET /api/categories/` | Catégories de prestations (public, avec `provider_count`) |
| `GET /api/feed/`, `GET /api/feed/{id}/`, `POST …/like/`, `POST …/comment/` | Fil d'actualité : lecture, likes et commentaires |
| `GET/POST /api/messagerie/conversations/…` | Messagerie JSON pour les clients mobiles (+ WebSocket `/ws/chat/<id>/`) |

Le champ `is_favorite` est exposé dans le sérialisé prestataire (calculé pour
l'utilisateur connecté), la liste est filtrée/triée (`ville`, `metier`,
`categorie`, `quartier`, `etoile`, `abonnes_only`, `search`) avec
`select_related`/`prefetch_related` et annotations pour éviter les requêtes N+1.

### 1.5 Données de test

`populate_db.py` crée désormais les **mots de passe** (`password123`) et des
**abonnements actifs**, sans quoi le listing public restait vide
(`paye + est_actif + date_fin > now`).

---

## 2. Application Flutter (`presta_local_flutter/`)

### 2.1 Bugs UI listés dans `prompt.md`

| Bug signalé | Correction |
|---|---|
| Cartes prestataires : « right overflowed by 76 pixels » | `lib/widgets/provider_card.dart` **réécrit** : `Expanded`/`Flexible`/`Wrap` partout, nom sur une ligne avec `ellipsis`, plus aucun prix affiché |
| Fiche prestataire : double trait jaune sous les informations | Cause = textes rendus sans `DefaultTextStyle` (aucun ancêtre `Material`) → `lib/main.dart` applique un `builder` global `DefaultTextStyle(decoration: TextDecoration.none)` + styles explicites |
| Fiche prestataire : le contenu doit passer **derrière** la photo de couverture au défilement | `CustomScrollView` + `SliverAppBar(pinned, expandedHeight: 220)` avec `flexibleSpace: _coverBackground()` ; l'identité, les actions et les onglets défilent sous la couverture |
| Fiche prestataire : ne pas afficher de prix | Grille tarifaire et bloc « estimation main-d'œuvre » supprimés ; onglet renommé « Services » (« Sur mesure » au lieu de « Sur devis ») |
| Fiche prestataire : doivent apparaître nom, prénom, métier, ville, description, cover, photo, actions (message, appel, WhatsApp, Facebook), évaluations | Carte identité (nom, métier, zone, note + nombre d'avis, « À propos ») + rangée de **4 boutons** `Expanded` (Message / Appel / WhatsApp / Facebook) + onglet Avis avec note globale et commentaires |
| Messagerie : « No Material widget found », « bottom overflowed by 99460 pixels », nom du destinataire souligné | `messages_screen.dart` et `chat_screen.dart` réécrits : `Material` explicite autour des tuiles, `Column` bornée (`Expanded` + liste en `reverse: true`), bulles limitées à 78 % de la largeur, styles de texte explicites |
| Drawer : « bottom overflowed by 38 pixels » sous « Connectez-vous pour plus de fonctionnalités » | Chaîne **inexistante dans le code** (seule occurrence : `ROADMAP.md`) et aucun `Drawer` Flutter dans `lib/`. Le menu latéral réel du site (`LesProduFao/templates/includes/navbar.html` + `.mobile-nav` de `static/css/main.css`) a été consolidé : `100dvh`, marge basse = hauteur de la barre de navigation (64 px) + *safe-area*, `z-index` au-dessus de la barre, bloc d'authentification non rogné |
| Profil : supprimer la carte « Mes commandes » | Carte « Mes demandes & devis » retirée du menu « MON ACTIVITÉ » |

### 2.2 Mise en relation avec l'API (données réelles, plus de mocks)

- **Favoris** : `lib/services/favorites_service.dart` utilise
  `GET /api/me/favorites/` et `POST /api/prestataire/{id}/toggle_favorite/`
  avec **cache local** (SharedPreferences) pour le mode hors ligne, et
  réalignement automatique si le serveur et le client divergent.
  `favoritesProvidersProvider` charge les prestataires favoris en une requête.
- **Catégories** : `GET /api/categories/` (public) alimente le provider
  `categoriesProvider` (accueil + recherche). Repli sur `/api/prestations/`
  pour les anciens backends. Les filtres de recherche utilisent `categorie`.
- **Évaluations** : bouton **« Évaluer ce prestataire »** dans l'onglet Avis
  (note 1–5 + commentaire) → `POST /api/prestataire/{id}/evaluer/`, puis
  rechargement de la fiche et des listes.
- **Likes / commentaires** des réalisations : déjà branchés, avec garde-fou
  « Connectez-vous pour aimer/commenter une réalisation ».
- **Messagerie** : REST + WebSocket (envoi optimiste avec annulation en cas
  d'échec, présence en ligne, reconnexion automatique).
- **Aucune donnée fictive** n'est plus utilisée par les écrans
  (`MockData` n'est plus référencé que par son propre fichier, conservé pour
  d'éventuelles démos/tests).
- **Recherche** : le filtre « budget < 15 000 FCFA » et le tri « Prix
  croissant » ont été **retirés** — la plateforme n'affiche pas de prix et
  l'API n'expose aucune donnée tarifaire ; ils étaient donc inertes. Un tri
  « Plus expérimentés » (`annee_experience`) les remplace, et le bouton
  « Filtres » ouvre désormais un vrai panneau (vérifiés / disponibles /
  mieux notés) au lieu de l'ancien « Bientôt disponible ».

### 2.3 Configuration & qualité

- `lib/config/constants.dart` : plus d'IP en dur. `--dart-define=API_BASE_URL=…`
  (sinon `10.0.2.2:8000` sur émulateur Android, `127.0.0.1:8000` sur
  web/desktop).
- `lib/main.dart` : taille de police bornée (0,9 → 1,2) pour éviter les
  débordements quand l'utilisateur agrandit les textes du système.
- `flutter_secure_storage` : déjà en place dans `lib/services/api_client.dart`
  (Keychain/Keystore), avec rafraîchissement automatique du JWT sur `401`.
- Compression des images à l'upload : 1 600 px / qualité 85 (réalisations),
  800 px (photo de profil).
- `test/widget_test.dart` réécrit : tests de fumée **sans réseau**
  (écran de démarrage, barre de navigation, état vide des favoris, lecture
  d'une réponse API par `ProviderModel.fromJson`). L'ancien test échouait
  (« LesProduFao BF », onglet « Rechercher »).

---

## 3. Vérifications effectuées

| Vérification | Résultat |
|---|---|
| `manage.py check` (DEBUG et prod) | ✅ Aucun problème |
| `manage.py makemigrations --check --dry-run` | ✅ « No changes detected » |
| `manage.py test api` | ✅ **30 tests OK** (12,6 s) |
| Cohérence routes API ↔ chemins appelés par Flutter | ✅ Les 24 chemins appelés existent côté Django |
| Équilibre des délimiteurs + références `AppTheme.*` / `AppConstants.*` | ✅ (script de contrôle sur les 50 fichiers Dart) |
| Compilation / `flutter analyze` | ⚠️ **Non exécutables ici** : le SDK Flutter est absent de l'environnement et non téléchargeable. La validation Flutter repose sur la relecture et les scripts de contrôle. |

---

## 4. Points restants (hors périmètre ou à décider)

1. **Drawer Flutter** : si vous parlez d'un menu latéral de l'application
   mobile (et non du site), il n'existe pas encore dans `lib/` — dites-moi si
   vous voulez que je le crée (il n'y aura alors aucun débordement : liste
   défilante + `SafeArea`).
2. **Paiement des abonnements** : recommandation de `CONTEXT_PROJET.md`
   (point 6) non traitée — modèle présent, intégration de paiement à prévoir
   (chantier à part entière).
3. **Mode sombre / variables CSS Web** et **tri/autocomplétion avancés** :
   recommandations « plus tard » de `SUGGESTIONS.md`, non entamées.
4. **Exécuter `flutter analyze` et `flutter test`** sur une machine disposant
   du SDK, puis `flutter run --dart-define=API_BASE_URL=…` pour valider
   visuellement les écrans corrigés.

---

## 5. Comment lancer

```bash
# API (SQLite en développement, PostgreSQL via docker compose)
cd PrestLocal
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env          # renseigner SECRET_KEY (obligatoire hors DEBUG)
python manage.py migrate
python populate_db.py         # jeu de données de test (mots de passe + abonnements)
python manage.py runserver 0.0.0.0:8000
python manage.py test api     # 30 tests

# Application Flutter
cd ../presta_local_flutter
flutter pub get
flutter run --dart-define=API_BASE_URL=http://192.168.1.85:8000   # IP de votre poste
flutter test
```

---

## 6. Rebranding « LesProduFao » + alignement du site web sur l'app

### 6.1 Renommage de la marque

- **Nom affiché partout : `LesProduFao`** (anciennement PrestaLocal / PrestLocal / PrestA Local).
  Aucune occurrence de l'ancien nom ne subsiste : ni dans les templates, les e-mails,
  le manifest PWA, le service worker, les métadonnées, ni dans les archives
  (le paquet `stitch_refonte_plateforme_lesprodufao.zip` a été reconstruit et ses
  dossiers/écrans renommés).
- **Identifiants techniques renommés** (application Flutter) :
  - package Dart `lesprodufao_flutter` (imports `package:lesprodufao_flutter/...`) ;
  - `applicationId` Android / bundle iOS / application id Linux / macOS : `bf.lesprodufao.app`
    (paquet Kotlin déplacé dans `android/app/src/main/kotlin/bf/lesprodufao/app/`) ;
  - libellés affichés Android/iOS/Web/Windows/Linux : `LesProduFao` ;
  - conteneurs Docker, base PostgreSQL et upstream nginx renommés (`lesprodufao`).
- **Dossiers du dépôt conservés** : `PrestLocal/` (backend) et `presta_local_flutter/`
  (app) pour ne pas casser les scripts, chemins de déploiement et l'historique Git.
- **Nouvelle identité visuelle du site web** : icônes PWA (48 → 512 px) et favicon
  régénérés — carré arrondi dégradé citrus + clé à molette blanche, comme `BrandMark`
  dans l'app.

### 6.2 Design du site web aligné sur l'application

Le site Django reprend désormais la charte « Warm Kinetic Modern » de l'app mobile :

| Token | Valeur | Usage |
| --- | --- | --- |
| `--primary-green` | `#FF8A3D` | actions, accents, liens actifs (alias historique conservé) |
| `--primary-pressed` | `#E07228` | états pressés / survol |
| `--primary-strong` | `#9A4600` | texte accentué sur fond orange clair |
| `--primary-soft` / `--bg-soft-green` | `#FFDBC9` / `#FFEDE3` | fonds teintés |
| `--text-dark` | `#1E293B` | encre navy (textes, structure) |
| `--success` | `#10B981` (texte `#047857`) | statuts « Vérifié », « Disponible » |
| `--bg-light` | `#FBF9F7` | canevas sable |
| `--card-border` / `--grey-200` | `#EAE3DB` | bordures chaudes |
| `--font-sans` | `Plus Jakarta Sans` | typographie unique (remplace Inter) |
| rayons | `8 / 12 / 24 / 999 px` | champs & boutons / cartes / pastilles |

Autres ajustements : bannière de confiance passée en navy avec icônes émeraude,
boutons d'action orange (texte blanc, survol `#E07228`), cartes blanches à 24 px de
rayon avec bordure chaude, en-tête mobile en surface claire, badge « Plateforme n°1
à Ouaga » sur le hero (comme l'écran d'accueil de l'app), anneau de focus orange
sur les champs, bulles de messagerie orange (identiques à l'app).

### 6.3 Vérifications

- `python manage.py check` : aucun problème.
- `python manage.py test api` : **30 tests OK**.
- `collectstatic` régénéré ; pages publiques et authentifiées testées
  (accueil, prestataires, fiche prestataire, à propos, connexion, inscription,
  profil, notifications, messagerie, hors-ligne) — plus aucune trace de l'ancien nom.
- Recherche plein texte dans le dépôt (hors dossiers `PrestLocal/` et
  `presta_local_flutter/`, conservés) : 0 occurrence de l'ancienne marque.

---

## 7. Logo officiel LesProduFao (site web + application)

### 7.1 Source de marque

- `tools/logo_source_emblem.png` — emblème (médaillon circulaire : artisans,
  monument de Ouagadougou, étoile).
- `tools/logo_source.png` — logo complet composé (emblème +
  « LesProduFao » + signature « La communauté qui connecte les talents locaux » +
  pastilles de métiers), fond transparent.
- Scripts de régénération (à relancer après tout changement de logo) :
  - `tools/compose_brand_logo.py` — compose le logo complet à partir de l'emblème ;
  - `tools/generate_brand_assets.py --source tools/logo_source.png --mark-source tools/logo_source_emblem.png`
    — produit toutes les déclinaisons (site + application).

### 7.2 Site web (Django)

| Emplacement | Fichier | Usage |
| --- | --- | --- |
| En-tête (desktop + mobile) | `static/images/logo-mark.png` (192 px) | emblème à côté du nom |
| Pied de page | `static/images/logo.png` (640 px) | logo complet |
| Pages d'authentification (connexion, inscription, vérification, mots de passe) | `static/images/logo.png` | en-tête du formulaire |
| Page hors ligne | `static/images/logo.png` | au-dessus du message |
| PWA / réseaux sociaux | `static/pwa/icon-*.png`, `static/apple-touch-icon.png`, `static/icon/favicon.ico`, `og:image` | icônes système et aperçus de partage |

### 7.3 Application Flutter

| Emplacement | Fichier |
| --- | --- |
| Écran de démarrage Flutter | `assets/images/logo.png` (`SplashScreen`, fond navy) |
| Marque dans l'app (`BrandMark` ≥ 32 px) | `assets/images/logo_mark.png` |
| Splash natif Android | `android/app/src/main/res/drawable{,-v21}/launch_background.xml` + `drawable-*/splash_logo.png` |
| Splash natif iOS | `ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage*.png` |
| Icônes Android / iOS / macOS / Windows | emblème (lisible à petite taille) |
| Web Flutter | `web/favicon.png`, `web/icons/*` + écran de chargement dans `web/index.html` |

> `BrandMark` conserve une pastille dégradée + clé à molette en dessous de 32 px
> (l'illustration n'y serait pas lisible) : les puces de connexion gardent ainsi
> une marque nette.

### 7.4 Poids des fichiers

Toutes les sorties sont redimensionnées à leur usage réel et compressées
(`optimize=True`) : logo web 315 Ko (640 px), emblème web 64 Ko (192 px),
logo app 566 Ko (900 px). À titre de comparaison, le premier export brut pesait
1,8 Mo pour le seul en-tête du site.

### 7.5 Vérifications

- `python manage.py check` : aucun problème ; `collectstatic` régénéré.
- Pages testées (200) avec logo présent : accueil, prestataires, à propos,
  connexion, inscription, mot de passe oublié, hors ligne.
- Assets servis : `/static/images/logo.png`, `/static/images/logo-mark.png`,
  `/static/icon/favicon.ico`, `/static/pwa/icon-192x192.png`,
  `/static/apple-touch-icon.png`, `/static/manifest.json`.
