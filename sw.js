/* Pulse AI — Service Worker v1.1 */
const CACHE = 'pulse-ai-v1.1';
const STATIC = [
  './',
  './index.html',
  './app.js',
  './style.css',
  './sources.js',
  './manifest.json',
  './icons/icon.svg',
];

/* Install: pre-cache all static assets */
self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE).then(c => c.addAll(STATIC)).then(() => self.skipWaiting())
  );
});

/* Activate: delete stale caches */
self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

/* Fetch strategy:
   - Same-origin static assets → cache-first (fast offline loads)
   - External URLs (CORS proxies, RSS feeds) → network-only (always fresh) */
self.addEventListener('fetch', e => {
  const url = new URL(e.request.url);

  // Skip non-GET and external requests
  if (e.request.method !== 'GET' || url.origin !== self.location.origin) return;

  e.respondWith(
    caches.match(e.request).then(cached => {
      if (cached) return cached;
      return fetch(e.request).then(res => {
        if (res.ok) {
          const clone = res.clone();
          caches.open(CACHE).then(c => c.put(e.request, clone));
        }
        return res;
      }).catch(() => caches.match('./index.html')); // offline fallback
    })
  );
});
