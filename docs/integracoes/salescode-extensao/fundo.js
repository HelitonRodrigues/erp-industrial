// Clicar no ícone da extensão abre (ou recarrega) a tela de Pedidos Disponíveis.
// Ao abrir, o coletor.js lê a tela e manda para o ERP sozinho.
const URL_PEDIDOS = 'https://salescode.com.br/adm/producao/pedidosDisponiveis';
chrome.action.onClicked.addListener(async () => {
  const [aba] = await chrome.tabs.query({ url: URL_PEDIDOS + '*' });
  if (aba) { await chrome.tabs.update(aba.id, { active: true }); await chrome.tabs.reload(aba.id); }
  else await chrome.tabs.create({ url: URL_PEDIDOS });
});
