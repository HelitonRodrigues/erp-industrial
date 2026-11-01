// Service worker só da Central de Rótulos (escopo /totem.html).
// Existe para o navegador aceitar "instalar" a central como app em tela cheia.
// Não guarda nada em cache: tudo vem sempre da rede.
self.addEventListener('install',()=>self.skipWaiting());
self.addEventListener('activate',e=>e.waitUntil(self.clients.claim()));
self.addEventListener('fetch',()=>{});
