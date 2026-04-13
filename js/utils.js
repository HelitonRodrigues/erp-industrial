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
  await addLog('LOGOUT', 'AUTH', user?.id || 'unknown', 'Logout realizado').catch(() => {});
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
  const ths = colunas.map(c => `<th>${c}</th>`).join('');
  const trs = linhas.map(r => `<tr>${r.map(c => `<td>${c || '—'}</td>`).join('')}</tr>`).join('');
  const html = `<!DOCTYPE html><html><head><meta charset="UTF-8">
    <style>body{font-family:sans-serif;padding:24px;}h2{color:#042D4D;margin-bottom:8px;}
    p{font-size:12px;color:#64748b;margin-bottom:16px;}
    table{width:100%;border-collapse:collapse;}
    th{background:#042D4D;color:#fff;padding:10px;text-align:left;font-size:12px;}
    td{padding:8px;border-bottom:1px solid #e2e8f0;font-size:12px;}</style>
    </head><body>
    <h2>${titulo}</h2>
    <p>Gerado em ${new Date().toLocaleString('pt-BR')} — Total: ${linhas.length} registro(s)</p>
    <table><thead><tr>${ths}</tr></thead><tbody>${trs}</tbody></table>
    </body></html>`;
  const w = window.open('', '_blank');
  w.document.write(html);
  w.document.close();
  setTimeout(() => w.print(), 500);
}
