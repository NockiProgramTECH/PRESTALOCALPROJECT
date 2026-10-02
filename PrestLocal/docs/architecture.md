# Architecture du backend LesProduFao

Ce document décrit **où écrire quoi**. Il est destiné à un développeur (ou à un
agent) qui reprend le projet : suivre ces emplacements évite de reconstruire les
mêmes requêtes à plusieurs endroits, ce qui était la principale source de bugs
corrigés lors du refactoring d'octobre 2026.

## 1. Les quatre couches d'un domaine

| Couche | Rôle | Ne fait **jamais** |
|---|---|---|
| `views/` (ou `views.py`) | Interpréter la requête, vérifier les permissions, valider en frontière, appeler un service/selector, construire la réponse HTTP | Calcul métier, envoi d'email, transactions |
| `services/` | Une opération métier nommée (règles, invariants, transactions) | Connaître `request`/`HttpResponse`, décider des codes HTTP |
| `selectors.py` | Requêtes de **lecture** prêtes à l'emploi (filtres, `select_related`, annotations) | Écrire en base, logique métier |
| `querysets.py` | Filtres et annotations réutilisables attachés à un manager | Orchestrer plusieurs modèles |
| `models.py` | Données, relations, invariants simples (`est_valide`, `profile_completed`) | Requêtes complexes, envois, formats d'API |
| `serializers.py` | Contrat d'entrée/sortie de l'API (validation + représentation) | Règles métier dupliquées |
| `tasks.py` + `management/commands/` | Exécution différée ou planifiée (worker) | Porter la règle métier (elle est dans `services/`) |

Règle pratique : **une règle métier s'écrit une seule fois**. Si deux vues en
ont besoin, elle descend dans un service ; si deux vues lisent les mêmes
données, elles descendent dans un selector.

## 2. Arborescence des applications Django

```
PrestLocal/
├── Core/                     # settings, urls, asgi, wsgi, middleware (JWT WebSocket)
├── main/                     # Comptes, prestataires, avis, favoris, notifications, accueil
│   ├── models.py             #   données + invariants du modèle
│   ├── querysets.py          #   PrestataireQuerySet : .prestataires() .visibles() .avec_relations() .avec_note_et_avis()
│   ├── selectors.py          #   requêtes de lecture des pages (accueil, annuaire, espace client)
│   ├── services/             #   comptes.py, avis.py, favoris.py, prestataires.py (+ __init__ = contrat public)
│   ├── views/                #   pages.py, comptes.py, prestataires.py, portfolio.py, notifications.py
│   ├── forms.py, urls.py
│   ├── tests.py              #   parcours web (inscription, connexion)
│   └── test_services.py      #   services, selectors, codes HTTP des endpoints AJAX
├── Abonnement/               # Offres et souscriptions
│   ├── services.py           #   souscrire(), abonnement_actif(), assurer_plans_par_defaut()
│   └── views.py, urls.py
├── Feed/                     # Fil d'actualité
│   ├── selectors.py          #   publications_avec_relations(), publications_annotees()
│   ├── services.py           #   basculer_like(), ajouter_commentaire(), compter_commentaires()
│   └── views.py, urls.py
├── Notifications/            # Envoi multi-canal + relances d'abonnement
│   ├── channels/             #   base.py (interface), email.py, whatsapp.py, push.py
│   ├── registre.py           #   CANAUX_DISPONIBLES — un canal = une ligne
│   ├── service.py            #   ServiceNotification, envoyer_email(), envoyer_notification()
│   ├── abonnement.py         #   cibles_relance(), relancer(), url_abonnement()
│   ├── tasks.py              #   executer_relances_abonnement() (worker)
│   └── management/commands/  #   relancer_abonnements, check_subscriptions (alias)
├── Messagerie/               # Conversations + WebSocket
├── api/                      # API REST (consommée par le site et l'application Flutter)
│   ├── selectors.py          #   prestataires_api(), favoris_api(), publications_api()
│   ├── serializers/          #   commun, reference, prestataires, feed, comptes, abonnement
│   ├── views/                #   prestataires, comptes, reference, feed, abonnement
│   ├── urls.py, permissions.py
│   └── tests.py              #   tests d'API (DRF)
├── templates/                # Gabarits HTML (site + emails/)
└── docs/                     # architecture.md, notifications.md
```

