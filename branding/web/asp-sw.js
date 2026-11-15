// ASP — 📶 کار کرن بێ ئینتەرنێت و ب ئینتەرنێتا لاواز
// - دەنگ، وێنە، فۆنت و CanvasKit: ئێک جار ژ ئینتەرنێتێ ➔ پاشان ژ سەر مۆبایلێ (بێ بارکرنەکا دی)
// - پەڕ، کۆد و JSON: هەردەم یا نوو ژ ئینتەرنێتێ؛ ئەگەر ئینتەرنێت نەبیت ➔ یا پاراستی
// - Supabase و ماڵپەڕێن دی: دەست لێ نادەین
const V = 'asp-v1';
const MEDIA = 'asp-media-v1'; // دەنگ (ناڤ = hash ـا نڤیسینێ ➔ هەرگیز ناگوهۆڕیت)
const PICS = 'asp-pics-v1'; // وێنە (دبیت بهێنە گوهۆڕین ➔ ل پشتێ نوو دبن)
const SHELL = 'asp-shell-v1'; // index.html, main.dart.js, JSON …
const MAX_MEDIA = 4000; // ~٧٠ MB

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => {
  e.waitUntil((async () => {
    const keep = [MEDIA, PICS, SHELL];
    for (const k of await caches.keys()) if (!keep.includes(k)) await caches.delete(k);
    await self.clients.claim();
  })());
});

function kind(url) {
  const p = url.pathname;
  // 👥 وێنەیێن کاراکتەرێن ئەدمینی (Supabase) — ب وەشان ➔ ئێک جار
  if (p.endsWith('/rest/v1/content') && url.search.includes('charimg_') && url.search.includes('neq.__v')) return 'media';
  if (url.origin !== self.location.origin) {
    // CanvasKit (Flutter) ژ gstatic
    if (url.hostname.endsWith('gstatic.com') && p.includes('canvaskit')) return 'media';
    if (url.hostname === 'fonts.gstatic.com') return 'media';
    return null;
  }
  if (p.startsWith('/asp-sw.js') || p.startsWith('/push-sw.js') || p.includes('/push/')) return null;
  if (p.includes('/assets/assets/tts/') || p.includes('/assets/assets/sfx/') || p.includes('/canvaskit/') ||
      p.includes('/assets/fonts/') || p.includes('/assets/assets/fonts/') || p.includes('/assets/packages/')) return 'media';
  if (p.includes('/assets/assets/') && /\.(webp|png|jpg|jpeg|gif|svg)$/i.test(p)) return 'pics';
  return 'shell';
}

async function trim(cache) {
  const keys = await cache.keys();
  if (keys.length > MAX_MEDIA) for (const k of keys.slice(0, keys.length - MAX_MEDIA + 300)) await cache.delete(k);
}

async function cacheFirst(req) {
  const c = await caches.open(MEDIA);
  const hit = await c.match(req);
  if (hit) return hit;
  const res = await fetch(req);
  if (res.ok || res.type === 'opaque') {
    c.put(req, res.clone()).then(() => (Math.random() < 0.05 ? trim(c) : null)).catch(() => {});
  }
  return res;
}

async function staleWhileRevalidate(req) {
  const c = await caches.open(PICS);
  const hit = await c.match(req);
  const net = fetch(req).then((res) => {
    if (res.ok) c.put(req, res.clone()).catch(() => {});
    return res;
  }).catch(() => hit);
  return hit || net;
}

async function networkFirst(req) {
  const c = await caches.open(SHELL);
  try {
    const res = await Promise.race([
      fetch(req),
      new Promise((_, rej) => setTimeout(() => rej(new Error('slow')), 6000)),
    ]);
    if (res.ok) c.put(req, res.clone()).catch(() => {});
    return res;
  } catch (e) {
    const hit = (await c.match(req)) || (req.mode === 'navigate' ? await c.match('/', { ignoreSearch: true }) : null);
    if (hit) return hit;
    return fetch(req); // دیسا تاقی بکە (دبیت ئینتەرنێت زڤڕیبیت)
  }
}

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  let url;
  try { url = new URL(req.url); } catch (_) { return; }
  const k = kind(url);
  if (!k) return;
  if (k === 'media') e.respondWith(cacheFirst(req));
  else if (k === 'pics') e.respondWith(staleWhileRevalidate(req));
  else e.respondWith(networkFirst(req));
});
