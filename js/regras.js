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

  global.Regras = Regras;
})(typeof window !== 'undefined' ? window : this);
