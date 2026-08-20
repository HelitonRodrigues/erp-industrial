/* ================================================================
   PLANCUSTOS-CORE — núcleo PURO do módulo Planejamento & Custos
   (plancustos.html). Sem DOM, sem banco, sem valor chutado.
   Testável no Node:  const PC = require('./js/plancustos-core.js')

   Regras herdadas (validadas em produção):
   • Motor de horas: portado 1:1 do custo-precificacao.html
     (bruto → −refeição/+extras → −perda eficiência → −paradas → disponível)
   • Alvo 38%: TETO de (custo produtivo ÷ faturamento). Não é margem.
   • Conciliação Planejado × Realizado: chave = LINHA DE PRODUTO
     normalizada (produtos_op.linha_produto) + mês. A linha física é
     DIMENSÃO de análise — nunca parte da chave (evita buracos quando
     a produção muda de linha).
   • Nunca inventar número: falta de dado retorna null e o chamador
     mostra o aviso; tolerâncias de arredondamento explícitas.
================================================================ */
(function (root, factory) {
  if (typeof module === 'object' && module.exports) module.exports = factory();
  else root.PC = factory();
})(typeof self !== 'undefined' ? self : this, function () {
  'use strict';

  var DIAS_SEMANA = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];
  var BUCKETS = ['L20', 'CONC', 'CAULIM25', 'CAULIMBB', 'CAULIMGRANEL'];
  var BUCKET_LABEL = { L20: 'Linha 20kg', CONC: 'Concentrado 10kg', CAULIM25: 'Caulim 25kg', CAULIMBB: 'Caulim Big Bag', CAULIMGRANEL: 'Caulim Granel' };
  var GRUPOS_CUSTO = ['MP', 'EMB', 'PROD', 'IND'];
  var GRUPO_LABEL = { MP: 'Matéria-prima', EMB: 'Embalagem', PROD: 'Produção', IND: 'Indiretos' };

  /* tolerância única de conferência de dinheiro (arredondamento) */
  var TOL_RS = 0.01;
  /* tolerância de unidades na conciliação (produção é inteira) */
  var TOL_UN = 0.5;

  /* ── nome normalizado — a MESMA régua do norm_nome() do banco ── */
  function normNome(s) {
    return String(s || '').toLowerCase().normalize('NFD')
      .replace(/[\u0300-\u036f]/g, '').replace(/[^a-z0-9]/g, '');
  }

  /* ================================================================
     MOTOR DE HORAS (1:1 com custo-precificacao.html — não recalibrar)
  ================================================================ */
  function calcMinutos(ini, fim) {
    if (!ini || !fim) return 0;
    var a = ini.split(':').map(Number), b = fim.split(':').map(Number);
    var mins = (b[0] * 60 + b[1]) - (a[0] * 60 + a[1]);
    if (mins < 0) mins += 1440;
    return mins;
  }

  function getFeriadosNacionais(ano, mes) {
    var f = [];
    var fixos = [[1, 1, 'Ano Novo'], [4, 21, 'Tiradentes'], [5, 1, 'Dia do Trabalho'], [9, 7, 'Independência'],
      [10, 12, 'N.Sra.Aparecida'], [11, 2, 'Finados'], [11, 15, 'Proclamação da República'], [11, 20, 'Consciência Negra'], [12, 25, 'Natal']];
    fixos.forEach(function (x) { if (x[0] === mes) f.push({ dia: x[1], nome: x[2] }); });
    var a = ano % 19, b = Math.floor(ano / 100), c = ano % 100, d2 = Math.floor(b / 4), e = b % 4,
      fi = Math.floor((b + 8) / 25), g = Math.floor((b - fi + 1) / 3), h = (19 * a + b - d2 - g + 15) % 30,
      i = Math.floor(c / 4), k = c % 4, l = (32 + 2 * e + 2 * i - h - k) % 7, m2 = Math.floor((a + 11 * h + 22 * l) / 451);
    var mesPascoa = Math.floor((h + l - 7 * m2 + 114) / 31), diaPascoa = (h + l - 7 * m2 + 114) % 31 + 1;
    var pascoa = new Date(ano, mesPascoa - 1, diaPascoa);
    var sf = new Date(pascoa); sf.setDate(pascoa.getDate() - 2);
    var carnaval = new Date(pascoa); carnaval.setDate(pascoa.getDate() - 47);
    var cc = new Date(pascoa); cc.setDate(pascoa.getDate() + 60);
    if (mesPascoa === mes) f.push({ dia: diaPascoa, nome: 'Páscoa' });
    if (sf.getMonth() + 1 === mes) f.push({ dia: sf.getDate(), nome: 'Sexta-feira Santa' });
    if (carnaval.getMonth() + 1 === mes) f.push({ dia: carnaval.getDate(), nome: 'Carnaval' });
    if (cc.getMonth() + 1 === mes) f.push({ dia: cc.getDate(), nome: 'Corpus Christi' });
    return f;
  }

  function gerarCalendarioMes(ano, mes, feriadosLocais, calendarioExistente) {
    var diasNoMes = new Date(ano, mes, 0).getDate();
    var prefixo = ano + '-' + String(mes).padStart(2, '0') + '-';
    var feriadosNac = getFeriadosNacionais(ano, mes);
    var dias = {};
    feriadosNac.forEach(function (x) { dias[x.dia] = true; });
    (feriadosLocais || []).forEach(function (x) { dias[x.dia] = true; });
    var calendario = {};
    Object.keys(calendarioExistente || {}).forEach(function (k) {
      if (k.indexOf(prefixo) === 0) calendario[k] = calendarioExistente[k];
    });
    for (var d = 1; d <= diasNoMes; d++) {
      var dateKey = prefixo + String(d).padStart(2, '0');
      if (calendario[dateKey] !== undefined) continue;
      var dow = new Date(ano, mes - 1, d).getDay();
      calendario[dateKey] = dias[d] ? 'feriado' : (dow === 0 ? 'folga' : 'trabalha');
    }
    return calendario;
  }

  function calcHorasSecao(calendarioMes, turno, eficienciaPct, extrasPorDia, paradasHoras, horasDomingoEspecial) {
    var refM = Number(turno && turno.refeicao_min) || 0;
    var extrasMins = Math.round((extrasPorDia || 0) * 60);
    var minsBrutos = 0, diasTrabalho = 0;
    Object.keys(calendarioMes || {}).forEach(function (dateKey) {
      var estado = calendarioMes[dateKey];
      if (estado === 'trabalha' || estado === 'domingo-especial') {
        diasTrabalho++;
        if (estado === 'domingo-especial') {
          minsBrutos += Math.round((horasDomingoEspecial || 0) * 60) + extrasMins;
        } else {
          var dow = new Date(dateKey + 'T12:00:00').getDay();
          var diaInfo = ((turno && turno.calendario) || {})[DIAS_SEMANA[dow]];
          var mDia = 0;
          if (diaInfo && diaInfo.ativo !== false && diaInfo.inicio && diaInfo.fim) {
            mDia = Math.max(0, calcMinutos(diaInfo.inicio, diaInfo.fim) - refM);
          }
          if (mDia > 0) minsBrutos += mDia + extrasMins;
        }
      }
    });
    var paradasMins = Math.round((paradasHoras || 0) * 60);
    var efic = (eficienciaPct === null || eficienciaPct === undefined) ? 100 : eficienciaPct;
    var perdaMins = Math.round(minsBrutos * (100 - efic) / 100);
    var liquidoMins = minsBrutos - perdaMins;
    var dispMins = Math.max(0, liquidoMins - paradasMins);
    return { diasTrabalho: diasTrabalho, horasBrutas: minsBrutos / 60, perdaH: perdaMins / 60, liquidoH: liquidoMins / 60, paradaH: paradasMins / 60, dispH: dispMins / 60 };
  }

  function distribuirHorasProdutos(produtos, horasDisp) {
    var horasNecTotal = 0, necPorId = {}, semDemanda = [];
    (produtos || []).forEach(function (p) {
      if (p.demanda > 0) { var nec = p.cap_hora > 0 ? p.demanda / p.cap_hora : 0; necPorId[p.id] = nec; horasNecTotal += nec; }
      else semDemanda.push(p);
    });
    var fatorRateio = (horasNecTotal > horasDisp && horasNecTotal > 0) ? horasDisp / horasNecTotal : 1;
    var horasComDemanda = 0, alocado = {};
    Object.keys(necPorId).forEach(function (id) { alocado[id] = necPorId[id] * fatorRateio; horasComDemanda += alocado[id]; });
    var horasRestantes = Math.max(0, horasDisp - horasComDemanda);
    var horasPorSemDem = semDemanda.length > 0 ? horasRestantes / semDemanda.length : 0;
    var res = {};
    (produtos || []).forEach(function (p) {
      var h = p.demanda > 0 ? alocado[p.id] : horasPorSemDem;
      res[p.id] = { horasDispProd: h, qtdMax: p.cap_hora > 0 ? Math.round(h * p.cap_hora) : 0 };
    });
    return res;
  }

  /* ================================================================
     PLANO — itens (linha_id, turno_id, produto_nome) → quantidades
     Régua: qtd = qtd_manual ?? (demanda>0 ? demanda : qtdMax das horas)
  ================================================================ */
  function gruposDoPlano(itens) {
    var grupos = [];
    (itens || []).forEach(function (it) {
      var g = null, i;
      for (i = 0; i < grupos.length; i++) if (grupos[i].linha_id === it.linha_id) { g = grupos[i]; break; }
      if (!g) { g = { linha_id: it.linha_id, turnos: [] }; grupos.push(g); }
      var t = null;
      for (i = 0; i < g.turnos.length; i++) if (g.turnos[i].turno_id === it.turno_id) { t = g.turnos[i]; break; }
      if (!t) { t = { turno_id: it.turno_id, itens: [] }; g.turnos.push(t); }
      t.itens.push(it);
    });
    return grupos;
  }

  function computarPlano(plano, turnoDe) {
    var porItem = {}, porProduto = {}, porLinha = {};
    gruposDoPlano(plano.itens).forEach(function (g) {
      g.turnos.filter(function (t) { return t.turno_id; }).forEach(function (tg) {
        var primeiroItem = null;
        for (var i = 0; i < tg.itens.length; i++) if (!tg.itens[i]._ph) { primeiroItem = tg.itens[i]; break; }
        primeiroItem = primeiroItem || tg.itens[0] || {};
        var turno = turnoDe(tg.turno_id);
        var efic = (primeiroItem.eficiencia === null || primeiroItem.eficiencia === undefined) ? 90 : primeiroItem.eficiencia;
        var horas = calcHorasSecao(plano.calendario, turno, efic,
          primeiroItem.extras || 0, primeiroItem.paradas_h || 0,
          (plano.horas_domingo_especial === null || plano.horas_domingo_especial === undefined) ? 8 : plano.horas_domingo_especial);
        var ativos = tg.itens.filter(function (i2) { return i2.ativo !== false && !i2._ph; });
        var dist = distribuirHorasProdutos(ativos, horas.dispH);
        tg.itens.filter(function (i2) { return !i2._ph; }).forEach(function (it) {
          var d = dist[it.id] || { horasDispProd: 0, qtdMax: 0 };
          var qtd = it.ativo === false ? 0 :
            ((it.qtd_manual !== null && it.qtd_manual !== undefined && it.qtd_manual !== '') ? Number(it.qtd_manual) :
              (Number(it.demanda) > 0 ? Number(it.demanda) : d.qtdMax));
          var excede = Number(it.demanda) > 0 && Number(it.demanda) > d.qtdMax && (it.qtd_manual === null || it.qtd_manual === undefined || it.qtd_manual === '');
          porItem[it.id] = { horas: horas, horasProd: d.horasDispProd, qtdMax: d.qtdMax, qtd: qtd, excede: excede };
          if (it.ativo === false) return;
          var chaveP = String(it.produto_nome || '').trim();
          porProduto[chaveP] = porProduto[chaveP] || { demanda: 0, planejado: 0, linhas: {} };
          porProduto[chaveP].demanda += Number(it.demanda) || 0;
          porProduto[chaveP].planejado += qtd;
          porProduto[chaveP].linhas[g.linha_id] = (porProduto[chaveP].linhas[g.linha_id] || 0) + qtd;
          porLinha[g.linha_id] = porLinha[g.linha_id] || { horasDisp: 0, horasUsadas: 0, sacos: 0, lenha: 0, _turnos: {} };
          if (!porLinha[g.linha_id]._turnos[tg.turno_id]) {
            porLinha[g.linha_id].horasDisp += horas.dispH;
            porLinha[g.linha_id].lenha += (Number(it.lenha_m3_turno) || 0) * horas.diasTrabalho;
            porLinha[g.linha_id]._turnos[tg.turno_id] = true;
          }
          porLinha[g.linha_id].horasUsadas += it.cap_hora > 0 ? qtd / it.cap_hora : 0;
          porLinha[g.linha_id].sacos += qtd;
        });
      });
    });
    return { porItem: porItem, porProduto: porProduto, porLinha: porLinha };
  }

  /* ================================================================
     REALIZADO — OPs da tabela `producao` do mês do plano
     Chave = linha_produto normalizado; produto específico vira detalhe;
     linha física vira dimensão. `status==='parada'` não é produção.
  ================================================================ */
  function computarRealizado(ops) {
    var porProduto = {}, porLinha = {}, porDia = {};
    (ops || []).forEach(function (r) {
      if (r.status === 'parada') return;
      var linhaR = String(r.linha || '—').trim();
      var pl = porLinha[linhaR] = porLinha[linhaR] || { sacos: 0, ht: 0, hp: 0, lenha: 0, registros: 0 };
      pl.ht += Number(r.ht) || 0; pl.hp += Number(r.hp) || 0; pl.lenha += Number(r.consumo_lenha) || 0; pl.registros++;
      (r.produtos_op || []).forEach(function (op) {
        var nomeLP = String(op.linha_produto || op.produto || '').trim();
        if (!nomeLP) return;
        var k = normNome(nomeLP);
        var pp = porProduto[k] = porProduto[k] || { nome: nomeLP, total: 0, porLinha: {}, det: {} };
        var sacos = Number(op.total_sacos !== undefined && op.total_sacos !== null ? op.total_sacos : op.sacos) || 0;
        pp.total += sacos;
        pp.porLinha[linhaR] = (pp.porLinha[linhaR] || 0) + sacos;
        var esp = String(op.produto || '').trim();
        if (esp) {
          pp.det[esp] = pp.det[esp] || { total: 0, porLinha: {} };
          pp.det[esp].total += sacos;
          pp.det[esp].porLinha[linhaR] = (pp.det[esp].porLinha[linhaR] || 0) + sacos;
        }
        pl.sacos += sacos;
        if (r.data) {
          porDia[r.data] = porDia[r.data] || 0;
          porDia[r.data] += sacos;
        }
      });
    });
    return { porProduto: porProduto, porLinha: porLinha, porDia: porDia };
  }

  /* ================================================================
     CONCILIAÇÃO Planejado × Realizado — o coração do módulo.
     União das chaves (plano ∪ realizado). Nunca buraco:
     • produzido sem plano   → status 'nao_planejado'
     • planejado sem produção→ status 'nao_realizado'
     • produção em outra linha NÃO é erro: soma no produto e marca
       desvioLinha=true com o detalhamento por linha.
  ================================================================ */
  function conciliar(planoPorProduto, realPorProduto, nomeLinhaDe, realCarregado) {
    var planoPorNorm = {};
    Object.keys(planoPorProduto || {}).forEach(function (nome) {
      planoPorNorm[normNome(nome)] = { nome: nome, dados: planoPorProduto[nome] };
    });
    var chaves = {};
    Object.keys(planoPorNorm).forEach(function (k) { chaves[k] = true; });
    Object.keys(realPorProduto || {}).forEach(function (k) { chaves[k] = true; });

    var itens = Object.keys(chaves).map(function (k) {
      var p = planoPorNorm[k], r = (realPorProduto || {})[k];
      var nome = (p && p.nome) || (r && r.nome) || '—';
      var demanda = p ? (p.dados.demanda || 0) : 0;
      var planejado = p ? (p.dados.planejado || 0) : 0;
      var realizado = r ? (r.total || 0) : 0;

      /* linhas planejadas (por id → nome) e realizadas (por nome) */
      var linhasPlan = [];
      if (p) Object.keys(p.dados.linhas || {}).forEach(function (lid) {
        var q = p.dados.linhas[lid];
        if (q > 0) linhasPlan.push({ id: lid, nome: nomeLinhaDe ? nomeLinhaDe(lid) : String(lid), qtd: q });
      });
      var setPlanNorm = {};
      linhasPlan.forEach(function (l) { setPlanNorm[normNome(l.nome)] = true; });
      var linhasReal = [], qtdForaDeLinha = 0;
      if (r) Object.keys(r.porLinha || {}).forEach(function (ln) {
        var q = r.porLinha[ln];
        var fora = planejado > 0 && !setPlanNorm[normNome(ln)];
        if (fora) qtdForaDeLinha += q;
        linhasReal.push({ nome: ln, qtd: q, fora: fora });
      });
      var desvioLinha = planejado > 0 && realizado > 0 && qtdForaDeLinha > 0;

      var saldo = realizado - planejado;
      var atendimentoPct = planejado > 0 ? (realizado / planejado * 100) : null;

      var status;
      if (planejado <= 0 && realizado > 0) status = 'nao_planejado';
      else if (planejado > 0 && realizado <= 0) status = realCarregado === false ? 'carregando' : 'nao_realizado';
      else if (planejado <= 0 && realizado <= 0) status = 'vazio';
      else if (Math.abs(saldo) <= TOL_UN) status = 'atendido';
      else if (saldo < 0) status = 'parcial';
      else status = 'excedente';

      return {
        chave: k, nome: nome, demanda: demanda,
        planejado: planejado, realizado: realizado,
        saldo: saldo, atendimentoPct: atendimentoPct,
        status: status, desvioLinha: desvioLinha, qtdForaDeLinha: qtdForaDeLinha,
        linhasPlan: linhasPlan, linhasReal: linhasReal,
        det: r ? r.det : {},
      };
    }).filter(function (x) { return x.status !== 'vazio'; });

    itens.sort(function (a, b) { return a.nome.localeCompare(b.nome, 'pt'); });
    return itens;
  }

  /* Indicadores gerenciais derivados da conciliação (dinâmicos) */
  function indicadoresConciliacao(itens) {
    var r = {
      totalPlanejado: 0, totalRealizado: 0,
      realizadoDoPlanejado: 0,      // realizado de itens que tinham plano (p/ % atendimento)
      qtdForaDeLinha: 0,
      naoPlanejadoQtd: 0, naoPlanejadoN: 0,
      naoRealizadoQtd: 0, naoRealizadoN: 0,
      parciais: 0, excedentes: 0, atendidos: 0, comDesvioLinha: 0,
    };
    (itens || []).forEach(function (x) {
      r.totalPlanejado += x.planejado;
      r.totalRealizado += x.realizado;
      if (x.planejado > 0) r.realizadoDoPlanejado += x.realizado;
      r.qtdForaDeLinha += x.qtdForaDeLinha || 0;
      if (x.status === 'nao_planejado') { r.naoPlanejadoQtd += x.realizado; r.naoPlanejadoN++; }
      if (x.status === 'nao_realizado') { r.naoRealizadoQtd += x.planejado; r.naoRealizadoN++; }
      if (x.status === 'parcial') r.parciais++;
      if (x.status === 'excedente') r.excedentes++;
      if (x.status === 'atendido') r.atendidos++;
      if (x.desvioLinha) r.comDesvioLinha++;
    });
    r.atendimentoPct = r.totalPlanejado > 0 ? Math.min(r.realizadoDoPlanejado, r.totalPlanejado) / r.totalPlanejado * 100 : null;
    r.atendimentoBrutoPct = r.totalPlanejado > 0 ? r.realizadoDoPlanejado / r.totalPlanejado * 100 : null;
    r.pctForaDeLinha = r.totalRealizado > 0 ? r.qtdForaDeLinha / r.totalRealizado * 100 : null;
    return r;
  }

  /* ================================================================
     FAMÍLIAS (buckets) e GRUPOS de custo
  ================================================================ */
  function bucketSugerido(nome) {
    var k = normNome(nome);
    if (k.indexOf('granel') >= 0) return 'CAULIMGRANEL';
    if (k.indexOf('bag') >= 0) return 'CAULIMBB';
    if (k.indexOf('25') >= 0) return 'CAULIM25';
    if (k.indexOf('20kg') >= 0 || k.indexOf('linha20') >= 0) return 'L20';
    if (k.indexOf('concentrado') >= 0 || k.indexOf('10kg') >= 0) return 'CONC';
    return '';
  }

  /* grupo de custo de um item do motor (para decompor MP/EMB/PROD/IND) */
  function grupoDoInsumo(ins, especial) {
    if (especial === 'folha_mod') return 'PROD';
    if (especial === 'folha_admin') return 'IND';
    if (especial === 'lenha') return 'PROD';
    var c = String((ins && ins.classe) || '').toUpperCase();
    if (c.indexOf('MP') === 0) return 'MP';                                   // MP MINERAL / MP QUÍMICA
    if (c === 'EMBALAGEM' || c === 'PALLET' || c === 'MAT. CONSUMO') return 'EMB';
    if (c === 'LENHA' || c === 'ENERGIA' || c === 'COMBUSTIVEL' || c === 'COMBUSTÍVEL' ||
        c === 'MAT. MOINHO' || c === 'MANUTENÇÃO' || c === 'MANUTENCAO' || c === 'MAT.' || c === 'FOLHA') return 'PROD';
    return 'IND';                                                             // ADM, BENEFICIO, FRETE, ARREND., etc.
  }

  /* o ledger de insumos cobre este item? (evita dupla contagem no
     custo realizado: confirmado pelo ledger substitui o assumido) */
  function cobertoPorLedger(ins, especial) {
    if (especial === 'lenha') return true;                       // baixada pela RPC
    if (especial) return false;                                  // folhas
    if (ins && ins.tipoRateio === 'direto') return true;         // MP, embalagem, aditivo, pallet
    if (ins && ins.id === 'stretch') return true;                // plástico stretch (ficha)
    return false;
  }

  /* tipo do insumo (tabela insumos.tipo) → grupo de custo */
  var TIPO_INSUMO_GRUPO = {
    MP_MINERAL: 'MP', MP_QUIMICA: 'MP',
    EMBALAGEM: 'EMB', PALLET: 'EMB', PLASTICO: 'EMB', COMPONENTE: 'EMB',
    LENHA: 'PROD', COMBUSTIVEL: 'PROD', MOINHO: 'PROD',
  };

  /* ================================================================
     MOTOR DE CUSTOS — mesmas réguas validadas do CP, sobre o modelo
     novo. Recebe TUDO por parâmetro (puro). Decompõe por bucket E por
     grupo (MP/EMB/PROD/IND).
     comp: {porProduto, porLinha} (do plano OU do realizado)
     cfg:  _plano.config (insumos, pesos, mapaProduto, fatorEncargos…)
     aux:  { folhaLinha:{lid:R$}, folhaModTotal, folhaAdmin,
             lenhaPorLinha:{lid:m3}, precoLenha, pesoDe(nome)→kg,
             bucketDe(nome)→bucket }
  ================================================================ */
  function computarCustos(comp, cfg, aux) {
    cfg = cfg || {};
    if (!cfg.insumos || !cfg.insumos.length) return null;

    var metas = {}, ton = {}, naoMapeados = [], tonLinha = {};
    Object.keys(comp.porProduto || {}).forEach(function (nome) {
      var p = comp.porProduto[nome];
      var b = aux.bucketDe(nome);
      if (!b || BUCKETS.indexOf(b) < 0) { if (p.planejado > 0) naoMapeados.push(nome); return; }
      var pesoKg = aux.pesoDe(nome);
      metas[b] = (metas[b] || 0) + p.planejado;
      ton[b] = (ton[b] || 0) + p.planejado * pesoKg / 1000;
      Object.keys(p.linhas || {}).forEach(function (lid) {
        tonLinha[lid] = tonLinha[lid] || {};
        tonLinha[lid][b] = (tonLinha[lid][b] || 0) + p.linhas[lid] * pesoKg / 1000;
      });
    });
    var tonTotal = BUCKETS.reduce(function (s, b) { return s + (ton[b] || 0); }, 0);
    var pctBucket = {};
    BUCKETS.forEach(function (b) { pctBucket[b] = tonTotal > 0 ? (ton[b] || 0) / tonTotal : 0; });

    /* lenha: m³ por linha × preço */
    var lenhaLinha = {}, lenhaTotal = 0, lenhaM3 = 0;
    Object.keys(aux.lenhaPorLinha || {}).forEach(function (lid) {
      var m3 = Number(aux.lenhaPorLinha[lid]) || 0;
      lenhaLinha[lid] = m3 * (Number(aux.precoLenha) || 0);
      lenhaTotal += lenhaLinha[lid]; lenhaM3 += m3;
    });

    function qtdDireto(ins) {
      switch (ins.formulaQtd) {
        case 'direta': return metas[ins.produtoBase] || 0;
        case 'manual': return Number(ins.quantidadeManual) || 0;
        case 'pallet': { var spp = Number(ins.sacosPorPallet) || 0; return spp > 0 ? (metas[ins.produtoBase] || 0) / spp : 0; }
        case 'mp_20': return ton.L20 || 0;
        case 'mp_10': return ton.CONC || 0;
        case 'mp_25': return ton.CAULIM25 || 0;
        case 'mp_caulim_total': return (ton.CAULIM25 || 0) + (ton.CAULIMBB || 0) + (ton.CAULIMGRANEL || 0);
        default: return 0;
      }
    }
    function modoCompart(ins) {
      return ins.modo || ((ins.quantidadeLivre !== null && ins.quantidadeLivre !== undefined && ins.quantidadeLivre !== '') ? 'qtdpreco' : (ins.classificacao === 'FIXO' ? 'mensal' : 'porton'));
    }

    /* ── réguas ESPECIAIS do CP (energia por grupos, stretch por pallet,
       refeição/EPI por pessoa, vale-alimentação % sobre folha, itens
       múltiplos) — sem elas o valor importado seria R$ 0 em silêncio. ── */
    var totalPalletsPlan = (cfg.insumos || []).filter(function (i) {
      return !i.removido && i.tipoRateio === 'direto' && i.formulaQtd === 'pallet';
    }).reduce(function (s, i) {
      var spp = Number(i.sacosPorPallet) || 0;
      return s + (spp > 0 ? (metas[i.produtoBase] || 0) / spp : 0);
    }, 0);
    function somaItensMultiplos(grupo) {
      var im = (cfg.itensMultiplos || {})[grupo] || [];
      return im.reduce(function (s, it) { return s + (Number(it.quantidade) || 0) * (Number(it.precoUnitario) || 0); }, 0);
    }
    var espSemDado = [];
    function valorEspecialExtra(id) {
      switch (id) {
        case 'energia': {
          var gs = (cfg.energia && cfg.energia.grupos) || [];
          if (!gs.length) return null;
          return gs.reduce(function (s, g) { return s + (Number(g.valor) || 0); }, 0);
        }
        case 'stretch': {
          if (!cfg.stretch) return null;
          return totalPalletsPlan * (Number(cfg.stretch.gramasPorPallet) || 0) * (Number(cfg.stretch.precoPorGrama) || 0);
        }
        case 'refeicao': {
          if (!cfg.refeicao || !(Number(cfg.refeicao.valorPorMarmita) > 0)) return null;
          var dias = Number(cfg.refeicao.diasPorMes) || aux.diasTrabalho || 0;
          return (Number(cfg.refeicao.valorPorMarmita) || 0) * dias * (aux.headcount || 0);
        }
        case 'valealim': {
          if (!cfg.cartaoAlimentacao) return null;
          return ((aux.folhaModTotal || 0) + (aux.folhaAdmin || 0)) * ((Number(cfg.cartaoAlimentacao.percentualSobreSalario) || 0) / 100);
        }
        case 'epi': { var v = somaItensMultiplos('epi'); return v > 0 ? v : null; }
        case 'adm_geral': { var v2 = somaItensMultiplos('adm_geral'); return v2 > 0 ? v2 : null; }
        case 'matconsumo': { var v3 = somaItensMultiplos('limpeza'); return v3 > 0 ? v3 : null; }
        case 'arrend': {
          var ag = (cfg.arrendamento && cfg.arrendamento.grupos) || [];
          if (!ag.length) return null;
          return ag.reduce(function (s, g) { return s + (Number(g.valor) || 0); }, 0);
        }
        case 'filtromanga': {
          /* precisa da quantidade de filtros por linha, que não existe no
             modelo do plano — deixado visível como "sem dado", nunca some */
          if (cfg.filtroManga && Number(cfg.filtroManga.precoUnitario) > 0) espSemDado.push('Filtro de manga: sem quantidade de filtros no plano (informe via valor mensal ou qtd × preço na régua do item)');
          return null;
        }
        default: return null;
      }
    }
    /* o valor digitado pelo usuário na régua do item VENCE a régua especial */
    function temValorProprio(ins) {
      if (ins.modo === 'mensal') return Number(ins.valorMensal) > 0;
      if (ins.modo === 'qtdpreco') return true;
      if (ins.modo === 'porton') return Number(ins.custoPorTon) > 0;
      return (ins.quantidadeLivre !== null && ins.quantidadeLivre !== undefined && ins.quantidadeLivre !== '') ||
             Number(ins.valorMensal) > 0 || Number(ins.custoPorTon) > 0;
    }

    var itens = [], totalBucket = {}, varBucket = {}, diretoBucket = {}, grupoBucket = {};
    BUCKETS.forEach(function (b) { totalBucket[b] = 0; varBucket[b] = 0; diretoBucket[b] = 0; });
    GRUPOS_CUSTO.forEach(function (g) { grupoBucket[g] = {}; BUCKETS.forEach(function (b) { grupoBucket[g][b] = 0; }); });
    var compartGenerico = 0;

    (cfg.insumos || []).filter(function (i) { return !i.removido; }).forEach(function (ins) {
      var especial = ins.id === 'folha_mod' ? 'folha_mod' : ins.id === 'folha_admin' ? 'folha_admin' : ins.id === 'lenha' ? 'lenha' : null;
      var extra = (!especial && ins.tipoRateio !== 'direto' && !temValorProprio(ins)) ? valorEspecialExtra(ins.id) : null;
      var regua = extra !== null;
      var qtd = null, valor = 0, porB = {};
      if (especial === 'folha_mod') valor = aux.folhaModTotal || 0;
      else if (especial === 'folha_admin') valor = aux.folhaAdmin || 0;
      else if (especial === 'lenha') { valor = lenhaTotal; qtd = lenhaM3; }
      else if (regua) { valor = extra; }
      else if (ins.tipoRateio === 'direto') {
        qtd = qtdDireto(ins);
        valor = qtd * (Number(ins.precoUnitario) || 0);
      } else {
        var modo = modoCompart(ins);
        if (modo === 'qtdpreco') { qtd = Number(ins.quantidadeLivre) || 0; valor = qtd * (Number(ins.precoUnitario) || 0); }
        else if (modo === 'mensal') valor = Number(ins.valorMensal) || 0;
        else valor = (Number(ins.custoPorTon) || 0) * tonTotal;
      }
      var temPct = ins.pctManual && BUCKETS.some(function (b) { return Number(ins.pctManual[b]) > 0; });
      if (ins.tipoRateio === 'direto' && !especial && !temPct) {
        if (ins.produtoBase === 'CAULIM_TOTAL') {
          var tC = (ton.CAULIM25 || 0) + (ton.CAULIMBB || 0) + (ton.CAULIMGRANEL || 0);
          ['CAULIM25', 'CAULIMBB', 'CAULIMGRANEL'].forEach(function (b) {
            porB[b] = tC > 0 ? valor * (ton[b] || 0) / tC : 0; diretoBucket[b] += porB[b];
          });
        } else if (BUCKETS.indexOf(ins.produtoBase) >= 0) { porB[ins.produtoBase] = valor; diretoBucket[ins.produtoBase] += valor; }
      } else if (temPct) {
        BUCKETS.forEach(function (b) { porB[b] = valor * (Number(ins.pctManual[b]) || 0) / 100; });
        if (ins.tipoRateio === 'direto' && !especial) BUCKETS.forEach(function (b) { diretoBucket[b] += (porB[b] || 0); });
      } else {
        BUCKETS.forEach(function (b) { porB[b] = valor * pctBucket[b]; });
      }
      var classif = especial ? 'VARIAVEL' : (ins.classificacao || 'VARIAVEL');
      var grupo = grupoDoInsumo(ins, especial);
      BUCKETS.forEach(function (b) {
        totalBucket[b] += (porB[b] || 0);
        if (classif !== 'FIXO') varBucket[b] += (porB[b] || 0);
        grupoBucket[grupo][b] += (porB[b] || 0);
      });
      itens.push({ ins: ins, qtd: qtd, valor: valor, porB: porB, especial: especial, regua: regua, grupo: grupo, coberto: cobertoPorLedger(ins, especial) });
    });

    compartGenerico = itens.filter(function (x) { return !(x.ins.tipoRateio === 'direto' && !x.especial) && x.especial !== 'folha_mod' && x.especial !== 'lenha'; })
      .reduce(function (s, x) { return s + x.valor; }, 0);
    var totalGeral = BUCKETS.reduce(function (s, b) { return s + totalBucket[b]; }, 0);

    /* por linha física: folha própria + lenha própria + fatia dos
       compartilhados (ton) + diretos (proporção da linha no bucket) */
    var linhas = {};
    var lids = {};
    Object.keys(tonLinha).forEach(function (k) { lids[k] = 1; });
    Object.keys(aux.folhaLinha || {}).forEach(function (k) { lids[k] = 1; });
    Object.keys(lenhaLinha).forEach(function (k) { lids[k] = 1; });
    Object.keys(lids).forEach(function (lid) {
      var tl = tonLinha[lid] || {};
      var tonL = BUCKETS.reduce(function (s, b) { return s + (tl[b] || 0); }, 0);
      var diretos = BUCKETS.reduce(function (s, b) { return s + ((ton[b] || 0) > 0 ? (diretoBucket[b] || 0) * ((tl[b] || 0) / (ton[b] || 1)) : 0); }, 0);
      var compart = tonTotal > 0 ? compartGenerico * (tonL / tonTotal) : 0;
      var folha = (aux.folhaLinha || {})[lid] || 0, lenha = lenhaLinha[lid] || 0;
      var total = folha + lenha + compart + diretos;
      linhas[lid] = { folha: folha, lenha: lenha, compart: compart, diretos: diretos, total: total, ton: tonL, custoTon: tonL > 0 ? total / tonL : null };
    });

    return {
      metas: metas, ton: ton, tonTotal: tonTotal, pctBucket: pctBucket, naoMapeados: naoMapeados,
      itens: itens, totalBucket: totalBucket, varBucket: varBucket, grupoBucket: grupoBucket,
      totalGeral: totalGeral, folhaModTotal: aux.folhaModTotal || 0, folhaAdmin: aux.folhaAdmin || 0,
      lenhaTotal: lenhaTotal, linhas: linhas, espSemDado: espSemDado, totalPallets: totalPalletsPlan,
      custoTonGeral: tonTotal > 0 ? totalGeral / tonTotal : null,
    };
  }

  /* ================================================================
     LEDGER DE INSUMOS — consumo REAL valorizado (insumos_movimentos,
     tipo='consumo'). Retorna decomposição por bucket e grupo + a
     parte não atribuível (visível, nunca escondida).
     movs: [{insumo_id,data,quantidade,qtd_teorica,custo_unitario,produto,origem,origem_id}]
     insumoTipoDe: id → insumos.tipo ('MP_MINERAL'…)
     linhaProdutoDe: nomeProdutoEspecifico → nome da linha de produto (das OPs do mês)
     bucketDe: nomeLinhaProduto → bucket
  ================================================================ */
  function computarLedger(movs, insumoTipoDe, linhaProdutoDe, bucketDe) {
    var porBucket = {}, semAtrib = { total: 0, itens: [] }, total = 0;
    var porGrupoGeral = {}; GRUPOS_CUSTO.forEach(function (g) { porGrupoGeral[g] = 0; });
    BUCKETS.forEach(function (b) {
      porBucket[b] = { total: 0, grupos: {} };
      GRUPOS_CUSTO.forEach(function (g) { porBucket[b].grupos[g] = 0; });
    });
    var variacao = { qtdRealMenosTeorica: 0, valor: 0 };
    var nMovs = 0;

    (movs || []).forEach(function (m) {
      var q = Number(m.quantidade) || 0;
      var cu = Number(m.custo_unitario) || 0;
      var v = q * cu;
      if (!v && !q) return;
      nMovs++;
      total += v;
      var tipo = insumoTipoDe(m.insumo_id) || '';
      var grupo = TIPO_INSUMO_GRUPO[tipo] || 'IND';
      porGrupoGeral[grupo] += v;
      var qt = Number(m.qtd_teorica);
      if (!isNaN(qt) && qt > 0) {
        variacao.qtdRealMenosTeorica += (q - qt);
        variacao.valor += (q - qt) * cu;
      }
      var bucket = '';
      if (m.produto) {
        var lp = linhaProdutoDe(m.produto);
        bucket = lp ? bucketDe(lp) : (bucketDe(m.produto) || bucketSugerido(m.produto));
      }
      if (bucket && BUCKETS.indexOf(bucket) >= 0) {
        porBucket[bucket].total += v;
        porBucket[bucket].grupos[grupo] += v;
      } else {
        semAtrib.total += v;
        semAtrib.itens.push({ produto: m.produto || null, tipo: tipo, valor: v, origem_id: m.origem_id || null });
      }
    });
    return { porBucket: porBucket, porGrupoGeral: porGrupoGeral, semAtrib: semAtrib, total: total, variacao: variacao, nMovs: nMovs };
  }

  /* rateia a parte não atribuível do ledger pela tonelagem real (marcada) */
  function ratearSemAtrib(ledger, tonPorBucket, tonTotal) {
    var r = {};
    BUCKETS.forEach(function (b) {
      r[b] = tonTotal > 0 ? ledger.semAtrib.total * ((tonPorBucket[b] || 0) / tonTotal) : 0;
    });
    return r;
  }

  /* ================================================================
     CUSTO REALIZADO consolidado por bucket =
       confirmado (ledger) + assumido (itens do motor NÃO cobertos
       pelo ledger, com quantidades reais) — sem dupla contagem.
     ccReal: resultado de computarCustos(compDoRealizado, …)
     Retorna null quando não há dado suficiente.
  ================================================================ */
  function custoRealizado(ccReal, ledger, temOps) {
    if (!temOps && (!ledger || ledger.nMovs === 0)) return null;   // dado insuficiente
    var confirmado = {}, assumido = {}, totalB = {};
    var rateado = ledger ? ratearSemAtrib(ledger, (ccReal && ccReal.ton) || {}, (ccReal && ccReal.tonTotal) || 0) : {};
    BUCKETS.forEach(function (b) {
      confirmado[b] = ledger ? (ledger.porBucket[b].total + (rateado[b] || 0)) : 0;
      assumido[b] = 0;
    });
    if (ccReal) {
      ccReal.itens.forEach(function (x) {
        if (x.coberto) return;                       // ledger substitui
        BUCKETS.forEach(function (b) { assumido[b] += (x.porB[b] || 0); });
      });
    }
    var totalGeral = 0, confTotal = 0, assumTotal = 0;
    BUCKETS.forEach(function (b) {
      totalB[b] = confirmado[b] + assumido[b];
      totalGeral += totalB[b]; confTotal += confirmado[b]; assumTotal += assumido[b];
    });
    return {
      confirmado: confirmado, assumido: assumido, porBucket: totalB,
      totalGeral: totalGeral, confirmadoTotal: confTotal, assumidoTotal: assumTotal,
      semAtribRateado: rateado, ledgerVazio: !ledger || ledger.nMovs === 0,
    };
  }

  /* ================================================================
     AJUSTES MANUAIS — trilha de auditoria. O valor automático NUNCA
     é apagado: ajuste é uma linha nova; anular é outra linha.
  ================================================================ */
  function somaAjustes(lista, escopo) {
    return (lista || []).filter(function (a) {
      return !a.anulado && (escopo ? a.escopo === escopo : true);
    }).reduce(function (s, a) { return s + (Number(a.valor) || 0); }, 0);
  }
  function aplicarAjustes(custoReal, lista) {
    if (!custoReal) return null;
    var porBucket = {}, totalAj = 0;
    BUCKETS.forEach(function (b) {
      var aj = somaAjustes(lista, b);
      porBucket[b] = custoReal.porBucket[b] + aj;
      totalAj += aj;
    });
    var ajGeral = somaAjustes(lista, 'GERAL');
    totalAj += ajGeral;
    return {
      porBucket: porBucket, ajusteGeral: ajGeral, ajusteTotal: totalAj,
      totalGeral: custoReal.totalGeral + totalAj,
    };
  }

  /* ================================================================
     ALVO — teto de custo produtivo ÷ faturamento (padrão 38%)
  ================================================================ */
  function calcularAlvo(custo, faturamento, alvoPct) {
    var alvo = (Number(alvoPct) || 0) / 100;
    if (!(faturamento > 0)) return { pct: null, dentro: null, custoMax: null, excesso: null, folga: null, alvoPct: alvoPct };
    var pct = custo / faturamento;
    var custoMax = faturamento * alvo;
    return {
      pct: pct, dentro: pct <= alvo, custoMax: custoMax,
      excesso: Math.max(0, custo - custoMax),           // R$ acima do teto (economia necessária)
      folga: Math.max(0, custoMax - custo),             // R$ de folga até o teto
      faturamentoNecessario: alvo > 0 ? custo / alvo : null,
      alvoPct: alvoPct,
    };
  }

  /* ================================================================
     VALIDAÇÕES — conferência matemática (nunca esconder falha)
  ================================================================ */
  function validar(cc, concilia, ind) {
    var problemas = [];
    if (cc) {
      var somaB = BUCKETS.reduce(function (s, b) { return s + cc.totalBucket[b]; }, 0);
      if (Math.abs(somaB - cc.totalGeral) > TOL_RS)
        problemas.push('Soma dos custos por família (' + somaB.toFixed(2) + ') difere do total geral (' + cc.totalGeral.toFixed(2) + ')');
      var somaG = 0;
      GRUPOS_CUSTO.forEach(function (g) { BUCKETS.forEach(function (b) { somaG += cc.grupoBucket[g][b]; }); });
      if (Math.abs(somaG - cc.totalGeral) > TOL_RS)
        problemas.push('Soma dos grupos MP/EMB/PROD/IND (' + somaG.toFixed(2) + ') difere do total geral (' + cc.totalGeral.toFixed(2) + ')');
      var somaL = Object.keys(cc.linhas).reduce(function (s, k) { return s + cc.linhas[k].total; }, 0);
      if (Math.abs(somaL - cc.totalGeral) > TOL_RS)
        problemas.push('Soma do custo por linha (' + somaL.toFixed(2) + ') difere do total geral (' + cc.totalGeral.toFixed(2) + ') — verifique linhas sem tonelagem');
    }
    if (concilia && ind) {
      var somaPlan = 0, somaReal = 0;
      concilia.forEach(function (x) { somaPlan += x.planejado; somaReal += x.realizado; });
      if (Math.abs(somaPlan - ind.totalPlanejado) > TOL_UN) problemas.push('Total planejado da conciliação não confere');
      if (Math.abs(somaReal - ind.totalRealizado) > TOL_UN) problemas.push('Total realizado da conciliação não confere');
      concilia.forEach(function (x) {
        var somaLinhasReal = x.linhasReal.reduce(function (s, l) { return s + l.qtd; }, 0);
        if (x.realizado > 0 && Math.abs(somaLinhasReal - x.realizado) > TOL_UN)
          problemas.push('Detalhe por linha de "' + x.nome + '" (' + somaLinhasReal + ') difere do total realizado (' + x.realizado + ')');
      });
    }
    return problemas;
  }

  return {
    DIAS_SEMANA: DIAS_SEMANA, BUCKETS: BUCKETS, BUCKET_LABEL: BUCKET_LABEL,
    GRUPOS_CUSTO: GRUPOS_CUSTO, GRUPO_LABEL: GRUPO_LABEL,
    TOL_RS: TOL_RS, TOL_UN: TOL_UN, TIPO_INSUMO_GRUPO: TIPO_INSUMO_GRUPO,
    normNome: normNome, calcMinutos: calcMinutos,
    getFeriadosNacionais: getFeriadosNacionais, gerarCalendarioMes: gerarCalendarioMes,
    calcHorasSecao: calcHorasSecao, distribuirHorasProdutos: distribuirHorasProdutos,
    gruposDoPlano: gruposDoPlano, computarPlano: computarPlano,
    computarRealizado: computarRealizado, conciliar: conciliar,
    indicadoresConciliacao: indicadoresConciliacao,
    bucketSugerido: bucketSugerido, grupoDoInsumo: grupoDoInsumo, cobertoPorLedger: cobertoPorLedger,
    computarCustos: computarCustos, computarLedger: computarLedger, ratearSemAtrib: ratearSemAtrib,
    custoRealizado: custoRealizado, somaAjustes: somaAjustes, aplicarAjustes: aplicarAjustes,
    calcularAlvo: calcularAlvo, validar: validar,
  };
});
