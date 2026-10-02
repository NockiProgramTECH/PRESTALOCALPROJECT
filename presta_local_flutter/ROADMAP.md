# ROADMAP — Prochaine session de développement

> **Statut de ce document — mise à jour**
> Les points 1 à 6 ci-dessous ont été **traités** (voir `RAPPORT_CORRECTIONS.md`
> à la racine du dépôt pour le détail des fichiers touchés et des vérifications) :
> 1. ✅ Évaluer / liker / commenter : endpoints API + écrans Flutter (bouton
>    « Évaluer ce prestataire », like + commentaires sur les réalisations,
>    garde-fou « connectez-vous »).
> 2. ✅ Favoris synchronisés avec l'API (`GET /api/me/favorites/`,
>    `POST /api/prestataire/{id}/toggle_favorite/`) + cache local hors ligne.
> 3. ✅ Messagerie réelle (REST + WebSocket) — plus aucune donnée fictive.
> 4. ✅ Catégories depuis `GET /api/categories/` (endpoint public + compteur).
> 5. ✅ `flutter_secure_storage` pour les JWT, refresh automatique, données de
>    test (`populate_db.py` : mots de passe + abonnements actifs).
> 6. ✅ Bugs UI de `prompt.md` corrigés (cartes, fiche prestataire, messagerie,
>    profil). Le seul point non reproductible est le « Drawer » : aucun
>    `Drawer` Flutter n'existe dans le code ; le menu latéral du site
>    (`LesProduFao/templates/includes/navbar.html`) a été consolidé pour que son
>    bloc d'authentification ne soit plus rogné par la barre de navigation basse.

---

