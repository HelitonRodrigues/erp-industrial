/**
 * Programação de Cargas — envia a planilha CARREGAMENTOS para o ERP.
 * Instalar (uma vez):
 *   1. Na planilha: Extensões → Apps Script → cole este arquivo → salvar.
 *   2. Configurações do projeto (engrenagem) → Propriedades do script → adicionar
 *      TOKEN = <token que o Claude passou>.
 *   3. Escolha a função "instalar" e clique em Executar (autorize com sua conta).
 * Depois disso roda sozinho a cada 10 minutos, sem precisar do PC ligado.
 */
const SUPABASE_URL = 'https://zodgbitbflkepbszshmu.supabase.co';
const SUPABASE_ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpvZGdiaXRiZmxrZXBic3pzaG11Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYwNjYwNjgsImV4cCI6MjA5MTY0MjA2OH0.iWROA5X7CkxOunt7Cn46wWODa7SQ5nU8OJcD52NhCgA';
const ABA = 'CARREGAMENTOS';
const DIAS_PARA_TRAS = 60;
const VERDES = ['#c5e0b3', '#b6d7a8', '#d9ead3', '#93c47d', '#a9d08e', '#c6efce'];

function enviarProgramacao() {
  const token = PropertiesService.getScriptProperties().getProperty('TOKEN');
  if (!token) throw new Error('Falta a propriedade TOKEN (Configurações do projeto → Propriedades do script).');
  const ss = SpreadsheetApp.getActive();
  const sh = ss.getSheetByName(ABA) || ss.getSheets()[0];
  const rg = sh.getDataRange();
  const v = rg.getValues(), bg = rg.getBackgrounds();
  const norm = s => String(s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toUpperCase().trim();

  let hr = -1;
  for (let r = 0; r < Math.min(v.length, 40) && hr < 0; r++)
    for (let c = 0; c < v[r].length; c++) if (norm(v[r][c]) === 'COD. PEDIDO') { hr = r; break; }
  if (hr < 0) throw new Error('Não achei o cabeçalho "Cod. Pedido".');
  const col = {};
  v[hr].forEach((h, c) => { const k = norm(h); if (k) col[k] = c; });
  const C = k => col[Object.keys(col).find(h => h.indexOf(k) === 0)];
  const cD = C('DATA COLETA'), cP = C('COD. PEDIDO'), cN = C('NOTA');

  const lim = new Date(); lim.setDate(lim.getDate() - DIAS_PARA_TRAS);
  const tz = ss.getSpreadsheetTimeZone() || 'America/Sao_Paulo';
  const linhas = [];
  for (let r = hr + 1; r < v.length; r++) {
    const ped = String(v[r][cP] || '').trim();
    const d = v[r][cD];
    if (!ped || !(d instanceof Date) || d < lim) continue;
    const nota = String(v[r][cN] || '').trim();
    const temNota = /^\d+$/.test(nota);
    linhas.push({
      pedido: ped,
      data: Utilities.formatDate(d, tz, 'yyyy-MM-dd'),
      cliente: v[r][C('CLIENTE')] || null,
      cnpj: v[r][C('CNPJ')] || null,
      peso_t: Number(v[r][C('PESO')]) || null,
      nota: temNota ? nota : null,
      preco: Number(v[r][C('PRECO')]) || null,
      material: v[r][C('MATERIAL')] || null,
      embalagem: v[r][C('EMBALAGEM')] || null,
      transp: v[r][C('TRANSP')] || null,
      obs: v[r][C('OBSERVA')] || null,
      carregado: temNota || VERDES.indexOf(String(bg[r][cD]).toLowerCase()) >= 0,
    });
  }
  const resp = UrlFetchApp.fetch(SUPABASE_URL + '/rest/v1/rpc/sync_planilha', {
    method: 'post', contentType: 'application/json', muteHttpExceptions: true,
    headers: { apikey: SUPABASE_ANON, Authorization: 'Bearer ' + SUPABASE_ANON },
    payload: JSON.stringify({ p_token: token, p_linhas: linhas }),
  });
  Logger.log(resp.getResponseCode() + ' ' + resp.getContentText());
  if (resp.getResponseCode() >= 300) throw new Error('ERP recusou: ' + resp.getContentText());
}

function instalar() {
  ScriptApp.getProjectTriggers().forEach(t => { if (t.getHandlerFunction() === 'enviarProgramacao') ScriptApp.deleteTrigger(t); });
  ScriptApp.newTrigger('enviarProgramacao').timeBased().everyMinutes(10).create();
  enviarProgramacao();
}
