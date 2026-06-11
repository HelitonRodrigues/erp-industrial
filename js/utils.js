// ============================================================
// ERP INDUSTRIAL — UTILS.JS  v2.0
// Engine de controle de acesso, sidebar filtrada e utilitários
// ============================================================

// ── MAPA CANÔNICO DE MÓDULOS ──────────────────────────────
// chave = id interno usado em permissoes{}
// page  = arquivo .html correspondente
// label = rótulo exibido no menu
// group = grupo do sidebar
// icon  = emoji do sidebar
const MODULO_MAP = [
  // PRINCIPAL
  { id:'dashboard',      page:'dashboard.html',      label:'Dashboard',            group:'principal',    icon:'📊' },
  { id:'notificacoes',   page:'notificacoes.html',    label:'Notificações',         group:'principal',    icon:'🔔' },
  { id:'relatorios',     page:'relatorios.html',      label:'Relatórios',           group:'principal',    icon:'📋' },
  // ADMINISTRAÇÃO
  { id:'usuarios',       page:'usuarios.html',        label:'Usuários',             group:'administracao',icon:'👥' },
  { id:'perfis',         page:'perfis.html',          label:'Perfis & Permissões',  group:'administracao',icon:'🔒' },
  { id:'auditoria',      page:'auditoria.html',       label:'Auditoria',            group:'administracao',icon:'📋' },
  { id:'configuracoes',  page:'configuracoes.html',   label:'Configurações',        group:'administracao',icon:'⚙️' },
  // CADASTROS
  { id:'funcionarios',   page:'funcionarios.html',    label:'Funcionários',         group:'cadastros',    icon:'👷' },
  { id:'equip_linhas',   page:'equip-linhas.html',    label:'Equip. das Linhas',    group:'cadastros',    icon:'⚙️' },
  { id:'equip_gerais',   page:'equip-gerais.html',    label:'Equip. Gerais',        group:'cadastros',    icon:'🔧' },
  { id:'linhas',         page:'linhas.html',          label:'Linhas de Produção',   group:'cadastros',    icon:'🏭' },
  { id:'turnos',         page:'turnos.html',          label:'Turnos',               group:'cadastros',    icon:'🕐' },
  { id:'produtos',       page:'produtos.html',        label:'Produtos',             group:'cadastros',    icon:'📦' },
  { id:'motivos',        page:'motivos.html',         label:'Motivos de Parada',    group:'cadastros',    icon:'🛑' },
  // PRODUÇÃO
  { id:'planejamento',   page:'planejamento.html',    label:'Planejamento',         group:'producao',     icon:'📋' },
  { id:'escala',         page:'escala.html',          label:'Escala de Equipe',     group:'producao',     icon:'🧤' },
  { id:'producao',       page:'producao.html',        label:'Produção',             group:'producao',     icon:'⚙️' },
  { id:'banners',        page:'banners.html',         label:'Produção de Banners',  group:'producao',     icon:'🖼️' },
  // QUALIDADE
  { id:'laboratorio',    page:'laboratorio.html',     label:'Laboratório',          group:'qualidade',    icon:'🧪' },
  { id:'bpf',            page:'bpf.html',             label:'BPF',                  group:'qualidade',    icon:'📋' },
  // OPERAÇÕES
  { id:'manutencao',     page:'manutencao.html',      label:'Manutenção',           group:'operacoes',    icon:'🔧' },
  { id:'frota',          page:'frota.html',           label:'Frota',                group:'operacoes',    icon:'🚜' },
  { id:'abastecimento',  page:'abastecimento.html',   label:'Abastecimento',        group:'operacoes',    icon:'⛽' },
  // SUPRIMENTOS
  { id:'almoxarifado',   page:'almoxarifado.html',    label:'Almoxarifado',         group:'suprimentos',  icon:'📦' },
  { id:'compras',        page:'compras.html',         label:'Compras',              group:'suprimentos',  icon:'🛒' },
  // CUSTOS
  { id:'custos',         page:'custos.html',          label:'Gestão de Custos',     group:'custos',       icon:'💰' },
  // LOGÍSTICA
  { id:'portaria',       page:'portaria.html',        label:'Portaria',             group:'logistica',    icon:'🚪' },
  { id:'expedicao',      page:'expedicao.html',       label:'Expedição',            group:'logistica',    icon:'🚛' },
  { id:'carregamento',   page:'carregamento.html',    label:'Carregamento',         group:'logistica',    icon:'📦' },
  // SEGURANÇA
  { id:'epi',            page:'epi.html',             label:'EPI',                  group:'seguranca',    icon:'🦺' },
  // RH
  { id:'rh',             page:'rh.html',              label:'RH & Escala',          group:'rh',           icon:'📅' },
];

