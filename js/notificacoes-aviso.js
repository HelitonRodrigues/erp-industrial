/* ============================================================
   AVISO DE NOTIFICAÇÕES  (migração 061)
   - Escuta a tabela `notificacoes` em tempo real (canal Realtime) e,
     de reserva, confere o banco a cada 60 s.
   - Notificação nova → som pelo tipo, aviso na tela do computador
     (quando a aba está em segundo plano) e contador no título da aba.
   - Urgente repete o som a cada 20 s até alguém marcar "Vi" (máx. 3 min).
   - Preferências ficam NESTE APARELHO (localStorage): som é coisa do
     computador/celular, não do usuário.
   - Várias abas abertas: só uma toca (trava curta no localStorage).
   Uso:  AvisoNotif.iniciar({ aoChegar: n => ..., aoMudar: n => ... })
   ============================================================ */
(function () {
  const LS = 'erp_notif_prefs';
  const PADRAO = { som: true, volume: 0.8, urgente: true, aviso: true, info: false, repetir: true, tela: true };
  const POLL_MS = 60000, REPETE_MS = 20000, REPETE_MAX_MS = 3 * 60 * 1000;

  const ls = {
    get(k) { try { return localStorage.getItem(k); } catch (e) { return null; } },
    set(k, v) { try { localStorage.setItem(k, v); } catch (e) { /* sem armazenamento */ } },
  };
  function prefs() {
    let p = {}; try { p = JSON.parse(ls.get(LS) || '{}') || {}; } catch (e) { p = {}; }
    return Object.assign({}, PADRAO, p);
  }
  function salvarPrefs(p) { if (p && 'som' in p) { ls.set('erp_alerta_som', p.som ? 'on' : 'off'); if (!p.som) parar(); }
    ls.set(LS, JSON.stringify(Object.assign(prefs(), p))); if (master) master.gain.value = 1.6 * prefs().volume; }

  /* ── SOM (gerado no navegador, sem arquivo) ─────────────────────────── */
  let ctx = null, master = null, ativos = [];
  function prepara() {
    if (!ctx) {
      const AC = window.AudioContext || window.webkitAudioContext;
      if (!AC) return false;
      ctx = new AC();
      const comp = ctx.createDynamicsCompressor();
      comp.threshold.value = -20; comp.ratio.value = 8; comp.attack.value = 0.002; comp.release.value = 0.15;
      master = ctx.createGain(); master.gain.value = 1.6 * prefs().volume;
      window.addEventListener('erp-volume', () => { if (master) master.gain.value = 1.6 * prefs().volume; });
      master.connect(comp); comp.connect(ctx.destination);
    }
    if (ctx.state === 'suspended') ctx.resume().then(avisarMudanca, () => {});
    return true;
  }
  const liberado = () => !!ctx && ctx.state === 'running';
  function tom(f, ini, dur, { tipo = 'sine', vol = 0.8, decai = true, fim = null } = {}) {
    const o = ctx.createOscillator(), g = ctx.createGain();
    o.type = tipo; o.frequency.setValueAtTime(f, ini);
    if (fim) o.frequency.linearRampToValueAtTime(fim, ini + dur);
    g.gain.setValueAtTime(0.0001, ini); g.gain.linearRampToValueAtTime(vol, ini + 0.006);
    if (decai) g.gain.exponentialRampToValueAtTime(0.0001, ini + dur);
    else { g.gain.setValueAtTime(vol, ini + dur - 0.02); g.gain.linearRampToValueAtTime(0.0001, ini + dur); }
    o.connect(g); g.connect(master); o.start(ini); o.stop(ini + dur + 0.05); ativos.push(o);
  }
  const SONS = {
    // urgente: alarme de dois tons, 3 vezes
    urgente(t) { for (let i = 0; i < 3; i++) { const b = t + i * 0.9; tom(880, b, 0.38, { tipo: 'square', vol: 0.45, decai: false }); tom(660, b + 0.42, 0.38, { tipo: 'square', vol: 0.45, decai: false }); } },
    // aviso: dois bipes
    aviso(t) { [0, 0.28].forEach(d => tom(1180, t + d, 0.16, { tipo: 'square', vol: 0.4, decai: false })); },
    // informativo: ding suave
    info(t) { tom(988, t, 0.9, { tipo: 'triangle', vol: 0.8 }); tom(1976, t, 0.5, { vol: 0.2 }); },
  };
  function parar() { ativos.forEach(o => { try { o.stop(); } catch (e) { /* já parou */ } }); ativos = []; }
  function tocar(tipo, forcar) {
    const p = prefs();
    tipo = SONS[tipo] ? tipo : 'info';
    if (!forcar && (!p.som || !p[tipo] || (typeof somDesligado === 'function' && somDesligado()))) return false;
    if (!prepara() || !liberado()) { avisarMudanca(); return false; }
    parar(); SONS[tipo](ctx.currentTime + 0.05); return true;
  }
  // o navegador só libera som depois de um toque/tecla na página
  ['pointerdown', 'keydown', 'touchstart'].forEach(ev => document.addEventListener(ev, () => { prepara(); }, { passive: true }));

  /* ── AVISO NA TELA DO COMPUTADOR (Notification API) ───────────────── */
  const telaSuportada = () => 'Notification' in window;
  const telaPermitida = () => telaSuportada() && Notification.permission === 'granted';
  async function pedirTela() {
    if (!telaSuportada()) return 'nao-suportado';
    try { const r = await Notification.requestPermission(); avisarMudanca(); return r; } catch (e) { return 'negado'; }
  }
  function mostrarNaTela(n) {
    const p = prefs();
    if (!p.tela || !telaPermitida() || !document.hidden) return;
    try {
      const nt = new Notification((n.tipo === 'urgente' ? '🔴 ' : n.tipo === 'aviso' ? '🟡 ' : '') + (n.titulo || 'Nova notificação'),
        { body: n.descricao || '', tag: 'erp-notif-' + n.id, requireInteraction: n.tipo === 'urgente', icon: 'favicon.ico' });
      nt.onclick = () => { window.focus(); if (!/notificacoes\.html/.test(location.pathname)) location.href = 'notificacoes.html'; nt.close(); };
    } catch (e) { /* alguns navegadores só permitem pelo service worker */ }
  }

  /* ── REPETIÇÃO DO URGENTE ──────────────────────────────────────────── */
  const pendUrg = new Map();   // id → desde
  let repeteTimer = null;
  function agendarRepeticao() {
    if (repeteTimer) return;
    repeteTimer = setInterval(() => {
      const agora = Date.now();
      for (const [id, desde] of pendUrg) if (agora - desde > REPETE_MAX_MS) pendUrg.delete(id);
      if (!pendUrg.size || !prefs().repetir) { clearInterval(repeteTimer); repeteTimer = null; return; }
      if (minhaVez('rep')) tocar('urgente');
    }, REPETE_MS);
  }
  function confirmar(id) { if (id == null) pendUrg.clear(); else pendUrg.delete(id); if (!pendUrg.size) parar(); }

  /* várias abas: só uma toca o mesmo aviso */
  function minhaVez(chave) {
    const k = 'erp_notif_tocou:' + chave, agora = Date.now(), ult = +ls.get(k) || 0;
    if (agora - ult < 2500) return false;
    ls.set(k, String(agora)); return true;
  }

  /* ── CHEGADA ───────────────────────────────────────────────────────── */
  const vistos = new Set();
  let opts = {}, inicioMs = Date.now(), ultimoTs = null;
  function anunciar(n, { silencioso = false, denovo = false } = {}) {
    if (!n || !n.id || (vistos.has(n.id) && !denovo)) return;
    vistos.add(n.id);
    if (n.created_at && (!ultimoTs || n.created_at > ultimoTs)) ultimoTs = n.created_at;
    if (typeof opts.aoChegar === 'function') { try { opts.aoChegar(n); } catch (e) { console.warn(e); } }
    if (silencioso) return;
    const tipo = n.tipo === 'alerta' ? 'urgente' : (n.tipo || 'info');
    if (minhaVez(n.id)) tocar(tipo);
    mostrarNaTela(n);
    if (tipo === 'urgente' && prefs().repetir) { pendUrg.set(n.id, Date.now()); agendarRepeticao(); }
    if (!opts.semToast && typeof toast === 'function') toast((tipo === 'urgente' ? '🔴 ' : '🔔 ') + (n.titulo || 'Nova notificação'), tipo === 'urgente' ? 'danger' : 'warning');
  }

  /* ── TEMPO REAL + RESERVA ─────────────────────────────────────────── */
  let canal = null, conectado = false;
  function assinar() {
    if (typeof _supabase === 'undefined' || !_supabase.channel) return;
    try {
      canal = _supabase.channel('notificacoes-aviso')
        .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'notificacoes' }, p => anunciar(p.new))
        .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'notificacoes' }, p => {
          const n = p.new || {};
          if (n.status_notif && n.status_notif !== 'novo') confirmar(n.id);
          if (typeof opts.aoMudar === 'function') { try { opts.aoMudar(n); } catch (e) { console.warn(e); } }
        })
        .subscribe(st => { conectado = st === 'SUBSCRIBED'; avisarMudanca(); });
    } catch (e) { conectado = false; }
  }
  async function conferir() {
    if (typeof _supabase === 'undefined') return;
    try {
      const desde = ultimoTs || new Date(inicioMs - 5000).toISOString();
      const { data } = await _supabase.from('notificacoes').select('*').gt('created_at', desde).order('created_at', { ascending: true }).limit(50);
      (data || []).forEach(n => anunciar(n));
    } catch (e) { /* tenta de novo no próximo ciclo */ }
  }

  /* quem quiser redesenhar o estado (página de notificações) */
  const ouvintes = [];
  function avisarMudanca() { ouvintes.forEach(f => { try { f(estado()); } catch (e) { /* ignora */ } }); }
  function estado() { return { conectado, liberado: liberado(), tela: telaSuportada() ? Notification.permission : 'nao-suportado', prefs: prefs() }; }

  let iniciado = false;
  function iniciar(o) {
    opts = Object.assign(opts, o || {});
    if (iniciado) return;
    iniciado = true; inicioMs = Date.now();
    assinar();
    setInterval(() => { if (!document.hidden || !conectado) conferir(); }, POLL_MS);
  }

  window.AvisoNotif = {
    iniciar, anunciar, tocar, parar, confirmar, prefs, salvarPrefs, pedirTela, estado,
    liberar() { prepara(); setTimeout(avisarMudanca, 150); },
    aoMudarEstado(f) { ouvintes.push(f); f(estado()); },
  };
})();
