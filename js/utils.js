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
  { id:'fechamento',     page:'fechamento.html',      label:'Fechamento Diário',    group:'principal',    icon:'📄' },
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
  { id:'painel_metas',   page:'painel-metas.html',    label:'Painel de Metas (TV)', group:'producao',     icon:'🎯' },
  { id:'desgaste',       page:'desgaste.html',        label:'Controle de Desgaste', group:'producao',     icon:'🔨' },
  { id:'aferidor',       page:'aferidor.html',        label:'Aferidor',             group:'producao',     icon:'🏷️' },
  { id:'ensacadeiras',   page:'ensacadeiras.html',    label:'Ensacadeiras',         group:'producao',     icon:'⚖️' },
  { id:'custo_precificacao', page:'custo-precificacao.html', label:'Custo & Precificação', group:'producao', icon:'💵' },
  { id:'felisbina',      page:'felisbina.html',       label:'Felisbina',            group:'producao',     icon:'🏪' },
  // QUALIDADE
  { id:'laboratorio',    page:'laboratorio.html',     label:'Laboratório',          group:'qualidade',    icon:'🧪' },
  { id:'bpf',            page:'bpf.html',             label:'BPF',                  group:'qualidade',    icon:'📋' },
  { id:'qualidade',      page:'qualidade.html',       label:'Central da Qualidade', group:'qualidade',    icon:'🎯' },
  // OPERAÇÕES
  { id:'manutencao',     page:'manutencao.html',      label:'Manutenção',           group:'operacoes',    icon:'🔧' },
  { id:'frota',          page:'frota.html',           label:'Frota',                group:'operacoes',    icon:'🚜' },
  { id:'abastecimento',  page:'abastecimento.html',   label:'Abastecimento',        group:'operacoes',    icon:'⛽' },
  { id:'terceiros',      page:'terceiros.html',       label:'Serviços de Terceiros',group:'operacoes',    icon:'🤝' },
  // SUPRIMENTOS
  { id:'insumos',        page:'insumos.html',         label:'Insumos & MP',         group:'suprimentos',  icon:'🌿' },
  { id:'almoxarifado',   page:'almoxarifado.html',    label:'Almoxarifado',         group:'suprimentos',  icon:'📦' },
  { id:'solicitacoes',   page:'solicitacoes.html',    label:'Solicitações',         group:'suprimentos',  icon:'📝' },
  { id:'compras',        page:'compras.html',         label:'Compras',              group:'suprimentos',  icon:'🛒' },
  { id:'lenha',          page:'lenha.html',           label:'Lenha',                group:'suprimentos',  icon:'🪵' },
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
  { id:'ferias',         page:'ferias.html',          label:'Férias',               group:'rh',           icon:'🏖️' },
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
  finalizar:'Finalizar/Concluir', imprimir:'Imprimir/PDF', assinar:'Assinar/Validar',
};