// Rótulos dos grupos para render do sidebar
const GROUP_LABELS = {
  principal:    'PRINCIPAL',
  administracao:'ADMINISTRAÇÃO',
  cadastros:    'CADASTROS',
  producao:     'PRODUÇÃO',
  qualidade:    'QUALIDADE',
  operacoes:    'OPERAÇÕES',
  suprimentos:  'SUPRIMENTOS',
  custos:       'CUSTOS',
  logistica:    'LOGÍSTICA',
  seguranca:    'SEGURANÇA DO TRABALHO',
  rh:           'RH',
};

// Módulos sempre visíveis para SADM/ADM (acesso total)
const PERFIS_ADMIN = ['SADM', 'ADM'];

// ── AÇÕES E TELAS POR MÓDULO ───────────────────────────────
// Ações base (módulos de tela única / legado).
const ACOES_BASE = ['view', 'create', 'edit', 'delete', 'export'];
// Ações configuráveis POR ABA/TELA (modelo detalhado).
const ACOES_TAB  = ['view', 'create', 'edit', 'delete', 'aprovar', 'export', 'imprimir'];

const ACAO_LABELS_FULL = {
  view:'Ver', create:'Criar', edit:'Editar', delete:'Excluir',
  export:'Exportar', aprovar:'Aprovar', cancelar:'Cancelar/Rejeitar',
  finalizar:'Finalizar/Concluir', imprimir:'Imprimir/PDF',
};

// Ações EXTRAS por módulo, acrescentadas às de aba (ex.: fluxos de aprovação).
const MODULO_ACOES_EXTRAS = {
  almoxarifado: ['cancelar', 'finalizar'],
  compras:      ['cancelar', 'finalizar'],
  aprovacoes:   ['cancelar', 'finalizar'],
};
// Ações disponíveis para as abas de um módulo (base de aba + extras).
function acoesDaAba(moduloId) {
  return ACOES_TAB.concat(MODULO_ACOES_EXTRAS[moduloId] || []);
}
// (compat) ações no nível de módulo p/ módulos de tela única.
function acoesDoModulo(moduloId) {
  return ACOES_BASE.concat(MODULO_ACOES_EXTRAS[moduloId] || []);
}

// ── CATÁLOGO DE TELAS/ABAS POR MÓDULO ──────────────────────
// Apenas módulos multi-tela. Os demais são "tela única" (permissão no
// nível do módulo). Para dar controle por tela a um módulo, inclua-o aqui
// com os ids das suas abas (o id deve bater com o argumento usado na função
// de troca de aba da página, para o enforcement por guardTab/data-tab-perm).
const MODULO_FUNCIONALIDADES = {
  funcionarios: [
    { id:'cad', label:'📋 Cadastro' },
    { id:'cert', label:'🎓 Capacitações / Certificações' },
    { id:'custo', label:'💰 Custos' },
  ],
  laboratorio: [
    { id:'analises', label:'📋 Análises' },
    { id:'afericoes', label:'⚙️ Aferições' },
    { id:'composicao', label:'🧱 Composições' },
    { id:'pallets', label:'📦 Análise de Pallets' },
  ],
  manutencao: [
    { id:'monitor', label:'🖥️ Monitor' },
    { id:'historico', label:'📋 Ordens de Serviço' },
    { id:'kanban', label:'🗂️ Kanban' },
    { id:'agenda', label:'🗓️ Agenda' },
    { id:'docs', label:'📁 Documentação' },
    { id:'cronograma', label:'📅 Cronograma' },
    { id:'prev', label:'🔧 Preventiva' },
    { id:'kpis', label:'📊 KPIs' },
  ],
  frota: [
    { id:'cadastro', label:'🚜 Equipamentos' },
    { id:'empresas', label:'🏢 Empresas / Mecânicos' },
    { id:'os', label:'📋 Ordens de Serviço' },
  ],
  abastecimento: [
    { id:'dashboard', label:'📊 Dashboard' },
    { id:'historico', label:'📋 Histórico' },
    { id:'frotas', label:'🚛 Por Frota' },
    { id:'entradas', label:'📥 Entradas NF' },
    { id:'bombas', label:'🛢️ Bombas' },
  ],
  almoxarifado: [
    { id:'estoque', label:'📦 Estoque' },
    { id:'insumos', label:'🌿 Insumos' },
    { id:'movimentos', label:'🔄 Movimentos' },
    { id:'relatorio', label:'📊 Relatório' },
    { id:'previsao', label:'🔮 Previsão' },
    { id:'solicitacoes', label:'📝 Solicitações' },
    { id:'fornecedores', label:'🏢 Fornecedores' },
  ],
  compras: [
    { id:'painel', label:'📊 Painel' },
    { id:'kanban', label:'🗂️ Kanban' },
    { id:'catalogo', label:'📚 Catálogo' },
    { id:'solicitacoes', label:'📝 Solicitações' },
    { id:'cotacoes', label:'💬 Cotações' },
    { id:'pedidos', label:'📦 Pedidos' },
    { id:'recebimentos', label:'📥 Recebimentos' },
    { id:'fornecedores', label:'🏭 Fornecedores' },
    { id:'contratos', label:'📄 Contratos' },
    { id:'nc', label:'⚠️ Não Conf.' },
    { id:'indicadores', label:'📈 Indicadores' },
    { id:'auditoria', label:'🛡️ Auditoria' },
  ],
  custos: [
    { id:'dashboard', label:'📊 Dashboard' },
    { id:'dre', label:'📈 DRE' },
    { id:'orcamento', label:'🎯 Orçamento' },
    { id:'comparativo', label:'📅 Comparativo' },
    { id:'custoton', label:'⚖️ Custo/Ton' },
    { id:'custoprod', label:'🏷️ Custo/Produto' },
    { id:'lancamentos', label:'📋 Lançamentos' },
    { id:'naturezas', label:'🏷️ Naturezas' },
    { id:'centros', label:'🏭 Centros' },
    { id:'metas', label:'🎯 Metas' },
    { id:'fechamento', label:'🔒 Fechamento' },
  ],
  expedicao: [
    { id:'ordens', label:'📋 Ordens' },
    { id:'pedidos', label:'📄 Pedidos' },
    { id:'relatorio', label:'📊 Relatório' },
  ],
  epi: [
    { id:'tab-cadastro', label:'📦 Cadastro de EPIs' },
    { id:'tab-alertas', label:'⚠️ Painel de Alertas' },
    { id:'tab-treinamentos', label:'🎓 Treinamentos' },
  ],
};

