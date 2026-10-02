# Messagerie temps réel — Documentation WebSocket pour Flutter

> Architecture temps réel de LesProduFao : envoi/réception **instantanés** via WebSockets,
> **présence en ligne**, et **suppression du polling HTTP 30 s** (le badge de notifications
> est désormais poussé par le serveur).

---

## 1. Vue d'ensemble

| Brique | Technologie |
|---|---|
| Serveur | Django 6 + **Django Channels 4.3** (ASGI via **daphne**) |
| Channel layer | **Redis** (`REDIS_URL`) en prod, repli **In-Memory** en dev |
| Auth | **JWT (Bearer)** pour les clients mobiles/API · Session (cookie) pour le web |
| Deux WebSockets | `/ws/chat/<id>/` (messages + présence) · `/ws/notifications/` (compte non-lu) |
| API REST JSON | `/api/messagerie/...` (liste, historique, envoi, démarrage) |
| CORS | activé (`django-cors-headers`) pour les clients cross-origin |

Chaque message, qu'il soit envoyé par WebSocket ou par le repli HTTP, est **créé puis diffusé
au groupe** de la conversation. Le destinataire le reçoit en temps réel **sans rechargement**.

---

## 2. Endpoints WebSocket

### 2.1 Chat — `ws(s)://HOST/ws/chat/<conversation_id>/`

- **`conversation_id`** : entier (pk de la `Conversation`).
- **Autorisation** : refusé (403 / fermeture) si non connecté ou non participant.
- **Événements reçus** :

| `type` | Payload | Signification |
|---|---|---|
| `chat.message` | `{ "message": { "id", "sender_id", "content", "created_at" } }` | Nouveau message dans la conversation |
| `chat.presence` | `{ "user_id", "online" }` | Un participant est en ligne / hors ligne |

- **Événement envoyé** (client → serveur) :

```json
{ "type": "chat.message", "content": "Bonjour !" }
```

