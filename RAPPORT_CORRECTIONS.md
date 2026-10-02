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

## 8. Inscription / connexion : correction des trois bugs signalés

### 8.1 Le bug

1. **Après vérification de l'email, l'utilisateur devait se reconnecter** — côté
   site comme côté application.
2. **Après connexion, l'écran ne changeait pas** (l'API `/api/auth/me/`
   répondait 200 mais il fallait relancer l'application pour voir l'état
   connecté).
3. **Un prestataire n'était pas redirigé vers la configuration de son profil**
   après la création de son compte.

### 8.2 Cause n° 2 — navigation Flutter (écran figé)

`AuthGate` est l'écran **racine** de `MaterialApp`, mais les écrans de
connexion/inscription étaient ouverts par-dessus avec `Navigator.push`. Quand
l'état passait à « connecté », `AuthGate` reconstruisait bien `MainShell`…
sous l'écran de connexion toujours affiché : d'où la page figée.

**Correctif** (`lib/screens/auth/login_screen.dart`) : après une connexion
réussie, `Navigator.popUntil((route) => route.isFirst)` dépile tous les écrans
d'authentification ; l'interface connectée devient immédiatement visible.
Le lien « S'inscrire » empile désormais l'écran (`push` au lieu de
`pushReplacement`) pour que ce dépilement soit toujours possible.

### 8.3 Cause n° 1 — connexion automatique après vérification

- **API** (`api/views.py`) : `POST /api/auth/verify-email/` renvoie maintenant
  `access`, `refresh` et le profil (`user`) en plus du message — l'utilisateur
  est connecté dans la requête qui vérifie son code. Par sécurité, un compte
  **déjà** vérifié ne reçoit jamais de jetons par cette route (sinon l'email
  suffirait à se connecter) : il obtient simplement « Cet email est déjà
  vérifié. Connectez-vous. ».