// Retorna o catálogo de telas de um módulo, ou null se for tela única.
function funcsDoModulo(moduloId) {
  return (typeof MODULO_FUNCIONALIDADES !== 'undefined' && MODULO_FUNCIONALIDADES[moduloId]) || null;
}

// ── AGREGADOR DE PERMISSÕES (rollup módulo ← abas) ─────────
// Mantém checkPerm('modulo','acao') funcionando também no modelo por aba:
// no nível de módulo, a ação é concedida se QUALQUER aba liberada a concede.
function _modAgg(mp, acao) {
  if (!mp) return false;
  if (mp.abas) {
    if (acao === 'view') return !!mp.view || Object.values(mp.abas).some(t => t && t.view);
    return Object.values(mp.abas).some(t => t && t.view && t[acao]);
  }
  return !!mp[acao];
}

/**
 * Pode ver/usar uma TELA (aba) de um módulo?
 * Retrocompat: perfil sem mapa `abas` segue o view do módulo (libera todas).
 */
function canTab(moduloId, abaId) {
  const u = getUser();
  if (!u) return false;
  if (PERFIS_ADMIN.includes(u.perfil)) return true;
  const mp = (u.permissoes || {})[moduloId];
  if (!mp) return false;
  if (!mp.abas) return !!mp.view;          // tela única / legado
  return !!(mp.abas[abaId] && mp.abas[abaId].view);
}

/**
 * Permissão de uma AÇÃO dentro de uma TELA específica.
 * acao: 'view'|'create'|'edit'|'delete'|'aprovar'|'export'|'cancelar'|'finalizar'
 */
function checkPermTab(moduloId, abaId, acao) {
  const u = getUser();
  if (!u) return false;
  if (PERFIS_ADMIN.includes(u.perfil)) return true;
  const mp = (u.permissoes || {})[moduloId];
  if (!mp) return false;
  if (mp.abas) {
    const t = mp.abas[abaId];
    if (!t || !t.view) return false;
    return acao === 'view' ? true : !!t[acao];
  }
  if (!mp.view) return false;              // tela única → nível de módulo
  return acao === 'view' ? true : !!mp[acao];
}

// Guard de troca de aba (toast + false se negado).
function guardTab(moduloId, abaId) {
  if (canTab(moduloId, abaId)) return true;
  const modulo = MODULO_MAP.find(m => m.id === moduloId);
  toast(`Sem permissão para acessar esta seção de ${modulo?.label || moduloId}.`, 'warning');
  return false;
}

// Guard de ação dentro de uma tela (toast + false se negado).
function guardActionTab(moduloId, abaId, acao) {
  const user = getUser();
  if (!user) { window.location.href = 'index.html'; return false; }
  if (PERFIS_ADMIN.includes(user.perfil)) return true;
  if (checkPermTab(moduloId, abaId, acao)) return true;
  const modulo = MODULO_MAP.find(m => m.id === moduloId);
  toast(`Sem permissão para ${ACAO_LABELS_FULL[acao] || acao} em ${modulo?.label || moduloId}.`, 'warning');
  return false;
}

// ── ENGINE DE PERMISSÕES ──────────────────────────────────
function getUser() {
  try { return JSON.parse(sessionStorage.getItem('erp_user')); }
  catch { return null; }
}

function isAdmin() {
  const u = getUser();
  return u && PERFIS_ADMIN.includes(u.perfil);
}

/**
 * Verifica se o usuário tem permissão para ação em módulo.
 * acao: 'view' | 'create' | 'edit' | 'delete' | 'export'
 */