> ⚠️ Le **destinataire** reçoit le `chat.message` ; **l'expéditeur** reçoit aussi son propre écho
> (il est membre du groupe). Filtre-le côté client : ignore un message dont `sender_id == user_id`
> (l'expéditeur affiche déjà sa bulle en local/optimiste).

### 2.2 Notifications — `ws(s)://HOST/ws/notifications/`

- **Autorisation** : refusé si non connecté.
- **Événement reçu** : `{ "type": "notification.unread", "count": <int> }` (poussé à la connexion, puis à chaque nouveau message reçu).

---

## 3. Schémas JSON

### `chat.message` (reçu)
```json
{
  "type": "chat.message",
  "message": {
    "id": 42,
    "sender_id": "3f2c...-uuid-du-sender",
    "content": "Bonjour !",
    "created_at": "2026-08-01T09:34:10.648778+00:00"
  }
}
```
- `sender_id` est un **UUID** (pk du user) — compare-le toujours comme **chaîne** (`sender_id == user_id`).

### `chat.presence` (reçu)
```json
{ "type": "chat.presence", "user_id": "3f2c...", "online": true }
```

### `notification.unread` (reçu)
```json
{ "type": "notification.unread", "count": 3 }
```

---

## 4. API REST JSON (Flutter)

Authentification : en-tête `Authorization: Bearer <access_token>`.

### 4.1 Obtenir un token JWT
| Méthode | URL | Body | Réponse |
|---|---|---|---|
| `POST` | `/api/auth/token/` | `{ "email", "password" }` | `{ "access", "refresh" }` |
| `POST` | `/api/auth/token/refresh/` | `{ "refresh" }` | `{ "access" }` |

### 4.2 Conversations
| Méthode | URL | Description | Réponse |
|---|---|---|---|
| `GET` | `/api/messagerie/conversations/` | Liste des conversations | `[Conversation]` |
| `POST` | `/api/messagerie/conversations/start/<prestataire_id>/` | Créer ou retrouver une conversation | `{ "conversation_id": <int> }` |
| `GET` | `/api/messagerie/conversations/<pk>/` | Historique des messages | `{ "id", "participant", "messages": [Message] }` |
| `POST` | `/api/messagerie/conversations/<pk>/messages/` | Envoyer un message (`{ "content" }`) | `Message` (201) |

### 4.3 Schémas
```json
// Conversation (liste)
{
  "id": 11,
  "participant": { "id": "uuid", "first_name": "Bob", "last_name": "B",
                   "full_name": "Bob B", "photo_url": null, "role": "prestataire" },
  "last_message": { "id": 20, "sender_id": "uuid", "content": "Hello", "created_at": "..." },
  "unread_count": 1,
  "updated_at": "..."
}
```
```json
// Message
{ "id": 20, "sender_id": "uuid", "content": "Hello depuis Flutter", "created_at": "..." }
```

> Le `POST .../messages/` **diffuse aussi** au groupe WebSocket : un client connecté
> reçoit le message en temps réel même s'il a été envoyé via l'API.

### 4.4 Endpoints web (HTML, legacy)
| Méthode | URL | Description |
|---|---|---|
| `GET` | `/messages/` | Liste des conversations (page web) |
| `GET` | `/messages/<pk>/` | Détail d'une conversation (page web) |

---

## 5. Authentification

- **Web / navigateur** : session Django (`AuthMiddlewareStack`). Cookies envoyés
  automatiquement pour un WebSocket **same-origin**.
- **Flutter / mobile (implémenté)** : le WebSocket s'authentifie par **JWT** via l'en-tête
  `Authorization: Bearer <access>` du handshake. Un middleware `JWTAuthMiddleware`
  (côté Channels) valide le token et résout `scope['user']`. Sans token valide →
  connexion refusée (403).
- **Précédence** : si un token JWT valide est fourni, il prime sur la session.

---

## 6. Cycle de vie & reconnexion

1. Se connecter, **résoudre l'URL WS** : `ws` si `http`, `wss` si `https`.
2. **Reconnexion** en cas de fermeture (réseau, serveur) : délai court (≈ 2–5 s) avec backoff,
   puis reconnexion. Le serveur renvoie le compte initial de notifications à la connexion.
3. **Présence** : à la connexion d'un participant, le groupe reçoit `chat.presence {online:true}` ;
   à sa déconnexion, `{online:false}`.

---

## 7. Exemple Flutter (`web_socket_channel`)

**`pubspec.yaml`** :
```yaml
dependencies:
  web_socket_channel: ^2.4.0
```

**Service de messagerie** :
```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

class Auth {
  static String? access; // obtenu via POST /api/auth/token/

  static Future<void> login(String email, String password) async {
    final resp = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/auth/token/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = jsonDecode(resp.body);
    access = data['access']; // puis refresh via /api/auth/token/refresh/
  }

  static Map<String, String> get headers =>
      {'Authorization': 'Bearer $access', 'Content-Type': 'application/json'};
}

class ChatService {
  WebSocketChannel? _channel;
  String? _selfId;

  Uri _wsUri(String path) {
    final scheme = kIsWeb ? 'wss' : 'ws'; // adapte http/https
    return Uri.parse('$scheme://${ApiConfig.host}$path');
  }

  /// Ouvre la conversation en temps réel (auth par JWT).
  void connect(int conversationId, String selfId, {
    void Function(Map<String, dynamic> message)? onMessage,
    void Function(bool online, String userId)? onPresence,
    void Function()? onClose,
  }) {
    _selfId = selfId;
    _channel = WebSocketChannel.connect(
      _wsUri('/ws/chat/$conversationId/'),
      headers: {'Authorization': 'Bearer ${Auth.access}'}, // REQUIS
    );

    _channel!.stream.listen((data) {
      final ev = jsonDecode(data as String) as Map<String, dynamic>;
      switch (ev['type']) {
        case 'chat.message':
          final m = ev['message'] as Map<String, dynamic>;
          if (m['sender_id'] == _selfId) return; // ignore son écho
          onMessage?.call(m);
        case 'chat.presence':
          onPresence?.call(ev['online'] as bool, ev['user_id'] as String);
      }
    }, onDone: (_) => onClose?.call());
  }

  /// Envoie un message via le WebSocket.
  void send(String content) =>
      _channel?.sink.add(jsonEncode({'type': 'chat.message', 'content': content}));

  /// Repli API REST si le WS est indisponible (diffuse aussi en temps réel).
  Future<void> sendViaApi(int conversationId, String content) async {
    final resp = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/messagerie/conversations/$conversationId/messages/'),
      headers: Auth.headers,
      body: jsonEncode({'content': content}),
    );
    // 201 + body Message : {id, sender_id, content, created_at}
  }

  /// Liste des conversations (JSON).
  Future<List<dynamic>> fetchConversations() async {
    final resp = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/messagerie/conversations/'),
      headers: Auth.headers,
    );
    return jsonDecode(resp.body) as List<dynamic>;
  }

  void dispose() => _channel?.sink.close();
}
```

**Utilisation (écran de discussion)** :
```dart
service.connect(convId, selfId,
  onMessage: (m) => _addBubble(m, fromSelf: false),
  onPresence: (online, userId) => setState(() => _otherOnline = online),
);
```

---

## 8. Notes de production

- **Redis obligatoire en multi-workers** (`REDIS_URL=redis://…`) : l'In-Memory ne propage pas
  entre plusieurs workers daphne.
- **Serveur** : `daphne -b 0.0.0.0 -p 8000 Core.asgi:application`.
- **Reverse-proxy (nginx/caddy)** : forcer l'upgrade HTTP→WS pour `/ws/` (en-têtes `Upgrade`
  et `Connection`).
- **CORS** : activé par défaut (`CORS_ALLOW_ALL_ORIGINS=True`). En production, restreindre à
  la liste des origines autorisées (`CORS_ALLOWED_ORIGINS`) et penser au proxy WS.
- **JWT** : le WebSocket accepte `Authorization: Bearer <access>`. Le token est émis par
  `/api/auth/token/` (durée : 1 jour, rafraîchissable via `/api/auth/token/refresh/`).
- **Dépendances serveur** : `channels>=4.3,<5`, `channels-redis>=4.3,<5`, `redis>=4.6,<7`, `daphne>=4.2,<5`.
