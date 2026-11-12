// ASP — Web Push (پەیام و بیرئینان)
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));
self.addEventListener('push', (e) => {
  let d = {};
  try { d = e.data.json(); } catch (_) { d = { title: 'ASP', body: e.data ? e.data.text() : '' }; }
  e.waitUntil(Promise.all([
    self.registration.showNotification(d.title || 'ASP', {
      body: d.body || '',
      icon: 'icons/Icon-192.png',
      badge: 'icons/Icon-192.png',
      vibrate: [70, 50, 70, 50, 70, 50, 180], // 📳 ریتما ASP (Android)
      data: { url: d.url || '../' },
    }),
    // 🔔 ئەگەر ئەپ ڤەکری بیت ➔ ئاوازا ASP د ناڤ ئەپێ دا لێ ددەت
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((ws) => {
      for (const w of ws) { try { w.postMessage({ asp: 'push' }); } catch (_) {} }
    }),
  ]));
});
self.addEventListener('notificationclick', (e) => {
  e.notification.close();
  const url = new URL(e.notification.data.url || '../', self.registration.scope).href;
  e.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((ws) => {
    for (const w of ws) { if ('focus' in w) return w.focus(); }
    return self.clients.openWindow(url);
  }));
});
