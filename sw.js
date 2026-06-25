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
