// ============================================================
// ERP INDUSTRIAL — PLANO-CAPACIDADE.JS
// Ponte entre o "Planejamento & Custos" (custo-precificacao.html,
// tabela `planejamentos_custo`) e os módulos que só precisam da
// CAPACIDADE do mês: produção e dashboard.
//
// Antes existia uma tabela `planejamentos` separada, alimentada por um
// planejamento.html próprio. Eram DOIS planejamentos vivos ao mesmo tempo,
// e nada garantia que falavam a mesma coisa. Agora existe um só: a aba
// Capacidade de cada planejamento de custo.
//
// Este arquivo devolve o MESMO formato que a tabela antiga entregava
// (`secoes: [{linha, dispH, horasBrutas, diasTrabalho, produtos:[{nome,capHora}]}]`),
// para os consumidores não precisarem ser reescritos.
// ============================================================

(function (raiz) {
  'use strict';

  var DIAS_SEMANA = ['Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado'];

  // "07:20" → minutos. Vira o dia quando o turno atravessa a meia-noite.
  function calcMinutos(inicio, fim) {
    if (!inicio || !fim) return 0;
    var a = String(inicio).split(':'), b = String(fim).split(':');
    var mins = (Number(b[0]) * 60 + Number(b[1])) - (Number(a[0]) * 60 + Number(a[1]));
    if (mins < 0) mins += 1440;
    return mins;
  }

  /* Horas de UMA seção (uma linha rodando em um turno).
     bruto → (− refeição, + extras) → perda por eficiência → líquido → (− paradas) → disponível
     É a mesma conta da aba Capacidade; se um dia ela mudar lá, muda aqui. */
  function calcHorasSecao(calendarioMes, turno, eficienciaPct, extrasPorDia, paradasHoras, horasDomingoEspecial) {
    var refM = Number(turno && (turno.refeicao_min || turno.refeicaoMin)) || 0;
    var extrasMins = Math.round((extrasPorDia || 0) * 60);
    var minsBrutos = 0, diasTrabalho = 0;
    Object.keys(calendarioMes || {}).forEach(function (dateKey) {
      var estado = calendarioMes[dateKey];
      if (estado !== 'trabalha' && estado !== 'domingo-especial') return;
      diasTrabalho++;
      if (estado === 'domingo-especial') {
        minsBrutos += Math.round((horasDomingoEspecial || 0) * 60) + extrasMins;
        return;
      }
      var dow = new Date(dateKey + 'T12:00:00').getDay();
      var diaInfo = ((turno && turno.calendario) || {})[DIAS_SEMANA[dow]];
      var mDia = 0;
      if (diaInfo && diaInfo.ativo !== false && diaInfo.inicio && diaInfo.fim) {
        mDia = Math.max(0, calcMinutos(diaInfo.inicio, diaInfo.fim) - refM);
      }
      if (mDia > 0) minsBrutos += mDia + extrasMins;
    });
    var paradasMins = Math.round((paradasHoras || 0) * 60);
    var perdaMins = Math.round(minsBrutos * (100 - eficienciaPct) / 100);
    var liquidoMins = minsBrutos - perdaMins;
    var dispMins = Math.max(0, liquidoMins - paradasMins);
    return {
      diasTrabalho: diasTrabalho,
      horasBrutas: minsBrutos / 60,
      dispH: dispMins / 60,
    };
  }

  /* Converte o estado salvo de um planejamento de custo no formato antigo.
     UMA entrada por LINHA, somando os turnos: se a linha roda dois turnos, a
     capacidade do mês é a soma dos dois. (A tabela antiga gravava uma entrada
     por turno e os consumidores ficavam só com a última — subestimava a linha.) */
  function secoesDoEstado(estado, turnos) {
    var e = estado || {};
    var porNome = {};
    (turnos || []).forEach(function (t) { porNome[t.nome] = t; });
    var acc = {};
    (e.blocos || []).forEach(function (bloco) {
      var linha = bloco.linhaNome || '(sem nome)';
      acc[linha] = acc[linha] || { linha: linha, dispH: 0, horasBrutas: 0, diasTrabalho: 0, produtos: [] };
      var vistos = {};
      (bloco.secoes || []).forEach(function (sec) {
        var paradas = (sec.paradas || []).reduce(function (s, p) { return s + (Number(p.horas) || 0); }, 0);
        var h = calcHorasSecao(e.calendario, porNome[sec.turnoNome], Number(sec.eficiencia) || 0,
                               Number(sec.extras) || 0, paradas, Number(e.horasDomingoEspecial) || 0);
        acc[linha].dispH += h.dispH;
        acc[linha].horasBrutas += h.horasBrutas;
        acc[linha].diasTrabalho = Math.max(acc[linha].diasTrabalho, h.diasTrabalho);
        (sec.produtos || []).forEach(function (p) {
          if (p.ativo === false) return;                 // produto desligado não é capacidade
          var cap = Number(p.capHora) || 0;
          if (!cap || vistos[p.nome]) return;
          vistos[p.nome] = true;
          acc[linha].produtos.push({ nome: p.nome, capHora: cap, unidade: p.unidade || '' });
        });
      });
    });
    return Object.keys(acc).map(function (k) { return acc[k]; })
      .filter(function (s) { return s.horasBrutas > 0 || s.produtos.length; });
  }

  /* Escolhe o planejamento que vale para o mês. Podem existir vários (cenários):
     ignoro os da lixeira e fico com o mais recente que TENHA linha configurada —
     um cenário vazio não deve apagar a capacidade do mês. Devolvo qual foi usado
     para a tela poder dizer de onde veio o número. */
  function escolherPlano(linhas) {
    var vivos = (linhas || []).filter(function (p) { return p.status !== 'excluido'; });
    var comLinha = vivos.filter(function (p) {
      return ((p.estado || {}).blocos || []).length > 0;
    });
    return (comLinha[0] || vivos[0] || null);
  }

  var cache = {};

  /* mesAno: 'AAAA-MM' (mesmo formato que os módulos já usam).
     Devolve { secoes, plano, erro } — `secoes` sempre é array. */
  async function capacidadeDoMes(mesAno, forcar) {
    var chave = String(mesAno || '');
    if (!forcar && cache[chave]) return cache[chave];
    var vazio = { secoes: [], plano: null, erro: null };
    if (!chave || typeof _supabase === 'undefined' || !_supabase) return vazio;
    var partes = chave.split('-');
    var ano = Number(partes[0]), mes = Number(partes[1]);
    if (!ano || !mes) return vazio;
    try {
      var r = await Promise.all([
        _supabase.from('planejamentos_custo')
          .select('id,codigo,nome,mes,ano,status,estado,atualizado_em')
          .eq('mes', mes).eq('ano', ano).order('atualizado_em', { ascending: false }),
        _supabase.from('turnos').select('id,nome,refeicao_min,calendario,status'),
      ]);
      var planos = r[0], turnos = r[1];
      if (planos.error) throw planos.error;
      var plano = escolherPlano(planos.data);
      var res = {
        secoes: plano ? secoesDoEstado(plano.estado, (turnos && turnos.data) || []) : [],
        plano: plano ? { id: plano.id, codigo: plano.codigo, nome: plano.nome } : null,
        erro: null,
      };
      cache[chave] = res;
      return res;
    } catch (err) {
      console.error('[plano-capacidade] ' + chave + ':', err);
      return { secoes: [], plano: null, erro: (err && err.message) || String(err) };
    }
  }

  /* Atalho no formato EXATO que a tabela antiga devolvia, para trocar
     `from('planejamentos').select('secoes,mes')` por uma linha só. */
  async function planosDoMes(mesAno, forcar) {
    var r = await capacidadeDoMes(mesAno, forcar);
    return r.secoes.length ? [{ mes: mesAno, secoes: r.secoes, _plano: r.plano }] : [];
  }

  raiz.PlanoCapacidade = {
    capacidadeDoMes: capacidadeDoMes,
    planosDoMes: planosDoMes,
    secoesDoEstado: secoesDoEstado,
    calcHorasSecao: calcHorasSecao,
    escolherPlano: escolherPlano,
    limparCache: function () { cache = {}; },
  };
})(typeof window !== 'undefined' ? window : globalThis);