`api/serializers/` et `api/views/` sont des paquets : leurs `__init__.py`
réexportent **tous** les noms publics, donc `from api.serializers import
RegisterSerializer` et `from .views import FeedListView` restent valides. Un
découpage futur n'oblige pas à modifier les imports.

## 3. Exemple : le parcours d'un avis

1. **Vue** `main/views/portfolio.py::submit_evaluation` — refuse l'anonyme (403),
   vérifie la présence des champs (400), récupère le prestataire (404).
2. **Service** `main.services.avis.soumettre_avis` — valide la note (1-5), le
   commentaire, refuse l'auto-évaluation et le doublon, écrit l'évaluation dans
   une transaction et renvoie `(evaluation, cree)`.
3. **Notification** `main.services.avis.notifier_nouvel_avis` — email idempotent
   (`cle_unique=f"avis:<id>"`) puis notification interne, sans jamais faire
   échouer l'avis.
4. **API** `api/views/prestataires.py::evaluer` appelle **le même service**
   (`remplacer=True`, car l'API met à jour l'avis existant) : la règle métier
   n'existe qu'une fois.

## 4. Ajouter une fonctionnalité

- **Nouvelle opération métier** → un module dans `services/`, une fonction
  nommée à l'infinitif, dépendances explicites, résultat clair, exceptions
  métier dédiées (`AvisInvalide`, `CodeInvalide`…). L'ajouter au `__init__.py`
  du paquet `services/` (contrat public) et écrire les tests dans
  `main/test_services.py`.
- **Nouvelle lecture** → un selector (`main/selectors.py`, `Feed/selectors.py`,
  `api/selectors.py`) avec les `select_related` / `prefetch_related` nécessaires.
  Si la même règle de lecture revient pour un modèle, elle appartient à
  `querysets.py` (`Prestataire.objects.visibles()`).
- **Nouveau canal de notification** (WhatsApp, push, SMS…) → voir
  `docs/notifications.md` : une classe dans `channels/` + une ligne dans
  `registre.CANAUX_DISPONIBLES` + le nom dans `NOTIFICATIONS_CHANNELS`. Aucun
  service ni aucune vue à modifier.
- **Nouvelle route API** → le serializer dans le module de domaine
  (`api/serializers/<domaine>.py`), la vue dans `api/views/<domaine>.py`,
  l'export dans le `__init__.py` correspondant, puis `api/urls.py`.

## 5. Conventions transverses

- **Erreurs** : les services lèvent des exceptions métier ; les vues les
  traduisent en 400/403/404. Jamais de détail technique (`str(e)`) dans une
  réponse HTTP ; en cas de panne inattendue, journaliser et renvoyer un message
  générique.
- **Transactions** : `@transaction.atomic` sur toute opération qui écrit
  plusieurs lignes (souscription, inscription + envoi du code, avis).
- **N+1** : les listes annotent leurs compteurs (`avec_note_et_avis`) et
  préchargent leurs relations. Le test
  `main.test_services.SelectorsTests.test_les_notes_ne_declenchent_pas_une_requete_par_carte`
  échoue si une requête par carte réapparaît.
- **Secrets** : uniquement via `.env` (voir `.env.example`) ; jamais dans le
  code, les logs ou les réponses.
- **Tests** : `python manage.py test` doit rester vert avant chaque commit.
  Les services et selectors se testent sans client HTTP (`main/test_services.py`).

## 6. Tâches différées

Le projet n'a **pas** de file de tâches distribuée (Celery/RQ) : le volume
actuel ne le justifie pas. Le worker `Notifications/tasks.py` est déclenché par
une commande planifiable par cron (1×/jour) :

```bash
python manage.py relancer_abonnements --simulation   # audit des cibles
python manage.py relancer_abonnements                # envoi réel
```

Si le volume grandit (campagnes massives, envoyées en parallèle d'une requête
utilisateur), introduire Celery + Redis en réutilisant **tel quel**
`executer_relances_abonnement()` comme corps de la tâche : le service métier ne
change pas, seul le déclencheur change.