// Ações EXTRAS por módulo, acrescentadas às de aba (ex.: fluxos de aprovação).
const MODULO_ACOES_EXTRAS = {
  ferias:       ['imprimir'],
  almoxarifado: ['cancelar', 'finalizar'],
  compras:      ['cancelar', 'finalizar'],
  aprovacoes:   ['cancelar', 'finalizar'],
  solicitacoes: ['aprovar', 'cancelar'],
  // Laboratório → aba Caulim: quem ASSINA (valida) as análises externas.
  // O banco confere a mesma permissão (auth_pode_acao, migração 039).
  laboratorio:  ['assinar'],
};
// Ações disponíveis para as abas de um módulo (base de aba + extras).
// Módulos cujas "telas" são só para VER (não têm criar/editar/excluir):
// no perfis.html aparece só a caixa "Ver" em cada uma.
const MODULO_SO_VER = ['dashboard'];
function acoesDaAba(moduloId) {
  if (MODULO_SO_VER.includes(moduloId)) return ['view'];
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
// ⚠️ Este catálogo é a fonte que o perfis.html desenha e que enforceTabs() usa
// para ESCONDER aba ausente. Aba que existe na tela e falta aqui desaparece
// para todo perfil não-admin; aba listada aqui que não existe mais na tela
// aparece no perfis.html como opção fantasma. Ao criar/remover/renomear uma
// aba num módulo, atualize a lista dele aqui no MESMO commit.
// Conferido contra os botões reais (showTab/switchEpiTab/funcTab/switchRhTab)
// em 20/08/2026.
const MODULO_FUNCIONALIDADES = {
  // Abas reais de cada módulo — extraídas dos próprios arquivos.
  // Módulo que não aparece aqui tem permissão só no nível do módulo (tela única).
  // Dashboard: cada seção do "Exibir" (VIEW_SECTIONS em dashboard.html — os ids
  // são as chaves de lá). Seção desmarcada no perfil some do dashboard e do Exibir.
  dashboard: [
    { id:'linhaagora', label:'🔬 Como a linha está' },
    { id:'custoalvo',  label:'💰 Custo & Alvo' },
    { id:'kpis',       label:'📈 Indicadores' },
    { id:'linhas',     label:'🏭 Linhas' },
    { id:'alertas',    label:'🔔 Alertas' },
    { id:'fila',       label:'🚛 Portaria' },
    { id:'grafico',    label:'📊 Gráfico' },
    { id:'oee',        label:'⚙️ OEE' },
    { id:'comp',       label:'📅 Comparativo' },
    { id:'resumo',     label:'🗂️ Resumo por área' },
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
    { id:'limpeza', label:'🧼 Produtos de Limpeza' },
    { id:'movimentos', label:'🔄 Movimentos' },
    { id:'relatorio', label:'📊 Relatório' },
    { id:'previsao', label:'🔮 Previsão' },
  ],
  carregamento: [
    { id:'estoque', label:'🏭 Estoque' },
    { id:'ordens', label:'🚛 Carregamento' },
    { id:'carregados', label:'✅ Carregados' },
    { id:'mes', label:'📆 Mês' },
    { id:'barracoes', label:'⚙️ Barracões' },
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
    { id:'nc', label:'⚠️ Não Conformidades' },
    { id:'indicadores', label:'📈 Indicadores' },
    { id:'auditoria', label:'🛡️ Auditoria' },
  ],
  custo_precificacao: [
    { id:'resumo', label:'📊 Resumo' },
    { id:'config', label:'📅 Capacidade' },
    { id:'metas', label:'🎯 Metas & Produção' },
    { id:'linha', label:'⚙️ Configuração da Linha' },
    { id:'custos', label:'🧾 Custos & Resultado' },
    { id:'impacto', label:'🧪 Impacto' },
    { id:'geral', label:'📋 Geral' },
    { id:'real', label:'⚖️ Planejado x Realizado' },
  ],
  desgaste: [
    { id:'resumo',   label:'📊 Resumo' },
    { id:'martelos', label:'🔨 Martelos' },
    { id:'eixos',    label:'⚙️ Eixos' },
    { id:'grelhas',  label:'🔲 Grelhas' },
    { id:'gavetas',  label:'🗄️ Gavetas' },
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
  aferidor: [
    { id:'rotulos', label:'🏷️ Rótulos' },
    { id:'amostras', label:'🧪 Amostras' },
    { id:'aditivacao', label:'🧾 Registro Diário — Aditivação' },
  ],
  insumos: [
    { id:'resumo', label:'📊 Resumo' },
    { id:'estoque', label:'📦 Estoque' },
    { id:'movs', label:'🔄 Movimentos' },
    { id:'ficha', label:'🧬 Ficha Técnica' },
    { id:'lotes', label:'🏷️ Lotes' },
    { id:'entradas', label:'🚚 Entradas de MP' },
    { id:'dia', label:'📅 Dia' },
    { id:'mes', label:'🗓️ Mês' },
    { id:'inventario', label:'🧮 Inventário' },
    { id:'fechamento', label:'📄 Ficha Diária' },
  ],
  producao: [
    { id:'tab-linhas', label:'🏭 Por Linha' },
    { id:'tab-metas', label:'🎯 Meta por Encarregado' },
    { id:'tab-indicadores', label:'📊 Indicadores' },
    { id:'tab-produtos', label:'📦 Por Produto' },
  ],
  epi: [
    { id:'tab-fichas', label:'📋 Fichas por Funcionário' },
    { id:'tab-cadastro', label:'📦 Cadastro de EPIs' },
    { id:'tab-alertas', label:'⚠️ Painel de Alertas' },
    { id:'tab-treinamentos', label:'🎓 Treinamentos' },
    { id:'tab-inativos', label:'⚫ Inativos' },
  ],
  expedicao: [
    { id:'ordens', label:'📋 Ordens' },
    { id:'pedidos', label:'📄 Pedidos' },
    { id:'relatorio', label:'📊 Relatório' },
  ],
  frota: [
    { id:'os', label:'📋 Ordens de Serviço' },
    { id:'cadastro', label:'🚜 Equipamentos' },
    { id:'empresas', label:'🏢 Empresas / Mecânicos' },
    { id:'kpis', label:'📊 Custos & KPIs' },
  ],
  funcionarios: [
    { id:'cad', label:'📋 Cadastro' },
    { id:'cert', label:'🎓 Capacitações / Certificações' },
    { id:'custo', label:'💰 Custos' },
  ],
  laboratorio: [
    { id:'analises', label:'📋 Análises' },
    { id:'afericoes', label:'⚙️ Aferições' },
    { id:'pallets', label:'📦 Análise de Pallets' },
    { id:'ensaios', label:'🧪 Ensaios & Limites' },
    { id:'entrada', label:'📥 Entrada (CAI)' },
    { id:'caulim', label:'🪨 Caulim' },
    { id:'laudo', label:'📜 Laudo' },
    { id:'correcoes', label:'✏️ Correções' },
  ],
  manutencao: [
    { id:'cronograma', label:'📅 Cronograma' },
    { id:'monitor', label:'🖥️ Monitor' },
    { id:'motores', label:'⚡ Motores Elétricos' },
    { id:'historico', label:'📋 Ordens de Serviço' },
    { id:'kanban', label:'🗂️ Kanban' },
    { id:'agenda', label:'🗓️ Agenda' },
    { id:'docs', label:'📁 Documentação' },
    { id:'prev', label:'🔧 Preventiva' },
    { id:'kpis', label:'📊 KPIs' },
  ],
  ensacadeiras: [
    { id:'aovivo', label:'🎯 Ao vivo' },
    { id:'historico', label:'📋 Histórico' },
    { id:'turnos', label:'🕐 Turnos' },
    { id:'amostras', label:'🧪 Amostras' },
    { id:'niveis', label:'🎚️ Níveis' },
    { id:'config', label:'⚙️ Configuração' },
  ],
  felisbina: [
    { id:'lancamento', label:'📝 Lançamento do dia' },
    { id:'grade', label:'🗓️ Grade do mês' },
    { id:'estoque', label:'📦 Estoque' },
    { id:'movimentos', label:'📋 Movimentos' },
    { id:'resumo', label:'📊 Resumos' },
    { id:'cadastro', label:'⚙️ Cadastro & Ficha' },
  ],
  lenha: [
    { id:'recebimentos', label:'📥 Recebimentos' },
    { id:'fechamentos', label:'📅 Fechamentos' },
    { id:'fornecedores', label:'🌲 Fornecedores & Motoristas' },
  ],
  perfis: [
    { id:'cards', label:'🃏 Cards' },
    { id:'matrix', label:'📋 Matriz' },
  ],
  rh: [
    { id:'tab-escalas', label:'🗓️ Escalas' },
    { id:'tab-folha',   label:'📋 Folha de Pagamento' },
  ],
  solicitacoes: [
    { id:'solicitacao', label:'📝 Solicitação' },
    { id:'aprovacao', label:'✅ Aprovação' },
    { id:'monitor', label:'📺 Monitor' },
    { id:'recebimentos', label:'📥 Recebimentos' },
  ],
  terceiros: [
    { id:'prestadores', label:'🤝 Prestadores' },
    { id:'remessas', label:'📤 Remessas' },
    { id:'servicos', label:'🧾 Serviços' },
    { id:'fechamento', label:'📅 Fechamento Mensal' },
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
  const t = mp.abas[abaId];
  // Mesma regra do checkPermTab: aba sem registro é aba criada DEPOIS que o
  // perfil foi salvo — herda o acesso do módulo em vez de sumir calada.
  if (!t) return !!mp.view;
  return !!t.view;
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
    // Aba SEM registro no perfil = aba criada depois que o perfil foi salvo.
    // Antes isso era tratado como "negado" e a aba nova sumia calada para todo
    // mundo — foi o que aconteceu com as telas novas do EPI. Agora ela herda o
    // que o perfil já tem no módulo, e só fica negada quando alguém realmente
    // desmarcou (aí existe registro, com view:false).
    if (!t) return !!mp.view && (acao === 'view' ? true : !!mp[acao]);
    if (!t.view) return false;
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
  // Central da Qualidade: quem abre BPF ou Laboratório abre a Central (vale até para sessão antiga)
  if (moduloId==='qualidade' && !perms.qualidade) return _modAgg(perms.bpf, 'view') || _modAgg(perms.laboratorio, 'view');
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
  const temAcesso = (perms[moduloId] && perms[moduloId].view)
    || (moduloId==='qualidade' && ((perms.bpf&&perms.bpf.view)||(perms.laboratorio&&perms.laboratorio.view)));

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
/* O <aside> da sidebar NÃO está no HTML dos módulos: cada página faz
   fetch('partials/sidebar.html') e injeta em #sidebar-container — e chama
   initSidebar() na linha seguinte, sem esperar o fetch. Quem preenchesse os
   campos antes disso escrevia em elemento inexistente e o texto de exemplo do
   partial ("Super Admin / SADM") ficava na tela como se fosse o usuário logado.
   Isto espera o nó existir. Se nunca chegar, AVISA em vez de seguir calado. */
function _esperarSidebar(timeoutMs) {
  timeoutMs = timeoutMs || 4000;
  return new Promise(resolve => {
    if (document.getElementById('sidebar')) return resolve(true);
    const ini = Date.now();
    const timer = setInterval(() => {
      if (document.getElementById('sidebar')) { clearInterval(timer); resolve(true); }
      else if (Date.now() - ini > timeoutMs) {
        clearInterval(timer);
        console.warn('[sidebar] partials/sidebar.html não chegou em ' + timeoutMs +
                     'ms — menu, usuário e empresa ficam sem preencher.');
        resolve(false);
      }
    }, 30);
  });
}

async function initSidebar(paginaAtiva) {
  // Resolver moduloId a partir do nome do arquivo (ex: 'producao.html' → 'producao')
  const moduloEntry = paginaAtiva ? MODULO_MAP.find(m => m.page === paginaAtiva) : null;
  const moduloId = moduloEntry ? moduloEntry.id : null;

  // Verificar auth + permissão de view para esta página
  const user = requireAuth(moduloId);
  if (!user) return;

  // A sidebar chega por fetch — sem esperar, o rodapé dela ficava com o nome
  // de exemplo do partial em vez do usuário de verdade.
  await _esperarSidebar();
  try{ AvisosQualidade.iniciar(); }catch(e){}

  // Dados do usuário na topbar e no rodapé da sidebar.
  // Nada de default 'Super Admin'/'SADM': se o dado faltar, mostra '—' e não
  // um nome plausível que não é o de quem está logado.
  const initials = (user.nome || '?').split(' ').map(x => x[0]).join('').substring(0, 2).toUpperCase();
  const setEl = (id, val) => { const el = document.getElementById(id); if (el) el.textContent = val; };
  { const av = document.getElementById('sb-avatar'); if (av) av.innerHTML = initials + '<span class="sb-online" title="Online"></span>'; }
  setEl('top-avatar',     initials);
  setEl('sb-user-name',   (user.nome || '—').split(' ')[0]);
  setEl('top-user-name',  user.nome || '—');
  setEl('sb-user-perfil', user.perfil || '—');
  setEl('top-user-perfil', (user.perfil || '—'));

  // Dados da empresa
  try {
    const { data } = await _supabase.from('empresa_config')
      .select('*').limit(1).maybeSingle();
    if (data) {
      window._ERP_EMPRESA = data;   // usado no cabeçalho dos PDFs (exportarPDF)
      setEl('sb-company-name', data.nome_fantasia || data.razao_social || 'Silicate Indústria');
      if (data.logo) {
        const logoEl = document.getElementById('sb-logo');
        if (logoEl) logoEl.innerHTML = `<img src="${data.logo}" style="width:100%;height:100%;object-fit:cover;">`;
      }
    }
  } catch (e) {}

  // Construir sidebar filtrada por permissões
  _buildSidebar(user, paginaAtiva);

  // Só agora a sidebar existe no DOM (ela chega por fetch de partials/sidebar.html),
  // então este é o único ponto em que dá para aplicar o colapso salvo com segurança.
  _erpAplicarSidebar();

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
  if (!sidebar) { console.warn('[sidebar] #sidebar ausente — menu não construído.'); return; }

  const nav = sidebar.querySelector('.sidebar-nav');
  if (!nav) { console.warn('[sidebar] .sidebar-nav ausente — menu não construído.'); return; }

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
      a.innerHTML = `<span class="nav-icon">${m.icon}</span><span class="nav-label">${m.label}</span><button type="button" class="nav-star${_sbFavs().includes(m.page)?' on':''}" title="Fixar nos favoritos" aria-label="Favorito" onclick="event.preventDefault();event.stopPropagation();sbFav('${m.page}')">${_sbFavs().includes(m.page)?'★':'☆'}</button>`;
      a.dataset.busca = (m.label + ' ' + (GROUP_LABELS[groupId] || '')).normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
      groupEl.appendChild(a);
    });
    nav.appendChild(groupEl);
  });
  _sbMods = modulos; _sbPagina = paginaAtualNorm;
  _sbRenderFavs(); _sbPrepararBusca();
  try { const b = document.getElementById('sb-som'); if (b) b.classList.toggle('mudo', typeof somDesligado === 'function' && somDesligado()); } catch (e) {}
}
/* ── menu: favoritos, busca (Ctrl K) e som ── */
let _sbMods = [], _sbPagina = '';
function _sbFavs() { try { return JSON.parse(localStorage.getItem('sb_favs') || '[]'); } catch (e) { return []; } }
function sbFav(page) {
  let f = _sbFavs(); f = f.includes(page) ? f.filter(x => x !== page) : f.concat(page).slice(-5);
  try { localStorage.setItem('sb_favs', JSON.stringify(f)); } catch (e) {}
  document.querySelectorAll('.nav-item').forEach(a => { const st = a.querySelector('.nav-star'); if (!st) return; const on = f.includes(a.getAttribute('href')); st.classList.toggle('on', on); st.textContent = on ? '★' : '☆'; });
  _sbRenderFavs();
}
function _sbRenderFavs() {
  const box = document.getElementById('sb-favs-box'), el = document.getElementById('sb-favs'); if (!box || !el) return;
  const favs = _sbFavs().map(p => _sbMods.find(m => m.page === p)).filter(Boolean);
  box.style.display = favs.length ? '' : 'none';
  el.innerHTML = favs.map(m => `<a class="sb-fav${m.page === _sbPagina ? ' on' : ''}" href="${m.page}">${m.label}</a>`).join('');
}
function _sbPrepararBusca() {
  const inp = document.getElementById('sb-busca'); if (!inp || inp._ok) return; inp._ok = true;
  const norm = t => String(t || '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().trim();
  inp.addEventListener('input', () => {
    const q = norm(inp.value);
    document.querySelectorAll('#sidebar-nav .nav-group-items').forEach(g => {
      let algum = false;
      g.querySelectorAll('.nav-item').forEach(a => { const ok = !q || (a.dataset.busca || '').includes(q); a.classList.toggle('sb-oculto', !ok); if (ok) algum = true; });
      const lab = document.querySelector(`.nav-group-label[data-group="${g.id.replace('group-', '')}"]`);
      if (q) { g.classList.add('open'); if (lab) lab.classList.toggle('sb-oculto', !algum); }
      else { if (lab) lab.classList.remove('sb-oculto'); g.classList.toggle('open', !!g.querySelector('.nav-item.active') || (lab && lab.classList.contains('open'))); }
    });
  });
  inp.addEventListener('keydown', e => {
    if (e.key === 'Enter') { const a = document.querySelector('#sidebar-nav .nav-item:not(.sb-oculto)'); if (a) location.href = a.getAttribute('href'); }
    if (e.key === 'Escape') { inp.value = ''; inp.dispatchEvent(new Event('input')); inp.blur(); }
  });
}
document.addEventListener('keydown', e => {
  if ((e.ctrlKey || e.metaKey) && (e.key === 'k' || e.key === 'K')) {
    const inp = document.getElementById('sb-busca'); if (!inp) return; e.preventDefault();
    const sb = document.getElementById('sidebar'); if (sb && sb.classList.contains('collapsed') && typeof toggleSidebar === 'function') toggleSidebar();
    setTimeout(() => inp.focus(), 60);
  }
});
// botão de som do rodapé: abre o controle (ligar/desligar + volume)
function sbSom(ev) {
  const old = document.getElementById('sb-som-pop'); if (old) { old.remove(); return; }
  const r = ev.currentTarget.getBoundingClientRect();
  const pop = document.createElement('div'); pop.id = 'sb-som-pop'; pop.className = 'sb-som-pop';
  pop.style.left = Math.max(8, r.left - 120) + 'px'; pop.style.bottom = (window.innerHeight - r.top + 8) + 'px';
  document.body.appendChild(pop);
  try { montarControleSom(pop); } catch (e) {}
  const fechar = e2 => { if (!pop.contains(e2.target) && e2.target !== ev.currentTarget) { pop.remove(); document.removeEventListener('mousedown', fechar); } };
  setTimeout(() => document.addEventListener('mousedown', fechar), 0);
}
window.addEventListener('erp-som', () => { const b = document.getElementById('sb-som'); if (b) b.classList.toggle('mudo', somDesligado()); });

// ── SIDEBAR helpers ───────────────────────────────────────
let _sidebarCollapsed = false;

// Estado inicial aplicado ANTES do primeiro paint: utils.js é carregado de forma
// síncrona no <head>, então .sb-boot entra no <html> antes do body existir e a
// página já nasce com o menu recolhido, sem piscar. Quem troca essa classe pelas
// classes reais é o _erpAplicarSidebar(), quando a sidebar já está no DOM.
(function () {
  try {
    if (localStorage.getItem('sb_collapsed') === '1') {
      document.documentElement.classList.add('sb-boot');
    }
  } catch (e) {}
})();

// Fonte única do breakpoint. Espelha o @media (max-width: 900px) do style.css,
// que é onde vivem as regras da gaveta mobile (.sidebar.mobile-open).
function _isMobileLayout() {
  return window.matchMedia('(max-width: 900px)').matches;
}

// Cria (uma vez só) o fundo escuro que aparece atrás da gaveta no celular
function _getSidebarBackdrop() {
  let bd = document.getElementById('sidebar-backdrop');
  if (!bd) {
    bd = document.createElement('div');
    bd.id = 'sidebar-backdrop';
    bd.className = 'sidebar-backdrop';
    bd.addEventListener('click', closeMobileSidebar);
    document.body.appendChild(bd);
  }
  return bd;
}

function openMobileSidebar() {
  document.getElementById('sidebar')?.classList.add('mobile-open');
  _getSidebarBackdrop().classList.add('show');
  document.body.style.overflow = 'hidden';   // trava o scroll do fundo
}

function closeMobileSidebar() {
  document.getElementById('sidebar')?.classList.remove('mobile-open');
  document.getElementById('sidebar-backdrop')?.classList.remove('show');
  document.body.style.overflow = '';
}

// Lê a preferência salva e a aplica aos três elementos do layout.
// Chamado pelo initSidebar() logo depois do _buildSidebar(): a sidebar chega por
// fetch de partials/sidebar.html e ainda não existe no DOMContentLoaded.
function _erpAplicarSidebar() {
  let salvo = '0';
  try { salvo = localStorage.getItem('sb_collapsed') || '0'; } catch (e) {}
  _sidebarCollapsed = (salvo === '1') && !_isMobileLayout();

  const ids = ['sidebar', 'topbar', 'main-content'];
  const els = ids.map(id => document.getElementById(id));
  const faltando = ids.filter((id, i) => !els[i]);

  // Aplicar só numa parte deixa o layout incoerente (topbar e main recolhidos com
  // a sidebar aberta por cima). Se faltar alguém, não mexe em nada e deixa o
  // .sb-boot segurando o estado visual — e avisa, em vez de falhar em silêncio.
  if (faltando.length) {
    console.warn('[sidebar] estado colapsado não aplicado, elemento(s) ausente(s):', faltando.join(', '));
    return;
  }

  // Troca sb-boot pelas classes reais no MESMO tick: sem paint no meio, sem piscar.
  els.forEach(el => el.classList.toggle('collapsed', _sidebarCollapsed));
  document.documentElement.classList.remove('sb-boot');
}

function toggleSidebar() {
  // No celular/tablet: abre/fecha a gaveta com fundo escuro
  if (_isMobileLayout()) {
    const sb = document.getElementById('sidebar');
    if (sb && sb.classList.contains('mobile-open')) closeMobileSidebar();
    else openMobileSidebar();
    return;
  }
  // No PC: recolhe/expande o menu e grava a preferência
  _sidebarCollapsed = !_sidebarCollapsed;
  try { localStorage.setItem('sb_collapsed', _sidebarCollapsed ? '1' : '0'); } catch (e) {}
  ['sidebar','topbar','main-content'].forEach(id => {
    document.getElementById(id)?.classList.toggle('collapsed', _sidebarCollapsed);
  });
}

// Ao girar/redimensionar a tela, evita que a gaveta ou o colapso fiquem "presos".
// Debounce para não reavaliar a cada pixel do arrasto.
let _erpRz;
window.addEventListener('resize', () => {
  clearTimeout(_erpRz);
  _erpRz = setTimeout(() => {
    if (!_isMobileLayout()) closeMobileSidebar();
    _erpAplicarSidebar();   // no mobile isso já limpa o .collapsed
  }, 120);
});

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
  try { await _supabase.auth.signOut(); } catch(e) {}
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

// ── DB: query que nunca esconde erro ───────────────────────
// Uso: const {data} = await db(_supabase.from('x').select('*'), 'carregar x');
// Retorna o MESMO {data, error} do supabase — não muda o fluxo, só torna o erro visível.
async function db(promise, contexto) {
  const res = await promise;
  if (res && res.error) {
    console.error('[db]' + (contexto ? ' ' + contexto : '') + ':', res.error.message || res.error);
    try { toast('Falha' + (contexto ? ' em ' + contexto : '') + ': ' + (res.error.message || res.error), 'danger'); } catch (e) {}
  }
  return res;
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

// ── BPF · trava de fornecedor de embalagem (POP-01) ──────────────────────
// Usada no Compras (pedido) e nas Solicitações (recebimento). A configuração
// fica no BPF → POP-01 → ⚙️: ligada/desligada, modo (bloquear/avisar), onde age,
// quais embalagens entram no BPF e quem pode liberar exceção.
const _bpfNorm=s=>String(s||'').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/[^a-z0-9]/g,'');
async function bpfAvisar(titulo,descricao,chave,pop){
  let dest=[];
  try{ const {data}=await _supabase.rpc('bpf_pessoas_pop',{p_pop:pop||'POP-01',p_papeis:['aviso','libera','responsavel']}); dest=data||[]; }catch(e){}
  try{ await _supabase.from('notificacoes').insert({tipo:'urgente',modulo:'bpf',titulo,descricao,chave:chave||null,fonte:'bpf',destinatarios:dest}); }catch(e){}
}

// ── AVISOS PESSOAIS (Central da Qualidade) ───────────────────────────────
// Em QUALQUER tela do ERP: confere a cada 60 s se chegou aviso com o nome do
// usuário (notificacoes.destinatarios). Chegou → som + aviso na tela + aviso do
// sistema (quando a aba está em segundo plano). Urgente toca 3 vezes.
// Também dispara a checagem de fichas atrasadas (bpf_notificar_atrasos).
// ── SOM DO SISTEMA: um único "mudo" para todos os avisos sonoros ──
// Desligado pelo sino das Linhas (erp_alerta_som='off') ou em Notificações → Som e avisos (som:false)
// → nenhum aviso toca, em nenhuma tela. Ligar em um lugar liga nos dois.
function somDesligado(){
  try{ if(localStorage.getItem('erp_alerta_som')==='off')return true;
       const p=JSON.parse(localStorage.getItem('erp_notif_prefs')||'{}'); return p.som===false; }catch(e){ return false; }
}
function volumeSom(){ try{ const v=Number(JSON.parse(localStorage.getItem('erp_notif_prefs')||'{}').volume); return v>0&&v<=1?v:0.8; }catch(e){ return 0.8; } }
function definirVolume(v){ try{ const p=JSON.parse(localStorage.getItem('erp_notif_prefs')||'{}'); p.volume=Math.max(0.1,Math.min(1,Number(v)||0.8)); localStorage.setItem('erp_notif_prefs',JSON.stringify(p));
  window.dispatchEvent(new Event('erp-volume')); }catch(e){} }
function definirSom(ligado){
  try{ localStorage.setItem('erp_alerta_som',ligado?'on':'off');
       const p=JSON.parse(localStorage.getItem('erp_notif_prefs')||'{}'); p.som=!!ligado; localStorage.setItem('erp_notif_prefs',JSON.stringify(p)); }catch(e){}
  window.dispatchEvent(new Event('erp-som'));
}
// Controle de som pronto para qualquer tela: [🔔/🔕] [🔈━━━🔊] 80%  — liga/desliga e volume de TODOS os avisos
function montarControleSom(el){
  if(!el)return;
  const pintar=()=>{const off=somDesligado(),v=volumeSom();
    el.innerHTML=`<span class="cs-box${off?' off':''}" title="Som dos avisos do sistema (vale para todas as telas deste aparelho)">
      <button type="button" class="cs-bt">${off?'🔕 Som desligado':'🔔 Som ligado'}</button>
      <input type="range" class="cs-vol" min="0.1" max="1" step="0.1" value="${v}" ${off?'disabled':''} aria-label="Volume dos avisos">
      <b class="cs-pc">${off?'—':Math.round(v*100)+'%'}</b></span>`;
    el.querySelector('.cs-bt').onclick=()=>{definirSom(somDesligado());if(!somDesligado()&&window.AvisosQualidade)AvisosQualidade.bip(false,true);};
    const r=el.querySelector('.cs-vol');r.oninput=()=>{definirVolume(r.value);el.querySelector('.cs-pc').textContent=Math.round(r.value*100)+'%';};
    r.onchange=()=>{if(window.AvisosQualidade)AvisosQualidade.bip(false,true);};};
  if(!document.getElementById('cs-css')){const st=document.createElement('style');st.id='cs-css';st.textContent=`.cs-box{display:inline-flex;align-items:center;gap:8px;border:1.5px solid #e2e8f0;border-radius:12px;padding:4px 10px 4px 4px;background:#fff}
.cs-box.off{background:#fef2f2;border-color:#fecaca}.cs-bt{border:0;background:#ecfdf5;color:#166534;border-radius:9px;padding:7px 10px;font-family:inherit;font-weight:700;font-size:12.5px;cursor:pointer;white-space:nowrap}
.cs-box.off .cs-bt{background:#fee2e2;color:#b91c1c}.cs-vol{width:96px;accent-color:#042D4D}.cs-pc{font-size:12px;color:#042D4D;min-width:34px}`;document.head.appendChild(st);}
  pintar();window.addEventListener('erp-som',pintar);
  window.addEventListener('erp-volume',()=>{const r=el.querySelector('.cs-vol');if(r&&document.activeElement!==r){r.value=volumeSom();el.querySelector('.cs-pc').textContent=somDesligado()?'—':Math.round(volumeSom()*100)+'%';}});window.addEventListener('storage',e=>{if(/erp_alerta_som|erp_notif_prefs/.test(e.key||''))pintar();});
}
const AvisosQualidade=(()=>{
  let timer=null,ctx=null;
  const chaveVistos=()=>'erp_avisos_vistos_'+((getUser()||{}).nome||'');
  const vistos=()=>{try{return new Set(JSON.parse(localStorage.getItem(chaveVistos())||'[]'));}catch(e){return new Set();}};
  const salvarVistos=s=>{try{localStorage.setItem(chaveVistos(),JSON.stringify([...s].slice(-400)));}catch(e){}};
  function bip(urgente,forcar){
    // respeita o mudo do sistema; e onde o aviso de notificações já toca (Início), não toca de novo
    if(!forcar&&(somDesligado()||window.AvisoNotif))return;
    try{
      const AC=window.AudioContext||window.webkitAudioContext;if(!AC)return;
      ctx=ctx||new AC(); if(ctx.state==='suspended')ctx.resume();
      const toca=(t0,f)=>{const o=ctx.createOscillator(),g=ctx.createGain();o.type='square';o.frequency.value=f;
        g.gain.setValueAtTime(0.0001,ctx.currentTime+t0);g.gain.exponentialRampToValueAtTime(Math.max(0.02,volumeSom()),ctx.currentTime+t0+0.02);
        g.gain.exponentialRampToValueAtTime(0.0001,ctx.currentTime+t0+0.35);o.connect(g);g.connect(ctx.destination);o.start(ctx.currentTime+t0);o.stop(ctx.currentTime+t0+0.4);};
      const n=urgente?4:2; for(let i=0;i<n;i++){toca(i*0.8,880);toca(i*0.8+0.18,1320);toca(i*0.8+0.36,1760);}
    }catch(e){}
  }
  function avisoSistema(n){
    try{ if(document.hidden&&'Notification' in window&&Notification.permission==='granted')
      new Notification(n.titulo||'Aviso da Qualidade',{body:n.descricao||'',icon:'icons/icon-192.png',tag:n.id}); }catch(e){}
  }
  async function conferir(){
    const u=getUser(); if(!u||!u.nome) return;
    try{
      const ultimaAtraso=+(localStorage.getItem('erp_atrasos_ts')||0);
      if(Date.now()-ultimaAtraso>5*60*1000){ localStorage.setItem('erp_atrasos_ts',String(Date.now())); _supabase.rpc('bpf_notificar_atrasos').then(()=>{},()=>{}); }
      const desde=new Date(Date.now()-3*864e5).toISOString();
      const {data}=await _supabase.from('notificacoes').select('id,tipo,titulo,descricao,created_at')
        .contains('destinatarios',[u.nome]).gte('created_at',desde).order('created_at',{ascending:false}).limit(30);
      const vs=vistos(); const novos=(data||[]).filter(n=>!vs.has(n.id));
      const badge=document.getElementById('sb-badge-qualidade');
      if(badge){badge.textContent=novos.length||'';badge.style.display=novos.length?'':'none';}
      const avisados=JSON.parse(sessionStorage.getItem('erp_avisos_tocados')||'[]');
      const tocar=novos.filter(n=>!avisados.includes(n.id));
      if(tocar.length){
        bip(tocar.some(n=>n.tipo==='urgente'));
        tocar.slice(0,3).forEach(n=>{ if(typeof toast==='function')toast('🎯 '+(n.titulo||'Aviso')+(n.descricao?' — '+n.descricao:''),n.tipo==='urgente'?'danger':'info'); avisoSistema(n); });
        sessionStorage.setItem('erp_avisos_tocados',JSON.stringify(avisados.concat(tocar.map(n=>n.id)).slice(-200)));
      }
    }catch(e){}
  }
  return {
    iniciar(){ if(timer||!getUser()) return;
      const a=document.querySelector('a[href="qualidade.html"]');
      if(a&&!document.getElementById('sb-badge-qualidade')){const b=document.createElement('span');b.id='sb-badge-qualidade';
        b.style.cssText='display:none;margin-left:auto;background:#dc2626;color:#fff;border-radius:999px;padding:0 7px;font-size:11px;font-weight:800;';a.appendChild(b);}
      setTimeout(conferir,4000); timer=setInterval(conferir,60000);
      document.addEventListener('click',()=>{try{const AC=window.AudioContext||window.webkitAudioContext;if(AC){ctx=ctx||new AC();if(ctx.state==='suspended')ctx.resume();}}catch(e){}},{once:true}); },
    marcarVisto(ids){ const s=vistos(); (ids||[]).forEach(i=>s.add(i)); salvarVistos(s); conferir(); },
    vistos, conferir, bip,
  };
})();
/* itens: [{insumo_id, nome}] · fornecedor: {nome, cnpj} · onde: 'pedido' | 'recebimento'
   devolve null (tudo certo / trava desligada) ou {modo, msg, liberadores:[nomes], podeLiberar} */
async function bpfTravaFornecedor({onde,itens,fornecedor}){
  try{
    const [{data:tv},{data:g}]=await Promise.all([
      _supabase.from('bpf_travas').select('ativa,config').eq('codigo','fornecedor_nao_homologado').maybeSingle(),
      _supabase.from('bpf_gatilhos').select('filtro').eq('codigo','g_emb_insumo').maybeSingle()]);
    if(!tv||!tv.ativa) return null;
    const cfg=tv.config||{}; if(!(cfg.onde||[]).includes(onde)) return null;
    const cods=(g&&g.filtro&&g.filtro.itens)||[]; if(!cods.length) return null;
    const {data:ins}=await _supabase.from('insumos').select('id,codigo,nome').in('codigo',cods);
    const ids=new Set((ins||[]).map(x=>x.id)), nomes=new Set((ins||[]).map(x=>_bpfNorm(x.nome)));
    const embs=(itens||[]).filter(i=>ids.has(i.insumo_id)||nomes.has(_bpfNorm(i.nome)));
    if(!embs.length) return null;                       // nada de embalagem BPF nesta compra
    const fn=_bpfNorm(fornecedor&&fornecedor.nome), fc=String((fornecedor&&fornecedor.cnpj)||'').replace(/\D/g,'');
    const {data:regs}=await _supabase.from('bpf_registros').select('numero,campos,status,lancado_em,cancelado_em')
      .eq('formulario_cod','REG-POP01-02').is('cancelado_em',null).limit(500);
    const hoje=new Date().toISOString().slice(0,10);
    const ok=(regs||[]).some(r=>{const c=r.campos||{};
      const mesmo=(fc.length>=11&&String(c.cnpj||'').replace(/\D/g,'')===fc)||(fn&&(_bpfNorm(c.nome).includes(fn)||fn.includes(_bpfNorm(c.nome)))&&_bpfNorm(c.nome).length>=4);
      return mesmo&&(r.lancado_em||r.status==='concluido')&&c.status==='Homologado'&&(!c.reavaliacao||c.reavaliacao>=hoje);});
    if(ok) return null;
    const u=getUser()||{};
    const libs=cfg.liberadores||[];
    return {modo:cfg.modo==='avisar'?'avisar':'bloquear',liberadores:libs,
      podeLiberar:libs.some(n=>_bpfNorm(n)===_bpfNorm(u.nome)),
      msg:`Fornecedor "${(fornecedor&&fornecedor.nome)||'—'}" não está homologado no BPF (POP-01) para embalagem: ${embs.map(i=>i.nome).join(', ')}.`};
  }catch(e){ console.warn('[BPF trava fornecedor]',e); return null; }   // BPF fora do ar não para a compra
}
// aplica o resultado: true = pode seguir · false = parar
async function bpfAplicarTrava(res,contexto){
  if(!res) return true;
  if(res.modo==='avisar'){
    await bpfAvisar('BPF: fornecedor não homologado',res.msg+' ('+contexto+' seguiu com aviso)','forn_'+Date.now());
    toast('⚠️ '+res.msg+' Seguiu com aviso — a Qualidade foi avisada.','warning');
    return true;
  }
  if(res.podeLiberar){
    const motivo=await erpPrompt(res.msg+'\n\nVocê pode liberar esta exceção. Informe o motivo (fica registrado):',{titulo:'Fornecedor não homologado',icone:'🚫',ok:'Liberar exceção'});
    if(motivo&&motivo.trim()){
      await bpfAvisar('BPF: exceção liberada (fornecedor)',res.msg+' · '+contexto+' · liberado por '+((getUser()||{}).nome||'—')+': '+motivo.trim(),'forn_lib_'+Date.now());
      return true;
    }
    return false;
  }
  await bpfAvisar('BPF: bloqueio por fornecedor não homologado',res.msg+' · '+contexto,'forn_blq_'+Date.now());
  alert('🚫 BLOQUEADO PELO BPF\n\n'+res.msg+'\n\nHomologue o fornecedor no BPF (POP-01 → REG-POP01-02)'+(res.liberadores.length?' ou peça liberação a: '+res.liberadores.join(', '):'')+'.');
  return false;
}

// ── TRAVA BPF GENÉRICA ─────────────────────────────────────────────────
// Usada pelos módulos (Carregamento, Laboratório, Produção) para conferir uma trava
// ligada em BPF → Travas. Respeita a configuração do POP: modo (bloquear / só avisar),
// onde age (cfg.onde) e quem pode liberar a exceção (cfg.liberadores, com motivo).
// Devolve true = pode seguir · false = parar. BPF fora do ar não para a operação.
async function bpfTravaGenerica(codigo,{onde,violou,msg,contexto}){
  if(!violou) return true;
  let tv=null;
  try{ const {data}=await _supabase.from('bpf_travas').select('ativa,config,nome,pop_cod').eq('codigo',codigo).maybeSingle(); tv=data; }catch(e){ return true; }
  if(!tv||!tv.ativa) return true;
  const cfg=tv.config||{};
  if(onde&&Array.isArray(cfg.onde)&&cfg.onde.length&&!cfg.onde.includes(onde)) return true;
  const u=getUser()||{}; const libs=cfg.liberadores||[];
  const titulo='BPF '+(tv.pop_cod||'')+': '+(tv.nome||codigo);
  if(cfg.modo==='avisar'){
    await bpfAvisar(titulo,msg+' · '+contexto+' (seguiu com aviso)',codigo+'_'+Date.now(),tv.pop_cod);
    toast('⚠️ '+msg+' Seguiu com aviso — a Qualidade foi avisada.','warning');
    return true;
  }
  if(libs.some(n=>_bpfNorm(n)===_bpfNorm(u.nome))){
    const motivo=await erpPrompt(msg+'\n\nVocê pode liberar esta exceção. Informe o motivo (fica registrado):',{titulo:tv.nome,icone:'🚫',ok:'Liberar exceção'});
    if(motivo&&motivo.trim()){
      await bpfAvisar(titulo+' — exceção liberada',msg+' · '+contexto+' · liberado por '+(u.nome||'—')+': '+motivo.trim(),codigo+'_lib_'+Date.now(),tv.pop_cod);
      return true;
    }
    return false;
  }
  await bpfAvisar(titulo+' — bloqueado',msg+' · '+contexto,codigo+'_blq_'+Date.now(),tv.pop_cod);
  alert('🚫 BLOQUEADO PELO BPF — '+tv.nome+'\n\n'+msg+(libs.length?'\n\nPeça liberação a: '+libs.join(', '):''));
  return false;
}

// ── ASSINATURA DE PRÓPRIO PUNHO (BPF e Central da Qualidade) ───────────
// Abre um quadro para assinar com o dedo, a caneta ou o mouse. Devolve a imagem (PNG) ou null.
// "Guardar neste aparelho" deixa a pessoa reaproveitar a MESMA assinatura dela depois.
function padAssinatura({titulo,quem,funcao,detalhe}){
  const E=s=>String(s==null?'':s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const chave='bpf_assinatura_'+String(quem||'').toLowerCase();
  let salva=null;try{salva=localStorage.getItem(chave);}catch(e){}
  return new Promise(res=>{
    const ov=document.createElement('div');
    ov.style.cssText='position:fixed;inset:0;background:rgba(2,20,40,.55);z-index:30000;display:flex;align-items:center;justify-content:center;padding:12px;';
    ov.innerHTML=`<div style="background:#fff;border-radius:16px;max-width:640px;width:100%;box-shadow:0 20px 60px rgba(0,0,0,.3);font-family:'Plus Jakarta Sans',sans-serif;">
      <div style="padding:14px 18px;border-bottom:1px solid #e2e8f0;font-weight:800;color:#042D4D;font-size:15.5px;">✍️ ${E(titulo||'Assinatura')}</div>
      <div style="padding:14px 18px;">
        <div style="font-size:13px;margin-bottom:8px;"><b>${E(quem)}</b> · ${E(funcao||'')} · ${new Date().toLocaleString('pt-BR')}</div>
        ${detalhe?`<div style="font-size:12px;color:#64748b;margin:-2px 0 8px;">${E(detalhe)}</div>`:''}
        <div style="position:relative;border:2px dashed #94a3b8;border-radius:12px;background:#fff;touch-action:none;">
          <canvas data-c style="width:100%;height:210px;display:block;border-radius:12px;cursor:crosshair;"></canvas>
          <div data-dica style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center;color:#cbd5e1;font-size:15px;pointer-events:none;">Assine aqui com o dedo, a caneta ou o mouse</div>
          <div style="position:absolute;left:18px;right:18px;bottom:40px;border-bottom:1px solid #cbd5e1;pointer-events:none;"></div></div>
        <div style="display:flex;gap:8px;flex-wrap:wrap;margin-top:9px;align-items:center;">
          <button data-limpar class="btn btn-secondary btn-sm">🧹 Limpar</button>
          ${salva?'<button data-salva class="btn btn-secondary btn-sm">↺ Usar minha assinatura guardada</button>':''}
          <label style="margin-left:auto;font-size:12.5px;display:flex;gap:6px;align-items:center;"><input type="checkbox" data-guardar ${salva?'checked':''}> Guardar neste aparelho</label></div>
        <div style="margin-top:9px;font-size:11.5px;color:#64748b;">A assinatura fica no registro e na trilha de auditoria e não pode ser removida.</div></div>
      <div style="padding:12px 18px;border-top:1px solid #e2e8f0;display:flex;gap:8px;justify-content:flex-end;">
        <button data-cancel class="btn btn-secondary">Cancelar</button><button data-ok class="btn btn-primary" disabled>✍️ Assinar</button></div></div>`;
    document.body.appendChild(ov);
    const q=s=>ov.querySelector(s);
    const cv=q('[data-c]'),ctx=cv.getContext('2d');
    const dpr=Math.max(1,window.devicePixelRatio||1);const W=cv.clientWidth,H=cv.clientHeight;
    cv.width=W*dpr;cv.height=H*dpr;ctx.scale(dpr,dpr);ctx.lineWidth=2.4;ctx.lineCap='round';ctx.lineJoin='round';ctx.strokeStyle='#0b1f4a';ctx.fillStyle='#0b1f4a';
    let des=false,tem=false,ult=null;
    const pos=e=>{const b=cv.getBoundingClientRect();return {x:e.clientX-b.left,y:e.clientY-b.top};};
    const marca=()=>{tem=true;q('[data-ok]').disabled=false;q('[data-dica]').style.display='none';};
    cv.addEventListener('pointerdown',e=>{e.preventDefault();try{cv.setPointerCapture(e.pointerId);}catch(x){}des=true;ult=pos(e);ctx.beginPath();ctx.arc(ult.x,ult.y,1.1,0,7);ctx.fill();marca();});
    cv.addEventListener('pointermove',e=>{if(!des)return;e.preventDefault();const p=pos(e);ctx.beginPath();ctx.moveTo(ult.x,ult.y);ctx.lineTo(p.x,p.y);ctx.stroke();ult=p;});
    ['pointerup','pointercancel','pointerleave'].forEach(t=>cv.addEventListener(t,()=>{des=false;}));
    q('[data-limpar]').onclick=()=>{ctx.clearRect(0,0,W,H);tem=false;q('[data-ok]').disabled=true;q('[data-dica]').style.display='flex';};
    const bs=q('[data-salva]');
    if(bs)bs.onclick=()=>{const im=new Image();im.onload=()=>{ctx.clearRect(0,0,W,H);const k=Math.min(W/im.width,H/im.height);ctx.drawImage(im,(W-im.width*k)/2,(H-im.height*k)/2,im.width*k,im.height*k);marca();};im.src=salva;};
    const fim=v=>{ov.remove();res(v);};
    q('[data-cancel]').onclick=()=>fim(null);
    q('[data-ok]').onclick=()=>{
      if(!tem)return;
      const o=document.createElement('canvas');o.width=500;o.height=Math.round(500*H/W);o.getContext('2d').drawImage(cv,0,0,o.width,o.height);
      const img=o.toDataURL('image/png');
      try{ if(q('[data-guardar]').checked)localStorage.setItem(chave,img); else localStorage.removeItem(chave); }catch(e){}
      fim(img);};
  });
}

// ── BUSCAR TODAS AS LINHAS ─────────────────────────────────
/* O Supabase devolve NO MÁXIMO 1.000 linhas por consulta — mesmo com
   .limit(5000) ou .limit(50000). Passou disso, o resto some calado.
   selectTodos(q) recebe a consulta já montada (select + filtros + ordem),
   busca em páginas de 1.000 até acabar e devolve { data, error } igual ao
   Supabase, então pode entrar no lugar da consulta sem mudar quem usa.
   opts.max      → teto opcional de linhas (ex.: "carregar mais")
   opts.desempate→ coluna(s) únicas para a ordem ficar estável entre páginas
                   (padrão 'id'; false se a ordem já for única). */
async function selectTodos(q, opts = {}) {
  const PAG = 1000, max = opts.max || 500000, out = [];
  const desemp = opts.desempate === undefined ? 'id' : opts.desempate;
  if (desemp) (Array.isArray(desemp) ? desemp : [desemp]).forEach((c) => { q = q.order(c, { ascending: true }); });
  for (let de = 0; de < max; de += PAG) {
    const ate = Math.min(de + PAG, max) - 1;
    const { data, error } = await q.range(de, ate);
    if (error) return { data: out.length ? out : null, error };
    out.push(...(data || []));
    if (!data || data.length < ate - de + 1) break;
  }
  return { data: out, error: null };
}

// ── EXPORT PDF genérico ─────────────────────────────────────
/* Cabeçalho da empresa para PDFs/impressões: logo, nome fantasia, razão social,
   CNPJ/IE, endereço e contato — tudo vem de Configurações → Empresa. */
async function carregarEmpresaPDF(){
  if (window._ERP_EMPRESA) return window._ERP_EMPRESA;
  try {
    const { data } = await _supabase.from('empresa_config').select('*').limit(1).maybeSingle();
    if (data) window._ERP_EMPRESA = data;
  } catch (e) {}
  return window._ERP_EMPRESA || null;
}
function cabecalhoEmpresaHTML(emp) {
  const e = emp || window._ERP_EMPRESA || {};
  const x = v => String(v == null ? '' : v).replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
  const nome  = e.nome_fantasia || e.razao_social || document.getElementById('sb-company-name')?.textContent?.trim() || 'ERP Industrial';
  const razao = e.razao_social && e.razao_social !== nome ? e.razao_social : '';
  const doc   = [e.cnpj && 'CNPJ: ' + e.cnpj, e.ie && 'IE: ' + e.ie].filter(Boolean).join(' &nbsp;|&nbsp; ');
  const end   = [e.rua && (e.rua + (e.numero ? ', ' + e.numero : '')), e.bairro, e.cidade && (e.cidade + (e.uf ? '/' + e.uf : '')), e.cep && 'CEP ' + e.cep].filter(Boolean).join(' — ');
  const cont  = [e.telefone, e.email].filter(Boolean).join('  |  ');
  const logo  = e.logo || document.querySelector('#sb-logo img')?.src || null;
  const logoHtml = logo
    ? `<img src="${x(logo)}" style="height:52px;max-width:130px;object-fit:contain;">`
    : `<div style="width:52px;height:52px;background:#042D4D;border-radius:8px;display:flex;align-items:center;justify-content:center;color:#fff;font-size:22px;">🏭</div>`;
  const linha = t => t ? `<div style="font-size:10.5px;color:#64748b;margin-top:2px;">${t}</div>` : '';
  return `<div style="display:flex;align-items:center;gap:14px;padding-bottom:12px;border-bottom:2px solid #042D4D;margin-bottom:16px;">
    ${logoHtml}<div style="flex:1;min-width:0;"><div style="font-size:17px;font-weight:800;color:#042D4D;line-height:1.15;">${x(nome)}</div>
    ${razao ? `<div style="font-size:11px;color:#475569;margin-top:1px;">${x(razao)}</div>` : ''}${linha(doc)}${linha(x(end))}${linha(x(cont))}</div></div>`;
}
async function exportarPDF(titulo, colunas, linhas) {
  const w = window.open('','_blank');      // abre já (no clique) para o navegador não bloquear
  if (!w) { if (typeof toast === 'function') toast('Permita pop-ups para gerar o PDF.', 'warning'); return; }
  const emp = await carregarEmpresaPDF();
  const html = `<!DOCTYPE html><html lang="pt-BR"><head><meta charset="UTF-8"><title>${titulo}</title><style>
    body{font-family:Arial,Helvetica,sans-serif;padding:24px;color:#1e293b;}
    h2{color:#042D4D;margin:0 0 4px;font-size:15px;}
    .meta{font-size:11px;color:#64748b;margin:0 0 14px;}
    table{width:100%;border-collapse:collapse;}
    th{background:#042D4D;color:#C9FF64;padding:8px 10px;text-align:left;font-size:10.5px;text-transform:uppercase;letter-spacing:.3px;}
    td{padding:7px 10px;border-bottom:1px solid #e2e8f0;font-size:11.5px;}
    tr:nth-child(even) td{background:#f8fafc;}
    @page{size:A4;margin:12mm;} @media print{body{padding:0;}}
    *{-webkit-print-color-adjust:exact;print-color-adjust:exact;}
  </style></head><body>
  ${cabecalhoEmpresaHTML(emp)}
  <h2>${titulo}</h2>
  <p class="meta">Gerado em ${new Date().toLocaleString('pt-BR')} &nbsp;·&nbsp; ${linhas.length} registro(s)</p>
  <table><thead><tr>${colunas.map(c=>`<th>${c}</th>`).join('')}</tr></thead>
  <tbody>${linhas.map(r=>`<tr>${r.map(c=>`<td>${c==null||c===''?'—':c}</td>`).join('')}</tr>`).join('')}</tbody></table>
  <script>window.onload=()=>setTimeout(()=>window.print(),300);<\/script>
  </body></html>`;
  w.document.write(html);
  w.document.close();
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
// ── PWA (instalar como app / tela cheia) ──────────────────
// Injeta manifesto + meta tags e registra o service worker.
// Feito por JS para NÃO precisar editar os arquivos .html.
(function setupPWA() {
  try {
    const head = document.head;
    if (head && !document.querySelector('link[rel="manifest"]')) {
      const add = (tag, attrs) => {
        const el = document.createElement(tag);
        for (const k in attrs) el.setAttribute(k, attrs[k]);
        head.appendChild(el);
      };
      add('link', { rel: 'manifest', href: 'manifest.json' });
      add('meta', { name: 'theme-color', content: '#042D4D' });
      // iOS: abrir em tela cheia + ícone na tela inicial
      add('meta', { name: 'apple-mobile-web-app-capable', content: 'yes' });
      add('meta', { name: 'apple-mobile-web-app-status-bar-style', content: 'black-translucent' });
      add('meta', { name: 'apple-mobile-web-app-title', content: 'ERP' });
      add('meta', { name: 'mobile-web-app-capable', content: 'yes' });
      add('link', { rel: 'apple-touch-icon', href: 'icons/icon-180.png' });
    }
  } catch (e) { /* sem PWA não quebra o sistema */ }

  if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
      navigator.serviceWorker.register('sw.js').catch(() => {});
    });
  }
})();

