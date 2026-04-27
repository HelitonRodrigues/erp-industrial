// ============================================================
// ERP INDUSTRIAL — UTILS.JS
// Funções compartilhadas entre todos os módulos
// ============================================================

// ── SIDEBAR ──
let _sidebarCollapsed = false;

function toggleSidebar() {
  _sidebarCollapsed = !_sidebarCollapsed;
  document.getElementById('sidebar').classList.toggle('collapsed', _sidebarCollapsed);
  document.getElementById('topbar').classList.toggle('collapsed', _sidebarCollapsed);
  document.getElementById('main-content').classList.toggle('collapsed', _sidebarCollapsed);
}

function toggleGroup(grupo) {
  const label = document.querySelector(`[data-group="${grupo}"]`);
  const items = document.getElementById('group-' + grupo);
  if (!label || !items) return;
  const isOpen = items.classList.contains('open');
  document.querySelectorAll('.nav-group-items').forEach(el => el.classList.remove('open'));
  document.querySelectorAll('.nav-group-label').forEach(el => el.classList.remove('open'));
  if (!isOpen) { items.classList.add('open'); label.classList.add('open'); }
}

function openGroup(grupo) {
  document.querySelectorAll('.nav-group-items').forEach(el => el.classList.remove('open'));
  document.querySelectorAll('.nav-group-label').forEach(el => el.classList.remove('open'));
  const items = document.getElementById('group-' + grupo);
  const label = document.querySelector(`[data-group="${grupo}"]`);
  if (items) items.classList.add('open');
  if (label) label.classList.add('open');
}

// ── TOAST ──
function toast(msg, type = 'success') {
  const icons = { success: '✅', danger: '❌', warning: '⚠️', info: 'ℹ️' };
  const el = document.createElement('div');
  el.className = 'toast ' + type;
  el.innerHTML = `<span>${icons[type] || 'ℹ️'}</span><span>${msg}</span>`;
  document.getElementById('toast-container').appendChild(el);
  setTimeout(() => el.remove(), 3500);
}

// ── MODAL ──
function closeModal(id) {
  document.getElementById(id).classList.add('hidden');
}

// Fechar modal ao clicar fora
document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('.modal-overlay').forEach(el => {
    el.addEventListener('click', e => { if (e.target === el) el.classList.add('hidden'); });
  });
});

// ── AUDITORIA ──
async function addLog(acao, modulo, registroId, descricao) {
  const user = getUser();
  try {
    await _supabase.from('auditoria').insert({
      acao, modulo,
      registro_id: String(registroId),
      descricao,
      usuario_email: user?.email || 'sistema'
    });
  } catch (e) {
    console.warn('Erro ao registrar auditoria:', e);
  }
}

// ── AUTH ──
function getUser() {
  try { return JSON.parse(sessionStorage.getItem('erp_user')); }
  catch { return null; }
}

function requireAuth() {
  const user = getUser();
  if (!user) { window.location.href = 'index.html'; return null; }
  return user;
}

async function doLogout() {
  const user = getUser();
  try{await addLog('LOGOUT','AUTH',user?.id||'unknown','Logout realizado');}catch(e){}
  sessionStorage.removeItem('erp_user');
  window.location.href = 'index.html';
}

