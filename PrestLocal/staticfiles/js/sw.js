/**
 * LesProduFao — Service Worker
 *
 * Stratégies de cache :
 *   - Cache First (assets statiques : CSS, JS, polices)
 *   - Network First (pages HTML, API)
 *   - Stale While Revalidate (images)
 */

const CACHE_VERSION = 'v1';
const STATIC_CACHE = `lesprodufao-static-${CACHE_VERSION}`;
const PAGE_CACHE   = `lesprodufao-pages-${CACHE_VERSION}`;
const IMAGE_CACHE  = `lesprodufao-images-${CACHE_VERSION}`;

/* ── Ressources pré-cachées au moment de l'installation ── */
const PRECACHE_URLS = [
  '/',
  '/offline/',
  '/static/css/main.css',
  '/static/js/main.js',
  '/static/manifest.json',
  '/static/pwa/icon-192x192.png',
  '/static/pwa/icon-512x512.png',
  '/static/icon/favicon.ico',
];

/* ── Installation : ouvrir les caches et pré-cacher ── */
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(STATIC_CACHE).then((cache) => {
      return cache.addAll(PRECACHE_URLS);
    }).then(() => {
      // Forcer l'activation immédiate du nouveau SW
      return self.skipWaiting();
    })
  );
});

/* ── Activation : nettoyer les anciens caches ── */
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames
          .filter((name) => {
            return name.startsWith('lesprodufao-') &&
                   !name.endsWith(CACHE_VERSION);
          })
          .map((name) => caches.delete(name))
      );
    }).then(() => {
      // Prendre le contrôle de toutes les pages ouvertes
      return self.clients.claim();
    })
  );
});

/* ── Interception des requêtes ── */
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  // Ne pas intercepter les requêtes non-GET
  if (request.method !== 'GET') return;

  // Ne pas intercepter les requêtes vers des domaines externes
  if (url.origin !== self.location.origin) return;

  // Ne pas intercepter les requêtes de l'API REST (on les laisse passer)
  if (url.pathname.startsWith('/api/')) {
    // Network First pour l'API
    event.respondWith(networkFirstStrategy(request));
    return;
  }

  // Stratégie par type de ressource
  if (isStaticAsset(url)) {
    // Cache First pour les assets statiques
    event.respondWith(cacheFirstStrategy(request, STATIC_CACHE));
  } else if (isImage(url)) {
    // Stale While Revalidate pour les images
    event.respondWith(staleWhileRevalidateStrategy(request, IMAGE_CACHE));
  } else {
    // Network First pour les pages HTML / navigation
    event.respondWith(networkFirstStrategy(request));
  }
});

/* ── Utilitaires ── */

function isStaticAsset(url) {
  return /\.(css|js|json|webmanifest)$/.test(url.pathname) ||
         url.pathname.startsWith('/static/');
}

function isImage(url) {
  return /\.(png|jpg|jpeg|gif|svg|webp|ico)$/.test(url.pathname);
}

/* ── Stratégies de cache ── */

/**
 * Cache First : servir depuis le cache, sinon aller sur le réseau.
 * Utilisé pour : CSS, JS, polices, icônes, manifest.
 */
async function cacheFirstStrategy(request, cacheName) {
  const cachedResponse = await caches.match(request);
  if (cachedResponse) {
    return cachedResponse;
  }
  try {
    const networkResponse = await fetch(request);
    if (networkResponse && networkResponse.ok) {
      const cache = await caches.open(cacheName);
      cache.put(request, networkResponse.clone());
    }
    return networkResponse;
  } catch (error) {
    // En dernier recours : page offline
    return caches.match('/offline/');
  }
}

/**
 * Network First : essayer le réseau d'abord, fallback sur le cache.
 * Utilisé pour : pages HTML, API REST.
 */
async function networkFirstStrategy(request) {
  try {
    const networkResponse = await fetch(request);
    if (networkResponse && networkResponse.ok) {
      const cache = await caches.open(PAGE_CACHE);
      cache.put(request, networkResponse.clone());
    }
    return networkResponse;
  } catch (error) {
    const cachedResponse = await caches.match(request);
    if (cachedResponse) {
      return cachedResponse;
    }
    // Fallback : page offline personnalisée
    return caches.match('/offline/');
  }
}

/**
 * Stale While Revalidate : servir la version en cache, puis
 * mettre à jour le cache avec la réponse réseau en arrière-plan.
 * Utilisé pour : images.
 */
async function staleWhileRevalidateStrategy(request, cacheName) {
  const cache = await caches.open(cacheName);
  const cachedResponse = await cache.match(request);

  const fetchPromise = fetch(request).then((networkResponse) => {
    if (networkResponse && networkResponse.ok) {
      cache.put(request, networkResponse.clone());
    }
    return networkResponse;
  }).catch(() => cachedResponse);

  return cachedResponse || fetchPromise;
}

/* ── Gestion des notifications push (future implémentation) ── */
self.addEventListener('push', (event) => {
  if (!event.data) return;

  const data = event.data.json();
  const options = {
    body: data.body || 'Nouvelle notification',
    icon: '/static/pwa/icon-192x192.png',
    badge: '/static/pwa/icon-96x96.png',
    vibrate: [200, 100, 200],
    data: {
      url: data.url || '/'
    }
  };

  event.waitUntil(
    self.registration.showNotification(data.title || 'LesProduFao', options)
  );
});

/* ── Message : mise à jour forcée (SKIP_WAITING) ── */
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});

/* ── Clic sur une notification ── */
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const urlToOpen = event.notification.data?.url || '/';

  event.waitUntil(
    clients.matchAll({ type: 'window' }).then((windowClients) => {
      for (const client of windowClients) {
        if (client.url === urlToOpen && 'focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(urlToOpen);
      }
    })
  );
});