function checkPerm(moduloId, acao) {
  const u = getUser();
  if (!u) return false;
  if (PERFIS_ADMIN.includes(u.perfil)) return true;
  const perms = u.permissoes;
  if (!perms) return false;
  return _modAgg(perms[moduloId], acao);   // agrega abas → nível de módulo
}

/**
 * Atalho: pode visualizar o módulo?
 */
function canView(moduloId) {
  return checkPerm(moduloId, 'view');
}

/**
 * requireAuth com verificação de acesso à página atual.
 * Redireciona para acesso-negado.html ou dashboard se não tiver permissão.
 */
function requireAuth(moduloId) {
  const user = getUser();
  // Não autenticado — vai para login
  if (!user) { window.location.href = 'index.html'; return null; }

  // SADM e ADM têm acesso total — nunca bloquear
  if (PERFIS_ADMIN.includes(user.perfil)) return user;

  // Sem moduloId definido — apenas verifica autenticação
  if (!moduloId) return user;

  // Verificar permissão de view para o módulo
  const perms = user.permissoes || {};
  const temAcesso = perms[moduloId] && perms[moduloId].view;

  if (!temAcesso) {
    if (moduloId === 'dashboard') {
      // Sem acesso ao dashboard: redirecionar para o primeiro módulo permitido
      const primeiroModulo = MODULO_MAP.find(m => perms[m.id] && perms[m.id].view);
      if (primeiroModulo) {
        window.location.href = primeiroModulo.page;
      } else {
        // Nenhum módulo permitido — logout
        sessionStorage.removeItem('erp_user');
        window.location.href = 'index.html';
      }
    } else {
      sessionStorage.setItem('erp_access_denied', moduloId);
      window.location.href = 'dashboard.html';
    }
    return null;
  }
  return user;
}

/**
 * Oculta elementos com data-perm="modulo:acao" se sem permissão.
 * Uso: <button data-perm="producao:create">Novo</button>
 */
function applyPermUI() {
  // data-perm="modulo:acao"  OU  data-perm="modulo.aba:acao" (ação por tela)
  document.querySelectorAll('[data-perm]').forEach(el => {
    const [left, acao] = (el.getAttribute('data-perm') || '').split(':');
    let ok;
    if (left.includes('.')) {
      const [mod, aba] = left.split('.');
      ok = checkPermTab(mod, aba, acao || 'view');
    } else {
      ok = checkPerm(left, acao || 'view');
    }
    if (!ok) el.style.display = 'none';
  });
  // Visibilidade de aba: <button data-tab-perm="compras:cotacoes">
  document.querySelectorAll('[data-tab-perm]').forEach(el => {
    const [mod, aba] = (el.getAttribute('data-tab-perm') || '').split(':');
    if (mod && aba && !canTab(mod, aba)) el.style.display = 'none';
  });
}

/**
 * Guard para ações destrutivas ou restritas chamado no início
 * de funções de create/edit/delete em qualquer módulo.
 *
 * Uso:
 *   async function excluirRegistro(id) {
 *     if (!guardAction('producao', 'delete')) return;
 *     ...
 *   }
 *
 * Retorna true se permitido, false (+ toast) se negado.
 */
function guardAction(moduloId, acao) {
  const user = getUser();
  if (!user) { window.location.href = 'index.html'; return false; }
  if (PERFIS_ADMIN.includes(user.perfil)) return true;
  if (checkPerm(moduloId, acao)) return true;

  const acaoLabel = {
    view:      'visualizar',
    create:    'criar registros em',
    edit:      'editar registros em',
    delete:    'excluir registros de',
    export:    'exportar dados de',
    aprovar:   'aprovar registros em',
    cancelar:  'cancelar/rejeitar registros em',
    finalizar: 'finalizar registros em',
  }[acao] || acao;
  const modulo = MODULO_MAP.find(m => m.id === moduloId);
  toast(`Sem permissão para ${acaoLabel} ${modulo?.label || moduloId}.`, 'warning');
  return false;
}

// Regex que identifica botões de TROCA DE ABA pelas funções conhecidas.
const _TAB_FN_RE = /(?:showTab|switchEpiTab|funcTab)\(\s*'([^']+)'/;
function _abaDoBotao(el){
  const m = (el.getAttribute('onclick') || '').match(_TAB_FN_RE);
  return m ? m[1] : null;
}
// id da aba atualmente ativa (botão de aba com classe 'active').
function _abaAtiva(scope){
  scope = scope || document;
  const btn = [...scope.querySelectorAll('.active')].find(b => _abaDoBotao(b));
  return btn ? _abaDoBotao(btn) : null;
}

/**
 * Esconde as ABAS (telas) que o perfil não pode ver, de forma genérica,
 * para qualquer módulo cujo perfil tenha permissão por aba configurada.
 * Se a aba ativa for bloqueada, troca para a primeira aba permitida.
 * Não faz nada para perfis sem `abas` (retrocompat: libera tudo).
 */
