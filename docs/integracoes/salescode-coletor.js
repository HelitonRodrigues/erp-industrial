/**
 * Programação de Cargas — lê "Pedidos Disponíveis" do Salescode e envia ao ERP.
 * Roda DENTRO da página https://salescode.com.br/adm/producao/pedidosDisponiveis
 * (tarefa agendada do Claude no PC, ou favorito/bookmarklet). TOKEN = o mesmo da planilha.
 * O Salescode não tem API: a leitura é pelos cartões da tela (a[href*="/ret/pedido/view/"]).
 */
(async (TOKEN) => {
  const URL = 'https://zodgbitbflkepbszshmu.supabase.co/rest/v1/rpc/sync_salescode';
  const ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpvZGdiaXRiZmxrZXBic3pzaG11Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYwNjYwNjgsImV4cCI6MjA5MTY0MjA2OH0.iWROA5X7CkxOunt7Cn46wWODa7SQ5nU8OJcD52NhCgA';
  if (!/pedidosDisponiveis/.test(location.href)) return 'abra a tela Pedidos Disponíveis do Salescode';
  const t = s => (s || '').replace(/\s+/g, ' ').trim();
  const map = {};
  document.querySelectorAll('a[href*="/ret/pedido/view/"]').forEach(a => {
    const ped = t(a.querySelector('.card-ped')?.textContent).replace(/\s*PROG\.?$/, '');
    const pro = t(a.querySelector('.card-pro')?.textContent);
    if (!ped || !pro) return;
    const info = t(a.querySelector('.card-info')?.textContent).split('·').map(t);
    const k = ped + '|' + pro;
    const r = map[k] || { pedido: ped, produto: pro, cliente: t(a.querySelector('.card-cli')?.textContent), cidade: info[0], frete: info[1],
      qtd: t(a.querySelector('.qtd')?.textContent), data: t(a.querySelector('.kb-data')?.textContent), view: a.href.split('/').pop() };
    if (info[2] && !r.status) r.status = info[2];
    if (!r.data) r.data = t(a.querySelector('.kb-data')?.textContent);
    map[k] = r;
  });
  const itens = Object.values(map);
  const resp = await fetch(URL, { method: 'POST', headers: { 'Content-Type': 'application/json', apikey: ANON, Authorization: 'Bearer ' + ANON },
    body: JSON.stringify({ p_token: TOKEN, p_itens: itens }) });
  const txt = await resp.text();
  return `Salescode → ERP: ${itens.length} linhas lidas · resposta ${resp.status} ${txt}`;
})('COLE_O_TOKEN_AQUI');
