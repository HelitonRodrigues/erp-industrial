/* ============================================================
   ALERTA DO STATUS DAS LINHAS  (migração 057 + função push-linhas)
   - Quando o laboratório muda o status de uma linha (OK / Ajuste /
     Manutenção / Parada), a tela aberta toca um som alto e mostra um
     aviso grande na cor do status. Parada repete até alguém tocar "OK, VI".
   - Botão 🔔 no canto: liga o som (o navegador exige 1 toque na tela),
     testa, desliga nesta tela e cadastra o celular para notificação.
   - Fonte: tabela linhas_status_eventos (gravada pelo gatilho do banco).
     Chega na hora pelo canal Realtime "linhas-status" e, de reserva,
     confere o banco a cada 15 s.
   Uso:  AlertaLinhas.iniciar({ aoMudar: ev => ..., faixa: 'id-da-div' })
   ============================================================ */
(function () {
  const ST = {
    'OK':         { cor: '#16a34a', ic: '✅', som: 'dingdong', txt: 'OK' },
    'Ajuste':     { cor: '#d97706', ic: '⚠️', som: 'bipe',     txt: 'AJUSTE' },
    'Manutenção': { cor: '#2563eb', ic: '🔧', som: 'tres',     txt: 'MANUTENÇÃO' },
    'Parada':     { cor: '#dc2626', ic: '🛑', som: 'sirene',   txt: 'PARADA', repete: true },
  };
  const ST_SEM = { cor: '#64748b', ic: '❓', som: 'sino', txt: 'SEM ANÁLISE' };
  const LS_SOM = 'erp_alerta_som';             // 'off' = som desligado nesta tela
  const POLL_MS = 15000, REPETE_MS = 10000, REPETE_MAX_MS = 5 * 60 * 1000, VALIDADE_MS = 15 * 60 * 1000;

  let ctx = null, master = null, ativos = [];
  let ultimoId = null, opts = {}, rt = null, canal = null, buscando = false;
  let abertos = [];                            // avisos na tela ainda não confirmados
  let repeteTimer = null, repeteDesde = 0;

  const ls = {
    get(k) { try { return localStorage.getItem(k); } catch (e) { return null; } },
    set(k, v) { try { localStorage.setItem(k, v); } catch (e) { /* sem armazenamento: vale só nesta visita */ } },
  };
  const somLigado = () => ls.get(LS_SOM) !== 'off' && !(typeof somDesligado === 'function' && somDesligado());
  const escH = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const aviso = (m, t) => (typeof toast === 'function' ? toast(m, t) : alert(m));

  /* ── SOM (gerado no navegador, sem arquivo) ─────────────────────────── */
  function prepara() {
    if (!ctx) {
      const AC = window.AudioContext || window.webkitAudioContext;
      if (!AC) return false;
      ctx = new AC();
      const comp = ctx.createDynamicsCompressor();
      comp.threshold.value = -20; comp.knee.value = 6; comp.ratio.value = 8; comp.attack.value = 0.002; comp.release.value = 0.15;
      const vol = () => 1.6 * (typeof volumeSom === 'function' ? volumeSom() : 1);
      master = ctx.createGain(); master.gain.value = vol();
      window.addEventListener('erp-volume', () => { if (master) master.gain.value = vol(); });
      master.connect(comp); comp.connect(ctx.destination);
    }
    if (ctx.state === 'suspended') ctx.resume().then(desenharBotao, () => {});
    return true;
  }
  const audioLiberado = () => !!ctx && ctx.state === 'running';
  function tom(freq, ini, dur, { tipo = 'sine', vol = 0.8, ataque = 0.005, decai = true, fim = null } = {}) {
    const o = ctx.createOscillator(), g = ctx.createGain();
    o.type = tipo; o.frequency.setValueAtTime(freq, ini);
    if (fim) o.frequency.linearRampToValueAtTime(fim, ini + dur);
    g.gain.setValueAtTime(0.0001, ini);
    g.gain.linearRampToValueAtTime(vol, ini + ataque);
    if (decai) g.gain.exponentialRampToValueAtTime(0.0001, ini + dur);
    else { g.gain.setValueAtTime(vol, ini + dur - 0.02); g.gain.linearRampToValueAtTime(0.0001, ini + dur); }
    o.connect(g); g.connect(master); o.start(ini); o.stop(ini + dur + 0.05); ativos.push(o);
  }
  const SONS = {
    sino(t) { [0, 1.1].forEach(d => { [[523, 0.9], [1046, 0.5], [1443, 0.35], [2093, 0.2]].forEach(([f, v]) => tom(f, t + d, 1.4, { vol: v })); }); },
    bipe(t) { for (let i = 0; i < 3; i++) { const b = t + i * 0.7; tom(1250, b, 0.14, { tipo: 'square', vol: 0.5, decai: false }); tom(1250, b + 0.22, 0.14, { tipo: 'square', vol: 0.5, decai: false }); } },
    tres(t) { for (let r = 0; r < 2; r++) { [659, 880, 1175].forEach((f, i) => tom(f, t + r * 1.2 + i * 0.25, 0.3, { tipo: 'triangle', vol: 0.9 })); } },
    sirene(t) { for (let i = 0; i < 2; i++) { const b = t + i * 1.5; tom(600, b, 0.75, { tipo: 'sawtooth', vol: 0.4, decai: false, fim: 1400 }); tom(1400, b + 0.75, 0.75, { tipo: 'sawtooth', vol: 0.4, decai: false, fim: 600 }); } },
    dingdong(t) { tom(784, t, 1.0, { tipo: 'triangle', vol: 1 }); tom(1568, t, 0.6, { vol: 0.3 }); tom(622, t + 0.55, 1.4, { tipo: 'triangle', vol: 1 }); tom(1244, t + 0.55, 0.8, { vol: 0.3 }); },
  };
  function parar() { ativos.forEach(o => { try { o.stop(); } catch (e) { /* já parou */ } }); ativos = []; }
  function tocar(status, forcar) {
    if (!somLigado() && !forcar) return;
    if (!prepara()) return;
    if (!audioLiberado()) { desenharBotao(); return; }   // falta o 1º toque: o botão pisca
    parar(); desenharBotao();
    SONS[(ST[status] || ST_SEM).som](ctx.currentTime + 0.05);
  }

  /* ── ESTILO ─────────────────────────────────────────────────────────── */
  function css() {
    if (document.getElementById('al-css')) return;
    const s = document.createElement('style'); s.id = 'al-css';
    s.textContent = `
#al-bt{position:fixed;right:16px;bottom:16px;z-index:9998;border:0;border-radius:999px;font:inherit;font-weight:800;cursor:pointer;
  box-shadow:0 6px 20px rgba(4,45,77,.35);display:flex;align-items:center;gap:8px;padding:12px 16px;font-size:14px;background:#042D4D;color:#C9FF64}
#al-bt.trava{background:#dc2626;color:#fff;animation:alPulsa 1.2s infinite}
#al-bt.off{background:#475569;color:#fff}
@keyframes alPulsa{0%,100%{transform:scale(1)}50%{transform:scale(1.06)}}
#al-menu{position:fixed;right:16px;bottom:76px;z-index:9998;background:#fff;border-radius:14px;box-shadow:0 12px 40px rgba(0,0,0,.25);
  width:min(320px,calc(100vw - 32px));padding:14px;display:none;flex-direction:column;gap:8px}
#al-menu.aberto{display:flex}
#al-menu h4{margin:0 0 4px;font-size:13px;color:#042D4D;text-transform:uppercase;letter-spacing:.5px}
#al-menu p{margin:0;font-size:12px;color:#64748b;line-height:1.4}
#al-menu button{font:inherit;font-weight:700;font-size:14px;border:0;border-radius:10px;padding:12px;cursor:pointer;text-align:left;background:#f1f5f9;color:#042D4D}
#al-menu button.pri{background:#042D4D;color:#C9FF64}
#al-ov{position:fixed;left:0;right:0;top:0;z-index:9999;display:flex;flex-direction:column;gap:8px;padding:10px;pointer-events:none}
.al-av{pointer-events:auto;color:#fff;border-radius:16px;padding:16px 18px;box-shadow:0 12px 40px rgba(0,0,0,.35);display:flex;align-items:center;gap:16px;
  max-width:900px;width:100%;margin:0 auto;animation:alEntra .25s ease-out}
.al-av.pisca{animation:alEntra .25s ease-out,alPisca 1s infinite}
@keyframes alEntra{from{transform:translateY(-30px);opacity:0}to{transform:none;opacity:1}}
@keyframes alPisca{0%,100%{filter:none}50%{filter:brightness(1.35)}}
.al-av .al-ic{font-size:44px;line-height:1}
.al-av .al-tx{flex:1;min-width:0}
.al-av .al-t1{font-size:26px;font-weight:900;letter-spacing:.5px;line-height:1.1}
.al-av .al-t2{font-size:14px;opacity:.95;margin-top:4px}
.al-av button{font:inherit;font-size:18px;font-weight:900;border:0;border-radius:12px;padding:14px 18px;background:#fff;color:#0f172a;cursor:pointer;white-space:nowrap}
@media (max-width:600px){.al-av{flex-wrap:wrap}.al-av .al-t1{font-size:21px}.al-av button{width:100%}}
.al-faixa{display:grid;grid-template-columns:repeat(auto-fill,minmax(170px,1fr));gap:10px;margin-bottom:16px}
.al-chip{border-radius:12px;padding:12px 14px;color:#fff;display:flex;flex-direction:column;gap:2px}
.al-chip b{font-size:15px}
.al-chip span{font-size:13px;font-weight:800}
.al-chip small{font-size:11px;opacity:.9}
.al-chip.flash{animation:alPisca 1s 6}
.al-cards{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:10px;margin-bottom:16px}
.al-card{background:#fff;border:1.5px solid #e2e8f0;border-left:6px solid #94a3b8;border-radius:14px;padding:12px 14px;display:flex;flex-direction:column;gap:4px}
.al-card.flash{animation:alPisca 1s 6}
.al-card .al-c1{display:flex;justify-content:space-between;align-items:baseline;gap:6px}
.al-card .al-c1 b{font-size:14px;font-weight:800;color:#042D4D}
.al-card .al-c1 span{font-size:12px;font-weight:800;white-space:nowrap}
.al-card .al-c2{font-size:11.5px;color:#64748b;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.al-card .al-inds{display:flex;flex-direction:column;gap:4px;margin:6px 0 2px}
.al-card .al-ind{display:flex;justify-content:space-between;align-items:baseline;gap:8px;background:#f8fafc;border:1px solid #e2e8f0;border-radius:7px;padding:4px 9px}
.al-card .al-ind i{font-style:normal;font-size:11px;font-weight:700;color:#64748b;white-space:nowrap}
.al-card .al-ind em{font-style:normal;font-size:15px;font-weight:800;color:#042D4D;font-variant-numeric:tabular-nums;white-space:nowrap}
.al-card .al-ind.fora{background:#fee2e2;border-color:#ef4444}
.al-card .al-ind.fora i,.al-card .al-ind.fora em{color:#991b1b}
.al-card .al-c3{font-size:11px;font-weight:700;margin-top:2px}
.al-card.aguarda{border-left-color:#cbd5e1;background:#fafbfc}
#al-modal{position:fixed;inset:0;z-index:10000;background:rgba(3,32,54,.6);display:flex;align-items:center;justify-content:center;padding:16px}
#al-modal .box{background:#fff;border-radius:16px;padding:18px;width:min(420px,100%);display:flex;flex-direction:column;gap:10px}
#al-modal h3{margin:0;color:#042D4D;font-size:17px}
#al-modal p{margin:0;font-size:13px;color:#475569;line-height:1.45}
#al-modal label{display:flex;align-items:center;gap:10px;font-size:16px;font-weight:700;padding:10px;border-radius:10px;background:#f8fafc;cursor:pointer}
#al-modal label input{width:22px;height:22px}
#al-modal .acoes{display:flex;gap:8px;justify-content:flex-end;margin-top:6px}
#al-modal .acoes button{font:inherit;font-weight:800;border:0;border-radius:10px;padding:12px 16px;cursor:pointer}`;
    document.head.appendChild(s);
  }

  /* ── BOTÃO 🔔 E MENU ────────────────────────────────────────────────── */
  function montarBotao() {
    if (document.getElementById('al-bt')) return;
    const bt = document.createElement('button'); bt.id = 'al-bt'; bt.type = 'button';
    bt.onclick = () => {
      prepara();
      if (!audioLiberado() && somLigado()) { setTimeout(desenharBotao, 150); aviso('🔔 Som dos avisos ligado nesta tela.', 'success'); return; }
      alternarMenu();
    };
    document.body.appendChild(bt);
    const m = document.createElement('div'); m.id = 'al-menu'; document.body.appendChild(m);
    document.addEventListener('click', e => {
      const menu = document.getElementById('al-menu');
      if (menu && menu.classList.contains('aberto') && !menu.contains(e.target) && e.target.id !== 'al-bt') menu.classList.remove('aberto');
    });
    // qualquer toque na tela também libera o som
    ['pointerdown', 'keydown'].forEach(ev => document.addEventListener(ev, () => { if (somLigado()) { prepara(); setTimeout(desenharBotao, 150); } }, { passive: true }));
    desenharBotao();
  }
  function desenharBotao() {
    const bt = document.getElementById('al-bt'); if (!bt) return;
    bt.classList.remove('trava', 'off');
    if (!somLigado()) { bt.classList.add('off'); bt.innerHTML = '🔕'; bt.title = 'Som dos avisos desligado nesta tela'; }
    else if (!audioLiberado()) { bt.classList.add('trava'); bt.innerHTML = '🔇 Toque aqui para ligar o som dos avisos'; bt.title = ''; }
    else { bt.innerHTML = '🔔'; bt.title = 'Avisos do Status das Linhas'; }
  }
  async function alternarMenu() {
    const m = document.getElementById('al-menu');
    if (m.classList.contains('aberto')) { m.classList.remove('aberto'); return; }
    const sub = await pushAtual().catch(() => null);
    m.innerHTML = `
      <h4>🔔 Avisos do Status das Linhas</h4>
      <p>Quando o laboratório muda o status de uma linha, esta tela toca um som e mostra o aviso.</p>
      <button class="pri" data-a="testar">🔊 Testar o som</button>
      <button data-a="som">${somLigado() ? '🔕 Desligar o som' : '🔔 Ligar o som'}</button>
      <label style="display:flex;align-items:center;gap:8px;font-size:13px;font-weight:700;">🔈<input type="range" id="al-vol" min="0.1" max="1" step="0.1" value="${typeof volumeSom==='function'?volumeSom():0.8}" style="flex:1;">🔊</label>
      <p id="al-vol-t" style="margin:-4px 0 0;">Volume: ${Math.round((typeof volumeSom==='function'?volumeSom():0.8)*100)}% — vale para todos os avisos</p>
      ${sub ? `<p>📱 Este aparelho <b>recebe</b> as notificações.</p>
               <button data-a="celular">⚙️ Escolher quais avisos recebo</button>
               <button data-a="parar">✖ Parar notificações neste aparelho</button>`
            : `<button data-a="celular">📱 Receber avisos neste aparelho (mesmo com o ERP fechado)</button>`}`;
    m.querySelectorAll('button').forEach(b => b.onclick = () => acaoMenu(b.dataset.a));
    const vr = m.querySelector('#al-vol');
    if (vr) { vr.oninput = () => { if (typeof definirVolume === 'function') definirVolume(vr.value); m.querySelector('#al-vol-t').textContent = `Volume: ${Math.round(vr.value * 100)}% — vale para todos os avisos`; };
      vr.onchange = () => { prepara(); tocar('OK', true); }; }
    m.classList.add('aberto');
  }
  function acaoMenu(a) {
    const m = document.getElementById('al-menu'); m.classList.remove('aberto');
    if (a === 'testar') testarSom();
    else if (a === 'som') { const ligar = !somLigado(); if (typeof definirSom === 'function') definirSom(ligar); else ls.set(LS_SOM, ligar ? 'on' : 'off'); if (!somLigado()) pararRepeticao(); desenharBotao(); aviso(somLigado() ? 'Som ligado nesta tela.' : 'Som desligado nesta tela.', 'info'); }
    else if (a === 'celular') escolherAvisosCelular();
    else if (a === 'parar') pararCelular();
  }
  function testarSom() {
    if (!somLigado()) { if (typeof definirSom === 'function') definirSom(true); else ls.set(LS_SOM, 'on'); }
    prepara();
    const seq = ['OK', 'Ajuste', 'Manutenção', 'Parada'];
    let i = 0;
    const prox = () => { if (i >= seq.length) return; const s = seq[i++]; mostrarTeste(s); tocar(s, true); setTimeout(prox, 3600); };
    setTimeout(() => { desenharBotao(); prox(); }, 120);
  }
  function mostrarTeste(s) {
    mostrar({ id: 'teste-' + s, linha: 'TESTE', status_novo: s, status_antes: null, produto: 'Só um teste do som', turno: null, hora: null }, true);
    setTimeout(() => confirmar('teste-' + s), 3400);
  }

  /* ── AVISO GRANDE NA TELA ───────────────────────────────────────────── */
  function ov() {
    let o = document.getElementById('al-ov');
    if (!o) { o = document.createElement('div'); o.id = 'al-ov'; document.body.appendChild(o); }
    return o;
  }
  function mostrar(e, teste) {
    const c = ST[e.status_novo] || ST_SEM;
    const antes = e.status_antes ? (ST[e.status_antes] || ST_SEM) : null;
    const det = [antes ? `antes: ${antes.ic} ${e.status_antes}` : null, e.produto, e.turno, e.hora ? String(e.hora).slice(0, 5) : null, e.responsavel ? 'por ' + e.responsavel : null].filter(Boolean).join(' · ');
    // um aviso por linha: se a mesma linha mudou de novo, troca o aviso
    abertos.filter(a => a.linha === e.linha && !teste).forEach(a => confirmar(a.id, true));
    const d = document.createElement('div');
    d.className = 'al-av' + (c.repete ? ' pisca' : ''); d.style.background = c.cor; d.dataset.id = e.id;
    d.innerHTML = `<div class="al-ic">${c.ic}</div>
      <div class="al-tx"><div class="al-t1">${escH(String(e.linha).toUpperCase())} — ${c.txt}</div><div class="al-t2">${escH(det)}</div></div>
      <button type="button">OK, VI</button>`;
    d.querySelector('button').onclick = () => { prepara(); confirmar(e.id); };
    ov().appendChild(d);
    abertos.push({ id: e.id, linha: e.linha, status: e.status_novo, el: d });
  }
  function confirmar(id, semParar) {
    const i = abertos.findIndex(a => String(a.id) === String(id));
    if (i < 0) return;
    abertos[i].el.remove(); abertos.splice(i, 1);
    if (!abertos.some(a => (ST[a.status] || {}).repete)) pararRepeticao();
    if (!semParar && !abertos.length) parar();
  }
  function iniciarRepeticao() {
    repeteDesde = Date.now();
    if (repeteTimer) return;
    repeteTimer = setInterval(() => {
      const urg = abertos.find(a => (ST[a.status] || {}).repete);
      if (!urg || Date.now() - repeteDesde > REPETE_MAX_MS) { pararRepeticao(); return; }
      tocar(urg.status);
    }, REPETE_MS);
  }
  function pararRepeticao() { if (repeteTimer) clearInterval(repeteTimer); repeteTimer = null; }

  /* ── EVENTOS (banco + canal ao vivo) ────────────────────────────────── */
  async function buscarNovos() {
    if (buscando || typeof _supabase === 'undefined') return;
    buscando = true;
    try {
      if (ultimoId == null) {                  // 1ª leitura: só marca onde está, não toca o passado
        const r = await _supabase.from('linhas_status_eventos').select('id').order('id', { ascending: false }).limit(1);
        if (r.error) { console.error('[alerta-linhas] eventos:', r.error.message); return; }
        ultimoId = (r.data && r.data[0] && r.data[0].id) || 0;
        return;
      }
      const r = await _supabase.from('linhas_status_eventos')
        .select('id,linha,status_novo,status_antes,produto,turno,hora,responsavel,criado_em')
        .gt('id', ultimoId).order('id').limit(20);
      if (r.error) { console.error('[alerta-linhas] eventos:', r.error.message); return; }
      (r.data || []).forEach(chegou);
    } finally { buscando = false; }
  }
  function chegou(e) {
    if (e.id <= ultimoId) return;
    ultimoId = e.id;
    if (e.criado_em && Date.now() - new Date(e.criado_em).getTime() > VALIDADE_MS) return;   // tela ficou desligada: não toca coisa velha
    mostrar(e);
    tocar(e.status_novo);
    if ((ST[e.status_novo] || {}).repete) iniciarRepeticao();
    if (opts.faixa) desenharFaixa(e.linha);
    if (typeof opts.aoMudar === 'function') { try { opts.aoMudar(e); } catch (err) { console.error('[alerta-linhas] aoMudar:', err); } }
  }
  function ligarCanal() {
    try {
      if (!window.supabase || typeof SUPABASE_URL === 'undefined') return;
      rt = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY, { auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false, storageKey: 'erp-alerta-linhas' } });
      canal = rt.channel('linhas-status')
        .on('broadcast', { event: 'mudou' }, () => buscarNovos())
        .subscribe(st => { if (st === 'CHANNEL_ERROR' || st === 'TIMED_OUT') console.warn('[alerta-linhas] canal ao vivo:', st, '— seguindo pelo banco a cada 15 s'); });
    } catch (e) { console.error('[alerta-linhas] canal ao vivo não ligou:', e); }
  }

  /* ── FAIXA "STATUS DAS LINHAS" (aferidor) ───────────────────────────
     Mesmo card do dashboard e do laboratório: SÓ a análise de HOJE de cada
     linha (sem análise hoje → "Aguardando análise"), com Granulometria,
     Separador e Umidade e as faixas de js/regras.js (cor só fora da faixa).
     Separador: o gravado na análise; vazio → última aferição da linha.     */
  let _faixa = { linhas: [], porLinha: {}, afs: [], hoje: '' };
  const hojeLocal = () => { const d = new Date(); return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0'); };
  const f2 = v => Number(v).toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  function idadeTxt(a) {
    const dt = new Date(a.data + 'T' + String(a.hora || '00:00').slice(0, 5) + ':00');
    if (isNaN(dt)) return '';
    const h = Math.max(0, (Date.now() - dt.getTime()) / 36e5);
    return h < 1 ? 'há menos de 1 h' : 'há ' + Math.round(h) + ' h';
  }
  function cardHTML(nome, piscar) {
    const a = _faixa.porLinha[nome];
    if (!a) return `<div class="al-card aguarda${piscar === nome ? ' flash' : ''}"><div class="al-c1"><b>${escH(nome)}</b><span style="color:#64748b">⏳ Aguardando análise</span></div>
      <div class="al-c2">nenhuma análise hoje</div></div>`;
    const c = ST[a.status] || ST_SEM;
    let inds = '';
    if (window.Regras && Regras.labIndicadoresCard) {
      const ind = Regras.labIndicadoresCard(a, _faixa.afs);
      const gf = ind.granFaixa, uf = ind.umidadeFaixa;
      const faixaG = ind.granMax === null ? ind.granMin + '% ou mais' : ind.granMin + ' a ' + ind.granMax + '%';
      const cel = (rot, val, fora, dica) => `<div class="al-ind${fora ? ' fora' : ''}" title="${escH(dica)}"><i>${rot}</i><em>${val}</em></div>`;
      inds = `<div class="al-inds">
        ${cel('Granulometria', ind.gran === null ? '—' : (gf === 'baixo' ? '▼ ' : gf === 'alto' ? '▲ ' : '') + f2(ind.gran) + '%', gf === 'baixo' || gf === 'alto', 'Faixa: ' + faixaG)}
        ${cel('Separador', ind.separador === null ? '—' : escH(ind.separador), false, ind.separadorOrigem === 'aferidor' ? 'Da última aferição da linha' : 'Gravado na análise')}
        ${cel('Umidade', ind.umidade === null ? '—' : (uf === 'alta' ? '▲ ' : '') + f2(ind.umidade) + '%', uf === 'alta', 'Até ' + f2(Regras.LAB_UMIDADE_MAX) + '%')}</div>`;
    }
    return `<div class="al-card${piscar === nome ? ' flash' : ''}" style="border-left-color:${c.cor}">
      <div class="al-c1"><b>${escH(nome)}</b><span style="color:${c.cor}">${c.ic} ${escH(a.status || '—')}</span></div>
      <div class="al-c2">${escH(a.produto || '—')}${a.turno ? ' · ' + escH(a.turno) : ''}</div>
      ${inds}
      <div class="al-c3" style="color:#64748b">análise das ${escH(String(a.hora || '').slice(0, 5))} · ${idadeTxt(a)}</div></div>`;
  }
  async function carregarFaixa() {
    const hj = hojeLocal();
    const [ln, an, af] = await Promise.all([
      _supabase.from('linhas_producao').select('nome').eq('status', 'ativo').order('nome'),
      _supabase.from('laboratorio').select('id,linha,data,hora,status,produto,turno,responsavel,separador,umidade,peneiramento')
        .eq('data', hj).order('hora', { ascending: false }).limit(200),
      _supabase.from('aferidor_aditivacao').select('numero,data,hora,linha,itens').order('data', { ascending: false }).limit(60),
    ]);
    const err = ln.error || an.error;
    if (err) throw err;
    const por = {};
    (an.data || []).forEach(r => { if (r.linha && !por[r.linha]) por[r.linha] = r; });   // já vem da mais nova p/ mais velha
    _faixa = { linhas: (ln.data || []).map(l => l.nome), porLinha: por, afs: af.error ? [] : (af.data || []), hoje: hj };
  }
  async function desenharFaixa(piscar) {
    const el = document.getElementById(opts.faixa); if (!el) return;
    try { await carregarFaixa(); }
    catch (e) {
      console.error('[alerta-linhas] faixa:', e.message || e);
      el.innerHTML = `<div style="font-size:12px;color:#b91c1c;margin-bottom:12px;">⚠️ Não foi possível ler o Status das Linhas: ${escH(e.message || e)}</div>`;
      return;
    }
    el.innerHTML = `<div style="font-size:12px;font-weight:800;color:#042D4D;text-transform:uppercase;letter-spacing:1px;margin-bottom:8px;">🏭 Como a linha está agora <span style="font-weight:600;text-transform:none;letter-spacing:0;color:#64748b;">— análise de hoje</span></div>
      <div class="al-cards">${_faixa.linhas.map(n => cardHTML(n, piscar)).join('') || '<div style="color:#64748b;font-size:13px;">Nenhuma linha ativa.</div>'}</div>`;
    if (typeof opts.aoDesenharFaixa === 'function') { try { opts.aoDesenharFaixa(); } catch (e) { /* tela que usa o card */ } }
  }

  /* ── CELULAR (Web Push) ─────────────────────────────────────────────── */
  const pushSuportado = () => 'serviceWorker' in navigator && 'PushManager' in window && 'Notification' in window;
  const ehIOS = () => /iPad|iPhone|iPod/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  const instalado = () => (window.matchMedia && matchMedia('(display-mode: standalone)').matches) || navigator.standalone === true;
  async function pushAtual() {
    if (!pushSuportado()) return null;
    const reg = await navigator.serviceWorker.getRegistration();
    return reg ? reg.pushManager.getSubscription() : null;
  }
  function b64ParaBytes(s) {
    const p = '='.repeat((4 - s.length % 4) % 4), b = atob((s + p).replace(/-/g, '+').replace(/_/g, '/'));
    return Uint8Array.from(b, c => c.charCodeAt(0));
  }
  function bytesParaB64(buf) {
    let s = ''; new Uint8Array(buf).forEach(x => { s += String.fromCharCode(x); });
    return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  }
  function nomeAparelho() {
    const u = navigator.userAgent;
    const so = /Android/.test(u) ? 'Android' : ehIOS() ? 'iPhone/iPad' : /Windows/.test(u) ? 'Windows' : /Mac/.test(u) ? 'Mac' : 'Outro';
    const nav = /Edg\//.test(u) ? 'Edge' : /SamsungBrowser/.test(u) ? 'Samsung' : /Chrome\//.test(u) ? 'Chrome' : /Firefox\//.test(u) ? 'Firefox' : /Safari\//.test(u) ? 'Safari' : 'Navegador';
    return so + ' · ' + nav;
  }
  async function escolherAvisosCelular() {
    if (!pushSuportado()) {
      if (ehIOS() && !instalado()) modalInfo('📱 No iPhone', 'No Safari, toque em <b>Compartilhar</b> → <b>Adicionar à Tela de Início</b>. Depois abra o ERP pelo ícone novo e toque em 🔔 de novo.');
      else modalInfo('Este navegador não recebe notificações', 'Use o Chrome (Android ou computador), Edge ou Safari atualizado.');
      return;
    }
    let atuais = Object.keys(ST);
    const sub = await pushAtual().catch(() => null);
    if (sub) {
      const r = await _supabase.from('push_inscricoes').select('status_filtro').eq('endpoint', sub.endpoint).maybeSingle();
      if (!r.error && r.data && Array.isArray(r.data.status_filtro)) atuais = r.data.status_filtro;
    }
    const box = abrirModal(`<h3>📱 Avisos neste aparelho</h3>
      <p>Marque quais mudanças você quer receber. Chega mesmo com o ERP fechado.</p>
      ${Object.keys(ST).map(s => `<label style="border-left:6px solid ${ST[s].cor}"><input type="checkbox" value="${s}" ${atuais.includes(s) ? 'checked' : ''}> ${ST[s].ic} ${s}</label>`).join('')}
      <div class="acoes"><button data-x style="background:#f1f5f9;color:#042D4D">Cancelar</button><button data-ok style="background:#042D4D;color:#C9FF64">Salvar e testar</button></div>`);
    box.querySelector('[data-x]').onclick = fecharModal;
    box.querySelector('[data-ok]').onclick = async () => {
      const sel = [...box.querySelectorAll('input:checked')].map(i => i.value);
      if (!sel.length) { aviso('Marque pelo menos um tipo de aviso.', 'warning'); return; }
      const bt = box.querySelector('[data-ok]'); bt.disabled = true; bt.textContent = 'Aguarde...';
      const ok = await ligarCelular(sel);
      if (ok) fecharModal(); else { bt.disabled = false; bt.textContent = 'Salvar e testar'; }
    };
  }
  async function ligarCelular(statusSel) {
    try {
      const perm = await Notification.requestPermission();
      if (perm !== 'granted') {
        modalInfo('Notificação bloqueada', 'O navegador está bloqueando as notificações do ERP. Toque no <b>cadeado</b> ao lado do endereço → <b>Notificações</b> → <b>Permitir</b> e tente de novo.');
        return false;
      }
      let reg = await navigator.serviceWorker.getRegistration();
      if (!reg) reg = await navigator.serviceWorker.register('sw.js');
      reg = await navigator.serviceWorker.ready;
      const k = await _supabase.functions.invoke('push-linhas', { body: { acao: 'chave' } });
      if (k.error || !k.data || !k.data.publica) { aviso('Não foi possível ligar as notificações: ' + ((k.error && k.error.message) || (k.data && k.data.erro) || 'sem chave'), 'danger'); return false; }
      let sub = await reg.pushManager.getSubscription();
      if (sub && sub.options && sub.options.applicationServerKey && bytesParaB64(sub.options.applicationServerKey) !== k.data.publica) { await sub.unsubscribe(); sub = null; }
      if (!sub) sub = await reg.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: b64ParaBytes(k.data.publica) });
      const j = sub.toJSON(), u = (typeof getUser === 'function' && getUser()) || {};
      const row = { endpoint: j.endpoint, p256dh: j.keys.p256dh, auth: j.keys.auth, usuario_id: u.id || null, usuario_nome: u.nome || null,
        aparelho: nomeAparelho(), status_filtro: statusSel, ativo: true, falhas: 0, ultimo_erro: null, atualizado_em: new Date().toISOString() };
      const q = _supabase.from('push_inscricoes').upsert(row, { onConflict: 'endpoint' });
      const r = typeof db === 'function' ? await db(q, 'Cadastrar aparelho para notificação') : await q;
      if (r.error) return false;
      const t = await _supabase.functions.invoke('push-linhas', { body: { acao: 'teste', endpoint: j.endpoint } });
      if (t.error) aviso('Aparelho cadastrado, mas o teste não chegou: ' + t.error.message, 'warning');
      else aviso('📱 Pronto! Deve chegar uma notificação de teste agora.', 'success');
      return true;
    } catch (e) {
      console.error('[alerta-linhas] celular:', e);
      aviso('Não foi possível ligar as notificações: ' + (e.message || e), 'danger');
      return false;
    }
  }
  async function pararCelular() {
    try {
      const sub = await pushAtual();
      if (!sub) { aviso('Este aparelho já não recebe notificações.', 'info'); return; }
      const ep = sub.endpoint;
      await sub.unsubscribe();
      const q = _supabase.from('push_inscricoes').update({ ativo: false, atualizado_em: new Date().toISOString() }).eq('endpoint', ep);
      const r = typeof db === 'function' ? await db(q, 'Desligar notificação') : await q;
      if (!r.error) aviso('Notificações desligadas neste aparelho.', 'info');
    } catch (e) { console.error('[alerta-linhas] parar:', e); aviso('Erro ao desligar: ' + (e.message || e), 'danger'); }
  }
  function abrirModal(html) {
    fecharModal();
    const m = document.createElement('div'); m.id = 'al-modal';
    m.innerHTML = `<div class="box">${html}</div>`;
    m.addEventListener('click', e => { if (e.target === m) fecharModal(); });
    document.body.appendChild(m);
    return m.querySelector('.box');
  }
  function fecharModal() { const m = document.getElementById('al-modal'); if (m) m.remove(); }
  function modalInfo(t, p) {
    const b = abrirModal(`<h3>${t}</h3><p>${p}</p><div class="acoes"><button data-x style="background:#042D4D;color:#C9FF64">Entendi</button></div>`);
    b.querySelector('[data-x]').onclick = fecharModal;
  }

  /* ── INÍCIO ─────────────────────────────────────────────────────────── */
  let iniciado = false;
  function iniciar(o) {
    if (iniciado) return; iniciado = true;
    opts = o || {};
    const go = () => {
      css(); prepara(); montarBotao();   // TV/PC com Chrome em modo quiosque já libera o som sem toque
      if (opts.faixa) { desenharFaixa(); setInterval(() => { if (!document.hidden) desenharFaixa(); }, 60000); }   // análise nova com o mesmo status não gera evento
      buscarNovos();
      ligarCanal();
      setInterval(buscarNovos, POLL_MS);
    };
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', go); else go();
  }

  // cardLinha(nome): o card da linha (mesmo da faixa) para outra parte da tela usar — ex.: modo pátio do aferidor
  window.AlertaLinhas = { iniciar, tocar, testarSom, _chegou: chegou, cardLinha: n => cardHTML(n), atualizarFaixa: () => desenharFaixa(), _estado: () => ({ ultimoId, abertos: abertos.length, audio: audioLiberado(), repetindo: !!repeteTimer }) };
})();
