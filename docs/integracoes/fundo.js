// Clicar no ícone da extensão abre (ou recarrega) a tela de Pedidos Disponíveis do Salescode.
// O coletor.js lê a tela e manda para o ERP; quando termina, avisa aqui e abrimos o Portal da balança
// (consulta de tickets com #erp) — o balanca.js lê os tickets novos e dá baixa nos pedidos que pesaram.
const URL_PEDIDOS = 'https://salescode.com.br/adm/producao/pedidosDisponiveis';
const URL_BALANCA = 'http://45.184.42.85:8007/relatorio/ticket/consulta';

chrome.action.onClicked.addListener(async () => {
  const [aba] = await chrome.tabs.query({ url: URL_PEDIDOS + '*' });
  if (aba) { await chrome.tabs.update(aba.id, { active: true }); await chrome.tabs.reload(aba.id); }
  else await chrome.tabs.create({ url: URL_PEDIDOS });
});

chrome.runtime.onMessage.addListener((msg) => {
  if (!msg || msg.tipo !== 'salescode_fim') return;
  (async () => {
    const [aba] = await chrome.tabs.query({ url: URL_BALANCA + '*' });
    if (aba) await chrome.tabs.update(aba.id, { url: URL_BALANCA + '#erp', active: true }).then(() => chrome.tabs.reload(aba.id));
    else await chrome.tabs.create({ url: URL_BALANCA + '#erp' });
  })();
});
