// prog-rep — dados do representante logado (representante.html).
// Segurança:
//  • Sem JWT do ERP. Auth = token da sessão do representante (rep_sessao, só service_role executa).
//  • Filtra no SERVIDOR pelo representante da conta (igualdade exata). Nenhum pedido de outro
//    representante sai daqui — nem anônimo: a conta dos dias livres é feita aqui, e só o
//    "cabem X" de cada dia vai para o celular.
//  • A conta é a MESMA do ERP: o motor é lido do próprio site (js/programacao-motor.js),
//    então ERP, link e representante nunca divergem.
//  • (20/11) pedido CANCELADO (pela fábrica ou no SalesCode) não aparece e não ocupa capacidade.
//  • (22/11, v5) DOCUMENTOS (NF e laudo) dos pedidos carregados desde DOCS_DESDE:
//      - documento só pelo NÚMERO DO PEDIDO (portaria_nfs.pedido / lab_laudo_carregamentos.pedido_numero),
//        nunca por cliente ou caminhão; documento sem pedido não aparece;
//      - para abrir, o servidor confere DE NOVO que o pedido é deste representante (programacao_cargas);
//      - NF: link assinado de 5 min (bucket privado); laudo: HTML montado aqui com SÓ o cliente/pedido dele.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const SITE = "https://erp-industrial-theta.vercel.app";
const CAULIM = ["Bag", "Linha 25kg"];
const DOCS_DESDE = "2026-11-03";
const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });

const CORS = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "content-type, apikey, authorization, x-client-info", "Access-Control-Allow-Methods": "POST, OPTIONS" };
const resp = (o: unknown, st = 200) => new Response(JSON.stringify(o), { status: st, headers: { ...CORS, "Content-Type": "application/json" } });