- **Application** (`services/auth_service.dart`, `providers/auth_provider.dart`) :
  `AuthNotifier.verifyEmailAndLogin()` enregistre les jetons renvoyés, met à
  jour l'état (`authenticated`) et retourne le profil. L'écran de vérification
  n'affiche plus « Connectez-vous maintenant » : il poursuit directement le
  parcours. Un repli (connexion avec le mot de passe de l'étape 1) couvre le cas
  d'un backend qui ne renverrait pas de jetons.
- **Site** (`main/views.py`) : la vue appelait déjà `login(request, user)` mais
  le compte venait d'être créé avec `is_active = False` — `ModelBackend` refuse
  un utilisateur inactif, donc la session n'était jamais créée. Elle active donc
  le compte **avant** la connexion. Le gabarit annonce la connexion automatique.

### 8.4 Cause n° 3 — redirection d'un prestataire vers son profil

- **Site** (`main/views.py`) : après vérification, un prestataire est redirigé
  vers `main:profile` (métier, ville, quartier, réalisation, abonnement), un
  client vers son espace (`main:client_dashboard`). Une connexion ultérieure d'un
  prestataire dont le profil est incomplet mène aussi à `main:profile` avec un
  message d'invitation.
- **Formulaire web** (`main/forms.py`) : métier, ville, quartier et années
  d'expérience ne sont obligatoires **que** pour un compte prestataire ; un
  client s'inscrit donc avec son seul email/téléphone (validation dans `clean()`).
  `static/js/auth-forms.js` applique la même règle en direct selon le rôle
  sélectionné.
- **Application** : nouvelle propriété `profile_completed` (modèle `Prestataire`
  → `UserSerializer`) : prestataire → métier + ville + quartier ; client →
  prénom + nom. Après la vérification du code, l'app ouvre
  `ProfileEditScreen(onboarding: true)` (`lib/screens/profile/profile_edit_screen.dart`)
  pour un prestataire : bannière d'accueil, titre « Configurez votre profil »,
  bouton « Terminer », champs indispensables validés. Une fois le profil
  complété, la racine affiche l'interface principale (`MainShell`).

### 8.5 Tests

- `python manage.py test` → **42 tests OK** :
  - `api` : 33 tests (dont 3 nouveaux : connexion immédiate après vérification,
    absence de jetons pour un compte déjà vérifié, `profile_completed`) ;
  - `main` : 9 tests (nouveaux) — inscription client/prestataire, connexion
    automatique + redirection par rôle, code invalide, accès à la page profil,
    et redirections de connexion.
- Parcours vérifiés de bout en bout sur le serveur de développement
  (`curl`) : inscription client → code → `/client/dashboard/` ; inscription
  prestataire (refusée sans métier/ville/quartier) → code → `/profile/` ;
  `POST /api/auth/verify-email/` → jetons + `profile_completed`
  (`true` pour un client, `false` pour un prestataire, qui sera donc envoyé
  vers la configuration de son profil).
- `Core/settings.py` : le stockage de fichiers statiques avec manifeste
  (`CompressedManifestStaticFilesStorage`) n'est plus actif qu'hors `DEBUG`,
  afin qu'un `collectstatic` oublié ne fasse plus échouer le rendu des pages en
  développement et pendant les tests.

## 9. Application : sélecteurs de profil corrigés + abonnement complet

### 9.1 Villes et métiers impossibles à sélectionner (corrigé)

`AuthService.fetchVilles()` / `fetchMetiers()` passaient par
`ApiClient.get()`, qui **ne décode que les objets JSON**. Or `/api/villes/` et
`/api/prestations/` renvoient un **tableau** (endpoints sans pagination) :
le dictionnaire obtenu était vide, donc `_villes` et `_metiers` restaient
vides et les menus déroulants « Ville » / « Métier » ne s'ouvraient pas.

- `lib/services/auth_service.dart` : passage à `ApiClient.getList()`
  (qui accepte le tableau direct **et** l'objet paginé `{"results": [...]}`).
- `lib/screens/profile/profile_edit_screen.dart` : si les listes ne chargent
  pas, un bandeau « Villes et métiers indisponibles » avec bouton
  **Réessayer** remplace les menus vides (plus d'écran muet) ; libellés
  d'aide « Sélectionnez votre ville / votre métier ».
- La biographie reste un champ de texte libre : elle est enregistrée avec le
  reste du profil via `PATCH /api/auth/me/`.
- Test API ajouté : `/api/categories/`, `/api/villes/` et `/api/prestations/`
  doivent renvoyer un **tableau JSON** (contrat attendu par l'app).

### 9.2 Abonnement : nouvelles fonctions dans l'application

Rien n'existait côté app alors que le site web gérait déjà les offres, le
paiement Mobile Money simulé et la mise en avant. Ajout d'un parcours
complet, aligné sur le web :

| Fonction | Emplacement |
| --- | --- |
| Écran « Abonnement » (état, bénéfices, offres, paiement) | `lib/screens/profile/subscription_screen.dart` |
| Service (offres, état, souscription) | `lib/services/subscription_service.dart` |
| Carte « Mettre mon profil en avant » + section **MON ABONNEMENT** | `lib/screens/profile/profile_screen.dart` |
| Badge **Profil mis en avant** (listes, fiche prestataire, profil) | `lib/widgets/badges.dart` (`FeaturedPill`), `provider_card.dart`, `profile_model.dart` |
| Astuce abonnement à la fin de la configuration prestataire | `lib/screens/profile/profile_edit_screen.dart` |
| « Moyens de paiement » (profil pro) → parcours d'abonnement | `lib/screens/profile/profile_screen.dart` |

Nouveaux endpoints Django (`api/urls.py`) :

| Méthode | URL | Rôle |
| --- | --- | --- |
| GET | `/api/abonnement/plans/` | offres (public) |
| GET | `/api/abonnement/mon-abonnement/` | état de l'abonnement du prestataire |
| POST | `/api/abonnement/souscrire/` | `{plan, methode, otp}` → active l'abonnement |

`/api/auth/me/` expose désormais `abonnement_actif`, `abonnement_plan`,
`abonnement_fin` et `abonnement_jours_restants` : l'app affiche donc le badge
et l'échéance immédiatement après la souscription (rafraîchissement du profil
via `AuthNotifier.refreshProfile()`), sans redémarrer.

`ProviderModel.isFeatured` est branché sur `abonnement_actif` (il était figé à
`false`) : les prestataires abonnés portent la pastille « Profil mis en avant »
dans les listes et sur leur fiche.

### 9.3 Vérifications

- `python manage.py test` → **49 tests OK** (dont 7 nouveaux sur l'abonnement
  et le contrat « listes de référence en tableau »).
- Parcours API complet rejoué sur le serveur de développement :
  `GET /api/abonnement/plans/` → offres ; connexion prestataire ;
  `POST /api/abonnement/souscrire/` (`{plan, methode: "Orange Money", otp}`)
  → 201, abonnement actif + `transaction_id` ; `GET /api/auth/me/` →
  `abonnement_actif = true`, offre et jours restants ;
  `GET /api/prestataire/?abonnes_only=1` → 8 profils mis en avant.
- Paiement **simulé** (comme sur le site) : aucun montant réel n'est prélevé.

### 9.4 Session expirée : plus d'interface figée

`ApiClient` vide les jetons dès que le refresh token est refusé, mais aucun
signal n'était envoyé à l'interface : l'app restait affichée en mode
« connecté » avec des écrans figés jusqu'au redémarrage.

- `ApiClient.onSessionExpired` : nouveau signal émis sur 401 authentifié ou
  refresh refusé.
- `AuthNotifier` s'y abonne et repasse en état **déconnecté** avec un message
  explicite (« Votre session a expiré, veuillez vous reconnecter. »).
- `AuthGate` (`lib/main.dart`) dépile les écrans ouverts lors du passage
  connecté → déconnecté : l'écran de connexion redevient visible
  immédiatement (déconnexion volontaire comme expiration de session).

## 10. Visibilité des prestataires liée à l'abonnement

### 10.1 Règle appliquée

Un compte prestataire peut être **actif** (email vérifié, profil complet) sans
être **visible** : c'est l'abonnement qui ouvre la visibilité et le contact.

| Situation | Liste des prestataires | Fiche détaillée | Coordonnées |
| --- | --- | --- | --- |
| Abonnement payé, actif, non expiré | présent | accessible | téléphone + email |
| Sans abonnement (ou expiré) | **absent** | consultable (depuis une publication) | **masquées** |
| Publications (fil d'actualité) | toujours visibles | — | auteur marqué « Non contactable » |

Mise en œuvre côté API (`api/views.py`, `api/serializers.py`) :

- `GET /api/prestataire/` filtre par défaut sur
  `abonnement__paye=True`, `abonnement__est_actif=True`,
  `abonnement__date_fin__gt=now`. `?include_all=1` lève le filtre (aperçu
  interne, administration, tests) ; `?abonnes_only=1` reste accepté.
- La fiche `GET /api/prestataire/<id>/` **reste accessible** : on peut y
  arriver depuis une publication du fil. Le sérialiseur masque alors
  `telephone` et `email` et renvoie `contact_disponible = false` (masquage en
  lecture uniquement : l'écriture n'est pas impactée).
- `FeedPrestataireSerializer` expose `abonnement_actif` et
  `contact_disponible` pour que le fil signale un auteur non contactable.

### 10.2 Application

- `ProviderModel.contactDisponible` (nouveau) : la fiche prestataire affiche un
  bandeau « Ce prestataire n'a pas d'abonnement actif… » et les boutons
  **Message / Appel / WhatsApp** ainsi que le formulaire de devis sont
  désactivés avec un message explicite.
- Fil d'actualité : pastille « Non contactable — abonnement inactif » sur les
  publications d'un auteur sans abonnement (ses réalisations restent visibles).
- Recherche : mention « Seuls les prestataires avec un abonnement actif sont
  listés ici ».
- Profil prestataire : la carte d'abonnement indique désormais clairement
  « Sans abonnement actif, votre profil n'apparaît pas dans les recherches
  clients ».

### 10.3 Lien vers le site web (fonctionnalité abonnement)

Le site web reste la référence pour le paiement Mobile Money et la gestion
complète du profil prestataire ; l'application y renvoie désormais
explicitement :

- section **PRÉFÉRENCES & SUPPORT** du profil → « Abonnement » (écran in-app)
  et « Gérer mon abonnement sur le site web » (navigateur, URL affichée) ;
- écran « Abonnement » → bouton **Gérer sur le site web** ;
- méthodes mobiles « Moyens de paiement » et carte « Mettez votre profil en
  avant » → parcours d'abonnement in-app.

Nouvelle constante `AppConstants.webBaseUrl` (surchargeable au build via
`--dart-define=WEB_BASE_URL=…`, sinon l'hôte de l'API) et
`AppConstants.subscriptionWebUrl` = `<site>/abonnement/plans/`.

### 10.4 Connexion : dépilement garanti des écrans d'authentification

Pour supprimer définitivement l'effet « page figée après connexion »,
indépendamment de l'écran d'où l'utilisateur se connecte :

- `lib/navigation/auth_navigation.dart` : les écrans de connexion/inscription
  sont empilés avec `authRoute()` (route nommée `auth`) ;
- `LesProduFaoApp` écoute l'état d'authentification avec une **clé de
  navigateur** : dès qu'une session s'ouvre, `popAuthRoutes()` dépile les
  écrans d'authentification (sans toucher à la configuration du profil
  poussée juste après) ; à la déconnexion ou à l'expiration de session, retour
  à la racine.

### 10.5 Vérifications

- `python manage.py test` → **53 tests OK** (4 nouveaux : liste réservée aux
  abonnés, coordonnées visibles pour un abonné, `include_all` qui lève le
  filtre sans ouvrir le contact, abonnement expiré masqué).
- Parcours API rejoué sur le serveur de développement :
  liste par défaut = 8 abonnés ; inscription d'un prestataire sans abonnement
  → absent de la liste, fiche consultable avec `contact_disponible = false`,
  téléphone/email `null` ; `?include_all=1` → présent mais toujours masqué ;
  après souscription → présent dans la liste (9 au total).

---

## 11. Fil d'actualité de l'Accueil (refonte « réseau social »)

Objectif : que la section **Accueil / fil d'actualité** se comporte et se
présente comme un fil d'actualité moderne (création en haut, cartes, J'aime /
Commenter / Partager, défilement infini), en orange/blanc/gris et **sans
reprendre le logo ni l'identité graphique de Facebook**.

### 11.1 Zone de création en haut du fil

- `lib/screens/feed/feed_composer_sheet.dart` (nouveau) : panneau modal
  « Créer une publication » — photo de profil, nom, audience « Publique »,
  champ multiligne « Quoi de neuf dans votre activité ? », barre d'outils
  **Photos / Vidéo / Catégorie**, champ **Lien externe**, aperçu des fichiers
  avec bouton de retrait, bouton **Publier** (état « Envoi en cours… »).
- Le clic sur le champ « Quoi de neuf ? » de l'accueil (`_FeedSection`) ou de
  la page « Fil d'actualité » ouvre ce panneau : la rédaction se fait dans une
  interface confortable, jamais dans un champ d'une ligne.
- Fermeture : bouton ✕ ou geste ; si un brouillon existe, une confirmation
  « Abandonner la publication ? » évite la perte de contenu.

### 11.2 Gestion du contenu et validation

- Contenu : texte seul, une ou plusieurs images, vidéo, lien, catégorie —
  et toutes les combinaisons (texte + médias, catégorie seule, etc.).
- Validation **côté application** (`feed_composer_sheet.dart`) *et* **côté
  backend** (`api/serializers.py`) : mêmes limites des deux côtés —
  **10 images maximum**, **5 Mo par image** (JPG/JPEG/PNG/WEBP), **50 Mo pour
  la vidéo** (MP4/MOV/M4V/WEBM), publication vide refusée.
- L'application affiche l'erreur exacte renvoyée par l'API dans un encart
  rouge ; la publication **n'est annoncée comme enregistrée que si la requête
  a réussi** (le message de succès est émis après la réponse 2xx, jamais
  avant). Un échec réseau laisse le panneau ouvert avec le brouillon intact.
- Modification : menu ⋯ → « Modifier » rouvre le même panneau en mode édition
  (titre, texte, lien, catégorie) ; la catégorie peut aussi être retirée
  (`PATCH {"categorie": null}`).

### 11.3 Carte de publication et interactions

- `lib/widgets/feed_card.dart` : carte blanche à coins arrondis — en-tête
  (photo, nom + badge Vérifié, `métier · ville · date relative`), texte
  complet (« Voir plus / Voir moins » au-delà de 220 caractères), médias
  (image seule, paire, grille 2×2 avec pastille « +N », vidéo jouable),
  pastille de catégorie, aperçu du lien externe, compteurs réels puis barre
  d'actions **J'aime / Commenter / Partager**.
- `lib/widgets/feed_interactive_card.dart` (nouveau) : carte branchée sur
  l'API (J'aime avec compte à rebours réel, partage, modification,
  suppression) — l'accueil et la page complète utilisent le **même** widget,
  donc les mêmes comportements.
- J'aime : `POST /api/feed/<id>/like/` renvoie `{liked, like_count}` ; le
  compteur affiché est celui du serveur.
- Commenter : ouvre le détail avec la zone de saisie déjà focalisée.
- Partager : feuille « Copier le lien / Partager via WhatsApp / Ouvrir la
  fiche du prestataire » (`lib/utils/feed_actions.dart`, `url_launcher`).
- Permissions : menu **Modifier / Supprimer** uniquement si `can_edit` /
  `can_delete` (l'auteur, ou un rôle de modération) ; les autres comptes ne
  voient aucune action de gestion. Suppression confirmée par une boîte de
  dialogue, puis retrait de la carte.

### 11.4 Organisation du fil

- Tri du plus récent au plus ancien (backend `-date_ajout`), **pagination de
  10 publications** avec **défilement infini** (préchargement 400 px avant la
  fin, anti-doublons par identifiant, plafond serveur `page_size ≤ 50`).
- États gérés : chargement initial (squelettes), **état vide** « Aucune
  publication pour le moment » avec bouton **Publier une actualité**, **état
  d'erreur** avec bouton **Réessayer**, tirer-pour-rafraîchir, pied de liste
  « Vous êtes à jour », indicateur de chargement de la page suivante.
- Après publication ou modification, le fil et le portfolio sont
  rechargés depuis le backend (`invalidate` des providers).

### 11.5 Identité visuelle

Orange `#FF8A3D` pour toutes les actions (Publier, J'aime, liens, icônes de
la barre d'outils), cartes blanches, fond sable/gris clair `#FBF9F7`, textes
secondaires gris ardoise `#64748B`, titres navy quasi noir, coins arrondis
(18 px), séparateurs `#EAE3DB`, écarts réguliers (12/14 px), aucun élément
propriétaire ni logo tiers.

### 11.6 Contrat d'API utilisé

- `GET /api/feed/` (public) : `count`, `next`, `results[]` —
  `id, titre, contenu, lien, categorie, categorie_nom, images[], image,
  video_url, date_ajout, modifie_le, prestataire{…}, like_count,
  comment_count, is_liked, can_edit, can_delete` ; filtres `mine`,
  `prestataire`, `categorie`, `search`, `page`, `page_size`.
- `POST /api/feed/` (multipart, authentifié) : `contenu`, `titre`,
  `images` (répété, ≤ 10), `image` (ancien client), `video`, `lien`,
  `categorie` → **201 avec la publication complète**.
- `GET/PATCH/DELETE /api/feed/<id>/` : lecture publique ; `PATCH` réservé à
  l'auteur (403 sinon) ; `DELETE` auteur ou `is_staff` (403 sinon).
- `GET/POST /api/feed/<id>/comment/` : lecture publique, ajout authentifié
  (`comment`, `comment_count`) ; commentaires enrichis `user_id`,
  `user_photo`, `is_author` (= « écrit par moi »).
- Modèle : `Realisation` gagne `contenu`, `video`, `lien`, `categorie`
  (FK `CategoriePrestation`, `SET_NULL`), `modifie_le` ; `image` devient
  facultative et `RealisationImage` porte les images supplémentaires.

### 11.7 Vérifications

- `python manage.py test` → **66 tests OK** (9 nouveaux sur le fil :
  publication texte seul, images multiples, refus du vide, refus de 11
  images, extension interdite, 401 anonyme, pagination/tri, recherche et
  filtre catégorie, édition par l'auteur, 403 pour un autre compte,
  suppression par un modérateur, J'aime aller-retour, commentaires).
- Parcours API rejoué sur le serveur de développement (curl) :
  `POST` texte seul → 201 (`images: []`, `can_edit/can_delete: true`) ;
  `POST` 3 images + lien + catégorie → 201 (3 URLs, image principale = 1ʳᵉ) ;
  image de 25 Mo → **400 « fichier trop volumineux (maximum 5 Mo) »** ;
  fichier `.exe` → 400 ; publication vide → 400 ; `PATCH` par un autre
  prestataire → **403** ; `PATCH` par l'auteur → 200 avec `modifie_le` ;
  `PATCH {"categorie": null}` → 200 ; `DELETE` par un tiers → 403 ; par
  l'auteur → 204 ; commentaires `GET`/`POST` → 200/201 avec compteur ;
  J'aime aller-retour → `{liked, like_count}` cohérents ; fiche publique
  sans jeton → `is_liked: false`, `can_edit: false`, compteurs exacts.

### 11.8 Site web aligné sur le nouveau modèle

`image` étant devenue facultative, le site a été adapté pour ne rien casser :
`templates/feed/feed_items.html` (texte `contenu`, image **ou** vidéo
facultatives, lien), `templates/main/prestataire_detail.html` et
`templates/main/profile.html` (vignette de repli avec le texte),
`static/js/profile.js` (nouvelle réalisation sans image),
`main/forms.py` (champ `contenu` dans le formulaire d'ajout, image désormais
facultative) et styles `.feed-card__text` / `.portfolio-item__text`.

### 11.9 Application à recompiler

Aucun SDK Flutter n'est disponible dans l'environnement de travail : le code
Dart a été contrôlé par analyse structurelle (équilibrage et imbrication de
tous les délimiteurs, commentaires et chaînes retirés) et par vérification
des symboles utilisés (`AppTheme.*`, `AppConstants.*`, méthodes du service).
L'application doit être **recompilée** (`flutter run` / `flutter build`) sur
un poste disposant du SDK pour valider l'affichage final et, le cas échéant,
reformater avec `dart format`.

---

## 12. Relances d'abonnement multi-canal et refactoring (architecture)

### 12.1 Audit préalable — problèmes détectés

| # | Problème | Emplacement | Gravité |
|---|---|---|---|
| 1 | Envoi d'emails **dupliqué à 6 endroits** (construction `EmailMultiAlternatives` + `render_to_string` + `try/except` recopiés) | `main/views.py` (×4), `api/serializers.py`, `Abonnement/management/commands/check_subscriptions.py` | forte |
| 2 | Erreurs avalées par `except Exception` + `print(...)` : aucun journal, aucun suivi, succès affiché même si l'email n'est jamais parti | `main/views.py` | forte |
| 3 | **Logique métier dans les vues** : règles d'abonnement (création, échéance, transaction) recopiées dans la vue web *et* dans le sérialiseur API | `Abonnement/views.py`, `api/serializers.py` | forte |
| 4 | **Duplication like/commentaire** entre le site et l'API (deux implémentations du toggle et de l'ajout de commentaire) | `Feed/views.py`, `api/views.py` | moyenne |
| 5 | Liste des offres par défaut recopiée dans deux modules | `Abonnement/views.py`, `api/views.py` + `DEFAULT_PLANS` | moyenne |
| 6 | Rappel d'expiration : **une seule fois**, 7 jours avant, sans trace → un envoi manqué est définitif ; aucune relance des abonnements expirés ni des inscrits jamais abonnés | `check_subscriptions.py` | forte |
| 7 | Liens des emails vers `/profile/` sans contexte : le prestataire ne sait pas pourquoi il reçoit le message ; aucun lien d'abonnement direct | `templates/emails/*` | moyenne |
| 8 | Aucune journalisation applicative (pas de logger métier, `print()` en production) | transverse | moyenne |
| 9 | Imports et constantes mortes après déplacement de logique | `api/serializers.py`, `Abonnement/views.py` | faible |
| 10 | Fichiers volumineux mêlant plusieurs responsabilités : `api/serializers.py` (1160 l.), `api/views.py` (804 l.), `main/views.py` (596 l.) ; côté Flutter `profile_screen.dart` (2551 l.), `login_screen.dart` (1617 l.) | — | moyenne (planifié) |

### 12.2 Plan appliqué (priorisé)

1. **Couche de notifications** (`Notifications/`) : canaux interchangeables,
   service d'envoi, journal en base (idempotence + traçabilité).
2. **Services métier d'abonnement** : `souscrire` (règle unique), offres par
   défaut, `abonnement_actif`.
3. **Services métier du fil** : `basculer_like`, `ajouter_commentaire`,
   `compter_commentaires` (partagés site + API).
4. **Workers** : `executer_relances_abonnement` + commande
   `relancer_abonnements` (planifiable), ancienne commande conservée en alias.
5. **Refactoring des vues** : suppression des 6 envois directs d'emails.
6. **Tests** : services, canaux, worker, vues d'abonnement (10 nouveaux).
7. **Documentation** : `PrestLocal/docs/notifications.md`.

### 12.3 Fichiers créés / modifiés

**Créés** — `Notifications/{__init__,models,service,registre,abonnement,tasks,tests}.py`,
`Notifications/channels/{base,email,whatsapp,push}.py`,
`Notifications/management/commands/relancer_abonnements.py`,
`Notifications/migrations/0001_initial.py`,
`Feed/services.py`, `Feed/tests.py`, `Abonnement/services.py`,
`Abonnement/tests.py`, `templates/emails/abonnement_relance.html`,
`PrestLocal/docs/notifications.md`.

**Modifiés** — `Core/settings.py` (app, canaux, seuils, loggers), `.env.example`,
`main/views.py` (4 envois délégués, hook redondant retiré),
`api/serializers.py` (`send_code_email` délégué, souscription déléguée, imports morts retirés),
`api/views.py` (like/commentaire/offres délégués), `Feed/views.py`,
`Abonnement/views.py` (+ vue `gestion_abonnement`), `Abonnement/urls.py`,
`Abonnement/management/commands/check_subscriptions.py`,
`templates/abonnement/plan_list.html` (bandeau), `templates/emails/subscription_request.html`
(lien d'abonnement), `RAPPORT_CORRECTIONS.md`.

### 12.4 Responsabilités déplacées

| Avant | Après |
|---|---|
| Construction des emails dans les vues | `Notifications.service.envoyer_email` |
| Règles d'attribution d'abonnement dans 2 fichiers | `Abonnement.services.souscrire` |
| Toggle like / ajout commentaire dans 2 fichiers | `Feed.services` |
| Liste des offres par défaut dans 2 fichiers | `Abonnement.services.PLANS_PAR_DEFAUT` |
| Rappel d'expiration monolithique | `Notifications.abonnement` (règles) + `Notifications.tasks` (worker) |

### 12.5 Améliorations de testabilité

- Canaux **injectables** : `ServiceNotification(canaux=[CanalEnregistreur()])`
  permet de tester un envoi sans SMTP ni réseau.
- Backend email `locmem` + `mail.outbox` pour vérifier contenu et liens.
- Services purs testés sans HTTP (`Feed/tests.py`, `Abonnement/tests.py`).
- Vues testées sur les codes/rédactions (bandeau, redirections, refus du
  mauvais compte).

### 12.6 Vérifications réellement exécutées

- `python manage.py check` → aucun problème.
- `python manage.py test` → **97 tests OK** (66 → 87 → 97 : 21 tests
  Notifications, 5 tests services du fil, 5 tests services d'abonnement).
- Sur le serveur de développement :
  `relancer_abonnements --simulation` → 3 cibles (bientôt expiré, expiré,
  jamais abonné) ; exécution réelle → **3 emails envoyés** et journalisés ;
  seconde exécution → *0 envoyée, 3 ignorées* (idempotence confirmée).
- Lien du bouton vérifié dans le corps HTML :
  `…/abonnement/gestion/<id>/?ref=<jeton signé>`.
- Multi-canal par configuration seule : `NOTIFICATIONS_CHANNELS=email,whatsapp,push`
  → journal `email:envoye`, `whatsapp:ignore`, `push:ignore`, **sans changer une
  ligne de code métier**.
- Parcours web : lien ouvert par le bon compte → redirection vers les offres et
  bandeau affiché ; ouvert par un autre compte → redirection accueil, aucun
  bandeau ; sans jeton → aucun bandeau.

### 12.7 Actions manuelles nécessaires (déploiement)

1. `python manage.py migrate` (crée la table du journal de notifications).
2. Renseigner `SITE_URL` avec le domaine réel (les liens d'email partent de
   cette base).
3. Planifier `python manage.py relancer_abonnements` **une fois par jour**.
4. Optionnel : `NOTIFICATIONS_CHANNELS`, clés WhatsApp/push quand les
   fournisseurs seront choisis.

### 12.8 Reste à traiter (non fait volontairement)

- ~~**Découpage des gros modules** (`api/serializers.py`, `api/views.py`,
  `main/views.py` → packages)~~ : **fait**, voir le §13 (mêmes routes, mêmes
  contrats d'import).
- **Application mobile** : les canaux push/WhatsApp ne concernent que le
  backend ; l'enregistrement des jetons d'appareil (FCM) reste à faire, ainsi
  que son côté Flutter (`firebase_messaging`).
- **File de tâches** : non installée (YAGNI). Si les campagnes deviennent
  longues ou si l'on veut des tentatives automatiques, brancher Celery/RQ :
  seul l'appelant du worker change.
- **Refactoring Flutter** (`profile_screen.dart` 2551 lignes,
  `login_screen.dart` 1617 lignes) : à découper par fonctionnalité.

---

## 13. Refactoring en couches : audits, services et découpage des gros modules

Deuxième passe d'architecture (Clean Code / SOLID), appliquée **sans casser
l'existant** : aucune route, aucun contrat d'API, aucune migration modifiés.

### 13.1 Audit — problèmes détectés

| # | Problème | Preuve / portée |
|---|---|---|
| 1 | `api/serializers.py` : **1141 lignes**, six domaines mélangés (comptes, prestataires, fil, référence, abonnement) | `wc -l` avant refactoring |
| 2 | `api/views.py` : **796 lignes**, même mélange côté vues | idem |
| 3 | `main/views.py` : **604 lignes**, cinq domaines (pages, comptes, profil, portfolio, notifications) | idem |
| 4 | Requête des prestataires visibles **écrite 3 fois** (annuaire web, accueil, API liste/détail) — dont une version **en Python** (`[p for p in qs if p.has_active_subscription]`) qui chargeait toute la table | `main/views.py::index`, `PrestataireListView`, `api/views.py::get_queryset` |
| 5 | Queryset annoté du fil **dupliqué** entre la liste et le détail de l'API | `api/views.py` (2 blocs identiques de ~25 lignes) |
| 6 | Règles métier dans les vues : création du code + email d'inscription, activation, réinitialisation, dépôt d'avis | `main/views.py` |
| 7 | Compteurs d'audience (appel/contact) : même arithmétique `F()+1` + `refresh_from_db` recopiée | `main/views.py` (2 vues) |
| 8 | **Fuite d'information** : `except Exception as e: message=str(e)` renvoyait le détail technique au navigateur ; `print()` au lieu du logger en cas d'échec d'email | `main/views.py::submit_evaluation`, `signup_view` |
| 9 | N+1 : `average_rating` et `review_count` interrogeaient la base **par carte** (aucune annotation) ; le fil n'était pas préchargé (1 requête de likes par publication) | gabarits `includes/prestataire*.html`, `feed/feed_items.html` |
| 10 | `except Exception` masquant des erreurs réelles : `has_active_subscription` (modèle), authentification WebSocket | `main/models.py`, `Core/middleware.py` |
| 11 | Fenêtre d'incohérence à l'inscription : compte créé puis `delete()` si l'email échouait (non transactionnel) | `main/views.py::signup_view` |

### 13.2 Plan appliqué (priorisé)

1. **Requêtes partagées** : `PrestataireQuerySet` (`prestataires()`, `visibles()`,
   `avec_relations()`, `avec_note_moyenne()`, `avec_note_et_avis()`) et
   `Feed/selectors.py` — élimine les problèmes 4, 5 et 9.
2. **Services du domaine `main`** : `comptes.py`, `avis.py`, `favoris.py`,
   `prestataires.py` — élimine 6, 7, 11.
3. **Découpage `main/views.py` → `main/views/`** (pages, comptes, prestataires,
   portfolio, notifications) — élimine 3.
4. **Découpage `api/serializers.py` → paquet par domaine** (commun, reference,
   prestataires, feed, comptes, abonnement) — élimine 1.
5. **Découpage `api/views.py` → paquet par domaine** + `api/selectors.py` —
   élimine 2 et réutilise les requêtes du point 1.
6. **Erreurs et journalisation** : exceptions métier traduites en 400/403/404,
   plus de `str(e)` dans les réponses, `logger` au lieu de `print`, `except`
   ciblés — élimine 8 et 10.
7. **Tests** : services/selectors sans HTTP, codes de réponse des endpoints
   AJAX, garde-fou anti-N+1 — couvre l'ensemble.

### 13.3 Fichiers créés

- `main/querysets.py`, `main/selectors.py`
- `main/services/{__init__,comptes,avis,favoris,prestataires}.py`
- `main/views/{__init__,pages,comptes,prestataires,portfolio,notifications}.py`
- `api/selectors.py`
- `api/serializers/{__init__,commun,reference,prestataires,feed,comptes,abonnement}.py`
- `api/views/{__init__,prestataires,comptes,reference,feed,abonnement}.py`
- `Feed/selectors.py`
- `main/test_services.py` (26 tests)
- `PrestLocal/docs/architecture.md` (guide « où écrire quoi »)

### 13.4 Fichiers supprimés / remplacés

- `main/views.py` → paquet `main/views/` (l'ancien fichier est supprimé).
- `api/serializers.py` → paquet `api/serializers/`.
- `api/views.py` → paquet `api/views/`.

Les paquets réexportent **tous** les noms publics dans leur `__init__.py` :
`from api.serializers import RegisterSerializer`, `from .views import
PrestataireViews` et `main/urls.py` continuent de fonctionner sans modification.

### 13.5 Fichiers modifiés

`main/models.py` (manager basé sur le queryset, annotation utilisée par les
propriétés de note, `except` ciblé), `Feed/views.py` (queryset délégué au
selector), `Core/middleware.py` (erreurs de jeton ciblées), `main/forms.py`
(import inutilisé), `CONTEXT_PROJET.md` (arborescence), `RAPPORT_CORRECTIONS.md`.

### 13.6 Responsabilités déplacées

| Avant | Après |
|---|---|
| Filtre « abonnement actif » recopié dans 3 vues, dont une boucle Python | `PrestataireQuerySet.visibles()` (une requête SQL) |
| Annotation et préchargements des prestataires dans la vue API | `api/selectors.prestataires_api()` + `main.querysets` |
| Queryset annoté du fil écrit deux fois dans l'API | `Feed.selectors.publications_annotees()` (site **et** API) |
| Création du code, activation, réinitialisation dans les vues | `main.services.comptes` (transactionnel pour l'inscription) |
| Validation et écriture de l'avis dans la vue web **et** dans l'API | `main.services.avis.soumettre_avis` (+ `notifier_nouvel_avis`) |
| Statistiques d'avis (`Avg`/`Count`) dans la vue API | `main.services.avis.statistiques_avis` |
| Toggle des favoris écrit deux fois | `main.services.favoris.basculer_favori` |
| Incréments `F()+1` recopiés | `main.services.prestataires.enregistrer_clic` |
| `str(e)` renvoyé au client | Exceptions métier → 400/404, journalisation côté serveur |

### 13.7 Améliorations de testabilité

- Les services ne reçoivent ni `request` ni `HttpResponse` : testables par
  appel direct (26 nouveaux tests dans `main/test_services.py`).
- Les envois d'emails passent par `Notifications.service` : `mail.outbox`
  suffit, aucun accès SMTP.
- L'atomicité de l'inscription est **testée** : canal indisponible
  (`NOTIFICATIONS_CHANNELS=['push']`) → `EnvoiCodeImpossible` et aucun compte
  en base.
- Le garde-fou anti-N+1 compare le nombre de requêtes pour 2 puis 6 cartes :
  il échoue si une requête par carte réapparaît.
- Les codes HTTP des endpoints AJAX (403 anonyme, 404 inconnu, 400 champs
  manquants, 400 note hors bornes, 400 second avis) sont verrouillés par des
  tests.

### 13.8 Vérifications réellement exécutées

| Commande / test | Résultat |
|---|---|
| `python manage.py check` | aucun problème |
| `python manage.py test` (avant refactoring) | 97 tests OK |
| `python manage.py test` (après chaque étape) | 97 → 118 → **128 tests OK** |
| `python -m pyflakes` sur les paquets refactorisés | aucun avertissement |
| `manage.py test main.test_services` | 26 tests OK (services, selectors, codes HTTP, anti-N+1) |
| `manage.py test Feed` | 9 tests OK (dont 5 nouveaux sur les endpoints AJAX du fil) |
| Vérification HTTP (serveur local) | `/`, `/prestataires/`, `/login/`, `/signup/`, `/feed/list/`, `/api/prestataire/`, `/api/feed/`, `/api/villes/`, `/api/categories/`, `/api/abonnement/plans/` → 200 ; `/abonnement/plans/` → 302 (connexion requise) |
| Accueil avec 3 publications | les cartes du fil sont rendues (sélecteur + préchargements OK) |

Aucun test n'a été supprimé ni adapté à la baisse : les 97 tests existants
(parcours web, API DRF, notifications, abonnements, fil) passent sans
modification, ce qui prouve la préservation des comportements et des contrats.

### 13.9 Migrations et actions manuelles

- **Aucune migration** : seuls des fichiers Python ont été déplacés ; le schéma
  de base est inchangé (aucune opération destructive).
- **Aucune variable d'environnement** nouvelle.
- Après déploiement : rien de particulier, le serveur applicatif suffit
  (`python manage.py migrate` n'est nécessaire que pour le lot précédent, §12).

### 13.10 Reste à traiter

- `main/tests.py` et `api/tests.py` pourraient à leur tour devenir des paquets
  `tests/` (test_vues, test_api…) pour se lire plus vite ; sans urgence.
- Les fichiers `api/admin.py`, `api/models.py`, `Feed/admin.py` contiennent les
  imports par défaut de Django inutilisés (nettoyage cosmétique).
- Validation des données du site : `PrestataireSignupForm` reste la frontière
  unique — un passage aux `forms` par domaine n'est pas nécessaire aujourd'hui.
- Côté Flutter, les gros écrans (`profile_screen.dart` 2551 lignes,
  `login_screen.dart` 1617 lignes) restent à découper (hors périmètre backend).
