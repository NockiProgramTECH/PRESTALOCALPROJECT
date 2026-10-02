# Notifications et relances d'abonnement

## 1. Vue d'ensemble

Trois responsabilités nettement séparées :

| Couche | Rôle | Fichiers |
|---|---|---|
| **Services métier** | *Qui* relancer, *quand*, *avec quel contenu* | `Notifications/abonnement/` (`types`, `liens`, `cibles`, `envoi`), `Notifications/service.py` |
| **Canaux (transport)** | *Comment* acheminer (email, WhatsApp, push) | `Notifications/channels/` |
| **Workers (planification)** | *Quand exécuter* la campagne | `Notifications/tasks.py`, commandes `relance_*` |

Les vues n'envoient plus jamais d'email directement : elles appellent
`Notifications.service.envoyer_email(...)`.

```
vue / tâche planifiée
        │
        ▼
service métier (Notifications/abonnement/)      → décide et rédige
        │
        ▼
service d'envoi (Notifications/service.py)     → diffuse + journalise
        │
        ▼
canal (Notifications/channels/*)               → transporte
```

## 2. Relance d'abonnement (fonctionnalité en production)

Trois motifs, un seul email maximum par motif et par prestataire :

| Motif | Destinataires | Clé d'idempotence |
|---|---|---|
| `abonnement_expire_bientot` | abonnement actif qui se termine dans N jours | `expire-bientot:<abo>:<date_fin>` |
| `abonnement_expire` | abonnement échu, inactif ou impayé | `expire:<abo>:<date_fin>` |
| `abonnement_jamais_souscrit` | prestataire inscrit depuis X jours sans abonnement | `sans-abonnement:<user>:<AAAA-MM>` |

Chaque email contient un **lien vers l'espace d'abonnement du prestataire**
`<SITE_URL>/abonnement/gestion/<id>/?ref=<jeton signé>` :

- la vue vérifie que le compte connecté correspond à l'identifiant de l'URL
  (aucune donnée d'un autre compte n'est exposée si le lien circule) ;
- le jeton signé (`django.core.signing`) personnalise l'accueil et permet
  d'afficher le bandeau « Votre abonnement conditionne votre visibilité » ;
- les liens expirent au bout de `RELANCE_LIEN_TTL_JOURS` (90 jours par défaut).

### Exécution

```bash
# Liste des cibles sans rien envoyer
python manage.py relancer_abonnements --simulation

# Envoi réel (email)
python manage.py relancer_abonnements

# Canaux précis (utile pour tester un nouveau canal)
python manage.py relancer_abonnements --canal email --canal whatsapp

# Seuils personnalisés
python manage.py relancer_abonnements --jours-avant-expiration 3 \
                                      --delai-sans-abonnement 7
```

À planifier **une fois par jour** :

- hébergeur type Render/Railway : « scheduled job » =
  `python manage.py relancer_abonnements` ;
- serveur classique : `crontab -e` → `0 8 * * * cd /srv/lesprodufao && python manage.py relancer_abonnements` ;
- Docker : ajouter un service dédié avec la même image et la même commande.

L'idempotence rend l'exécution sûre : relancer la commande dans la journée ne
renvoie pas un second email au même prestataire.

`check_subscriptions` reste disponible (alias déprécié) pour ne pas casser une
planification existante.

## 3. Ajouter un canal (WhatsApp, push, SMS…)

Les canaux `whatsapp` et `push` sont **déjà branchés** mais inactifs : il
manque uniquement l'appel au fournisseur. Pour en activer un :

1. implémenter `envoyer()` dans `Notifications/channels/whatsapp.py` (ou
   `push.py`) en respectant le contrat `CanalNotification` ;
2. renseigner les variables d'environnement :

```dotenv
NOTIFICATIONS_CHANNELS=email,whatsapp
NOTIFICATIONS_WHATSAPP_ENABLED=True
WHATSAPP_API_URL=https://graph.facebook.com/v20.0/<phone_id>/messages
WHATSAPP_API_TOKEN=…
```

Aucune vue, aucun service métier, aucun test existant n'a besoin d'être
modifié : c'est le principe ouvert/fermé appliqué au transport.

Pour ajouter un canal entièrement nouveau (SMS) :

```python
# Notifications/channels/sms.py
from .base import STATUT_ENVOYE, STATUT_IGNORE, CanalNotification, ResultatEnvoi


class CanalSMS(CanalNotification):
    nom = "sms"

    def disponible(self) -> bool:
        return bool(getattr(settings, "SMS_API_KEY", ""))

    def envoyer(self, message, destinataire) -> ResultatEnvoi:
        numero = getattr(destinataire, "telephone", "")
        if not numero:
            return ResultatEnvoi(self.nom, STATUT_IGNORE, "sans téléphone")
        # … appel du fournisseur …
        return ResultatEnvoi(self.nom, STATUT_ENVOYE)
```

puis l'enregistrer dans `Notifications/registre.py` (`CANAUX_DISPONIBLES`) et
l'ajouter à `NOTIFICATIONS_CHANNELS`.

## 4. Journal et traçabilité

`JournalNotification` conserve chaque tentative (`envoye`, `ignore`, `echec`)
avec son canal, sa clé d'idempotence et la cause technique éventuelle. Un
échec n'interrompt jamais une campagne : le rapport de la commande indique le
détail par cible.

## 5. Réglages

| Variable | Défaut | Rôle |
|---|---|---|
| `SITE_URL` | `http://localhost:8000` | Base des liens absolus des emails |
| `NOTIFICATIONS_CHANNELS` | `email` | Canaux actifs |
| `NOTIFICATIONS_WHATSAPP_ENABLED` / `WHATSAPP_API_*` | désactivé | Canal WhatsApp |
| `NOTIFICATIONS_PUSH_ENABLED` / `PUSH_API_KEY` | désactivé | Canal push |
| `RELANCE_ABONNEMENT_JOURS_AVANT` | `7` | Rappel avant échéance |
| `RELANCE_SANS_ABONNEMENT_DELAI_JOURS` | `3` | Ancienneté minimale sans abonnement |
| `RELANCE_LIEN_TTL_JOURS` | `90` | Validité des liens signés |

## 6. Tests

```bash
python manage.py test Notifications Feed Abonnement
```

Les tests injectent un canal de test (`CanalEnregistreur`) et l'`outbox` Django :
aucun SMTP ni accès réseau n'est nécessaire.