function enforceTabs(moduloId, containerEl){
  if (!moduloId) return;
  const u = getUser();
  if (!u || PERFIS_ADMIN.includes(u.perfil)) return;
  const mp = (u.permissoes || {})[moduloId];
  if (!mp || !mp.abas) return;                 // sem config por aba → não restringe
  const scope = containerEl || document.getElementById('main-content') || document;
  const botoes = [...scope.querySelectorAll('button, a[onclick]')].filter(b => _abaDoBotao(b));
  if (!botoes.length) return;

  let firstAllowed = null, activeBloqueada = false;
  botoes.forEach(b => {
    const aba = _abaDoBotao(b);
    if (canTab(moduloId, aba)) {
      if (!firstAllowed) firstAllowed = b;
    } else {
      if (b.classList.contains('active')) activeBloqueada = true;
      b.style.display = 'none';
      // esconder também o painel (convenções "tab-<id>" ou "<id>")
      const p1 = document.getElementById('tab-' + aba);
      const p2 = document.getElementById(aba);
      if (p1) p1.style.display = 'none';
      if (p2 && p2 !== b) p2.style.display = 'none';
    }
  });
  if (activeBloqueada && firstAllowed) { try { firstAllowed.click(); } catch(e){} }
}

/**
 * Oculta botões de ação não autorizados. Agora é ESCOPADO À ABA ATIVA:
 * quando o módulo tem permissão por aba, usa checkPermTab(modulo, abaAtiva, acao),
 * evitando "vazar" botões de uma aba para outra. Reaplicável (faz reset antes).
 */
function applyActionGuards(moduloId, containerEl) {
  if (!moduloId || !containerEl) return;
  if (isAdmin()) return; // admin vê tudo

  const mp = (getUser()?.permissoes || {})[moduloId] || {};

  // Reset: reexibe o que ESTE guard ocultou anteriormente (permite reavaliar ao trocar de aba)
  containerEl.querySelectorAll('[data-blocked]').forEach(el => {
    el.style.display = '';
    el.removeAttribute('data-blocked');
  });

  const aba = mp.abas ? _abaAtiva(containerEl) : null;
  const pode = (acao) => (aba && mp.abas) ? checkPermTab(moduloId, aba, acao) : checkPerm(moduloId, acao);

  const patterns = [
    { regex: /exclu|delet|remov|apagar/i,                                         acao: 'delete'  },
    { regex: /aprov/i,                                                            acao: 'aprovar' },
    { regex: /edit|alter|modific/i,                                               acao: 'edit'    },
    { regex: /\bnov[oa]\b|criar|cadastr|adicion|inclu|inserir|\badd\b|salvar|gravar/i, acao: 'create' },
    { regex: /imprim|\.pdf|etiqueta|\bficha\b/i,                                    acao: 'imprimir'},
    { regex: /export|csv|baixar|download|planilha|xlsx/i,                          acao: 'export'  },
  ];

  containerEl.querySelectorAll('button, a[onclick]').forEach(el => {
    if (el.hasAttribute('data-perm') || el.hasAttribute('data-tab-perm')) return; // marcação explícita vence
    if (_abaDoBotao(el)) return;             // botões de aba são tratados por enforceTabs
    const sig = (el.getAttribute('onclick') || '') + ' ' + (el.textContent || '');
    for (const {regex, acao} of patterns) {
      if (regex.test(sig) && !pode(acao)) {
        el.style.display = 'none';
        el.setAttribute('data-blocked', acao);
        break;
      }
    }
  });
}

