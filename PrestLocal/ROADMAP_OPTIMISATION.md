# 🚀 Roadmap : Phase d'Optimisation & Présentation Premium (Phase 3)

Ce document liste les améliorations critiques pour transformer **LesProduFao** en une plateforme prête pour le marché.

## 🎨 1. Design & UX "Wow Effect"
- [ ] **Priorité Mobile (Mobile-First)** : Repasser sur chaque page (Profil, Recherche, Accueil) pour s'assurer que l'expérience est pensée d'abord pour le pouce (boutons tactiles larges, espacements aérés).
- [ ] **Corrections Responsives** : Ajuster la grille des prestataires et les formulaires sur les très petits écrans (iPhone SE, etc.).
- [ ] **Micro-animations** : Ajouter des animations d'entrée (Fade-in, slide-up) sur les cartes de prestataires et les éléments du flux social.
- [ ] **Dark Mode** : Implémenter un switch Jour/Nuit avec des variables CSS (`--bg-primary`, etc.).

## 📱 2. Social Feed "Facebook Style"
- [ ] **Visualisation Réaliste** : Améliorer les cartes du flux avec des images de profil plus grandes, des noms en gras, et une typographie plus lisible.
- [ ] **Interactions Étendues** : 
    - [ ] Ajouter un système de "Réactions" (au lieu d'un simple Like).
    - [ ] Permettre le **Partage** d'une réalisation sur les réseaux sociaux.
    - [ ] Ajouter une "Galerie" tactile si une réalisation contient plusieurs photos.
- [ ] **Flux "Infini"** : Charger de nouvelles réalisations au scroll (Infinite Scroll) sans bouton "Suivant".
- [ ] **Vrai système de commentaires** : Afficher les photos de profil à côté des commentaires et permettre d'y répondre (fils de discussion).

## 🛠️ 3. Fonctionnalités de Rétention & Engagement
- [ ] **Système de Chat Interne** : Permettre aux clients d'envoyer un message direct au prestataire sans quitter le site (Messagerie simple).
- [ ] **Centre de Notifications** : Une icône "Cloche" qui affiche les nouveaux likes, commentaires ou messages.
- [ ] **Badges de Confiance** : Afficher des badges "Top Prestataire", "Réactif", ou "Nouveau" basés sur les statistiques réelles.
- [ ] **Géolocalisation** : Proposer de trier les prestataires par "Distance" (si l'utilisateur autorise sa position).

## 💰 3. Business & Analytics (Dashboard)
- [ ] **Dashboard Prestataire Premium** : Un graphique (Chart.js) montrant l'évolution des vues et des clics sur les 30 derniers jours.
- [ ] **Historique de Paiement** : Une page listant les factures/transactions d'abonnement passées.
- [ ] **Abonnement à paliers** : Créer une vraie différence visuelle entre un plan "Basique" (Profil standard) et "Premium" (Profil mis en avant avec bordure dorée).

## 🚀 4. Performance & SEO
- [ ] **Optimisation Image** : Mise en place de `sorl-thumbnail` ou redimensionnement automatique des photos de profil pour charger 10x plus vite.
- [ ] **Meta-tags SEO** : Générer dynamiquement les titres et descriptions pour Google sur chaque page de profil.

---

# 🤖 Instructions pour l'IA (Prompts)

*Utilisez ces instructions pour guider l'IA lors des prochaines sessions de code.*

> "Agis en tant qu'expert Full-Stack et UX Designer. Pour chaque modification :
> 1. Garde une cohérence stricte avec les variables CSS de `static/css/main.css`.
> 2. Assure-toi que chaque nouvelle vue AJAX gère un état 'Loading' (Skeleton).
> 3. Priorise le 'Mobile First' : tout doit être parfait sur smartphone.
> 4. Commente le code de manière pédagogique pour expliquer les choix techniques.
> 5. Ne casse pas la logique de séparation des apps (main, Abonnement, Feed)."
