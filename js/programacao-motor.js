/* ═══════════════════════════════════════════════════════════════════
   PROGRAMAÇÃO DE CARGAS — motor de conta (sem tela, sem banco)
   Usado pelo programacao-cargas.html (ERP) e pelo programacao-rep.html
   (link público do representante). As duas telas fazem a MESMA conta.

   - Produto do Salescode → produto do ERP: apelido (produto_aliases) →
     nome igual → parecido (mesma regra do casarProduto da portaria.html).
   - Família do produto (produtos.linhas[0]) → produto do planejamento
     (Bag, Linha 25kg, Linha 20kg, Concentrado 10kg, Impermeabilizante 10kg,
     Caulim Granel).
   - Linha: Big Bag e 25 kg = Linha 2; o resto = linhas do planejamento onde
     o produto está ativo (Linha 3, Emitec, Longa Vida). O pedido pode ter
     linha_manual (escolhida na tela) e aí vai para ela.
   - Capacidade do dia = planejamento ATIVO do mês (planejamentos_custo) ×
     turnos.calendario × eficiência da seção — igual ao calcHorasSecao do
     custo-precificacao.html. Folga/feriado = 0 h.
   ═══════════════════════════════════════════════════════════════════ */
(function (G) {
  const DIAS = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];
  const FAM = {
    'Bag':                    { un: 'bags',  kg: 1000, rot: 'Big Bag',           linhaFixa: 'Linha 2' },
    'Linha 25kg':             { un: 'sacos', kg: 25,   rot: 'Ensacado 25 kg',    linhaFixa: 'Linha 2' },
    'Linha 20kg':             { un: 'sacos', kg: 20,   rot: '20 kg' },
    'Concentrado 10kg':       { un: 'sacos', kg: 10,   rot: 'Concentrado 10 kg' },
    'Impermeabilizante 10kg': { un: 'sacos', kg: 10,   rot: 'Impermeabilizante' },
    'Caulim Granel':          { un: 't',     kg: 1000, rot: 'Granel' },
  };
  const FINANCEIRO = ['ANALISE DE AVAL', 'APROVACAO - DIRETOR', 'APROVACAO - GESTOR', 'APROVACAO - REPRESENTANTE', 'EM ABERTO'];

  let _planos = [], _turnos = [], _produtos = [], _aliases = [], _cap = {}, _casa = {};

  const norm = s => String(s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toUpperCase().replace(/\s+/g, ' ').trim();
  const addDias = (iso, n) => { const d = new Date(iso + 'T12:00:00'); d.setDate(d.getDate() + n); return d.toISOString().slice(0, 10); };
  const dow = iso => new Date(iso + 'T12:00:00').getDay();
  const minutos = (ini, fim) => { const p = t => { const [h, m] = String(t).split(':').map(Number); return h * 60 + (m || 0); }; let d = p(fim) - p(ini); if (d <= 0) d += 1440; return d; };

  /* ── produto do Salescode → produto do ERP (regra da portaria.html) ── */
  const SIN = { com: 'c', c: 'c', kg: 'kg', kgs: 'kg', quilos: 'kg', bigbag: 'bag', big: 'bag', bags: 'bag', sc: '', saco: '', sacos: '', ensacado: '', un: '', und: '', impermeab: 'impermeabilizante', impemeabilizante: 'impermeabilizante', impermeabilizante: 'impermeabilizante' };
  function prodNorm(s) {
    return String(s || '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '')
      .replace(/(\d+)\s*(kg|g|l|lt)\b/g, '$1$2').replace(/c\//g, 'c ').replace(/[^a-z0-9 ]+/g, ' ').replace(/\s+/g, ' ').trim();
  }
  // variação de cor/qualidade escrita sem zero ("BRANCO 2") vira "02", igual ao cadastro ("Branco 02")
  const prodTokens = s => prodNorm(s).split(' ').map(t => SIN[t] !== undefined ? SIN[t] : t).map(t => /^\d$/.test(t) ? '0' + t : t).filter(Boolean);
  const prodPeso = s => { const m = prodNorm(s).match(/\b(\d+(?:\.\d+)?)kg\b/); return m ? Number(m[1]) : null; };
  const prodTipo = s => { const n = prodNorm(s); return /granel/.test(n) ? 'granel' : /\bbag\b|big ?bag/.test(n) ? 'bag' : 'saco'; };
  function casarProduto(texto) {
    const an = prodNorm(texto); if (!an) return null;
    if (_casa[an] !== undefined) return _casa[an];
    let r = null;
    const al = _aliases.find(a => a.alias_norm === an);
    const pAl = al && _produtos.find(x => x.id === al.produto_id);
    if (pAl) r = { produto: pAl, seguro: true, via: 'apelido' };
    if (!r) { const ex = _produtos.find(p => prodNorm(p.nome) === an); if (ex) r = { produto: ex, seguro: true, via: 'igual' }; }
    if (!r) {
      const A = new Set(prodTokens(texto)), pa = prodPeso(texto), ta = prodTipo(texto);
      const notas = _produtos.map(p => {
        const B = new Set(prodTokens(p.nome)); let inter = 0; A.forEach(t => { if (B.has(t)) inter++; });
        const uni = new Set([...A, ...B]).size || 1; let s = 0.6 * inter / uni + 0.4 * (B.size ? inter / B.size : 0);
        const pb = prodPeso(p.nome); if (pa != null && pb != null && pa !== pb) s -= 0.5;
        const med = t => /^\d+(?:\.\d+)?(kg|g|l|lt|ml)$/.test(t), ma = [...A].filter(med), mb = [...B].filter(med);
        if (ma.some(t => !B.has(t)) && mb.some(t => !A.has(t))) s -= 0.35;
        if (prodTipo(p.nome) !== ta) s -= 0.4;
        const varA = [...A].filter(t => /^0\d$/.test(t)), varB = [...B].filter(t => /^0\d$/.test(t));
        if (!varA.length && varB.includes('01')) s += 0.12;
        if (varA.length && varB.length && !varB.some(t => varA.includes(t))) s -= 0.3;
        return { produto: p, s };
      }).sort((x, y) => y.s - x.s);
      const b = notas[0], s2 = notas[1] ? notas[1].s : 0;
      if (b && b.s >= 0.5 && b.s - s2 >= 0.1) r = { produto: b.produto, seguro: false, via: 'parecido' };
    }
    return (_casa[an] = r);
  }

  /* ── família (produto do planejamento) ── */
  function familiaDeTexto(t) {
    const n = norm(t);
    if (/BIG ?BAG|^BAG$|\bBAG\b/.test(n)) return 'Bag';
    if (/GRANEL/.test(n)) return 'Caulim Granel';
    if (/IMPERME/.test(n)) return 'Impermeabilizante 10kg';
    if (/25 ?KG/.test(n)) return 'Linha 25kg';
    if (/20 ?KG/.test(n)) return 'Linha 20kg';
    if (/CONCENTRADO|KILIGA|LIGANEX|LIGAPRO|10 ?KG/.test(n)) return 'Concentrado 10kg';
    return null;
  }
  const REVENDA = /^ORIGINAL|LIQUIDO|50 ?G\b|STAND POUCH|MASSA|SELADOR|FUNDO PREPARADOR|TOPDRY|ADESIVO|PU 40|BETUMEX|VEDAMASSA|CHAPISTEC|ACQUABLOCK|IMPER PRO/;
  function familia(textoSalescode, prodErp) {
    if (REVENDA.test(norm(textoSalescode))) return null;
    if (prodErp && Array.isArray(prodErp.linhas) && prodErp.linhas[0]) { const f = familiaDeTexto(prodErp.linhas[0]); if (f) return f; }
    return familiaDeTexto(textoSalescode);
  }
  function grupo(textoSalescode) { const n = norm(textoSalescode); if (/^CAULIM/.test(n)) return 'caulim'; return REVENDA.test(n) ? 'original' : 'ligas'; }
  function material(texto) {
    const n = norm(texto);
    if (/AMARELO/.test(n)) return 'amarelo'; if (/CINZA/.test(n)) return 'cinza'; if (/CREME/.test(n)) return 'creme';
    if (/BRANCO ?0?3/.test(n)) return 'branco3'; if (/BRANCO ?0?2/.test(n)) return 'branco2'; if (/BRANCO/.test(n)) return 'branco';
    return grupo(texto) === 'ligas' ? 'liga' : 'outro';
  }

  /* ── itens de uma carga, já na unidade da família ── */
  function itens(c) {
    let base = Array.isArray(c.itens) && c.itens.length ? c.itens : null;
    if (!base) { // legado da planilha
      const p = c.planilha || {}; const emb = norm(p.embalagem), mat = p.material || '';
      const nome = /BAG/.test(emb) ? 'CAULIM BIG BAG – ' + mat : /GRANEL/.test(emb) ? 'CAULIM GRANEL – ' + mat : /SAC/.test(emb) ? 'CAULIM ENSACADO 25 Kg – ' + mat : (mat || p.embalagem || '—');
      base = [{ produto: nome, qtd: Number(p.peso_t) || 0, unidade: 'TL' }];
    }
    return base.map(i => {
      const m = casarProduto(i.produto); const erp = m && m.produto;
      const fam = familia(i.produto, erp); const f = FAM[fam];
      const kg = Number(erp && erp.peso_unidade_kg) || (f && f.kg) || null;
      const u = norm(i.unidade), qtd = Number(i.qtd) || 0;
      let q = qtd, un = f ? f.un : (i.unidade || '').toLowerCase(), t = null;
      if (u === 'TL' || u === 'T' || u === 'TON') { t = qtd; if (f && kg) q = f.un === 't' ? qtd : qtd * 1000 / kg; }
      else if (kg) t = qtd * kg / 1000;
      return { produto: i.produto, erp, casou: m ? m.via : null, nome: erp ? erp.nome : i.produto, fam, q, un, t, grupo: grupo(i.produto), mat: material((erp ? erp.nome : '') + ' ' + i.produto) };
    });
  }
  const ehFinanceiro = c => FINANCEIRO.includes(norm(c.status_salescode));
  // coluna do quadro do Salescode que manda (a mais adiantada) e prioridade para programar
  const COLUNAS = ['Ordem de Carga', 'A contratar', 'Ordem Cancelada', 'Programados', 'Financeiro'];
  const coluna = c => {
    const cs = c.colunas_salescode || c.col || [];
    const k = COLUNAS.find(x => cs.some(y => norm(y) === norm(x)));
    if (k) return k;
    const st = norm(c.status_salescode);
    if (st === 'ORDEM DE CARGA') return 'Ordem de Carga';
    if (st === 'ORDEM CANCELADA') return 'Ordem Cancelada';
    if (ehFinanceiro(c)) return 'Financeiro';
    return null;
  };
  const prioridade = c => { const i = COLUNAS.indexOf(coluna(c)); return i < 0 ? 9 : i; };
  // conta capacidade: tudo que não está no financeiro + financeiro que a fábrica já programou (tem data da fábrica)
  const contaCapacidade = c => !ehFinanceiro(c) || !!(c.data_manual || c.man);
  const dataDe = c => c.data_manual || c.data_salescode || c.data_planilha || null;

  /* ── capacidade ── */
  function planoDoDia(iso) {
    const [a, m] = iso.split('-').map(Number);
    return _planos.filter(p => Number(p.ano) === a && Number(p.mes) === m)
      .sort((x, y) => String(y.atualizado_em).localeCompare(String(x.atualizado_em)))[0] || null;
  }
  function capacidadeDia(iso) {
    if (_cap[iso]) return _cap[iso];
    const pl = planoDoDia(iso);
    if (!pl) return (_cap[iso] = { semPlano: true, linhas: [], estado: null, trabalha: false });
    const est = pl.estado || {}; const estado = (est.calendario || {})[iso] || null;
    const trabalha = estado === 'trabalha' || estado === 'domingo-especial';
    const linhas = (est.blocos || []).map(b => {
      let mins = 0; const cap = {}, capTodas = {};
      (b.secoes || []).forEach(s => {
        (s.produtos || []).forEach(p => {
          const ch = Number(p.capHora) || 0; if (!(ch > 0) || !FAM[p.nome]) return;
          capTodas[p.nome] = Math.max(capTodas[p.nome] || 0, ch);
          if (p.ativo !== false) cap[p.nome] = Math.max(cap[p.nome] || 0, ch);
        });
        if (!trabalha || s.simuladoDesligado) return;
        const pI = s.paradaProgInicio || s.simuladoParadaInicio, pF = s.paradaProgFim || s.simuladoParadaFim;
        if (pI && pF && iso >= pI && iso <= pF) return;   // parada por período (reforma) — o Custo conta os mesmos dias em "Parado N dias"
        const t = _turnos.find(x => x.nome === s.turnoNome); if (!t) return;
        let m = 0;
        if (estado === 'domingo-especial') m = Math.round((Number(est.horasDomingoEspecial) || 0) * 60);
        else { const di = (t.calendario || {})[DIAS[dow(iso)]]; if (di && di.ativo !== false && di.inicio && di.fim) m = Math.max(0, minutos(di.inicio, di.fim) - (Number(t.refeicao_min) || 0)); }
        mins += m * (Number(s.eficiencia) || 100) / 100;
      });
      return { nome: b.linhaNome, horas: mins / 60, cap, capTodas };
    });
    return (_cap[iso] = { semPlano: false, linhas, estado, trabalha, plano: pl.nome || pl.codigo });
  }
  // linhas onde a família roda neste dia (em ordem de preferência)
  function linhasDaFamilia(cap, fam, linhaManual) {
    if (linhaManual) { const l = cap.linhas.find(x => x.nome === linhaManual); if (l) return [l]; }
    // Big Bag e 25 kg: Linha 2. Se a Linha 2 estiver parada no plano (ex.: reforma), vão para onde o plano ativou o produto.
    const fixa = FAM[fam] && FAM[fam].linhaFixa;
    if (fixa) { const l = cap.linhas.find(x => x.nome === fixa); if (l && (l.horas > 0 || !cap.trabalha)) return [l]; }
    return cap.linhas.filter(l => l.cap[fam] && l.horas > 0).sort((a, b) => b.cap[fam] - a.cap[fam]);
  }
  function capHora(l, fam) {
    if (l.cap[fam]) return l.cap[fam]; if (l.capTodas[fam]) return l.capTodas[fam];
    let m = 0; Object.values(_cap).forEach(c => (c.linhas || []).forEach(x => { m = Math.max(m, x.capTodas[fam] || 0); }));
    return m || null;
  }
  // linha de um item (para agrupar na tela)
  function linhaDoItem(iso, fam, linhaManual) {
    if (!fam) return null;
    const cap = iso ? capacidadeDia(iso) : null;
    if (cap && cap.linhas.length) { const ls = linhasDaFamilia(cap, fam, linhaManual); if (ls[0]) return ls[0].nome; }
    if (linhaManual) return linhaManual;
    return (FAM[fam] && FAM[fam].linhaFixa) || null;
  }
  /* Encaixa as cargas do dia (na ordem) nas horas das linhas.
     cargas: [{id, _itens, linha_manual}] (financeiro já fora).                */
  function encaixarDia(iso, cargas) {
    const cap = capacidadeDia(iso);
    const resto = {}, usoH = {}, faltaH = {}, uni = {}, fit = {};
    cap.linhas.forEach(l => { resto[l.nome] = l.horas; usoH[l.nome] = 0; });
    cargas.forEach(c => {
      let tot = 0, cabe = 0, semLinha = true;
      c._itens.forEach(it => {
        if (!it.fam) return;
        const ls = linhasDaFamilia(cap, it.fam, c.linha_manual); if (!ls.length) return;
        semLinha = false; tot += it.q; let need = it.q;
        ls.forEach(l => {
          if (need <= 0) return; const ch = capHora(l, it.fam); if (!ch) return;
          const usa = Math.min(need, Math.max(0, resto[l.nome]) * ch);
          resto[l.nome] -= usa / ch; usoH[l.nome] += usa / ch; need -= usa; cabe += usa;
          if (usa > 0) { const u = (uni[l.nome] = uni[l.nome] || {}); (u[it.fam] = u[it.fam] || { q: 0, f: 0 }).q += usa; }
        });
        if (need > 0) { const l = ls[0], ch = capHora(l, it.fam) || 1; faltaH[l.nome] = (faltaH[l.nome] || 0) + need / ch; const u = (uni[l.nome] = uni[l.nome] || {}); (u[it.fam] = u[it.fam] || { q: 0, f: 0 }).f += need; }
      });
      fit[c.id] = semLinha ? { st: 'sl' } : (cabe >= tot - 0.01 ? { st: 'ok' } : (cabe > 0.5 ? { st: 'par', cabe, tot } : { st: 'no', tot }));
    });
    return { cap, usoH, faltaH, uni, fit, resto };
  }
  // quanto ainda cabe de uma família num dia (na linha padrão dela)
  function livre(iso, cargas, fam) {
    const e = encaixarDia(iso, cargas);
    if (e.cap.semPlano) return { semPlano: true, fechado: true, livre: 0, total: 0 };
    if (!e.cap.trabalha) return { fechado: true, livre: 0, total: 0 };
    const ls = linhasDaFamilia(e.cap, fam, null); if (!ls.length) return { fechado: true, livre: 0, total: 0 };
    let livreU = 0, total = 0;
    ls.forEach(l => { const ch = capHora(l, fam) || 0; livreU += Math.max(0, e.resto[l.nome] || 0) * ch; total += l.horas * ch; });
    const falta = ls.some(l => (e.faltaH[l.nome] || 0) > 0.01);
    return { fechado: false, livre: falta ? 0 : livreU, total };
  }

  G.ProgMotor = {
    FAM, DIAS, norm, addDias, dow, prodNorm,
    iniciar(o) { _planos = o.planos || []; _turnos = o.turnos || []; _produtos = o.produtos || []; _aliases = o.aliases || []; _cap = {}; _casa = {}; },
    casarProduto, familia, grupo, material, itens, ehFinanceiro, dataDe, COLUNAS, coluna, prioridade, contaCapacidade,
    capacidadeDia, linhasDaFamilia, linhaDoItem, capHora, encaixarDia, livre,
  };
})(typeof window !== 'undefined' ? window : globalThis);