// ── PREENCHER SIDEBAR COM DADOS DO USUÁRIO E EMPRESA ──
async function initSidebar(paginaAtiva) {
  const user = requireAuth();
  if (!user) return;

  // Usuário
  const initials = (user.nome || 'SA').split(' ').map(x => x[0]).join('').substring(0, 2).toUpperCase();
  const setEl = (id, val) => { const el = document.getElementById(id); if (el) el.textContent = val; };
  setEl('sb-avatar', initials);
  setEl('top-avatar', initials);
  setEl('sb-user-name', (user.nome || 'Super Admin').split(' ')[0]);
  setEl('top-user-name', user.nome || 'Super Admin');
  setEl('sb-user-perfil', user.perfil || 'SADM');
  setEl('top-user-perfil', (user.perfil || 'SADM') + ' — Super Administrador');

  // Empresa
  try {
    const { data } = await _supabase.from('empresa_config')
      .select('nome_fantasia,razao_social,logo').limit(1).maybeSingle();
    if (data) {
      setEl('sb-company-name', data.nome_fantasia || data.razao_social || 'ERP Industrial');
      if (data.logo) {
        const logoEl = document.getElementById('sb-logo');
        if (logoEl) logoEl.innerHTML = `<img src="${data.logo}" style="width:100%;height:100%;object-fit:cover;">`;
        const brandEl = document.getElementById('login-logo');
        if (brandEl) brandEl.innerHTML = `<img src="${data.logo}">`;
        const nomeEl = document.getElementById('login-empresa');
        if (nomeEl) nomeEl.textContent = data.nome_fantasia || data.razao_social || 'ERP Industrial';
      }
    }
  } catch (e) { /* silencioso */ }

  // Marcar item ativo na sidebar
  if (paginaAtiva) {
    document.querySelectorAll('.nav-item').forEach(el => {
      el.classList.toggle('active', el.getAttribute('href') === paginaAtiva);
    });
  }
}

// ── SHA256 (para senhas) ──
async function sha256(str) {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(str));
  return Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, '0')).join('');
}

// ── MÁSCARAS ──
function mascaraCNPJ(el) {
  let v = el.value.replace(/\D/g, '');
  if (v.length > 14) v = v.substring(0, 14);
  v = v.replace(/^(\d{2})(\d)/, '$1.$2')
       .replace(/^(\d{2})\.(\d{3})(\d)/, '$1.$2.$3')
       .replace(/\.(\d{3})(\d)/, '.$1/$2')
       .replace(/(\d{4})(\d)/, '$1-$2');
  el.value = v;
}

function mascaraCPF(el) {
  let v = el.value.replace(/\D/g, '');
  if (v.length > 11) v = v.substring(0, 11);
  v = v.replace(/(\d{3})(\d)/, '$1.$2')
       .replace(/(\d{3})(\d)/, '$1.$2')
       .replace(/(\d{3})(\d{1,2})$/, '$1-$2');
  el.value = v;
}

function mascaraTel(el) {
  let v = el.value.replace(/\D/g, '');
  if (v.length > 11) v = v.substring(0, 11);
  if (v.length > 10) v = v.replace(/(\d{2})(\d{5})(\d{4})/, '($1) $2-$3');
  else if (v.length > 6) v = v.replace(/(\d{2})(\d{4})(\d+)/, '($1) $2-$3');
  else if (v.length > 2) v = v.replace(/(\d{2})(\d+)/, '($1) $2');
  el.value = v;
}

function mascaraCEP(el) {
  let v = el.value.replace(/\D/g, '');
  if (v.length > 8) v = v.substring(0, 8);
  v = v.replace(/(\d{5})(\d)/, '$1-$2');
  el.value = v;
}

// ── EXPORT CSV genérico ──
function exportarCSV(colunas, linhas, nomeArquivo) {
  const csv = [colunas, ...linhas]
    .map(r => r.map(c => `"${(c || '').toString().replace(/"/g, '""')}"`).join(','))
    .join('\n');
  const a = document.createElement('a');
  a.href = 'data:text/csv;charset=utf-8,\uFEFF' + encodeURIComponent(csv);
  a.download = nomeArquivo + '.csv';
  a.click();
}