// ── SIDEBAR FILTRADA POR PERMISSÃO ────────────────────────
async function initSidebar(paginaAtiva) {
  // Resolver moduloId a partir do nome do arquivo (ex: 'producao.html' → 'producao')
  const moduloEntry = paginaAtiva ? MODULO_MAP.find(m => m.page === paginaAtiva) : null;
  const moduloId = moduloEntry ? moduloEntry.id : null;

  // Verificar auth + permissão de view para esta página
  const user = requireAuth(moduloId);
  if (!user) return;

  // Dados do usuário na topbar e sidebar
  const initials = (user.nome || 'SA').split(' ').map(x => x[0]).join('').substring(0, 2).toUpperCase();
  const setEl = (id, val) => { const el = document.getElementById(id); if (el) el.textContent = val; };
  setEl('sb-avatar',      initials);
  setEl('top-avatar',     initials);
  setEl('sb-user-name',   (user.nome || 'Super Admin').split(' ')[0]);
  setEl('top-user-name',  user.nome || 'Super Admin');
  setEl('sb-user-perfil', user.perfil || 'SADM');
  setEl('top-user-perfil', (user.perfil || 'SADM'));

  // Dados da empresa
  try {
    const { data } = await _supabase.from('empresa_config')
      .select('nome_fantasia,razao_social,logo').limit(1).maybeSingle();
    if (data) {
      setEl('sb-company-name', data.nome_fantasia || data.razao_social || 'ERP Industrial');
      if (data.logo) {
        const logoEl = document.getElementById('sb-logo');
        if (logoEl) logoEl.innerHTML = `<img src="${data.logo}" style="width:100%;height:100%;object-fit:cover;">`;
      }
    }
  } catch (e) {}

  // Construir sidebar filtrada por permissões
  _buildSidebar(user, paginaAtiva);

  // Aplicar restrições de UI baseadas em permissão
  applyPermUI();

  // Aplicar guards automáticos de aba + ação no conteúdo principal
  if (moduloId) {
    // Aguardar um tick para que o conteúdo dinâmico seja renderizado
    setTimeout(() => {
      const main = document.getElementById('main-content');
      enforceTabs(moduloId, main);                 // esconde abas não permitidas
      if (main) applyActionGuards(moduloId, main);

      // Re-aplicar quando conteúdo dinâmico for atualizado (fetch/render)
      const observer = new MutationObserver(() => {
        applyPermUI();
        if (main) applyActionGuards(moduloId, main);
      });
      if (main) observer.observe(main, { childList: true, subtree: true });

      // Reavaliar guards de ação ao TROCAR DE ABA (envolve as funções conhecidas)
      ['showTab', 'switchEpiTab', 'funcTab'].forEach(fn => {
        const orig = window[fn];
        if (typeof orig === 'function' && !orig.__permWrapped) {
          const wrapped = function(){
            const r = orig.apply(this, arguments);
            try { applyPermUI(); if (main) applyActionGuards(moduloId, main); } catch(e){}
            return r;
          };
          wrapped.__permWrapped = true;
          window[fn] = wrapped;
        }
      });
    }, 300);
  }

  // Aviso de acesso negado (vindo de redirecionamento)
  const denied = sessionStorage.getItem('erp_access_denied');
  if (denied) {
    sessionStorage.removeItem('erp_access_denied');
    const modulo = MODULO_MAP.find(m => m.id === denied);
    toast(`Acesso restrito: você não tem permissão para "${modulo?.label || denied}".`, 'warning');
  }
}

function _buildSidebar(user, paginaAtiva) {
  const sidebar = document.getElementById('sidebar');
  if (!sidebar) return;

  const nav = sidebar.querySelector('.sidebar-nav');
  if (!nav) return;

  // Determinar módulos visíveis
  const modulos = PERFIS_ADMIN.includes(user.perfil)
    ? MODULO_MAP
    : MODULO_MAP.filter(m => {
        const p = (user.permissoes || {})[m.id];
        return p && p.view;
      });

  // Agrupar
  const grupos = {};
  modulos.forEach(m => {
    if (!grupos[m.group]) grupos[m.group] = [];
    grupos[m.group].push(m);
  });

  // Limpar conteúdo de nav (mantém apenas os filhos que não são grupos)
  nav.innerHTML = '';

  const paginaAtualNorm = (paginaAtiva || window.location.pathname.split('/').pop() || '').toLowerCase();

  Object.entries(GROUP_LABELS).forEach(([groupId, groupLabel]) => {
    const itens = grupos[groupId];
    if (!itens || !itens.length) return;

    const temAtivo = itens.some(m => m.page === paginaAtualNorm);

    // Label do grupo
    const labelEl = document.createElement('div');
    labelEl.className = 'nav-group-label' + (temAtivo ? ' open' : '');
    labelEl.setAttribute('data-group', groupId);
    labelEl.setAttribute('onclick', `toggleGroup('${groupId}')`);
    labelEl.innerHTML = `<span>${groupLabel}</span><span class="group-arrow">▶</span>`;
    nav.appendChild(labelEl);

    // Items do grupo
    const groupEl = document.createElement('div');
    groupEl.className = 'nav-group-items' + (temAtivo ? ' open' : '');
    groupEl.id = 'group-' + groupId;
    itens.forEach(m => {
      const isActive = m.page === paginaAtualNorm;
      const a = document.createElement('a');
      a.className = 'nav-item' + (isActive ? ' active' : '');
      a.href = m.page;
      a.setAttribute('onclick', 'setActiveItem(this)');
      a.innerHTML = `<span class="nav-icon">${m.icon}</span><span class="nav-label">${m.label}</span>`;
      groupEl.appendChild(a);
    });
    nav.appendChild(groupEl);
  });
}

// ── SIDEBAR helpers ───────────────────────────────────────
let _sidebarCollapsed = false;

function toggleSidebar() {
  _sidebarCollapsed = !_sidebarCollapsed;
  ['sidebar','topbar','main-content'].forEach(id => {
    document.getElementById(id)?.classList.toggle('collapsed', _sidebarCollapsed);
  });
}

