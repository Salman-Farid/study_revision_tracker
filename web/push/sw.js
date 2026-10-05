// Web Push + notification-click handler for Smart Revision Tracker.
//
// This worker is deliberately registered at scope `/push/` instead of the
// site root. Flutter's generated `flutter_service_worker.js` runs
// `self.registration.unregister()` inside its `activate` handler, which
// silently destroys any root-scope worker — and with it the push
// subscription created by that registration. Keeping the push worker in its
// own scope makes it invisible to Flutter's bootstrap (which only looks for
// a registration covering the page URL), so it survives page loads.
'use strict';

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

function absolute(path) {
  const p = typeof path === 'string' && path.length > 0 ? path : '/home';
  if (/^[a-z][a-z0-9+.-]*:/i.test(p)) return p;
  return p.charAt(0) === '/' ? p : '/' + p;
}

self.addEventListener('push', (event) => {
  let data = { title: 'Smart Revision Tracker', body: '' };
  try {
    if (event.data) data = Object.assign({}, data, event.data.json());
  } catch (_) {
    if (event.data) data.body = event.data.text();
  }
  const title = data.title || 'Smart Revision Tracker';
  const options = {
    body: data.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: data.tag || 'routine-block',
    renotify: true,
    requireInteraction: true,
    data: { url: absolute(data.url) },
  };
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const url = absolute(
    (event.notification.data && event.notification.data.url) || '/home',
  );
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
      for (const client of list) {
        if ('focus' in client) {
          client.navigate(url);
          return client.focus();
        }
      }
      return self.clients.openWindow(url);
    }),
  );
});
