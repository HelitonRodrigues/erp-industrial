/* ============================================================
   SERVICE WORKER — ERP Industrial
   PROPÓSITO: habilitar a instalação do app (PWA / "adicionar à
   tela inicial") e abrir em tela cheia.

   Cache-busting completo: intercepta TODAS as requisições do
   próprio domínio (HTML, JS, CSS, partials) e força network-first,
   garantindo que qualquer atualização publicada seja vista por
   todos os dispositivos imediatamente.
   Requisições externas (Supabase, CDN, Fonts) seguem o caminho
   normal do navegador sem interferência.
   ============================================================ */

const APP_ORIGIN = self.location.origin;

// Ativa imediatamente a versão nova do SW, sem esperar abas antigas
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));

// Network-first para tudo do próprio domínio (HTML, JS, CSS, partials).
// Requisições externas (Supabase, CDN, Fonts) passam direto.
self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url);

  // Ignorar requisições externas (Supabase, jsdelivr, Google Fonts, etc.)
  if (url.origin !== APP_ORIGIN) return;

  // Para tudo do próprio domínio: sempre busca da rede com no-cache
  event.respondWith(
    fetch(event.request, { cache: 'no-store' }).catch(() => {
      // Se offline, tenta o cache do browser como fallback
      return caches.match(event.request);
    })
  );
});

/* ── NOTIFICAÇÃO NO CELULAR (Status das Linhas — função push-linhas) ──
   Chega mesmo com o ERP fechado. O som é o padrão do aparelho; Parada e
   Manutenção vibram mais e ficam na tela até a pessoa tocar.            */
self.addEventListener('push', (event) => {
  let d = {};
  try { d = event.data ? event.data.json() : {}; }
  catch (e) { d = { title: 'ERP Silicate', body: event.data ? event.data.text() : '' }; }
  const urgente = !!d.urgente;
  event.waitUntil(self.registration.showNotification(d.title || 'ERP Silicate', {
    body: d.body || '',
    tag: d.tag || undefined,
    renotify: !!d.tag,
    requireInteraction: urgente,
    vibrate: urgente ? [700, 200, 700, 200, 700, 200, 700] : [300, 150, 300],
    icon: 'icons/icon-192.png',
    badge: 'icons/icon-192.png',
    data: { url: d.url || 'dashboard.html' },
  }));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const alvo = new URL((event.notification.data && event.notification.data.url) || 'dashboard.html', self.registration.scope).href;
  event.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then((lista) => {
    for (const c of lista) { if (c.url.split('?')[0] === alvo && 'focus' in c) return c.focus(); }
    return self.clients.openWindow(alvo);
  }));
});
