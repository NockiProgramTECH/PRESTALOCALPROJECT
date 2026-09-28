# PrestaLocal — Contexte projet pour IA

## Intention du projet

**PrestaLocal** est une plateforme de mise en relation entre **prestataires de services locaux** et **clients** à **Ouagadougou, Burkina Faso**. L'objectif est de permettre aux utilisateurs de trouver, contacter et évaluer des prestataires de proximité (plombiers, électriciens, couturiers, etc.), avec un système d'abonnement pour la visibilité des prestataires.

---

## Stack technique

| Couche | Technologie |
|--------|------------|
| Backend | Python 3.13, Django 5.2.5, Django REST Framework 3.16.1 |
| Auth | SimpleJWT 5.5.1 (access + refresh tokens) |
| WebSocket | Django Channels 4.3.1 + Daphne 4.2.1 (ASGI) |
| Base de données | PostgreSQL (Neon cloud) |
| Cache/Channels | Redis |
| Frontend mobile | Flutter/Dart SDK ^3.11.1, Riverpod, go_router |
| Frontend web | Templates Django + CSS/JS vanilla (PWA avec service worker) |
| Infrastructure | Docker + Docker Compose |

---

## Architecture du projet

```
PRESTALOCAL/
├── PrestLocal/                    # Backend Django
│   ├── Core/                      # Config Django (settings, urls, asgi, wsgi, middleware)
│   ├── main/                      # App principale : modèles User, Ville, Prestation, Realisation, Evaluation, Favorite, Notification
│   ├── Abonnement/                # App abonnement : PlanAbonnement, Abonnement
│   ├── Feed/                      # App fil d'actualité : Like, Commentaire sur les réalisations
│   ├── Messagerie/                # App messagerie temps réel : Conversation, Message, WebSocket consumers
│   ├── api/                       # API REST : serializers, views, urls, permissions
│   ├── templates/                 # Templates HTML Django (PWA)
│   ├── static/                    # Fichiers statiques (CSS, JS)
│   ├── media/                     # Uploads utilisateurs
│   ├── docker-compose.yml
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── manage.py
│   └── .env                       # Variables d'environnement
│
└── presta_local_flutter/          # Frontend mobile Flutter
    └── lib/
        ├── config/                # Constantes, thème
        ├── models/                # Modèles Dart (provider, conversation, feed, etc.)
        ├── providers/             # State management Riverpod (auth, favorites, app_state)
        ├── screens/               # Écrans (auth, home, search, feed, messages, profile, favorites)
        ├── services/              # Clients API et WebSocket
        └── widgets/               # Composants réutilisables
```

---

## Modèles de données principaux

- **Prestataire** (AbstractUser, UUID PK) — rôle prestataire/client, métier, ville, quartier, bio, années d'expérience, disponibilité, vérification
- **Ville** — nom de ville
- **CategoriePrestation** / **Prestation** — catégories et types de services
- **Realisation** — portfolio du prestataire (image, titre)
- **Evaluation** — avis client (note 1-5, commentaire), unique par couple prestataire/client
- **Favorite** — favoris utilisateur
- **Notification** — notifications (nouveau message, avis, etc.)
- **PlanAbonnement** / **Abonnement** — plans d'abonnement avec durée et prix (FCFA)
- **Like** / **Commentaire** — interactions sur le fil d'actualité
- **Conversation** / **Message** — messagerie instantanée

---

## Endpoints API (`/api/`)

### Authentification
- `POST /api/auth/token/` — Connexion (JWT)
- `POST /api/auth/token/refresh/` — Rafraîchir le token
- `POST /api/auth/token/logout/` — Déconnexion
- `GET|PATCH /api/auth/me/` — Profil utilisateur courant
- `POST /api/auth/register/` — Inscription (envoi code vérification email)
- `POST /api/auth/verify-email/` — Vérification email
- `POST /api/auth/password-reset/` — Demande réinitialisation mot de passe
- `POST /api/auth/password-reset/confirm/` — Confirmation réinitialisation

### Données
- `GET /api/prestataire/` — Liste prestataires (filtres : ville, métier, disponibilité, étoiles, abonnés)
- `GET /api/prestataire/<uuid>/` — Détail prestataire (réalisations, évaluations incluses)
- `GET /api/villes/` — Liste des villes
- `GET /api/prestations/` — Liste des prestations actives
- `GET|POST /api/feed/` — Fil d'actualité (réalisations)
- `POST /api/feed/<id>/like/` — Liker/unliker
- `POST /api/feed/<id>/comment/` — Commenter

