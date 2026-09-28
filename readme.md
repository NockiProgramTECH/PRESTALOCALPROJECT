Critique — Sécurité (à faire immédiatement)
Secrets exposés — Le .env avec les mots de passe Neon et Gmail est dans le repo. Il faut le .gitignore, régénérer tous les secrets, et utiliser un vault ou des variables d'environnement serveur.
SECRET_KEY placeholder — Générer une clé aléatoire de 50+ caractères.
CORS grand ouvert — Restreindre CORS_ALLOWED_ORIGINS aux domaines réels (Flutter app, frontend web).
Fuite d'info password reset — Répondre "si ce mail existe, un code a été envoyé" que l'email existe ou non.
Email expéditeur hardcodé dans les serializers → utiliser settings.DEFAULT_FROM_EMAIL.
🟠 Important — Infrastructure & Déploiement
Nginx en reverse proxy — Pour servir les fichiers media/static en production (actuellement cassé avec DEBUG=False).
Docker-compose complet — Ajouter PostgreSQL local + nginx + health checks.
URL dynamique dans Flutter — Remplacer l'IP LAN hardcodée par une config environnement (dev/staging/prod).
CI/CD — Mettre en place un pipeline (GitHub Actions) : lint, tests, build Flutter, déploiement.
HTTPS — Certificat SSL (Let's Encrypt) pour la production.
🟡 Fonctionnel — Fonctionnalités manquantes
Intégration paiement — Le modèle Abonnement existe mais aucun paiement réel (Orange Money, Moov Money, ou carte via un provider local comme FedaPay/PayDunya).
Système de recherche avancé — Ajouter la recherche géolocalisée (par quartier/proximité), pas juste par ville.
Upload d'images optimisé — Compression côté serveur (Pillow resize), stockage cloud (S3/Cloudinary) au lieu du filesystem local.
Pagination — Vérifier que tous les endpoints listent paginés (prestataires, feed, conversations).
Rate limiting — Protéger les endpoints auth (login, register, password reset) contre le brute force avec django-ratelimit ou throttling DRF.
🔵 Qualité — Code & Maintenabilité
Tests automatisés — Priorité : tests d'auth (register, login, refresh, reset), puis CRUD prestataires, puis messagerie WebSocket.
Suppression du staticfiles/ commité — Générer via collectstatic au build Docker.
Import inutile — from os import read dans api/serializers.py.
Validation côté Flutter — Renforcer la validation des formulaires (email, téléphone, longueur bio).
Gestion d'erreurs Flutter — Ajouter un intercepteur HTTP global pour gérer les 401 (token expiré → refresh automatique), les erreurs réseau, etc.
🟣 Nice-to-have — Évolutions futures
Notifications push (Firebase Cloud Messaging) en plus des WebSocket.
Mode hors-ligne Flutter — Cache local avec Hive/Isar pour les données prestataires consultées.
Dashboard admin personnalisé — Statistiques (nombre d'inscriptions, revenus abonnements, prestataires actifs).
Internationalisation (i18n) — Support mooré/dioula en plus du français.
SEO — Rendre les profils prestataires indexables (server-side rendering ou pages statiques).