/* ═══════════════════════════════════════════════════════════════
   FOTOS NO SUPABASE STORAGE (bucket 'fotos')
   Fotos novas viram ARQUIVO no Storage e a tabela guarda só o link —
   o banco fica leve e o navegador faz cache das imagens.
   Cada troca gera arquivo novo (timestamp); o antigo permanece no bucket.
   Se o upload falhar (sem internet), retorna null e o módulo salva o
   base64 como antes — nada se perde; o migrarfotos.html move depois.
   ═══════════════════════════════════════════════════════════════ */
async function subirFotoStorage(dataUrl, pasta, id) {
  try {
    if (!dataUrl || !dataUrl.startsWith('data:')) return null;
    const m = /^data:([^;,]+)/.exec(dataUrl) || [];
    const mime = m[1] || 'image/jpeg';
    const ext = { 'image/jpeg': 'jpg', 'image/jpg': 'jpg', 'image/png': 'png', 'image/webp': 'webp', 'image/gif': 'gif' }[mime] || 'jpg';
    const blob = await (await fetch(dataUrl)).blob();
    const path = pasta + '/' + (id || 'novo') + '/foto-' + Date.now() + '.' + ext;
    const { error } = await _supabase.storage.from('fotos').upload(path, blob, { contentType: mime, cacheControl: '31536000', upsert: false });
    if (error) throw error;
    const { data: pub } = _supabase.storage.from('fotos').getPublicUrl(path);
    return (pub && pub.publicUrl) || null;
  } catch (e) {
    console.warn('[storage] upload falhou, mantendo base64:', e.message || e);
    return null;
  }
}

