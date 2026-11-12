// Silicate — lê os TICKETS DE PESAGEM do Portal de Relatórios (balança) e dá baixa na Programação de Cargas.
// Só roda quando a extensão abre a consulta com #erp (depois do Salescode). Abrir a consulta na mão não faz nada.
// Ticket com pesagem final = pedidos do ticket CARREGADOS, com a data/hora da pesagem final.
(() => {
  if (location.hash !== '#erp') return;
  const TOKEN = 'COLE_O_TOKEN_AQUI';
  const BASE = 'https://zodgbitbflkepbszshmu.supabase.co/rest/v1/rpc/';
  const ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpvZGdiaXRiZmxrZXBic3pzaG11Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYwNjYwNjgsImV4cCI6MjA5MTY0MjA2OH0.iWROA5X7CkxOunt7Cn46wWODa7SQ5nU8OJcD52NhCgA';
  const DIAS = 7;   // olha os tickets dos últimos 7 dias (só abre a impressão dos que o ERP ainda não tem)

  const faixa = (txt, cor) => {
    let el = document.getElementById('silicate-erp-faixa');
    if (!el) {
      el = document.createElement('div'); el.id = 'silicate-erp-faixa';
      el.style.cssText = 'position:fixed;top:12px;right:12px;z-index:2147483647;padding:14px 18px;border-radius:12px;font:700 15px/1.35 system-ui,Segoe UI,Arial;color:#fff;box-shadow:0 8px 24px rgba(0,0,0,.25);max-width:440px;cursor:pointer';
      el.title = 'clique para fechar'; el.onclick = () => el.remove();
      document.body.appendChild(el);
    }
    el.style.background = cor; el.textContent = txt;
  };
  const rpc = async (fn, corpo) => {
    const r = await fetch(BASE + fn, { method: 'POST', headers: { 'Content-Type': 'application/json', apikey: ANON, Authorization: 'Bearer ' + ANON }, body: JSON.stringify(corpo) });
    const j = await r.json().catch(() => ({}));
    if (!r.ok) throw new Error(j.message || ('HTTP ' + r.status));
    return j;
  };
  const dma = d => d.toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit', year: 'numeric' });
  const doc = h => new DOMParser().parseFromString(h, 'text/html');
  const ehLogin = d => !d.querySelector('a[href*="/ticket/impressao/"]') && !!d.querySelector('input[type=password]');

  // impressão do ticket → {ticket, placa, motorista, status, fim, liq, anot, itens:[{pedido,cliente,qtd,kg,produto}]}
  const lerTicket = (html, id) => {
    const x = doc(html); x.querySelectorAll('script,style').forEach(e => e.remove());
    const L = x.body.textContent.split('\n').map(s => s.trim()).filter(Boolean);
    const at = (k, de = 0) => { for (let i = de; i < L.length; i++) if (L[i].toUpperCase() === k) return i; return -1; };
    const dep = (k, de = 0) => { const i = at(k, de); return i >= 0 ? L[i + 1] : null; };
    const iF = at('PESAGEM FINAL'), iL = at('PESO LÍQUIDO'), iA = at('ANOTAÇÃO');
    const tab = [...x.querySelectorAll('table')].find(t => /Pedido/i.test(t.textContent));
    const itens = tab ? [...tab.querySelectorAll('tr')].slice(1).map(tr => [...tr.children].map(c => c.textContent.trim()))
      .filter(r => r[0] && r[0] !== 'Total' && r.length >= 5).map(r => ({ pedido: r[0], cliente: r[1], qtd: r[2], kg: r[3], produto: r[4] })) : [];
    return {
      ticket: id, placa: dep('PLACA'), motorista: dep('MOTORISTA'), status: dep('STATUS'),
      fim: iF >= 0 ? dep('DATA/HORA', iF) : null,
      liq: iL >= 0 ? (L.slice(iL + 1, iL + 4).find(s => /kg/i.test(s)) || null) : null,
      anot: iA >= 0 ? L.slice(iA + 1).filter(s => !/Portal de Relat|©/.test(s)).join(' | ').slice(0, 500) : '',
      itens,
    };
  };

  const rodar = async () => {
    if (ehLogin(document)) return faixa('Faça login no Portal da balança e clique de novo no ícone do ERP.', '#D98E04');
    faixa('Balança: procurando tickets…', '#042D4D');
    const csrf = document.querySelector('input[name=_csrf]')?.value || '';
    const hoje = new Date(), ini = new Date(); ini.setDate(ini.getDate() - DIAS);
    const corpo = new URLSearchParams({ ticket: '', status: '', motorista: '', placa: '', cliente: '', pedido: '', inicio: dma(ini), fim: dma(hoje), _csrf: csrf });
    const lista = doc(await fetch(location.pathname, { method: 'POST', credentials: 'include', body: corpo }).then(r => r.text()));
    if (ehLogin(lista)) return faixa('Faça login no Portal da balança e clique de novo no ícone do ERP.', '#D98E04');
    const ids = [...new Set([...lista.querySelectorAll('a[href*="/ticket/impressao/"]')].map(a => a.getAttribute('href').split('/').pop()))];
    if (!ids.length) return faixa(`Balança: nenhum ticket nos últimos ${DIAS} dias.`, '#D98E04');

    const novos = await rpc('balanca_novos', { p_token: TOKEN, p_tickets: ids });
    if (!novos.length) return faixa(`✓ Balança em dia — ${ids.length} tickets, nenhum novo.`, '#15803D');

    const lidos = []; let feitos = 0, erros = 0; const fila = novos.slice();
    const trabalhador = async () => {
      while (fila.length) {
        const id = fila.shift();
        try { lidos.push(lerTicket(await fetch('/relatorio/ticket/impressao/' + id, { credentials: 'include' }).then(r => r.text()), id)); }
        catch (e) { erros++; }
        faixa(`Balança: lendo tickets ${++feitos}/${novos.length}…`, '#042D4D');
      }
    };
    await Promise.all([1, 2, 3, 4].map(trabalhador));

    let tot = { tickets: 0, marcados: 0, corrigidos: 0 };
    for (let i = 0; i < lidos.length; i += 30) {
      const j = await rpc('sync_balanca', { p_token: TOKEN, p_tickets: lidos.slice(i, i + 30) });
      tot.tickets += j.tickets || 0; tot.marcados += j.marcados || 0; tot.corrigidos += j.corrigidos || 0;
    }
    const pesando = lidos.filter(t => !/\d{2}\/\d{2}\/\d{4}/.test(t.fim || '')).length;
    const hora = new Date().toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });
    faixa(`✓ Balança às ${hora} — ${tot.tickets} ticket(s) novo(s) · ${tot.marcados} pedido(s) carregado(s)` +
      (tot.corrigidos ? ` · ${tot.corrigidos} data(s) corrigida(s)` : '') + (pesando ? ` · ${pesando} ainda sem pesagem final` : '') +
      (erros ? ` · ${erros} com erro` : ''), '#15803D');
  };
  setTimeout(() => rodar().catch(e => faixa('✕ Balança: ' + e.message, '#E5484D')), 600);
})();
