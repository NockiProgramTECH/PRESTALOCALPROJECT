# Suggestions d'Ajustements et Évolutions - LesProduFao

Ce document répertorie les points d'amélioration, les fonctionnalités à ajouter et les corrections suggérées pour faire passer le projet **LesProduFao** d'un prototype à une application de production robuste.

---
[x] = Fonctionnalité déjà implémentée
[ ] = Fonctionnalité à implémenter
[!] = Fonctionnalité partiellement implémentée ou à revoir

## 🚀 1. Fonctionnalités à Ajouter 

### 🔐 Authentification & Sécurité
- **Vérification d'Email** : Implémenter l'envoi d'un email de confirmation lors de l'inscription pour éviter les faux comptes. [x]
- **Réinitialisation de mot de passe** : Ajouter la fonctionnalité "Mot de passe oublié" (Django `PasswordResetView`).[x]
- **Authentification Sociale** : Permettre l'inscription/connexion via Google ou Facebook.[ ]
- **Gestion des Rôles** : Différencier clairement les comptes "Client" et "Prestataire" (actuellement, tout utilisateur semble être un prestataire par défaut). [!]

### 🛠️ Espace Prestataire (Tableau de Bord)
- **Modification du Profil** : Permettre au prestataire de modifier ses informations personnelles (bio, ville, métier, téléphone) via un formulaire AJAX.
- **Statistiques** : Afficher un résumé (Nombre de vues du profil, nombre d'appels cliqués, note moyenne).
- **Disponibilité** : Ajouter un bouton "Disponible / Indisponible" pour masquer temporairement le prestataire des recherches.

### 🔍 Recherche & Filtrage
- **Recherche par rayon (Géolocalisation)** : Trouver des prestataires à X km de ma position actuelle.
- **Autocomplete** : Ajouter une suggestion automatique de métiers dans la barre de recherche.
- **Tri Avancé** : Permettre de trier par "Mieux notés", "Plus expérimentés" ou "Nouveaux inscrits".

### 💬 Communication
- **Système de Messagerie Interne** : Permettre aux clients de discuter avec les prestataires sans quitter la plateforme. [ ] *implementation coté application mobille*
- **Notifications** : Alertes (email ou push) lorsqu'un prestataire reçoit une nouvelle évaluation ou un message. [x]
---

## 🎨 2. Améliorations UI/UX

### 📱 Responsive Design
- **Menu Mobile** : Améliorer le menu "hamburger" pour une navigation plus fluide sur smartphone.[x]
- **Squelette de chargement (Skeleton Screens)** : Afficher des blocs gris animés pendant que les données AJAX chargent (meilleure perception de la vitesse).[x]

### 🖼️ Gestion des Médias
- **Compression d'Images** : Implémenter un redimensionnement automatique des images côté serveur (Pillow) pour réduire le poids des pages.
- **Lightbox** : Ajouter une galerie Lightbox pour agrandir les photos des réalisations au clic.
- **Placeholder intelligent** : Utiliser des icônes de métiers spécifiques si le prestataire n'a pas de photo de profil.

---

## 🛠️ 3. Corrections Techniques & Optimisations

### 🏗️ Architecture
- **Découpage des fichiers JS** : Sortir le JavaScript inline des fichiers HTML pour les mettre dans des fichiers `.js` séparés et minifiés.[x]
- **Utilisation de Variables CSS** : Centraliser toutes les couleurs (vert, jaune, gris) dans `:root` pour faciliter le changement de thème[ ]
(Dark Mode).

### ⚡ Performance
- **Caching** : Utiliser le cache de Django pour les listes de catégories et de villes qui changent rarement.
- **Optimisation SQL** : Utiliser `select_related` et `prefetch_related` dans les vues pour réduire le nombre de requêtes à la base de données (problème du N+1).

### 🧪 Tests & Qualité
- **Tests Unitaires** : Écrire des tests pour les vues AJAX (évaluations, ajout de réalisation).
- **Validation de formulaires** : Ajouter des validations côté client (Regex pour le téléphone, taille max pour les images).

---

## 📋 4. Liste de Priorité (Roadmap)

1.  **Priorité Haute** : Modification des informations du profil (Dashboard).
2.  **Priorité Haute** : Compression des images pour la performance.
3.  **Priorité Moyenne** : Système de messagerie interne.
4.  **Priorité Moyenne** : Tri avancé et Autocomplete.
5.  **Priorité Basse** : Authentification sociale (Google/FB).

---
*Document généré par Gemini CLI - Mai 2026*