> **État initial (au moment de la rédaction de ce document)**
> - Authentification complète : inscription + vérification email, connexion, déconnexion, réinitialisation de mot de passe (JWT SimpleJWT).
> - Profil : création / modification (prénom, nom, téléphone, bio, quartier, ville, métier, années d'expérience) + **upload de la photo de profil**.
> - Affichage des prestataires : **listing** (accueil / recherche) et **fiche détail** (réalisations + avis) branchés sur `GET /api/prestataire/`.
> - Backend API : `/api/auth/*`, `/api/auth/me/`, `/api/villes/`, `/api/prestations/`, `/api/prestataire/`.

---

## 1. ✅ Actions connectées : évaluations, likes, commentaires

### Backend (Django — `api/`)
Ajouter des `@action` DRF et des endpoints dédiés. Réutiliser la logique des vues Django existantes (`main/views.py`, `Feed/views.py`).

- **Évaluer un prestataire** : `POST /api/prestataire/{id}/evaluer/` (`@action`)
  - Corps : `note` (1-5), `commentaire`. Authentifié.
  - Réutiliser `submit_evaluation` : une seule évaluation par client (`unique_together`), note max 5, denormalisation `client_nom/prenom/email`.
- **Liker une réalisation** : `POST /api/realisation/{id}/like/` (`@action`, toggle) → `{liked, like_count}`. Réutiliser `Feed.views.toggle_like`.
- **Commenter une réalisation** : `POST /api/realisation/{id}/comment/` (`@action`) → `{comment, comment_count}`. Réutiliser `Feed.views.add_comment`.
- **Endpoints de lecture** :
  - `GET /api/realisation/{id}/` → détail avec `like_count`, `comment_count`, `commentaires` (auteur + contenu + date), `is_liked`.
  - Intégrer les compteurs dans le sérialiseur `RealisationSerializer` (déjà exposé dans le détail prestataire).
- Sérialiseurs à créer : `EvaluationSerializer` (création), `CommentaireSerializer`, `Like` (toggle).

### Frontend (Flutter)
- **Écran « Évaluer »** : dans la fiche détail, bouton « Évaluer » → formulaire (étoiles + commentaire) → POST → rafraîchir la note.
- **Likes / commentaires** : sous chaque réalisation (galerie), boutons like + affichage des commentaires ; saisie d'un commentaire.
- **Gestion « connecté requis »** : si non connecté, rediriger vers l'écran de connexion (les actions exigent le login).
- Modèles : `RealisationModel` à enrichir (`likeCount`, `commentCount`, `comments`, `isLiked`) ; `EvaluationModel` / `CommentModel`.

---

## 2. ✅ Favoris synchronisés avec l'API

Actuellement `FavoritesService` stocke en local (`shared_preferences`).

- **Backend** : le modèle `Favorite` existe déjà (`main/models.py`).
  - `POST /api/prestataire/{id}/toggle-favorite/` (`@action`) → `{status, count}`. Réutiliser `main.views.toggle_favorite`.
  - `GET /api/me/favorites/` → liste des prestataires favoris (ou `?favoris=true`).
  - Ajouter `is_favorite` dans le sérialiseur prestataire (selon le user connecté).
- **Frontend** : remplacer le stockage local par des appels API ; mettre à jour `favorites_provider.dart`.

---

## 3. ✅ Messagerie réelle (chat)

Actuellement le chat est 100% mock (`MockData.conversations`, `message_service.dart`).

- **Backend** : exposer `Messagerie` en DRF (`Conversation`, `Message`) :
  - `GET /api/conversations/`, `GET /api/conversations/{id}/messages/`, `POST /api/conversations/{id}/messages/`.
- **Frontend** : brancher `messages_screen.dart` / `chat_screen.dart` sur ces endpoints ; supprimer `MockData` ; réactiver le bouton « Message » de la fiche prestataire (actuellement neutralisé).

---

## 4. ✅ Catégories depuis l'API

Les chips de catégories (accueil / recherche) utilisent encore `MockData.categories`.

- **Backend** : `GET /api/categories/` (modèle `CategoriePrestation`) → `{id, nom, icone}`.
- **Frontend** : remplacer `MockData.categories` dans `home_screen.dart` et `search_screen.dart` par un provider API.

---

## 5. ✅ Sécurité / robustesse

- **`flutter_secure_storage`** à la place de `shared_preferences` pour les tokens JWT (access + refresh) dans `api_client.dart`.
- Vérifier le refresh automatique des tokens (déjà implémenté dans `ApiClient` — à valider en conditions réelles).
- **Données de test** : `populate_db.py` ne crée pas de mot de passe ni d'abonnement actif → le listing ne montre que les prestataires avec abonnement `paye + est_actif + date_fin > now`. Prévoir un script qui crée des prestataires avec mot de passe + abonnement pour tester le login et l'affichage.

---

## 6. ✅ Corrections UI (issues listées dans `prompt.md`)

Corriger indépendamment de l'API (bugs d'interface existants) :
- **Cartes prestataires** : « right overflowed by 76 pixels » → corriger le positionnement des infos sur la carte.
- **Détail prestataire** : informations soulignées d'un **double trait jaune** (à retirer) ; passer le contenu en arrière-plan derrière la photo de couverture au scroll ; ne pas afficher de prix.
- **Messages** : erreur « No Material widget found » et « bottom overflowed by 99460 pixels » ; nom du destinataire souligné d'un double trait jaune.
- **Drawer** : « bottom overflowed by 38 pixels » sous « Connectez-vous pour plus de fonctionnalités ».
- **Profil** : supprimer la carte « Mes commandes ».

---

## Notes techniques utiles
- Backend : serveur de dev `python manage.py runserver 0.0.0.0:8000` (venv `C:\Users\HP\Documents\LesProduFao`).
- `baseUrl` Flutter : **configurable au lancement** — `flutter run --dart-define=API_BASE_URL=http://192.168.1.85:8000`.
  Par défaut : `10.0.2.2:8000` (émulateur Android) ou `127.0.0.1:8000` (web/desktop).
- Format API : liste paginée sous la clé `results` ; images renvoyées en URL absolue par le viewset.
- Identifiant de test : `testclient@lesprodufao.bf` / `NouveauPass123`.
