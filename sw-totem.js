// Service worker só da Central de Rótulos (escopo /totem.html).
// Existe para o navegador aceitar "instalar" a central como app em tela cheia.
// O handler de fetch precisa RESPONDER (handler vazio não conta para instalar):
// repassa tudo para a rede e, sem internet, mostra um aviso simples.
self.addEventListener('install',()=>self.skipWaiting());
self.addEventListener('activate',e=>e.waitUntil(self.clients.claim()));
self.addEventListener('fetch',e=>{
  if(e.request.mode!=='navigate') return;            // dados e imagens seguem direto
  e.respondWith(fetch(e.request).catch(()=>new Response(
    '<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'+
    '<body style="font-family:system-ui;background:#042D4D;color:#fff;display:grid;place-items:center;height:100vh;margin:0;text-align:center">'+
    '<div><div style="font-size:64px">📶</div><h1>Sem internet</h1><p>A central volta sozinha quando a internet voltar.</p></div>'+
    '<script>setInterval(()=>navigator.onLine&&location.reload(),5000)</script>',
    {headers:{'Content-Type':'text/html; charset=utf-8'}})));
});