function toggleGroup(groupId) {
  const label = document.querySelector(`.nav-group-label[data-group="${groupId}"]`);
  const items = document.getElementById('group-' + groupId);
  if (!label || !items) return;
  const isOpen = label.classList.contains('open');
  if (isOpen && items.querySelector('.nav-item.active')) return;
  document.querySelectorAll('.nav-group-items').forEach(el => {
    if (el.id !== 'group-' + groupId && !el.querySelector('.nav-item.active'))
      el.classList.remove('open');
  });
  document.querySelectorAll('.nav-group-label').forEach(el => {
    const g = el.getAttribute('data-group');
    const gi = document.getElementById('group-' + g);
    if (g !== groupId && gi && !gi.querySelector('.nav-item.active')) el.classList.remove('open');
  });
  items.classList.toggle('open', !isOpen);
  label.classList.toggle('open', !isOpen);
}

function openGroup(grupo) {
  document.getElementById('group-' + grupo)?.classList.add('open');
  document.querySelector(`[data-group="${grupo}"]`)?.classList.add('open');
}

function setActiveItem(el) {
  document.querySelectorAll('.nav-item.active').forEach(i => i.classList.remove('active'));
  el.classList.add('active');
  const group = el.closest('.nav-group-items');
  if (group) {
    const gid = group.id.replace('group-', '');
    document.querySelector(`.nav-group-label[data-group="${gid}"]`)?.classList.add('open');
    group.classList.add('open');
  }
}

// ── TOAST ──────────────────────────────────────────────────
function toast(msg, type = 'success') {
  const icons = { success: '✅', danger: '❌', warning: '⚠️', info: 'ℹ️' };
  const el = document.createElement('div');
  el.className = 'toast ' + type;
  el.innerHTML = `<span>${icons[type] || 'ℹ️'}</span><span>${msg}</span>`;
  document.getElementById('toast-container')?.appendChild(el);
  setTimeout(() => el.remove(), 3500);
}

// ── MODAL ──────────────────────────────────────────────────
function closeModal(id) {
  document.getElementById(id)?.classList.add('hidden');
}
document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('.modal-overlay').forEach(el => {
    el.addEventListener('click', e => { if (e.target === el) el.classList.add('hidden'); });
  });
});

// ── AUTH ───────────────────────────────────────────────────
async function doLogout() {
  const user = getUser();
  try { await addLog('LOGOUT','AUTH', user?.id || 'unknown', 'Logout realizado'); } catch(e) {}
  sessionStorage.removeItem('erp_user');
  window.location.href = 'index.html';
}

/**
 * Carrega permissões do perfil do banco e salva no sessionStorage.
 * Chamado após login bem-sucedido.
 */
async function carregarPermissoesPerfil(user) {
  try {
    if (PERFIS_ADMIN.includes(user.perfil)) {
      // Admin: permissão total em todos os módulos
      const perms = {};
      MODULO_MAP.forEach(m => {
        const mp = { view:true, create:true, edit:true, delete:true, export:true };
        (MODULO_ACOES_EXTRAS[m.id] || []).forEach(a => { mp[a] = true; });
        perms[m.id] = mp;
      });
      user.permissoes = perms;
    } else {
      const { data, error } = await _supabase.from('perfis')
        .select('permissoes').eq('codigo', user.perfil).maybeSingle();

      if (data?.permissoes && Object.keys(data.permissoes).length > 0) {
        // Perfil encontrado no banco com permissões definidas
        user.permissoes = data.permissoes;
      } else {
        // Perfil não encontrado ou sem permissões configuradas no banco
        console.warn('Permissões não encontradas para perfil:', user.perfil, error?.message || '');
        user.permissoes = {};
      }
    }
    sessionStorage.setItem('erp_user', JSON.stringify(user));
  } catch(e) {
    console.warn('Erro ao carregar permissões:', e);
    // Manter permissões existentes se houver, senão objeto vazio
    if (!user.permissoes) user.permissoes = {};
    sessionStorage.setItem('erp_user', JSON.stringify(user));
  }
}

// ── AUDITORIA ──────────────────────────────────────────────
async function addLog(acao, modulo, registroId, descricao) {
  const user = getUser();
  // Monta descricao incluindo nome/perfil do usuário já no texto
  // (evita depender de colunas extras que podem não existir na tabela)
  const quem  = [user?.nome, user?.perfil].filter(Boolean).join(' / ') || 'sistema';
  const desc  = descricao ? String(descricao).slice(0, 490) + ` [${quem}]` : `[${quem}]`;
  try {
    const { error } = await _supabase.from('auditoria').insert({
      acao,
      modulo,
      registro_id:   registroId ? String(registroId).slice(0, 100) : null,
      descricao:     desc,
      usuario_email: user?.email || user?.nome || 'sistema',
    });
    if (error) console.warn('[addLog] Erro:', error.message, {acao, modulo});
  } catch(e) {
    console.warn('[addLog] Exceção:', e.message, {acao, modulo});
  }
}

// ── SHA256 ─────────────────────────────────────────────────
async function sha256(str) {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(str));
  return Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, '0')).join('');
}