// motor (cache 10 min)
let _motor: any = null, _motorEm = 0;
async function motor() {
  if (_motor && Date.now() - _motorEm < 600_000) return _motor;
  const r = await fetch(SITE + "/js/programacao-motor.js?v=" + Math.floor(Date.now() / 600_000));
  if (!r.ok) { if (_motor) return _motor; throw new Error("motor indisponível " + r.status); }
  const g: any = {};
  new Function("G", (await r.text()).replace(/\}\)\(typeof window[^)]*\);?\s*$/, "})(G);"))(g);
  if (!g.ProgMotor) throw new Error("motor inválido");
  _motor = g.ProgMotor; _motorEm = Date.now(); return _motor;
}
const hojeSP = () => new Date(Date.now() - 3 * 3600_000).toISOString().slice(0, 10);
const chk = (r: any, o: string) => { if (r.error) throw new Error(o + ": " + r.error.message); return r.data; };
const pedidosDoLink = (s: any) => String(s || "").split(/\s*,\s*/).map((x) => x.trim()).filter(Boolean);
const E = (s: any) => String(s == null ? "" : s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" } as any)[c]);
const fmtQtd = (q: any, u: any) => Number(q || 0).toLocaleString("pt-BR", { maximumFractionDigits: u === "t" ? 3 : 0 }) + " " +
  (u === "bag" ? (Number(q) === 1 ? "bag" : "bags") : u === "sc" ? "sacos" : u === "t" ? "t" : (u || ""));

// o pedido é deste representante? (consulta direta, sem depender da lista enviada antes)
async function pedidoDoRep(pedido: string, REP: string) {
  if (!pedido) return false;
  const { data, error } = await sb.from("programacao_cargas").select("pedido,representante").eq("pedido", pedido).eq("representante", REP).limit(1);
  if (error) throw new Error("conferência do pedido: " + error.message);
  return !!(data && data.length && data[0].representante === REP && data[0].pedido === pedido);
}

// quadro "Fornecimento (esta remessa)" — igual ao js/certificados.js, mas SÓ com o pedido deste representante
function blocoRemessa(x: any) {
  const d = x.data ? new Date(x.data + "T12:00:00").toLocaleDateString("pt-BR", { timeZone: "America/Sao_Paulo" }) : "—";
  const q = x.quantidade != null ? fmtQtd(x.quantidade, x.unidade) + (x.unidade !== "t" && x.peso_kg ? ` (${(Number(x.peso_kg) / 1000).toLocaleString("pt-BR", { maximumFractionDigits: 3 })} t)` : "") : "—";
  return `<div class="sec">Fornecimento (esta remessa)</div>
  <table class="cab"><colgroup><col style="width:23.85%"><col style="width:26.19%"><col style="width:23.83%"><col style="width:26.13%"></colgroup>
    <tr class="z"><td class="rot">Cliente</td><td colspan="3">${E(x.cliente || "—")}</td></tr>
    <tr><td class="rot">Quantidade deste lote</td><td class="cz"><b>${E(q)}</b></td><td class="rot">Data de expedição</td><td>${E(d)}</td></tr>
    <tr class="z"><td class="rot">Ordem de carregamento</td><td>${E(x.ordem_numero || "—")}${x.pedido_numero ? " · pedido " + E(x.pedido_numero) : ""}${x.nota_fiscal ? " · NF " + E(String(x.nota_fiscal).replace(/^0+/, "")) : ""}</td><td class="rot">Placa</td><td>${E(x.placa || "—")}</td></tr>
  </table>
  `;
}

async function abrirDoc(doc: any, REP: string) {
  const tipo = doc && doc.tipo, id = doc && String(doc.id || "");
  if (!/^[0-9a-f-]{36}$/i.test(id)) return resp({ ok: false, motivo: "Documento inválido." }, 400);
  if (tipo === "nf") {
    const n = chk(await sb.from("portaria_nfs").select("id,pedido,numero,arquivo_path,arquivo_nome").eq("id", id).maybeSingle(), "nf");
    if (!n || !n.arquivo_path || !(await pedidoDoRep(n.pedido, REP))) return resp({ ok: false, motivo: "Documento não encontrado." }, 404);
    const ext = (String(n.arquivo_path).split(".").pop() || "pdf").toLowerCase();
    const nome = `NF_${String(n.numero || "").replace(/^0+/, "")}_pedido_${n.pedido}.${ext}`;
    const s = await sb.storage.from("documentos").createSignedUrl(n.arquivo_path, 300, { download: false });
    if (s.error || !s.data) throw new Error("link da NF: " + (s.error && s.error.message));
    return resp({ ok: true, tipo: "nf", url: s.data.signedUrl, nome, ext });
  }
  if (tipo === "laudo") {
    const lk = chk(await sb.from("lab_laudo_carregamentos").select("*").eq("id", id).maybeSingle(), "ligação");
    if (!lk) return resp({ ok: false, motivo: "Documento não encontrado." }, 404);
    // o pedido DELE dentro da ligação (a ligação pode juntar pedidos de clientes diferentes do mesmo lote)
    let meu = "";
    for (const p of pedidosDoLink(lk.pedido_numero)) if (await pedidoDoRep(p, REP)) { meu = p; break; }
    if (!meu) return resp({ ok: false, motivo: "Documento não encontrado." }, 404);
    const l = chk(await sb.from("lab_laudos").select("id,numero,status,arquivo_path").eq("id", lk.laudo_id).maybeSingle(), "laudo");
    if (!l || l.status !== "finalizado" || !l.arquivo_path) return resp({ ok: false, motivo: "O laudo ainda não está pronto." }, 404);
    const dl = await sb.storage.from("documentos").download(l.arquivo_path);
    if (dl.error || !dl.data) throw new Error("arquivo do laudo: " + (dl.error && dl.error.message));
    let html = await dl.data.text();
    // remessa só com o cliente/pedido dele; ligação com mais de um pedido: quantidade pela ordem só do pedido dele
    const x: any = { ...lk, pedido_numero: meu };
    if (pedidosDoLink(lk.pedido_numero).length > 1) {
      const cg = chk(await sb.from("programacao_cargas").select("pedido,cliente_salescode,planilha").eq("pedido", meu).eq("representante", REP).limit(1), "pedido")[0] || {};
      x.cliente = (cg.planilha && cg.planilha.cliente) || cg.cliente_salescode || "—";
      x.peso_kg = null; x.nota_fiscal = null; x.quantidade = null;
      if (lk.romaneio_id) {
        const its = chk(await sb.from("romaneio_itens").select("quantidade,produto_erp,produto").eq("romaneio_id", lk.romaneio_id).eq("pedido", meu), "itens");
        const nm = (s: any) => String(s || "").toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "").trim();
        const q = its.filter((i: any) => nm(i.produto_erp) === nm(lk.produto)).reduce((a: number, i: any) => a + (parseFloat(i.quantidade) || 0), 0);
        if (q > 0) x.quantidade = q;
      }
    }
    const nfs = chk(await sb.from("portaria_nfs").select("numero").eq("pedido", meu).limit(5), "nf");
    if (nfs.length) x.nota_fiscal = nfs.map((n: any) => String(n.numero || "").replace(/^0+/, "")).join(", ");
    const marca = '<div class="sec">Identificação do produto</div>';
    html = html.includes(marca) ? html.replace(marca, blocoRemessa(x) + marca) : html.replace("</h1>", "</h1>" + blocoRemessa(x));
    return resp({ ok: true, tipo: "laudo", html, nome: `Laudo_${l.numero || ""}_pedido_${meu}.pdf`, numero: l.numero });
  }
  return resp({ ok: false, motivo: "Tipo de documento inválido." }, 400);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  if (req.method !== "POST") return resp({ ok: false, motivo: "método" }, 405);
  try {
    const { token, doc } = await req.json().catch(() => ({}));
    if (typeof token !== "string" || token.length < 40 || token.length > 200) return resp({ ok: false, sessao: false, motivo: "Entre de novo." }, 401);
    const ses = chk(await sb.rpc("rep_sessao", { p_token: token }), "sessão");
    const conta = Array.isArray(ses) ? ses[0] : null;
    if (!conta || !conta.representante) return resp({ ok: false, sessao: false, motivo: "Sessão expirada. Entre de novo." }, 401);
    const REP: string = conta.representante;
    if (doc) return await abrirDoc(doc, REP);

    const h = hojeSP(), fim = new Date(Date.parse(h) + 42 * 864e5).toISOString().slice(0, 10), desde30 = new Date(Date.parse(h) - 30 * 864e5).toISOString();
    const desdeCarr = DOCS_DESDE < desde30.slice(0, 10) ? DOCS_DESDE + "T03:00:00Z" : desde30;   // carregados: desde 03/11 (ou 30 dias, o que for mais antigo)
    const [meusR, carrR, cargaR, plR, tuR, prR, alR, atR, sincR] = await Promise.all([
      sb.from("programacao_cargas").select("*").eq("representante", REP).eq("carregado", false).eq("cancelado", false).limit(2000),
      sb.from("programacao_cargas").select("pedido,cliente_salescode,planilha,cidade,detalhes,itens,carregado_em,carregado_origem,balanca,representante").eq("representante", REP).eq("carregado", true).eq("cancelado", false).gte("carregado_em", desdeCarr).order("carregado_em", { ascending: false }).limit(800),
      sb.from("programacao_cargas").select("id,itens,planilha,linha_manual,status_salescode,data_manual,data_salescode,data_planilha,colunas_salescode,a_definir,cancelado").or(`carregado.eq.false,carregado_em.gte.${desde30.slice(0, 10)}`).limit(5000),   // carregado continua ocupando o dia programado
      sb.from("planejamentos_custo").select("codigo,nome,mes,ano,estado,atualizado_em").eq("status", "ativo").order("atualizado_em", { ascending: false }).limit(24),
      sb.from("turnos").select("nome,refeicao_min,calendario").limit(200),
      sb.from("produtos").select("id,nome,linhas,peso_unidade_kg,unidade").eq("status", "ativo").limit(1000),
      sb.from("produto_aliases").select("alias_norm,produto_id,produto_nome").limit(5000),
      sb.from("prog_atrasos").select("linha,inicio,dias,motivo,criado_em").is("desfeito_em", null).gte("criado_em", new Date(Date.now() - 10 * 864e5).toISOString()).order("criado_em", { ascending: false }).limit(20),
      sb.from("programacao_cargas").select("atualizado_salescode").order("atualizado_salescode", { ascending: false, nullsFirst: false }).limit(1),
    ]);
    const meusRaw = chk(meusR, "pedidos"), carrRaw = chk(carrR, "carregados"), cargaRaw = chk(cargaR, "carga");
    // trava extra: nada de outro representante passa, mesmo se a consulta mudar um dia
    if (meusRaw.some((c: any) => c.representante !== REP) || carrRaw.some((c: any) => c.representante !== REP)) throw new Error("filtro de representante");

    const M = await motor();
    M.iniciar({ planos: chk(plR, "planos"), turnos: chk(tuR, "turnos"), produtos: chk(prR, "produtos"), aliases: chk(alR, "apelidos") });
    const itensDe = (c: any) => M.itens(c).filter((i: any) => CAULIM.includes(i.fam)).map((i: any) => ({ nome: i.nome, q: i.q, un: i.un, fam: i.fam, mat: i.mat, t: i.t }));

    // dias livres: TODOS os pedidos que contam capacidade (igual ao ERP), conta feita aqui — cancelado não conta
    const porDia: Record<string, any[]> = {};
    cargaRaw.forEach((c: any) => { if (c.cancelado || c.a_definir || !M.contaCapacidade(c)) return; const d = M.dataDe(c); if (!d || d < h || d > fim) return; c._itens = M.itens(c); (porDia[d] = porDia[d] || []).push(c); });
    const livres: any[] = [];
    for (let k = 1; k <= 35; k++) {
      const iso = M.addDias(h, k); if (M.dow(iso) === 0) continue;
      const cap = M.capacidadeDia(iso), dia: any = { iso, estado: cap.estado || null };
      CAULIM.forEach(f => { const l = M.livre(iso, porDia[iso] || [], f); dia[f] = { livre: Math.max(0, Math.floor(l.livre + 1e-6)), total: Math.round(l.total || 0), fechado: !!l.fechado, semPlano: !!l.semPlano }; });
      livres.push(dia);
    }

    const meus = meusRaw.map((c: any) => {
      const its = itensDe(c); if (!its.length) return null;
      const dt = c.detalhes || {};
      return { pedido: c.pedido, cliente: (c.planilha && c.planilha.cliente) || c.cliente_salescode || "—", cidade: dt.entrega_cidade || c.cidade || "",
        itens: its, data: M.dataDe(c), data_salescode: c.data_salescode || c.data_planilha || null, data_manual: c.data_manual,
        status: c.status_salescode || "", fin: M.ehFinanceiro(c), coluna: M.coluna(c) };
    }).filter(Boolean);
    const carregados = carrRaw.map((c: any) => {
      const its = itensDe(c); if (!its.length) return null; const b = (c.balanca || [])[0] || {};
      return { pedido: c.pedido, cliente: (c.planilha && c.planilha.cliente) || c.cliente_salescode || "—", cidade: (c.detalhes || {}).entrega_cidade || c.cidade || "",
        itens: its, em: c.carregado_em, origem: c.carregado_origem, ticket: b.ticket ? String(b.ticket).replace(/^0+/, "") : null, placa: b.placa || null };
    }).filter(Boolean) as any[];

    // documentos dos carregados — SÓ pelo número do pedido deste representante
    const meusPed = new Set(carregados.map((c: any) => c.pedido).filter(Boolean));
    const lista = [...meusPed];
    const nfsPorPed: Record<string, any[]> = {}, lauPorPed: Record<string, any[]> = {};
    if (lista.length) {
      const nfs: any[] = [];
      for (let k = 0; k < lista.length; k += 150) nfs.push(...chk(await sb.from("portaria_nfs").select("id,pedido,numero,serie,emissao,arquivo_path").in("pedido", lista.slice(k, k + 150)), "nfs"));
      nfs.forEach((n: any) => { if (!n.arquivo_path || !meusPed.has(n.pedido)) return; (nfsPorPed[n.pedido] = nfsPorPed[n.pedido] || []).push({ id: n.id, numero: String(n.numero || "").replace(/^0+/, ""), serie: n.serie, emissao: n.emissao }); });
      const lks = chk(await sb.from("lab_laudo_carregamentos").select("id,laudo_id,pedido_numero,produto,data").not("pedido_numero", "is", null).gte("data", DOCS_DESDE).limit(5000), "ligações");
      const mine = lks.map((l: any) => ({ l, ps: pedidosDoLink(l.pedido_numero).filter((p) => meusPed.has(p)) })).filter((x: any) => x.ps.length);
      const ids = [...new Set(mine.map((x: any) => x.l.laudo_id).filter(Boolean))] as string[];
      const lau: Record<string, any> = {};
      for (let k = 0; k < ids.length; k += 150) chk(await sb.from("lab_laudos").select("id,numero,status,lote,arquivo_path").in("id", ids.slice(k, k + 150)), "laudos").forEach((x: any) => lau[x.id] = x);
      mine.forEach((x: any) => {
        const L = lau[x.l.laudo_id]; if (!L) return;
        const pronto = L.status === "finalizado" && !!L.arquivo_path;
        x.ps.forEach((p: string) => (lauPorPed[p] = lauPorPed[p] || []).push({ id: x.l.id, numero: L.numero, lote: L.lote, produto: x.l.produto, pronto }));
      });
    }
    carregados.forEach((c: any) => { c.nfs = nfsPorPed[c.pedido] || []; c.laudos = lauPorPed[c.pedido] || []; });

    return resp({ ok: true, representante: REP, nome: conta.nome, login: conta.login, hoje: h, docs_desde: DOCS_DESDE,
      atualizado: (chk(sincR, "sync")[0] || {}).atualizado_salescode || null,
      meus, carregados, livres, atrasos: chk(atR, "atrasos") });
  } catch (e) {
    console.error(e);
    return resp({ ok: false, motivo: "Erro no servidor. Tente de novo em instantes." }, 500);
  }
});
