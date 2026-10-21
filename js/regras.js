/* js/regras.js — FONTE ÚNICA das regras de cálculo do ERP.
 *
 * Regra de ouro: cada função aqui é PURA — mesma entrada, mesma saída, sem tocar
 * no DOM nem no banco. Nada de valor "chutado": se falta dado para calcular, a
 * função devolve null e QUEM CHAMA decide como mostrar o aviso (protocolo #7:
 * não esconder falha). Assim o mesmo número sai igual em todo módulo.
 *
 * Sem build, sem import. Carregue com <script src="js/regras.js"></script>
 * ANTES do <script> do módulo (depois de utils.js).
 *
 * Item 3 — piloto: TONELAGEM (sacos/unidades → toneladas).
 */
(function (global) {
  'use strict';

  var Regras = {};

  /* ── TONELAGEM ─────────────────────────────────────────────────────────────
   * Converte uma quantidade de unidades em toneladas, dado o peso de UMA unidade
   * em kg. Universal — o peso por unidade (cadastrado em produtos.peso_unidade_kg)
   * absorve a diferença entre embalagens:
   *   Regras.toneladas(100, 10)   -> 1    (100 sacos de 10 kg)
   *   Regras.toneladas(100, 20)   -> 2    (100 sacos de 20 kg)
   *   Regras.toneladas(5,  1000)  -> 5    (5 Big Bags de 1000 kg)
   *   Regras.toneladas(14, 1000)  -> 14   (14 t de granel, contado por tonelada)
   */
  Regras.toneladas = function (quantidade, pesoUnidadeKg) {
    var q = Number(quantidade) || 0;
    var p = Number(pesoUnidadeKg) || 0;
    return q * p / 1000;
  };

  /* ── NOME DE PRODUTO ───────────────────────────────────────────────────────
   * Normaliza para comparar: sem acento, sem caixa, sem espaço, sem pontuação.
   * "Liga Concentrado 10kg" e "liga concentrado 10 kg" viram a mesma chave.
   */
  Regras.normalizarNome = function (s) {
    return (s == null ? '' : String(s))
      .toLowerCase()
      .normalize('NFD').replace(/[̀-ͯ]/g, '')
      .replace(/\s+/g, '')
      .replace(/[^a-z0-9]/g, '');
  };

  /* Acha o peso_unidade_kg de um produto pelo NOME, na lista do cadastro
   * (produtos.html). Casamento por nome normalizado (exato). Devolve o peso em kg
   * (> 0) ou NULL quando: nome não bate com nenhum produto, ou o produto existe
   * mas está sem peso cadastrado. NUNCA chuta um peso — null é sinal para o
   * módulo avisar que falta cadastro.
   */
  Regras.pesoUnidadeKg = function (nomeProduto, produtos) {
    var alvo = Regras.normalizarNome(nomeProduto);
    if (!alvo || !Array.isArray(produtos)) return null;
    for (var i = 0; i < produtos.length; i++) {
      if (Regras.normalizarNome(produtos[i] && produtos[i].nome) === alvo) {
        var peso = Number(produtos[i].peso_unidade_kg);
        return peso > 0 ? peso : null;
      }
    }
    return null;
  };

  /* ── PALLET ────────────────────────────────────────────────────────────────
   * itens: lista pura de {cap, qtd} — cap = capacidade do pallet (sacos por pallet),
   * qtd = nº de pallets daquela capacidade. NÃO lê DOM: quem chama monta a lista.
   */

  // Sacos dos pallets CHEIOS: Σ(cap × qtd).
  Regras.sacosDePallets = function (itens) {
    if (!Array.isArray(itens)) return 0;
    var s = 0;
    for (var i = 0; i < itens.length; i++) {
      var cap = Number(itens[i] && itens[i].cap) || 0;
      var qtd = Number(itens[i] && itens[i].qtd) || 0;
      s += cap * qtd;
    }
    return s;
  };

  // Total de sacos produzidos = pallets cheios + sobra (a sobra é produção).
  Regras.totalSacos = function (itens, sobra) {
    return Regras.sacosDePallets(itens) + (Number(sobra) || 0);
  };

  // Pallets cheios físicos = Σ(qtd).
  Regras.palletsCheios = function (itens) {
    if (!Array.isArray(itens)) return 0;
    var s = 0;
    for (var i = 0; i < itens.length; i++) s += Number(itens[i] && itens[i].qtd) || 0;
    return s;
  };

  // Pallets físicos = cheios + 1 se a sobra ocupa um pallet (pallet parcial).
  Regras.palletsFisicos = function (itens, sobra, sobraOcupa) {
    var s = Number(sobra) || 0;
    return Regras.palletsCheios(itens) + (s > 0 && sobraOcupa ? 1 : 0);
  };

  /* ── EFICIÊNCIA DE PRODUÇÃO (realizado) ──────────────────────────────────────
   * ATENÇÃO: existe OUTRA "eficiência" no sistema — o FATOR DE PLANEJAMENTO do
   * planejamento.html (um %, default 100, que o planejador ajusta para descontar
   * horas: perda = brutos × (100−efic)/100). Aquilo é ENTRADA de planejamento,
   * não medição, e NÃO deve ser unificado com isto. Isto aqui é o REALIZADO:
   * quanto se produziu contra a meta.
   */

  // Meta de sacos = capacidade horária (sc/h) × horas. 0 se faltar qualquer um.
  Regras.metaSacos = function (capHora, horas) {
    return (Number(capHora) || 0) * (Number(horas) || 0);
  };

  // Eficiência de produção (%) = sacos realizados ÷ meta × 100. 0 se meta ≤ 0.
  // Devolve o número cru (sem arredondar) — quem chama formata/arredonda.
  Regras.eficienciaProducao = function (sacosReal, metaSacos) {
    var meta = Number(metaSacos) || 0;
    if (meta <= 0) return 0;
    return (Number(sacosReal) || 0) / meta * 100;
  };

  // Disponibilidade (%) = horas trabalhadas ÷ (horas trabalhadas + horas paradas) × 100.
  // H.T vem do horímetro (+ parada produtiva) e H.P são as paradas: a máquina parada
  // NÃO roda o horímetro, então H.P fica FORA de H.T (H.T + H.P = tempo do turno).
  // A conta antiga, (H.T − H.P) ÷ H.T, tratava H.P como parte de H.T e dava número
  // negativo quando o turno parou mais do que rodou (ex.: 6,7h rodando, 18,3h paradas → −172%).
  // 0 se não houver horas. NÃO confundir com a disponibilidade do OEE (base: planejamento).
  Regras.disponibilidade = function (htTrabalhada, htParada) {
    var ht = Number(htTrabalhada) || 0;
    var hp = Number(htParada) || 0;
    if (ht + hp <= 0) return 0;
    return ht / (ht + hp) * 100;
  };

  /* ── LENHA (recebimento e descarga) ─────────────────────────────────────────
   * Espelha, célula por célula, o documento "RECEBIMENTO E DESCARGA DE LENHA"
   * que a fábrica preenchia na planilha:
   *   LIQUIDO        = BRUTO − TARA                          (C15 = C13−C14)
   *   MÉDIA (altura) = média de TODAS as medidas dos 2 lados (J17 = AVERAGE(C17:H18))
   *   VOLUME (m³)    = MÉDIA × LARGURA × COMPRIMENTO         (I21 = J17*C19*C20)
   *   MÉDIA EM Kg/m³ = LIQUIDO ÷ VOLUME                      (C21 = C15/I21)
   *   Emitir nota de = TOTAL m³ × PREÇO do m³                (fechamento semanal)
   * Falta dado → devolve null e QUEM CHAMA avisa. Volume ou preço chutado aqui
   * viraria nota fiscal errada lá.
   */

  // Peso líquido. Sem clamp: bruto menor que tara devolve negativo de propósito,
  // para a tela poder gritar em vez de esconder um erro de balança.
  Regras.lenhaLiquido = function (bruto, tara) {
    var b = Number(bruto), t = Number(tara);
    if (!isFinite(b) || !isFinite(t)) return null;
    return b - t;
  };

  // Altura média da carga: uma média só, com as medidas dos DOIS lados juntas
  // (é o que a planilha faz). Ignora campo vazio; sem nenhuma medida, null.
  Regras.lenhaAlturaMedia = function (lado1, lado2) {
    var todas = [].concat(Array.isArray(lado1) ? lado1 : [], Array.isArray(lado2) ? lado2 : []);
    var soma = 0, n = 0;
    for (var i = 0; i < todas.length; i++) {
      var v = todas[i];
      if (v === null || v === undefined || v === '') continue;
      var x = Number(String(v).replace(',', '.'));
      if (!isFinite(x) || x <= 0) continue;
      soma += x; n++;
    }
    return n ? soma / n : null;
  };

  // Volume em m³. Precisa dos três; faltando um, null (não existe volume parcial).
  Regras.lenhaVolume = function (alturaMedia, largura, comprimento) {
    var a = Number(alturaMedia), l = Number(largura), c = Number(comprimento);
    if (!(a > 0) || !(l > 0) || !(c > 0)) return null;
    return a * l * c;
  };

  // Densidade da carga (Kg/m³) — é o número que denuncia carga molhada ou medição
  // torta. Carga de trator não passa na balança (bruto e tara zerados na
  // planilha): sem peso líquido, devolve null. A planilha mostrava "0 Kg/m³"
  // nesses casos — zero ali não é densidade zero, é "não pesado", e número
  // plausível-mas-falso é pior que um traço na tela.
  Regras.lenhaKgM3 = function (liquido, volume) {
    var q = Number(liquido), v = Number(volume);
    if (!(q > 0) || !(v > 0)) return null;
    return q / v;
  };

  // Valor a faturar no fechamento. Preço não cadastrado → null (nunca R$ 0).
  Regras.lenhaValor = function (totalM3, precoM3) {
    var m = Number(totalM3), p = Number(precoM3);
    if (!isFinite(m) || !isFinite(p) || p <= 0) return null;
    return m * p;
  };

  /* ── QUANTIDADE NA UNIDADE DO CADASTRO ─────────────────────────────────────
   * O apontamento de produção grava TUDO no campo `total_sacos` da OP. Para o
   * ensacado isso é saco e fecha. Para o GRANEL a OP lança a carga em QUILO
   * (3 × 14.000 kg + 2.100 = 44.100), mas o produto é cadastrado em TONELADA e
   * a média/h também (14 ton/h) — comparar 44.100 com 14 ton/h dava performance
   * de 45.867%. Converte pelo CADASTRO do produto (produtos.unidade), nunca
   * pelo nome: produto medido em unidade de massa com mais de 1 kg por unidade
   * tem o apontamento em kg.
   */
  Regras.UNIDADE_KG = { kg: 1, quilo: 1, quilos: 1, t: 1000, ton: 1000, tonelada: 1000, toneladas: 1000 };

  Regras.qtdNaUnidadeDoProduto = function (qtdApontada, unidadeProduto) {
    var q = Number(qtdApontada) || 0;
    var u = (unidadeProduto == null ? '' : String(unidadeProduto)).toLowerCase().trim();
    var kgPorUnidade = Regras.UNIDADE_KG[u] || 0;
    return kgPorUnidade > 1 ? q / kgPorUnidade : q;
  };

  // Unidade de um produto pelo NOME, na lista do cadastro. '' se não achar.
  Regras.unidadeDoProduto = function (nomeProduto, produtos) {
    var alvo = Regras.normalizarNome(nomeProduto);
    if (!alvo || !Array.isArray(produtos)) return '';
    for (var i = 0; i < produtos.length; i++) {
      if (Regras.normalizarNome(produtos[i] && produtos[i].nome) === alvo) {
        return String((produtos[i].unidade || '')).trim();
      }
    }
    return '';
  };

  /* ── CAPACIDADE HORÁRIA (média sc/h) ───────────────────────────────────────
   * Acha a média/h de um produto entre as fontes de cadastro (planejamento
   * primeiro, cadastro da linha depois — a ordem é de quem chama).
   *
   * Casa por nome EXATO e, só se não achar, tenta aproximado — e aí exige
   * candidato ÚNICO. O casamento aproximado antigo comparava token a token sem
   * filtrar unidade de medida: "kg" fazia "Concentrado 10kg" casar com
   * "Impermeabilizante 10kg", e como o laço não parava no primeiro achado, o
   * ÚLTIMO vencia. A Linha 3 media concentrado contra 230 sc/h em vez de 500 e
   * a performance saía 185%.
   *
   * Devolve { capHora, nome, origem, chave, exato } ou NULL. Null = falta
   * cadastro: quem chama AVISA, em vez de herdar a média de outro produto.
   */
  Regras._TOKEN_RUIDO = { kg: 1, g: 1, gr: 1, mg: 1, ton: 1, t: 1, l: 1, ml: 1, un: 1,
                          sc: 1, pc: 1, de: 1, da: 1, do: 1, das: 1, dos: 1, e: 1,
                          com: 1, linha: 1 };

  Regras._tokensNome = function (s) {
    return Regras.normalizarNome(s).match(/[a-z]+|[0-9]+/g) || [];
  };

  // Parecidos = compartilham um token que IDENTIFICA produto: 3+ caracteres e
  // fora da lista de ruído (unidade, conectivo, "linha"). Número curto como
  // "10", "20", "25" não casa — é justamente o que diferencia os produtos.
  Regras.nomesParecidos = function (a, b) {
    if (Regras.normalizarNome(a) === Regras.normalizarNome(b)) return true;
    var ta = Regras._tokensNome(a), tb = Regras._tokensNome(b);
    for (var i = 0; i < ta.length; i++) {
      if (ta[i].length > 2 && !Regras._TOKEN_RUIDO[ta[i]] && tb.indexOf(ta[i]) >= 0) return true;
    }
    return false;
  };

  Regras.capacidadeHora = function (chaves, fontes) {
    if (!Array.isArray(fontes)) return null;
    var cands = [];
    for (var i = 0; i < fontes.length; i++) {
      if ((Number(fontes[i] && fontes[i].capHora) || 0) > 0) cands.push(fontes[i]);
    }
    if (!cands.length) return null;
    var lista = [];
    var brutas = Array.isArray(chaves) ? chaves : [chaves];
    for (var b = 0; b < brutas.length; b++) if (brutas[b]) lista.push(brutas[b]);

    var achar = function (c, chave, exato) {
      return { capHora: Number(c.capHora), nome: c.nome, origem: c.origem || '',
               chave: chave, exato: exato };
    };
    // 1) exato, na ordem das chaves (linha de produto antes do nome do produto)
    for (var k = 0; k < lista.length; k++) {
      var alvo = Regras.normalizarNome(lista[k]);
      for (var j = 0; j < cands.length; j++) {
        if (Regras.normalizarNome(cands[j].nome) === alvo) return achar(cands[j], lista[k], true);
      }
    }
    // 2) aproximado e SEM ambiguidade. Dois candidatos casando devolve null de
    //    propósito: escolher um dos dois é exatamente o que quebrou antes.
    for (var m = 0; m < lista.length; m++) {
      var achados = [];
      for (var n = 0; n < cands.length; n++) {
        if (Regras.nomesParecidos(cands[n].nome, lista[m])) achados.push(cands[n]);
      }
      if (achados.length === 1) return achar(achados[0], lista[m], false);
    }
    return null;
  };

  /* ── OEE ───────────────────────────────────────────────────────────────────
   * OEE = Disponibilidade × Performance × Qualidade.
   *
   * DISPONIBILIDADE = horas PRODUZINDO ÷ horas planejadas. "Produzindo" é o
   *   horímetro. Parada produtiva (esvaziando silo) é máquina parada, mesmo com
   *   o operador trabalhando: somá-la ao H.T fazia H.T + H.P estourar o turno
   *   (91,97 h contra 88 h planejadas na Linha 2) e inflava a disponibilidade.
   * PERFORMANCE = produzido ÷ (média/h × horas produzindo). Acima de 100% não é
   *   erro de conta: é média/h cadastrada abaixo do que a linha faz.
   * QUALIDADE = pallets aprovados ÷ pallets JULGADOS. Pendente não penaliza nem
   *   vira 100%: sem nenhum julgado, qualidade é NULL.
   *
   * Fator sem base vem null. O OEE exige disponibilidade E performance; sem
   * qualidade devolve `parcial: true` e quem chama avisa na tela — nunca troca
   * qualidade ausente por 100%, que era o que inflava o número no producao.html.
   */
  Regras.oee = function (o) {
    o = o || {};
    var hProd = Number(o.horasProduzindo) || 0;
    var hPlan = Number(o.horasPlanejadas) || 0;
    var feito = Number(o.produzido) || 0;
    var meta  = Number(o.metaProduzido) || 0;
    var apr   = Number(o.palletsAprovados) || 0;
    var rep   = Number(o.palletsReprovados) || 0;

    var disponibilidade = hPlan > 0 ? (hProd / hPlan) * 100 : null;
    var performance     = meta  > 0 ? (feito / meta) * 100 : null;
    var julgados        = apr + rep;
    var qualidade       = julgados > 0 ? (apr / julgados) * 100 : null;

    var faltam = [];
    if (disponibilidade == null) faltam.push('horas planejadas no planejamento');
    if (performance == null)     faltam.push('média sc/h no planejamento');
    if (qualidade == null)       faltam.push('pallet julgado no laboratório');

    var temBase = disponibilidade != null && performance != null;
    var oee = temBase
      ? (disponibilidade / 100) * (performance / 100) * (qualidade != null ? qualidade / 100 : 1) * 100
      : null;

    return { disponibilidade: disponibilidade, performance: performance, qualidade: qualidade,
             julgados: julgados, oee: oee, parcial: temBase && qualidade == null, faltam: faltam };
  };

  /* OEE da fábrica: média das linhas PONDERADA pelo tempo planejado de cada uma.
   * Média simples fazia a Longa Vida (6 turnos) pesar igual à Emitec (12), e
   * linha sem base entrava como 0 e derrubava o número. Aqui linha sem OEE fica
   * fora da conta — e quem chama diz quantas ficaram.
   * itens: [{ oee, peso }]. Devolve { oee, peso, dentro, fora } — oee null se
   * nenhuma linha tem base.
   */
  Regras.oeeConsolidado = function (itens) {
    var somaPeso = 0, somaPond = 0, dentro = 0, fora = 0;
    (Array.isArray(itens) ? itens : []).forEach(function (x) {
      var v = x && x.oee, p = Number(x && x.peso) || 0;
      if (v == null || !isFinite(v) || p <= 0) { fora++; return; }
      somaPond += v * p; somaPeso += p; dentro++;
    });
    return { oee: somaPeso > 0 ? somaPond / somaPeso : null, peso: somaPeso,
             dentro: dentro, fora: fora };
  };

  /* ── EPI: SITUAÇÃO DE UMA ENTREGA ──────────────────────────────────────────
   * Três coisas tiram uma entrega da fila de atraso, e é aqui que elas moram —
   * o dashboard contava só "data de troca no passado" e chegava a 48 EPIs
   * vencidos onde o módulo mostrava 9:
   *   1) DEVOLVIDA  — o EPI voltou, o prazo dela morreu.
   *   2) SUBSTITUÍDA — já existe entrega mais nova do MESMO EPI para o MESMO
   *      funcionário. Quem manda é sempre a última; a antiga é histórico.
   *      (33 das 48 eram isso: troca de máscara PFF2 lançada mês a mês.)
   *   3) DESLIGADO  — entrega de quem saiu da empresa não é pendência de EPI.
   * Férias e afastado CONTINUAM contando: a pessoa volta e o EPI tem de estar
   * em dia.
   */
  Regras.EPI_DIAS_PROXIMO = 5;

  // Dias até a troca: negativo = atrasado, null = entrega sem prazo definido.
  Regras.diasAte = function (dataISO, hojeISO) {
    if (!dataISO) return null;
    var hoje = hojeISO ? new Date(hojeISO + 'T00:00:00') : new Date();
    hoje.setHours(0, 0, 0, 0);
    var alvo = new Date(String(dataISO).slice(0, 10) + 'T00:00:00');
    return Math.round((alvo - hoje) / 86400000);
  };

  Regras.epiSubstituida = function (entrega, todas) {
    if (!entrega || !Array.isArray(todas)) return false;
    for (var i = 0; i < todas.length; i++) {
      var x = todas[i];
      if (!x || x.id === entrega.id) continue;
      if (x.funcionario_id !== entrega.funcionario_id || x.epi_id !== entrega.epi_id) continue;
      if (x.data_entrega > entrega.data_entrega) return true;
      if (x.data_entrega === entrega.data_entrega &&
          String(x.created_at || '') > String(entrega.created_at || '')) return true;
    }
    return false;
  };

  // 'devolvida' | 'substituida' | 'vencido' | 'proximo' | 'em_dia'
  Regras.epiStatusEntrega = function (entrega, todas, hojeISO) {
    if (!entrega) return 'em_dia';
    if (entrega.devolvido_em) return 'devolvida';
    if (Regras.epiSubstituida(entrega, todas)) return 'substituida';
    var dias = Regras.diasAte(entrega.data_prevista_troca, hojeISO);
    if (dias === null) return 'em_dia';
    if (dias < 0) return 'vencido';
    if (dias <= Regras.EPI_DIAS_PROXIMO) return 'proximo';
    return 'em_dia';
  };

  /* Entrega de funcionário DESLIGADO não é pendência. `funcionarios` é a lista
   * do cadastro (id + status); ausente da lista também conta como desligado,
   * senão entrega órfã viraria alerta eterno.
   */
  Regras.EPI_STATUS_DESLIGADO = 'inativo';
  Regras.epiFuncNaAtiva = function (entrega, funcionarios) {
    if (!Array.isArray(funcionarios)) return true;   // sem lista, não filtra
    for (var i = 0; i < funcionarios.length; i++) {
      if (funcionarios[i] && funcionarios[i].id === entrega.funcionario_id) {
        return String(funcionarios[i].status || '') !== Regras.EPI_STATUS_DESLIGADO;
      }
    }
    return false;
  };

  // Entregas que são pendência de verdade, por situação. Uma chamada, um número
  // igual em qualquer módulo.
  Regras.epiPendencias = function (entregas, funcionarios, hojeISO) {
    var lista = Array.isArray(entregas) ? entregas : [];
    var vencidas = [], proximas = [];
    lista.forEach(function (e) {
      if (!Regras.epiFuncNaAtiva(e, funcionarios)) return;
      var st = Regras.epiStatusEntrega(e, lista, hojeISO);
      if (st === 'vencido') vencidas.push(e);
      else if (st === 'proximo') proximas.push(e);
    });
    return { vencidas: vencidas, proximas: proximas };
  };

  /* ── LABORATÓRIO: faixas que aparecem no card da linha ─────────────────────
   * Usado em dashboard.html e laboratorio.html — a cor no card serve para
   * regular a linha antes de abrir a análise.
   *   Granulometria: soma das peneiras #20 + #50 + #100 + #200 (%), faixa 20–25%.
   *     Longa Vida (granel) é diferente: de 30% para cima; abaixo de 30% sinaliza.
   *   Umidade: acima de 0,60% sinaliza.
   * Mudou a faixa? Muda aqui e os dois cards acompanham. */
  Regras.LAB_GRAN_MIN = 20;
  Regras.LAB_GRAN_MAX = 25;
  // Faixa por linha (nome como em linhas_producao). max null = sem teto.
  Regras.LAB_GRAN_POR_LINHA = { 'Longa Vida': { min: 30, max: null } };
  Regras.labGranFaixaDaLinha = function (linha) {
    var f = Regras.LAB_GRAN_POR_LINHA[String(linha || '').trim()];
    return f ? { min: f.min, max: f.max } : { min: Regras.LAB_GRAN_MIN, max: Regras.LAB_GRAN_MAX };
  };
  Regras.LAB_UMIDADE_MAX = 0.60;
  Regras.labGranTotal = function (pen) {
    if (!pen || typeof pen !== 'object') return null;
    var ks = ['p20', 'p50', 'p100', 'p200'], soma = 0, tem = false;
    ks.forEach(function (k) {
      var v = pen[k];
      if (v !== null && v !== undefined && v !== '' && !isNaN(Number(v))) { soma += Number(v); tem = true; }
    });
    return tem ? Math.round(soma * 100) / 100 : null;
  };
  // 'ok' | 'baixo' | 'alto' | null (sem ensaio)
  Regras.labGranFaixa = function (total, linha) {
    if (total === null || total === undefined || isNaN(Number(total))) return null;
    total = Number(total);
    var f = Regras.labGranFaixaDaLinha(linha);
    if (f.min !== null && total < f.min) return 'baixo';
    if (f.max !== null && total > f.max) return 'alto';
    return 'ok';
  };
  // 'ok' | 'alta' | null (sem medição)
  Regras.labUmidadeFaixa = function (u) {
    if (u === null || u === undefined || u === '' || isNaN(Number(u))) return null;
    return Number(u) > Regras.LAB_UMIDADE_MAX ? 'alta' : 'ok';
  };
  // Separador da última aferição (aferidor.html) da linha até a data.
  // Prefere o REGULADO (o que ficou na máquina); sem regulagem, o ATUAL.
  // "0" é valor válido. afericoes = linhas de aferidor_aditivacao (com itens).
  Regras.separadorDaAfericao = function (afericoes, linha, dataISO) {
    if (!linha || !Array.isArray(afericoes)) return null;
    var norm = function (t) { return String(t || '').trim().toLowerCase(); };
    var lista = afericoes.filter(function (a) {
      return norm(a.linha) === norm(linha) && (!dataISO || String(a.data) <= dataISO);
    }).sort(function (a, b) {
      return String(b.data).localeCompare(String(a.data)) || String(b.hora || '').localeCompare(String(a.hora || ''));
    });
    for (var i = 0; i < lista.length; i++) {
      var itens = Array.isArray(lista[i].itens) ? lista[i].itens : [];
      var it = null;
      for (var j = 0; j < itens.length; j++) { if (itens[j] && /separador/i.test(itens[j].item || '')) { it = itens[j]; break; } }
      if (!it) continue;
      var reg = String(it.regulado == null ? '' : it.regulado).trim();
      var atu = String(it.atual == null ? '' : it.atual).trim();
      var v = reg !== '' ? reg : atu;
      if (v !== '') return { valor: v, numero: lista[i].numero, data: lista[i].data, campo: reg !== '' ? 'regulado' : 'atual' };
    }
    return null;
  };
  // Os três indicadores do card, já com a faixa. Separador: o gravado na
  // análise; vazio → a aferição da linha (aferidor) até a data da análise.
  Regras.labIndicadoresCard = function (analise, afericoes) {
    if (!analise) return null;
    var gran = Regras.labGranTotal(analise.peneiramento);
    var gf = Regras.labGranFaixaDaLinha(analise.linha);
    var sep = (analise.separador !== null && analise.separador !== undefined && String(analise.separador).trim() !== '') ? String(analise.separador).trim() : null;
    var sepOrigem = sep !== null ? 'analise' : null;
    if (sep === null) {
      var af = Regras.separadorDaAfericao(afericoes, analise.linha, analise.data);
      if (af) { sep = af.valor; sepOrigem = 'aferidor'; }
    }
    var umid = (analise.umidade === null || analise.umidade === undefined || analise.umidade === '') ? null : Number(analise.umidade);
    return {
      gran: gran, granFaixa: Regras.labGranFaixa(gran, analise.linha), granMin: gf.min, granMax: gf.max,
      separador: sep, separadorOrigem: sepOrigem,
      umidade: (umid === null || isNaN(umid)) ? null : umid, umidadeFaixa: Regras.labUmidadeFaixa(umid)
    };
  };

  // ── NUMERAÇÃO DOS PALLETS DA OP — cada PRODUTO conta do 1 ──────────────
  // itens: um por pallet, na ordem da OP ({produto, ...}). Produto que aparece
  // duas vezes na OP (começo e fim do turno) continua a conta dele.
  // Devolve cada item com `numero` (do produto) e `sufixo`: '' quando a OP tem
  // um produto só (código igual ao de sempre: …-P001); com mais de um produto,
  // 'A-', 'B-'… na ordem em que aparecem (…-B-P001), para o código continuar único.
  Regras.numerarPalletsPorProduto = function (itens) {
    var ordem = [], cont = {};
    (itens || []).forEach(function (it) {
      var k = Regras.normalizarNome(it && it.produto);
      if (!(k in cont)) { cont[k] = 0; ordem.push(k); }
    });
    var multi = ordem.length > 1;
    return (itens || []).map(function (it) {
      var k = Regras.normalizarNome(it && it.produto);
      cont[k] += 1;
      var out = {};
      for (var c in it) if (Object.prototype.hasOwnProperty.call(it, c)) out[c] = it[c];
      out.numero = cont[k];
      out.sufixo = multi ? String.fromCharCode(65 + ordem.indexOf(k)) + '-' : '';
      return out;
    });
  };
  // Código do pallet: LIN-AAAAMMDD-OPTAIL-[X-]P###
  Regras.codigoPallet = function (linha, data, opNumero, sufixo, numero) {
    var lin3 = String(linha || '').replace(/[^A-Za-z0-9]/g, '').substring(0, 3).toUpperCase() || 'LIN';
    var opTail = opNumero ? String(opNumero).split('-').pop() : '0000';
    return lin3 + '-' + String(data || '').replace(/-/g, '') + '-' + opTail + '-' + (sufixo || '') + 'P' + String(numero || 0).padStart(3, '0');
  };
  /* ── META DE UM TURNO (OP) ───────────────────────────────────────────────────
   * Usada pelo Painel de Metas (TV) e pela tela "Conferir" do modo pátio.
   * Regra combinada (out/2026):
   *   • horas-meta do turno = horas disponíveis/dia do planejamento daquela linha e
   *     turno (dispH ÷ diasTrabalho — já com a eficiência do plano, ex.: 85%);
   *   • meta de produção de cada produto = média/h da linha de produto × horas-meta,
   *     rateada pelas horas que cada produto rodou na OP (quando a OP tem vários);
   *   • "bateu" = soma, em horas de média/h (real ÷ média/h), ≥ horas-meta;
   *   • máquina rodando: real = H.T da OP, meta = horas-meta do turno.
   * A média/h vem do planejamento do mês (seção da linha/turno); se não houver,
   * do cadastro da linha. Nome casado ignorando espaço/acento/maiúscula.
   * Turno parado (OP sem produção) conta a meta cheia com 0 feito.
   * Devolve { turno, producao:{bateu,horasReal,horasMeta,itens[]}, disponibilidade:{real,meta}, semCap[] }.
   */
  Regras.metaDaOP = function (op, secoes, linhaCad, produtos) {
    op = op || {};
    var norm = function (x) { return String(x || '').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/[^a-z0-9]/g, ''); };
    var daLinha = (secoes || []).filter(function (s) { return s && s.linha === op.linha; });
    var sec = daLinha.filter(function (s) { return s.turno === op.turno; })[0] || daLinha[0] || null;
    var horasMeta = sec ? (parseFloat(sec.dispH) || 0) / (parseInt(sec.diasTrabalho, 10) || 1) : 0;
    // candidatos de média/h: seção do turno, demais seções da linha, cadastro da linha
    var cands = [];
    if (sec) cands = cands.concat(sec.produtos || []);
    daLinha.forEach(function (s) { if (s !== sec) cands = cands.concat(s.produtos || []); });
    cands = cands.concat((linhaCad && linhaCad.produtos) || []);
    cands = cands.filter(function (c) { return c && c.nome && (parseFloat(c.capHora) || 0) > 0; });
    var capDe = function (lp) {
      var k = norm(lp); if (!k) return 0;
      var ex = cands.filter(function (c) { return norm(c.nome) === k; })[0];
      if (ex) return parseFloat(ex.capHora) || 0;
      var ap = cands.filter(function (c) { var n = norm(c.nome); return n.indexOf(k) === 0 || k.indexOf(n) === 0; });
      var nomes = ap.map(function (c) { return norm(c.nome); }).filter(function (v, i, a) { return a.indexOf(v) === i; });
      return nomes.length === 1 ? (parseFloat(ap[0].capHora) || 0) : 0;
    };
    var itensOP = (Array.isArray(op.produtos_op) && op.produtos_op.length) ? op.produtos_op
      : [{ produto: op.produto, total_sacos: op.total_sacos, ht: op.ht }];
    var htItens = itensOP.reduce(function (s, it) { return s + (Number(it.ht) || 0); }, 0);
    var itens = [], semCap = [], hReal = 0, hMeta = 0;
    itensOP.forEach(function (it) {
      var un = Regras.unidadeDoProduto(it.produto, produtos);
      var qtd = (it.total_sacos != null && it.total_sacos !== '') ? it.total_sacos : it.sacos_pallets;
      var real = Regras.qtdNaUnidadeDoProduto(qtd, un) || 0;
      var cadP = (produtos || []).filter(function (p) { return p && p.nome === it.produto; })[0];
      var lp = it.linha_produto || (cadP && cadP.linhas && cadP.linhas[0]) || it.produto || '';
      var cap = capDe(lp);
      if (!cap) { if (lp && semCap.indexOf(lp) < 0) semCap.push(lp); return; }
      var parte = htItens > 0 ? (Number(it.ht) || 0) / htItens : 1 / itensOP.length;
      var meta = cap * horasMeta * parte;
      itens.push({ produto: it.produto, linha_produto: lp, unidade: un, real: real, meta: meta, capHora: cap });
      hReal += real / cap; hMeta += meta / cap;
    });
    // turno PARADO (sem produção lançada): conta a meta cheia com 0 feito,
    // pela média/h do 1º produto planejado para a linha/turno
    var nada = itensOP.every(function (it) { return !(parseFloat(it.total_sacos) > 0) && !(parseFloat(it.sacos_pallets) > 0); });
    if (!itens.length && nada && horasMeta > 0) {
      var p0 = cands[0];
      if (p0) {
        var cap0 = parseFloat(p0.capHora) || 0;
        itens.push({ produto: p0.nome, linha_produto: p0.nome, unidade: p0.unidade || 'sacos', real: 0, meta: cap0 * horasMeta, capHora: cap0 });
        hMeta += horasMeta; semCap = [];
      }
    }
    return {
      turno: op.turno,
      producao: { bateu: hMeta > 0 ? hReal >= hMeta - 1e-9 : null, horasReal: hReal, horasMeta: hMeta, itens: itens },
      disponibilidade: { real: Number(op.ht) || htItens || 0, meta: horasMeta },
      semCap: semCap
    };
  };

  global.Regras = Regras;
})(typeof window !== 'undefined' ? window : this);