/* Converte um link de imagem (Storage) em base64 para uso no jsPDF
   (doc.addImage não aceita URL). Se já for base64, devolve como está. */
async function fotoParaDataUrl(src) {
  if (!src || typeof src !== 'string' || src.startsWith('data:')) return src || null;
  try {
    const blob = await (await fetch(src)).blob();
    return await new Promise((res, rej) => {
      const fr = new FileReader();
      fr.onload = () => res(fr.result);
      fr.onerror = rej;
      fr.readAsDataURL(blob);
    });
  } catch (e) {
    console.warn('[fotoParaDataUrl]', e.message || e);
    return null;
  }
}

/* ══════════════════════════════════════════════════════════════════════════
   AVISOS E CONFIRMAÇÕES EM MODAL DO SISTEMA (out/2026)
   Nada de caixinha do navegador ("site diz…"). Uso:
     if(!(await erpConfirm('Excluir este item?',{perigo:true,ok:'Excluir'}))) return;
     erpAlert('Pronto!');
   O alert() nativo também passa a abrir este modal.
   ══════════════════════════════════════════════════════════════════════════ */
(function () {
  function css() {
    if (document.getElementById('erp-dlg-css')) return;
    const st = document.createElement('style'); st.id = 'erp-dlg-css';
    st.textContent = `.erp-dlg-ov{position:fixed;inset:0;z-index:300000;background:rgba(4,45,77,.55);display:flex;align-items:center;justify-content:center;padding:16px;animation:erpDlgIn .12s ease-out;}
.erp-dlg{background:#fff;border-radius:18px;max-width:440px;width:100%;box-shadow:0 24px 64px rgba(0,0,0,.35);overflow:hidden;font-family:'Plus Jakarta Sans',system-ui,sans-serif;}
.erp-dlg-h{display:flex;gap:12px;align-items:flex-start;padding:20px 22px 6px;}
.erp-dlg-ic{flex-shrink:0;width:40px;height:40px;border-radius:12px;display:flex;align-items:center;justify-content:center;font-size:20px;background:#eff6ff;}
.erp-dlg.perigo .erp-dlg-ic{background:#fee2e2;} .erp-dlg.aviso .erp-dlg-ic{background:#fef3c7;} .erp-dlg.ok .erp-dlg-ic{background:#dcfce7;}
.erp-dlg-t{font-size:16px;font-weight:800;color:#042D4D;margin-top:2px;}
.erp-dlg-m{padding:4px 22px 18px 74px;font-size:14px;line-height:1.5;color:#334155;white-space:pre-line;}
.erp-dlg-f{display:flex;justify-content:flex-end;gap:8px;padding:12px 16px;background:#f8fafc;border-top:1px solid #e3e9f0;}
.erp-dlg-f button{border:0;border-radius:11px;padding:11px 18px;font:inherit;font-size:14px;font-weight:800;cursor:pointer;}
.erp-dlg-no{background:#fff !important;border:1.5px solid #d6e2ec !important;color:#042D4D;}
.erp-dlg-sim{background:#C9FF64;color:#042D4D;} .erp-dlg.perigo .erp-dlg-sim{background:#dc2626;color:#fff;}
@keyframes erpDlgIn{from{opacity:0}to{opacity:1}}
@media (max-width:520px){.erp-dlg-m{padding-left:22px;}.erp-dlg-f button{flex:1;}}`;
    document.head.appendChild(st);
  }
  const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  window.erpConfirm = function (msg, o) {
    o = o || {}; css();
    return new Promise(res => {
      const tipo = o.perigo ? 'perigo' : o.tipo || (o.soOk ? 'info' : 'aviso');
      const ic = o.icone || ({ perigo: '⚠️', aviso: '❓', ok: '✅', info: 'ℹ️' }[tipo] || 'ℹ️');
      const ov = document.createElement('div'); ov.className = 'erp-dlg-ov';
      ov.innerHTML = `<div class="erp-dlg ${tipo}" role="dialog" aria-modal="true">
        <div class="erp-dlg-h"><div class="erp-dlg-ic">${ic}</div><div class="erp-dlg-t">${esc(o.titulo || (o.soOk ? 'Aviso' : 'Confirme'))}</div></div>
        <div class="erp-dlg-m">${esc(msg)}</div>
        <div class="erp-dlg-f">${o.soOk ? '' : `<button type="button" class="erp-dlg-no">${esc(o.cancelar || 'Cancelar')}</button>`}<button type="button" class="erp-dlg-sim">${esc(o.ok || 'OK')}</button></div></div>`;
      const fim = v => { document.removeEventListener('keydown', tecla, true); ov.remove(); res(v); };
      const tecla = e => { if (e.key === 'Escape') { e.preventDefault(); fim(!!o.soOk); } else if (e.key === 'Enter') { e.preventDefault(); fim(true); } };
      ov.querySelector('.erp-dlg-sim').onclick = () => fim(true);
      const no = ov.querySelector('.erp-dlg-no'); if (no) no.onclick = () => fim(false);
      ov.addEventListener('click', e => { if (e.target === ov) fim(!!o.soOk); });
      document.addEventListener('keydown', tecla, true);
      document.body.appendChild(ov);
      setTimeout(() => ov.querySelector(o.soOk ? '.erp-dlg-sim' : (o.perigo ? '.erp-dlg-no' : '.erp-dlg-sim'))?.focus(), 30);
    });
  };
  window.erpAlert = function (msg, o) { return window.erpConfirm(msg, Object.assign({ soOk: true }, o || {})); };
  // pergunta com resposta escrita (devolve o texto, ou null se cancelar)
  window.erpPrompt = function (msg, o) {
    o = o || {}; css();
    return new Promise(res => {
      const ov = document.createElement('div'); ov.className = 'erp-dlg-ov';
      ov.innerHTML = `<div class="erp-dlg ${o.tipo || 'aviso'}" role="dialog" aria-modal="true">
        <div class="erp-dlg-h"><div class="erp-dlg-ic">${o.icone || '✍️'}</div><div class="erp-dlg-t">${esc(o.titulo || 'Informe')}</div></div>
        <div class="erp-dlg-m">${esc(msg)}<textarea class="erp-dlg-in" rows="2" style="display:block;width:100%;margin-top:10px;border:1.5px solid #d6e2ec;border-radius:10px;padding:9px 11px;font:inherit;font-size:14px;" placeholder="${esc(o.placeholder || '')}"></textarea></div>
        <div class="erp-dlg-f"><button type="button" class="erp-dlg-no">${esc(o.cancelar || 'Cancelar')}</button><button type="button" class="erp-dlg-sim">${esc(o.ok || 'Confirmar')}</button></div></div>`;
      const inp = ov.querySelector('.erp-dlg-in');
      const fim = v => { ov.remove(); res(v); };
      ov.querySelector('.erp-dlg-sim').onclick = () => { const v = inp.value.trim(); if (o.obrigatorio !== false && !v) { inp.style.borderColor = '#dc2626'; inp.focus(); return; } fim(v); };
      ov.querySelector('.erp-dlg-no').onclick = () => fim(null);
      document.body.appendChild(ov); setTimeout(() => inp.focus(), 30);
    });
  };
  // alert() de qualquer tela vira modal do sistema (não trava a página, só informa)
  window.alert = function (m) { window.erpAlert(String(m == null ? '' : m)); };
})();