// ── EXPORT PDF genérico ──
function exportarPDF(titulo, colunas, linhas) {
  // Buscar logo e empresa da config salva
  const cfg = (() => { try { return JSON.parse(localStorage.getItem('erp_config')||'{}'); } catch(e){ return {}; } })();
  const empresa = cfg.nome || document.getElementById('sb-company-name')?.textContent?.trim() || 'ERP Industrial';
  const logo = cfg.logo || document.querySelector('#sb-logo img')?.src || null;
  const logoHtml = logo ? `<img src="${logo}" style="height:48px;object-fit:contain;">` : `<div style="width:48px;height:48px;background:#042D4D;border-radius:8px;display:flex;align-items:center;justify-content:center;color:#fff;font-size:20px;">🏭</div>`;
  const ths = colunas.map(c => `<th>${c}</th>`).join('');
  const trs = linhas.map(r => `<tr>${r.map(c => `<td>${c || '—'}</td>`).join('')}</tr>`).join('');
  const html = `<!DOCTYPE html><html><head><meta charset="UTF-8">
    <style>
      body{font-family:sans-serif;padding:24px;color:#1e293b;}
      .cabecalho{display:flex;align-items:center;gap:14px;padding-bottom:14px;border-bottom:2px solid #042D4D;margin-bottom:18px;}
      .cab-info h1{font-size:16px;color:#042D4D;margin:0 0 2px;}
      .cab-info p{font-size:11px;color:#64748b;margin:0;}
      h2{color:#042D4D;margin-bottom:4px;font-size:15px;}
      .meta{font-size:11px;color:#64748b;margin-bottom:14px;}
      table{width:100%;border-collapse:collapse;}
      th{background:#042D4D;color:#fff;padding:9px 10px;text-align:left;font-size:11px;text-transform:uppercase;letter-spacing:.5px;}
      td{padding:7px 10px;border-bottom:1px solid #e2e8f0;font-size:12px;}
      tr:nth-child(even) td{background:#f8fafc;}
      @media print{body{padding:12px;}}
    </style></head><body>
    <div class="cabecalho">${logoHtml}<div class="cab-info"><h1>${empresa}</h1><p>ERP Industrial</p></div></div>
    <h2>${titulo}</h2>
    <p class="meta">Gerado em ${new Date().toLocaleString('pt-BR')} &nbsp;|&nbsp; Total: ${linhas.length} registro(s)</p>
    <table><thead><tr>${ths}</tr></thead><tbody>${trs}</tbody></table>
    </body></html>`;
  const w = window.open('', '_blank');
  w.document.write(html);
  w.document.close();
  setTimeout(() => w.print(), 500);
}

// ── MODAL FOTO INLINE ──
function verFotoInline(src){
  if(!src)return;
  let overlay=document.getElementById('foto-modal-overlay');
  if(!overlay){
    overlay=document.createElement('div');overlay.id='foto-modal-overlay';
    overlay.style.cssText='position:fixed;inset:0;background:rgba(0,0,0,.85);z-index:9999;display:flex;align-items:center;justify-content:center;cursor:zoom-out;';
    overlay.onclick=()=>overlay.remove();
    document.body.appendChild(overlay);
  }
  overlay.innerHTML=`<img src="${src}" style="max-width:90vw;max-height:90vh;border-radius:10px;box-shadow:0 8px 40px rgba(0,0,0,.6);">`;
  overlay.style.display='flex';
}

// ── VERIFICAÇÃO DE PERMISSÃO ──
function checkPerm(modulo, acao) {
  try {
    const user = getUser();
    if (!user) return false;
    if (['SADM','ADM'].includes(user.perfil)) return true;
    const perms = user.permissoes;
    if (!perms || !perms[modulo]) return false;
    return !!perms[modulo][acao];
  } catch(e) { return true; } // fallback permissivo
}

// Ao fazer login, salvar permissoes do perfil junto com o user
async function carregarPermissoesPerfil(user) {
  try {
    const {data} = await _supabase.from('perfis').select('permissoes').eq('codigo', user.perfil).maybeSingle();
    if (data?.permissoes) {
      user.permissoes = data.permissoes;
      sessionStorage.setItem('erp_user', JSON.stringify(user));
    }
  } catch(e) {}
}
