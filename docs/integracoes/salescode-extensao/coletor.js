// Silicate — lê os Pedidos Disponíveis do Salescode e atualiza a Programação de Cargas do ERP.
// O Salescode não tem API: a leitura é pelos cartões da tela. Roda sozinho quando a página abre.
(() => {
  const TOKEN = 'COLE_O_TOKEN_AQUI';
  const RPC = 'https://zodgbitbflkepbszshmu.supabase.co/rest/v1/rpc/sync_salescode';
  const ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpvZGdiaXRiZmxrZXBic3pzaG11Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYwNjYwNjgsImV4cCI6MjA5MTY0MjA2OH0.iWROA5X7CkxOunt7Cn46wWODa7SQ5nU8OJcD52NhCgA';

  const faixa = (txt, cor) => {
    let el = document.getElementById('silicate-erp-faixa');
    if (!el) {
      el = document.createElement('div'); el.id = 'silicate-erp-faixa';
      el.style.cssText = 'position:fixed;top:12px;right:12px;z-index:2147483647;padding:14px 18px;border-radius:12px;font:700 15px/1.35 system-ui,Segoe UI,Arial;color:#fff;box-shadow:0 8px 24px rgba(0,0,0,.25);max-width:420px;cursor:pointer';
      el.title = 'clique para fechar'; el.onclick = () => el.remove();
      document.body.appendChild(el);
    }
    el.style.background = cor; el.textContent = txt;
  };
  const t = s => (s || '').replace(/\s+/g, ' ').trim();

  const ler = () => {
    const map = {};
    document.querySelectorAll('a[href*="/ret/pedido/view/"]').forEach(a => {
      const ped = t(a.querySelector('.card-ped')?.textContent).replace(/\s*PROG\.?$/i, '');
      const pro = t(a.querySelector('.card-pro')?.textContent);
      if (!ped || !pro) return;
      const info = t(a.querySelector('.card-info')?.textContent).split('·').map(t);
      const k = ped + '|' + pro;
      const r = map[k] || { pedido: ped, produto: pro, cliente: t(a.querySelector('.card-cli')?.textContent), cidade: info[0], frete: info[1],
        qtd: t(a.querySelector('.qtd')?.textContent), data: t(a.querySelector('.kb-data')?.textContent), view: a.href.split('/').pop() };
      if (info[2] && !r.status) r.status = info[2];
      if (!r.data) r.data = t(a.querySelector('.kb-data')?.textContent);
      map[k] = r;
    });
    return Object.values(map);
  };

  const enviar = async (itens) => {
    faixa(`ERP: enviando ${itens.length} linhas…`, '#042D4D');
    try {
      const resp = await fetch(RPC, { method: 'POST', headers: { 'Content-Type': 'application/json', apikey: ANON, Authorization: 'Bearer ' + ANON },
        body: JSON.stringify({ p_token: TOKEN, p_itens: itens }) });
      const j = await resp.json().catch(() => ({}));
      if (!resp.ok) return faixa('✕ ERP recusou: ' + (j.message || resp.status), '#E5484D');
      if (!j.ok) return faixa('⚠ ERP não alterou nada: ' + (j.motivo || ''), '#D98E04');
      const resumo = `${j.pedidos} pedidos` + (j.sairam ? ` · ${j.sairam} saíram (faturados)` : '');
      const det = await detalhes(j.precisa_detalhe || [], resumo);
      const hora = new Date().toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });
      faixa(`✓ ERP atualizado às ${hora} — ${resumo}` + (det ? ` · ${det}` : ''), '#15803D');
    } catch (e) { faixa('✕ Sem conexão com o ERP: ' + e.message, '#E5484D'); }
  };

  // ── página de cada pedido (representante, observações, transportadora…) ──
  // Lê pelos RÓTULOS da página (como no PDF do pedido). Guarda também o texto bruto
  // (_bruto) para dar para ajustar a leitura depois sem precisar do PC.
  const lerPedido = (html) => {
    const doc = new DOMParser().parseFromString(html, 'text/html');
    doc.querySelectorAll('script,style,noscript,nav,header .sidebar').forEach(e => e.remove());
    const raiz = doc.querySelector('main, .content, .container-fluid, body') || doc.body;
    const L = [];
    const tw = doc.createTreeWalker(raiz, NodeFilter.SHOW_TEXT); let nd;
    while ((nd = tw.nextNode())) { const x = t(nd.nodeValue); if (x) L.push(x); }
    const N = s => s.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toUpperCase().replace(/[:\s]+$/, '').trim();
    const depois = (rot, n = 1) => { const i = L.findIndex(x => N(x) === rot); return i >= 0 ? L.slice(i + 1, i + 1 + n).join(' ') : null; };
    const junto = (rot) => { const x = L.find(x => N(x).startsWith(rot + ' ')); return x ? x.slice(rot.length).trim() : null; };
    const pega = (rot, n) => depois(rot, n) || junto(rot);
    const tudo = L.join(' | ');
    const data = s => (String(s || '').match(/\d{2}\/\d{2}\/\d{4}/) || [])[0] || null;
    const cond = {};
    ['PALETE', 'RETIRA', 'DESCARGA', 'ENTRA CARRETA', 'CONHECIMENTO DE FRETE'].forEach(k => { const v = pega(k); if (v) cond[k.toLowerCase()] = v.split(' ')[0]; });
    const idxEnt = L.findIndex(x => N(x) === 'ENTREGA');
    const cidEnt = idxEnt >= 0 ? (() => { const r = L.slice(idxEnt).findIndex(x => N(x) === 'CIDADE/UF'); return r >= 0 ? L[idxEnt + r + 1] : null; })() : null;
    return {
      representante: pega('REPRESENTANTE'),
      comprador: pega('COMPRADOR'),
      emissao: pega('DATA DE EMISSAO'),
      entrega: data(pega('ENTREGA PROGRAMADA')),
      obs: pega('OBSERVACOES E INFORMACOES'),
      transportadora: pega('TRANSPORTADORA'),
      placa_motorista: pega('PLACA / MOTORISTA'),
      pagamento: (tudo.match(/\d+(?:\/\d+)*\s*DDL|A VISTA|À VISTA|ANTECIPADO/i) || [])[0] || null,
      cliente_fantasia: pega('NOME FANTASIA'),
      cnpj: pega('CPF / CNPJ'),
      entrega_cidade: cidEnt,
      condicoes: cond,
      _bruto: L.slice(0, 400),
    };
  };
  const detalhes = async (lista, resumo) => {
    if (!lista.length) return '';
    const saida = []; let feitos = 0, erros = 0, login = false;
    const fila = lista.slice();
    const trabalhador = async () => {
      while (fila.length && !login) {
        const p = fila.shift();
        try {
          const r = await fetch('/ret/pedido/view/' + encodeURIComponent(p.view), { credentials: 'include' });
          const h = await r.text();
          if (/Entrar no sistema/i.test(h) && !/REPRESENTANTE/i.test(h)) { login = true; break; }
          saida.push(Object.assign({ pedido: p.pedido }, lerPedido(h)));
        } catch (e) { erros++; }
        feitos++;
        faixa(`ERP: ${resumo} · lendo pedidos ${feitos}/${lista.length}…`, '#042D4D');
      }
    };
    await Promise.all([1, 2, 3, 4].map(trabalhador));
    for (let i = 0; i < saida.length; i += 40) {
      await fetch(RPC.replace('sync_salescode', 'sync_salescode_detalhes'), { method: 'POST',
        headers: { 'Content-Type': 'application/json', apikey: ANON, Authorization: 'Bearer ' + ANON },
        body: JSON.stringify({ p_token: TOKEN, p_det: saida.slice(i, i + 40) }) });
    }
    return `${saida.length} pedido(s) detalhados` + (erros ? ` · ${erros} com erro` : '') + (login ? ' · Salescode pediu login' : '');
  };

  // espera os cartões aparecerem (até 20 s); tela de login = avisa
  let tentativas = 0;
  const esperar = () => {
    if (/Entrar no sistema/i.test(document.body.innerText) && !document.querySelector('a[href*="/ret/pedido/view/"]'))
      return faixa('Faça login no Salescode e clique de novo no ícone do ERP.', '#D98E04');
    const itens = ler();
    if (itens.length >= 5) return enviar(itens);
    if (++tentativas > 20) return faixa('⚠ Não achei os pedidos na tela — confira os filtros e clique de novo.', '#D98E04');
    setTimeout(esperar, 1000);
  };
  faixa('ERP: lendo os pedidos…', '#042D4D');
  setTimeout(esperar, 800);
})();
