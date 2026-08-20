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

  // Disponibilidade (%) = (horas trabalhadas − horas paradas) ÷ horas trabalhadas × 100.
  // 0 se não houver horas trabalhadas. É a disponibilidade "de linha" (base H.T);
  // NÃO confundir com a disponibilidade do OEE, que usa horas brutas do planejamento.
  Regras.disponibilidade = function (htTrabalhada, htParada) {
    var ht = Number(htTrabalhada) || 0;
    if (ht <= 0) return 0;
    var hp = Number(htParada) || 0;
    return (ht - hp) / ht * 100;
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

  global.Regras = Regras;
})(typeof window !== 'undefined' ? window : this);