// ── MÁSCARAS ───────────────────────────────────────────────
function mascaraCNPJ(el) {
  let v = el.value.replace(/\D/g, '').substring(0, 14);
  v = v.replace(/^(\d{2})(\d)/, '$1.$2')
       .replace(/^(\d{2})\.(\d{3})(\d)/, '$1.$2.$3')
       .replace(/\.(\d{3})(\d)/, '.$1/$2')
       .replace(/(\d{4})(\d)/, '$1-$2');
  el.value = v;
}
function mascaraCPF(el) {
  let v = el.value.replace(/\D/g, '').substring(0, 11);
  v = v.replace(/(\d{3})(\d)/, '$1.$2')
       .replace(/(\d{3})(\d)/, '$1.$2')
       .replace(/(\d{3})(\d{1,2})$/, '$1-$2');
  el.value = v;
}
function mascaraTel(el) {
  let v = el.value.replace(/\D/g, '').substring(0, 11);
  if (v.length > 10) v = v.replace(/(\d{2})(\d{5})(\d{4})/, '($1) $2-$3');
  else if (v.length > 6) v = v.replace(/(\d{2})(\d{4})(\d+)/, '($1) $2-$3');
  else if (v.length > 2) v = v.replace(/(\d{2})(\d+)/, '($1) $2');
  el.value = v;
}
function mascaraCEP(el) {
  let v = el.value.replace(/\D/g, '').substring(0, 8);
  v = v.replace(/(\d{5})(\d)/, '$1-$2');
  el.value = v;
}

// ── EXPORT CSV ─────────────────────────────────────────────
function exportarCSV(colunas, linhas, nomeArquivo) {
  const csv = [colunas, ...linhas]
    .map(r => r.map(c => `"${(c || '').toString().replace(/"/g, '""')}"`).join(','))
    .join('\n');
  const a = document.createElement('a');
  a.href = 'data:text/csv;charset=utf-8,\uFEFF' + encodeURIComponent(csv);
  a.download = nomeArquivo + '.csv';
  a.click();
}

// ── EXPORT PDF genérico ─────────────────────────────────────
function exportarPDF(titulo, colunas, linhas) {
  const empresa = document.getElementById('sb-company-name')?.textContent?.trim() || 'ERP Industrial';
  const logo    = document.querySelector('#sb-logo img')?.src || null;
  const logoHtml = logo
    ? `<img src="${logo}" style="height:48px;object-fit:contain;">`
    : `<div style="width:48px;height:48px;background:#042D4D;border-radius:8px;display:flex;align-items:center;justify-content:center;color:#fff;font-size:20px;">🏭</div>`;
  const html = `<!DOCTYPE html><html><head><meta charset="UTF-8"><style>
    body{font-family:sans-serif;padding:24px;color:#1e293b;}
    .cab{display:flex;align-items:center;gap:14px;padding-bottom:14px;border-bottom:2px solid #042D4D;margin-bottom:18px;}
    h2{color:#042D4D;margin-bottom:4px;font-size:15px;}
    .meta{font-size:11px;color:#64748b;margin-bottom:14px;}
    table{width:100%;border-collapse:collapse;}
    th{background:#042D4D;color:#fff;padding:9px 10px;text-align:left;font-size:11px;}
    td{padding:7px 10px;border-bottom:1px solid #e2e8f0;font-size:12px;}
    tr:nth-child(even) td{background:#f8fafc;}
    @media print{body{padding:12px;}}
  </style></head><body>
  <div class="cab">${logoHtml}<div><strong style="font-size:16px;color:#042D4D;">${empresa}</strong><br><span style="font-size:11px;color:#64748b;">ERP Industrial</span></div></div>
  <h2>${titulo}</h2>
  <p class="meta">Gerado em ${new Date().toLocaleString('pt-BR')} | Total: ${linhas.length} registros</p>
  <table><thead><tr>${colunas.map(c=>`<th>${c}</th>`).join('')}</tr></thead>
  <tbody>${linhas.map(r=>`<tr>${r.map(c=>`<td>${c||'—'}</td>`).join('')}</tr>`).join('')}</tbody></table>
  <script>setTimeout(()=>window.print(),400);<\/script>
  </body></html>`;
  const w = window.open('','_blank');
  w?.document.write(html);
  w?.document.close();
}

// ── MODAL FOTO ─────────────────────────────────────────────
function verFotoInline(src) {
  if (!src) return;
  let overlay = document.getElementById('foto-modal-overlay');
  if (!overlay) {
    overlay = document.createElement('div');
    overlay.id = 'foto-modal-overlay';
    overlay.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.85);z-index:9999;display:flex;align-items:center;justify-content:center;cursor:zoom-out;';
    overlay.onclick = () => overlay.remove();
    document.body.appendChild(overlay);
  }
  overlay.innerHTML = `<img src="${src}" style="max-width:90vw;max-height:90vh;border-radius:10px;box-shadow:0 8px 40px rgba(0,0,0,.6);">`;
  overlay.style.display = 'flex';
}