### Messagerie
- `GET /api/messagerie/conversations/` — Liste des conversations
- `POST /api/messagerie/conversations/start/<uuid>/` — Démarrer une conversation
- `POST /api/messagerie/conversations/<id>/messages/` — Envoyer un message

### WebSocket
- `ws/chat/<conversation_id>/` — Chat temps réel
- `ws/notifications/` — Notifications temps réel

---

## Fonctionnalités clés

1. **Inscription/Connexion** avec vérification email par code
2. **Profils prestataires** avec portfolio (réalisations), avis, statistiques
3. **Recherche et filtrage** par ville, métier, disponibilité, note
4. **Système d'abonnement** qui conditionne la visibilité des prestataires
5. **Fil d'actualité** (feed social) avec likes et commentaires
6. **Messagerie instantanée** via WebSocket
7. **Notifications temps réel** via WebSocket
8. **Favoris** pour sauvegarder des prestataires
9. **PWA** (service worker côté web)
10. **App mobile Flutter** avec les mêmes fonctionnalités

---

## Problèmes de conformité identifiés

### CRITIQUE — Sécurité

| # | Problème | Détail |
|---|----------|--------|
| 1 | **`.env` contient des secrets en clair** | Identifiants PostgreSQL Neon, mot de passe Gmail app, SECRET_KEY placeholder. Ce fichier ne doit JAMAIS être commité — l'ajouter à `.gitignore` |
| 2 | **`SECRET_KEY` non sécurisé** | Valeur actuelle : `replace-with-a-long-random-secret` (placeholder) |
| 3 | **`CORS_ALLOW_ALL_ORIGINS = True`** | Aucune restriction CORS, même en production |
| 4 | **Fuite d'information email** | `PasswordResetRequestSerializer` révèle si un email existe en base (le commentaire dit "don't reveal" mais le code lève une erreur explicite) |
| 5 | **Email expéditeur hardcodé** | L'adresse Gmail est codée en dur dans les serializers au lieu d'utiliser `settings.EMAIL_HOST_USER` |

### MOYEN — Configuration

| # | Problème | Détail |
|---|----------|--------|
| 6 | **Incohérence version Django** | `requirements.txt` → Django 5.2.5, mais `CLAUDE.md` et commentaires settings disent "Django 6" |
| 7 | **Pas de service PostgreSQL dans docker-compose** | Le fallback `db:5432` dans settings échouera si `DATABASE_URL` n'est pas défini |
| 8 | **Fichiers media non servis en production** | `DEBUG=False` dans `.env`, mais les media ne sont servis que quand `DEBUG=True`. Pas de reverse proxy (nginx) ni stockage cloud configuré |
| 9 | **URL backend hardcodée dans Flutter** | IP LAN `192.168.1.67:8000` dans `constants.dart` — ne fonctionnera pas en dehors du réseau local |
| 10 | **Import inutilisé** | `from os import read` dans `api/serializers.py` ligne 2 |

### FAIBLE — Qualité

| # | Problème | Détail |
|---|----------|--------|
| 11 | **Aucun test automatisé** | Zéro test unitaire ou d'intégration |
| 12 | **`staticfiles/` commité** | Le dossier généré par `collectstatic` ne devrait pas être dans le repo |
| 13 | **Pas de `.gitignore` complet** | `.env`, `media/`, `staticfiles/` devraient être ignorés |

---

## Résumé de conformité

| Aspect | Statut |
|--------|--------|
| Modèles de données | ✅ Cohérents et bien structurés |
| API REST | ✅ Complète, bien organisée avec DRF |
| WebSocket | ✅ Fonctionnel (Channels + Redis) |
| Auth JWT | ✅ Implémentée avec refresh/blacklist |
| Flutter frontend | ✅ Architecture propre (Riverpod, services séparés) |
| Sécurité | ❌ Secrets exposés, CORS ouvert, fuite d'info |
| Tests | ❌ Inexistants |
| Configuration Docker | ⚠️ Partielle (manque PostgreSQL, nginx) |
| Production-readiness | ❌ Pas prêt (DEBUG, media, CORS, secrets) |

---

## Recommandations prioritaires pour amélioration

1. **Sécuriser les secrets** — `.gitignore` le `.env`, générer une vraie `SECRET_KEY`, restreindre CORS
2. **Ajouter des tests** — au minimum pour l'authentification et les endpoints critiques
3. **Compléter Docker** — ajouter nginx comme reverse proxy pour servir les media/static en production
4. **Configurer le déploiement** — URL dynamique dans Flutter, variables d'environnement pour les URLs
5. **Corriger la fuite d'info** sur le reset password (répondre de manière identique que l'email existe ou non)
6. **Ajouter un système de paiement** pour les abonnements (actuellement le modèle existe mais pas d'intégration de paiement)
