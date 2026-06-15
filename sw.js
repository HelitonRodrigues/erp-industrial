/* ============================================================
   SERVICE WORKER — ERP Industrial
   PROPÓSITO: habilitar a instalação do app (PWA / "adicionar à
   tela inicial") e abrir em tela cheia.

   IMPORTANTE: este SW NÃO faz cache. Como o sistema está em
   desenvolvimento ativo (Supabase + atualizações frequentes),
   ele apenas repassa as requisições para a rede. Assim você
   NUNCA fica com tela/JS/CSS antigos por causa do service worker.
   ============================================================ */

// Ativa imediatamente a versão nova do SW, sem esperar abas antigas
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));

// Pass-through puro: sempre busca da rede, sem armazenar nada.
// (Só intercepta navegações de página; demais requisições — Supabase,
//  CDN, etc. — seguem o caminho normal do navegador.)
self.addEventListener('fetch', (event) => {
  if (event.request.mode === 'navigate') {
    event.respondWith(fetch(event.request));
  }
});
