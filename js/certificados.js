/* ═══════════════════════════════════════════════════════════════════════════
   CERTIFICADO DE ANÁLISE NA CARGA  (migração 051)
   ───────────────────────────────────────────────────────────────────────────
   O laudo é do LOTE/OP (laboratorio.html → aba Laudo). Ao finalizar, o
   laboratório grava a folha pronta no Storage (lab_laudos.arquivo_path).
   Aqui:
   • certVincularCarga() — chamado ao salvar a carga (carregamento.html): separa
     o que foi bipado POR LOTE e liga cada lote ao laudo dele em
     lab_laudo_carregamentos (origem 'carregamento'), com a quantidade daquele
     lote nesta carga. 13 bags do 261002B + 13 do 261003B = 2 certificados de
     13 bags. Vale para bag, saco (25 kg/20 kg) e granel.
     Laudo do lote: 1º pela OP do pallet (producao_pallets.lancamento_id),
     2º pelo número do lote (lab_laudos.lote), 3º granel sem lote → laudo mais
     recente do produto, marcado 'sugerido'.
   • certDaCarga() / certDaOrdem() — lista os certificados de uma carga/ordem.
   • certImprimir(laudoId, linkId) — abre a folha do Storage e acrescenta o
     quadro "Fornecimento" (cliente, quantidade deste lote, ordem, placa, data).
   Usado por carregamento.html e portaria.html. Precisa de _supabase.
   ═══════════════════════════════════════════════════════════════════════════ */
(function(){
  const N=s=>String(s||'').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/\s+/g,' ').trim();
  const E=s=>String(s==null?'':s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const L=s=>String(s||'').toUpperCase().replace(/\s+/g,'');          // lote normalizado
  // mesmos produtos do laudo do laboratório (LAUDO_PRODUTOS): caulim em saco, bag e granel
  const ehProdutoCert=nome=>/caulim|\bbag\b|big ?bag/.test(N(nome));
  const tipoProduto=nome=>{const n=N(nome);return /granel/.test(n)?'granel':/\bbag\b|big ?bag/.test(n)?'bag':'saco';};
  const UN={granel:'t',bag:'bag',saco:'sc'};
  const fmtQtd=(q,u)=>Number(q||0).toLocaleString('pt-BR',{maximumFractionDigits:u==='t'?3:0})+' '+(u==='bag'?(Number(q)===1?'bag':'bags'):u==='sc'?'sacos':u==='t'?'t':(u||''));
  window.certEhProduto=ehProdutoCert;
  window.certTipoProduto=tipoProduto;
  window.certFmtQtd=fmtQtd;

  async function pesoUnidade(nomes){
    const m={}; if(!nomes.length)return m;
    const {data}=await _supabase.from('produtos').select('nome,peso_unidade_kg').in('nome',nomes);
    (data||[]).forEach(p=>m[N(p.nome)]=Number(p.peso_unidade_kg)||null);
    return m;
  }
  const COLS='id,numero,status,produto,lote,op_numero,producao_id,unidade_qtd,emitido_em,assinado_em,dados_snapshot';
  // laudo é do LOTE (lote + linha): cobre todas as OPs de dados_snapshot.ops_lote, não só a OP "dona"
  const cobreOp=(l,opId)=>l.producao_id===opId||((l.dados_snapshot&&l.dados_snapshot.ops_lote)||[]).some(o=>o&&o.id===opId);

  /* itens = snapshot da carga (carregamentos.itens). Devolve {links, semLaudo, rascunho} */
  window.certVincularCarga=async function({cargaId,romaneioId,ordemNumero,placa,data,itens}){
    const its=(itens||[]).filter(i=>i&&!i.doador&&ehProdutoCert(i.produto));
    const out={links:[],semLaudo:[],rascunho:[]};
    if(!cargaId)return out;
    // limpa a ligação automática anterior desta carga/ordem (re-salvar não duplica)
    await _supabase.from('lab_laudo_carregamentos').delete().eq('origem','carregamento').eq('carregamento_id',cargaId);
    if(romaneioId)await _supabase.from('lab_laudo_carregamentos').delete().eq('origem','carregamento').eq('romaneio_id',romaneioId);
    if(!its.length)return out;

    // 1) pallet/bag → OP e lote do cadastro do pallet
    const palIds=[...new Set(its.map(i=>i.pallet_id).filter(Boolean))], pal={};
    for(let k=0;k<palIds.length;k+=150){
      const {data:ps}=await _supabase.from('producao_pallets').select('id,lancamento_id').in('id',palIds.slice(k,k+150));
      (ps||[]).forEach(p=>pal[p.id]=p);
    }
    const opIds=[...new Set(Object.values(pal).map(p=>p.lancamento_id).filter(Boolean))];
    const lotes=[...new Set(its.map(i=>i.lote).filter(x=>x&&!/^_+$|^—$/.test(String(x).trim())))];
    // 2) laudos: das OPs e dos lotes bipados
    const laudos=new Map();
    if(opIds.length){const {data:l}=await _supabase.from('lab_laudos').select(COLS).in('producao_id',opIds);(l||[]).forEach(x=>laudos.set(x.id,x));}
    if(lotes.length){const vs=[...new Set(lotes.flatMap(x=>[String(x).trim(),L(x),String(x).trim().toLowerCase()]))];
      const {data:l}=await _supabase.from('lab_laudos').select(COLS).in('lote',vs);(l||[]).forEach(x=>laudos.set(x.id,x));}
    const {data:ops}=opIds.length?await _supabase.from('producao').select('id,op_numero,produtos_op').in('id',opIds):{data:[]};
    // laudo do lote cuja OP "dona" é outra OP do mesmo lote: busca também pelos lotes das OPs dos pallets
    const lotesOp=[...new Set((ops||[]).flatMap(o=>(Array.isArray(o.produtos_op)?o.produtos_op:[]).map(it=>it&&it.lote).filter(Boolean)))];
    if(lotesOp.length){const {data:l}=await _supabase.from('lab_laudos').select(COLS).in('lote',lotesOp);(l||[]).forEach(x=>laudos.set(x.id,x));}
    const LS=[...laudos.values()];
    const opNum={}; (ops||[]).forEach(o=>opNum[o.id]=o.op_numero);
    const ultimoDoProduto={};
    for(const pn of [...new Set(its.filter(i=>tipoProduto(i.produto)==='granel').map(i=>i.produto))]){
      const {data:l}=await _supabase.from('lab_laudos').select(COLS).eq('status','finalizado').ilike('produto',pn).order('assinado_em',{ascending:false}).limit(1);
      if(l&&l[0])ultimoDoProduto[N(pn)]=l[0];
    }
    const pesos=await pesoUnidade([...new Set(its.map(i=>i.produto))]);
    // 3) cada item → laudo do SEU lote; soma por laudo (= por lote)
    const grupos={}, pend=(arr,x)=>arr.push(x);
    its.forEach(i=>{
      const tipo=tipoProduto(i.produto), opId=i.pallet_id&&pal[i.pallet_id]?pal[i.pallet_id].lancamento_id:null, lt=L(i.lote);
      const doOp=opId?LS.filter(l=>cobreOp(l,opId)):[];
      let doLote=lt?LS.filter(l=>L(l.lote)===lt):[];
      // mesmo lote em duas linhas (Big Bag Cinza na L2 + Granel Cinza na Longa Vida): o do mesmo tipo de produto
      if(doLote.length>1){ const mesmo=doLote.filter(l=>tipoProduto(l.produto)===tipo); if(mesmo.length) doLote=mesmo; }
      // OP com mais de um laudo (ex.: Bag B01 + Bag B02 na mesma OP): fica o do MESMO produto e, se ainda sobrar, o do lote bipado
      let cand=doOp;
      if(cand.length>1){ const mp=cand.filter(l=>N(l.produto)===N(i.produto)); if(mp.length) cand=mp; }
      if(cand.length>1&&lt){ const ml=cand.filter(l=>L(l.lote)===lt); if(ml.length) cand=ml; }
      if(!cand.length)cand=doLote;
      let laudo=cand.find(l=>l.status==='finalizado')||null, sugerido=false;
      if(!laudo&&cand.length){pend(out.rascunho,{op:opNum[opId]||cand[0].op_numero||'?',lote:i.lote||cand[0].lote||'',produto:i.produto});return;}
      if(!laudo&&tipo==='granel'&&!lt){laudo=ultimoDoProduto[N(i.produto)]||null;sugerido=!!laudo;}
      if(!laudo){pend(out.semLaudo,{op:opNum[opId]||(tipo==='granel'?'granel':'?'),lote:i.lote||'',produto:i.produto});return;}
      const un=UN[tipo], pu=pesos[N(i.produto)]||(tipo==='bag'?1000:null);
      let qtd, kg;
      if(tipo==='granel'){qtd=Number(i.ton)||0;kg=qtd*1000;}
      else if(tipo==='bag'){qtd=Number(i.sacos)||1;kg=qtd*(pu||1000);}      // 1 registro bipado = 1 bag (ou o nº gravado)
      else{qtd=Number(i.sacos)||0;kg=qtd*(pu||0);}
      // o laudo é do LOTE e pode cobrir saco + bag + granel: soma por laudo E unidade (não mistura sc com t)
      const gk=laudo.id+'|'+un;
      const g=grupos[gk]=grupos[gk]||{laudo,sugerido,qtd:0,kg:0,itens:0,unidade:un,clientes:new Set(),pedidos:new Set(),produto:i.produto};
      g.qtd+=qtd; g.kg+=kg; g.itens++; if(i.cliente)g.clientes.add(i.cliente); if(i.pedido)g.pedidos.add(i.pedido);
    });
    const dd=a=>[...new Map(a.map(x=>[x.op+'|'+x.lote+'|'+x.produto,x])).values()];
    out.semLaudo=dd(out.semLaudo); out.rascunho=dd(out.rascunho);
    const quem=(typeof getUser==='function'&&getUser()&&getUser().nome)||null;
    const rows=Object.values(grupos).map(g=>({laudo_id:g.laudo.id,carregamento_id:cargaId,romaneio_id:romaneioId||null,data:data||new Date().toISOString().slice(0,10),
      cliente:[...g.clientes].join(', ').slice(0,500)||null,pedido_numero:[...g.pedidos].join(', ').slice(0,300)||null,
      quantidade:Math.round(g.qtd*1000)/1000,unidade:g.unidade,peso_kg:Math.round(g.kg)||null,origem:'carregamento',ordem_numero:ordemNumero||null,placa:placa||null,
      produto:g.produto,op_numero:g.laudo.op_numero||null,sugerido:g.sugerido,criado_por:quem}));
    if(rows.length){
      const r=await _supabase.from('lab_laudo_carregamentos').insert(rows);
      if(r.error){console.error('[certificados] vincular:',r.error.message);out.erro=r.error.message;return out;}
    }
    out.links=Object.values(grupos).map(g=>({...g.laudo,quantidade:g.qtd,unidade:g.unidade,peso_kg:g.kg,sugerido:g.sugerido}));
    return out;
  };

  async function listar(col,val){
    const {data:lc,error}=await _supabase.from('lab_laudo_carregamentos').select('*').eq(col,val);
    if(error||!lc||!lc.length)return [];
    const ids=[...new Set(lc.map(x=>x.laudo_id))];
    const {data:ls}=await _supabase.from('lab_laudos').select('id,numero,status,produto,lote,op_numero,arquivo_path,validade,veredito').in('id',ids);
    return lc.map(x=>({...x,laudo:(ls||[]).find(l=>l.id===x.laudo_id)||null})).filter(x=>x.laudo)
      .sort((a,b)=>String(a.laudo.lote||'').localeCompare(String(b.laudo.lote||'')));
  }
  window.certDaCarga=id=>listar('carregamento_id',id);
  window.certDaOrdem=id=>listar('romaneio_id',id);

  // quadro "Fornecimento" desta remessa, no estilo das tabelas do certificado
  function blocoRemessa(x){
    const d=x.data?new Date(x.data+'T12:00:00').toLocaleDateString('pt-BR'):'—';
    const q=fmtQtd(x.quantidade,x.unidade)+(x.unidade!=='t'&&x.peso_kg?` (${(Number(x.peso_kg)/1000).toLocaleString('pt-BR',{maximumFractionDigits:3})} t)`:'');
    return `<div class="sec">Fornecimento (esta remessa)</div>
  <table class="cab"><colgroup><col style="width:23.85%"><col style="width:26.19%"><col style="width:23.83%"><col style="width:26.13%"></colgroup>
    <tr class="z"><td class="rot">Cliente</td><td colspan="3">${E(x.cliente||'—')}</td></tr>
    <tr><td class="rot">Quantidade deste lote</td><td class="cz"><b>${E(q)}</b></td><td class="rot">Data de expedição</td><td>${E(d)}</td></tr>
    <tr class="z"><td class="rot">Ordem de carregamento</td><td>${E(x.ordem_numero||'—')}${x.pedido_numero?' · pedido '+E(x.pedido_numero):''}</td><td class="rot">Placa</td><td>${E(x.placa||'—')}</td></tr>
  </table>
  `;
  }

  /* ═══ RELAÇÃO DAS UNIDADES (nov/2026) ═══════════════════════════════════════
     Cada certificado ligado à carga lista os bags/pallets dele: nº (o do rótulo,
     -P018 → 18), código, QR do rastreio e os dados do rótulo (fabricação, turno,
     linha, validade, OP, peso, qualidade). Tela da portaria + folha anexa impressa
     junto com o certificado (8 por folha). QR precisa de js/qrcode.min.js. */
  const numDoCodigo=c=>{const m=String(c||'').match(/-P(\d+)\s*$/i);return m?parseInt(m[1],10):null;};
  const urlRastreio=c=>(location.origin+location.pathname.replace(/[^/]+$/,''))+'rastreio.html?pallet='+encodeURIComponent(c);
  const dBR=d=>d?String(d).slice(0,10).split('-').reverse().join('/'):'—';
  function qrSvg(t,cls){
    if(!window.QRCode||!QRCode.create)return '';
    const q=QRCode.create(t,{errorCorrectionLevel:'M'}),n=q.modules.size,d=q.modules.data;let p='';
    for(let y=0;y<n;y++)for(let x=0;x<n;x++)if(d[y*n+x])p+='M'+(x+2)+' '+(y+2)+'h1v1h-1z';
    return `<svg class="${cls||''}" viewBox="0 0 ${n+4} ${n+4}" shape-rendering="crispEdges"><rect width="100%" height="100%" fill="#fff"/><path d="${p}" fill="#000"/></svg>`;
  }
  // faixas de números: [1,2,3,5,7,8] → "1 a 3, 5, 7 e 8"
  window.certFaixas=function(nums){
    const v=[...new Set(nums.filter(x=>x!=null))].sort((a,b)=>a-b), out=[]; let i=0;
    while(i<v.length){let j=i;while(j+1<v.length&&v[j+1]===v[j]+1)j++;out.push(j>i+1?v[i]+' a '+v[j]:j===i+1?v[i]+', '+v[j]:String(v[i]));i=j+1;}
    return out.join(', ');
  };
  /* unidades (bags/pallets) da carga que saíram com ESTE certificado (link = linha de lab_laudo_carregamentos) */
  window.certUnidades=async function(link){
    if(!link||!link.carregamento_id||!link.laudo_id)return [];
    const [{data:c},{data:l}]=await Promise.all([
      _supabase.from('carregamentos').select('itens').eq('id',link.carregamento_id).maybeSingle(),
      _supabase.from('lab_laudos').select(COLS).eq('id',link.laudo_id).maybeSingle()]);
    if(!l)return [];
    const prodNome=link.produto||l.produto;
    const its=((c&&c.itens)||[]).filter(i=>i&&!i.doador&&i.pallet_id&&N(i.produto)===N(prodNome));
    if(!its.length)return [];
    const ids=[...new Set(its.map(i=>i.pallet_id))], pal={};
    for(let k=0;k<ids.length;k+=150){
      const {data:ps}=await _supabase.from('producao_pallets').select('id,lancamento_id,numero,codigo,data,turno,linha,status').in('id',ids.slice(k,k+150));
      (ps||[]).forEach(p=>pal[p.id]=p);
    }
    const opIds=[...new Set(Object.values(pal).map(p=>p.lancamento_id).filter(Boolean))], op={};
    if(opIds.length){const {data:os}=await _supabase.from('producao').select('id,op_numero,produtos_op').in('id',opIds);(os||[]).forEach(o=>op[o.id]=o);}
    const pesos=await pesoUnidade([prodNome]), pu=pesos[N(prodNome)]||null, tipo=tipoProduto(prodNome), lt=L(l.lote);
    return its.filter(i=>{const p=pal[i.pallet_id];return (lt&&L(i.lote)===lt)||(p&&cobreOp(l,p.lancamento_id));}).map(i=>{
      const p=pal[i.pallet_id]||{}, o=op[p.lancamento_id]||{}, cod=i.codigo&&i.codigo!=='—'?i.codigo:(p.codigo||'');
      const po=(Array.isArray(o.produtos_op)?o.produtos_op:[]).find(x=>x&&N(x.produto)===N(prodNome))||{};
      const sacos=tipo==='bag'?1:(Number(i.sacos)||0);
      return {codigo:cod,n:numDoCodigo(cod)??p.numero??null,tipo,produto:prodNome,lote:i.lote||po.lote||l.lote,sacos,
        kg:tipo==='bag'?(pu||1000):(pu?sacos*pu:null),data:p.data||i.data_producao,turno:p.turno,linha:p.linha||i.linha,
        status:p.status,op:o.op_numero,validade:po.validade||null};
    }).sort((a,b)=>(a.n??1e9)-(b.n??1e9)||String(a.codigo).localeCompare(String(b.codigo)));
  };
  const turnoCurto=t=>String(t||'').replace(/\s*-\s*/,' ').replace(/\s*5x2.*$/i,'').trim()||'—';
  const qualTxt=s=>s==='aprovado'?'<span class="rlu-ok">✓ APROVADO</span>':`<span class="rlu-pend">${E(String(s||'—').toUpperCase())}</span>`;
  const UNI=t=>t==='bag'?'BAG':'PALLET';
  /* cartões da TELA (portaria / carregamento) */
  window.certUnidadesTela=function(us){
    if(!us||!us.length)return '<div style="font-size:12px;color:#64748b;">Nenhuma unidade com QR nesta carga (granel ou carga sem bipagem).</div>';
    return `<style>.rlu-g{display:grid;grid-template-columns:repeat(auto-fill,minmax(118px,1fr));gap:8px;}
      .rlu-c{border:1.5px solid #042D4D;border-radius:8px;padding:6px 4px 5px;text-align:center;background:#fff;}
      .rlu-c .n{font-size:13px;font-weight:800;color:#042D4D;line-height:1.1;} .rlu-c .n small{display:block;font-size:9px;color:#64748b;letter-spacing:.5px;}
      .rlu-c svg{width:74px;height:74px;display:block;margin:3px auto;} .rlu-c .c{font-family:monospace;font-size:9px;color:#334155;word-break:break-all;}
      .rlu-c .d{font-size:9.5px;color:#64748b;margin-top:2px;}</style>
      <div class="rlu-g">${us.map(u=>`<div class="rlu-c"><div class="n"><small>${UNI(u.tipo)}</small>${u.n??'—'}</div>${qrSvg(urlRastreio(u.codigo))}
        <div class="c">${E(u.codigo)}</div><div class="d">${dBR(u.data)} · ${E(turnoCurto(u.turno))}${u.tipo!=='bag'?' · '+u.sacos+' sc':''}</div></div>`).join('')}</div>`;
  };
  /* FOLHA ANEXA impressa: 1 unidade por linha, 8 por folha A4 */
  window.certRelacaoHtml=function(link,laudo,us,emp){
    if(!us||!us.length)return '';
    const POR=8, pags=[]; for(let i=0;i<us.length;i+=POR)pags.push(us.slice(i,i+POR));
    const q=fmtQtd(link.quantidade,link.unidade)+(link.unidade!=='t'&&link.peso_kg?` (${(Number(link.peso_kg)/1000).toLocaleString('pt-BR',{maximumFractionDigits:3})} t)`:'');
    const nomeEmp=emp&&(emp.nome_fantasia||emp.razao_social)||'';
    const css=`<style>
      .rlu-pg{width:210mm;height:297mm;padding:11mm 12mm 9mm;box-sizing:border-box;page-break-before:always;break-before:page;font-family:Arial,Helvetica,sans-serif;color:#032036;display:flex;flex-direction:column;overflow:hidden;background:#fff;}
      .rlu-top{display:flex;justify-content:space-between;align-items:flex-end;border-bottom:3px solid #042D4D;padding-bottom:4px;}
      .rlu-top .m{font-size:17px;font-weight:800;color:#042D4D;} .rlu-top h1{font-size:14px;margin:0;color:#042D4D;text-align:right;} .rlu-top .s{font-size:8.5px;color:#64748b;text-align:right;}
      .rlu-lime{height:3.5px;background:#C9FF64;margin-bottom:6px;}
      .rlu-cab{display:grid;grid-template-columns:repeat(4,1fr);gap:4px;font-size:9.5px;margin-bottom:5px;} .rlu-cab div{border:1px solid #cbd5e1;border-radius:5px;padding:4px 6px;} .rlu-cab small,.rlu-d small{display:block;font-size:7px;color:#64748b;font-weight:700;text-transform:uppercase;}
      .rlu-sec{font-size:9.5px;font-weight:800;color:#042D4D;text-transform:uppercase;margin:4px 0 5px;border-left:4px solid #C9FF64;padding-left:6px;}
      .rlu-l{display:grid;grid-template-columns:25mm 31mm 1fr;gap:3mm;align-items:center;border:1.4px solid #042D4D;border-radius:7px;padding:1.6mm 2.5mm;margin-bottom:1.8mm;height:27mm;box-sizing:border-box;}
      .rlu-l svg{width:24mm;height:24mm;display:block;}
      .rlu-id .t{font-size:8px;color:#64748b;font-weight:800;letter-spacing:1px;} .rlu-id .n{font-size:26px;font-weight:900;color:#042D4D;line-height:1;} .rlu-id .c{font-family:monospace;font-size:8.5px;color:#334155;margin-top:3px;word-break:break-all;}
      .rlu-d{display:grid;grid-template-columns:1.25fr 1fr 1fr .9fr;gap:2px 8px;font-size:9.5px;} .rlu-d .w2{grid-column:span 2;}
      .rlu-ok{display:inline-block;background:#dcfce7;color:#166534;font-weight:800;font-size:8.5px;padding:0 6px;border-radius:9px;}
      .rlu-pend{display:inline-block;background:#fef3c7;color:#92400e;font-weight:800;font-size:8.5px;padding:0 6px;border-radius:9px;}
      .rlu-rod{margin-top:auto;font-size:8.5px;color:#64748b;display:flex;justify-content:space-between;}
      @media print{.rlu-pg{margin:0;}} @media screen{.rlu-pg{margin:10px auto;box-shadow:0 1px 4px #0003;}}
    </style>`;
    return css+pags.map((pg,pi)=>`<div class="rlu-pg">
      <div class="rlu-top"><div class="m">${E(nomeEmp||'')}</div><div><h1>RELAÇÃO DAS UNIDADES CARREGADAS</h1><div class="s">anexo do certificado de análise ${E(laudo.numero||'')}</div></div></div><div class="rlu-lime"></div>
      ${pi===0?`<div class="rlu-cab"><div><small>Certificado</small><b>${E(laudo.numero||'')}</b></div><div><small>Produto</small>${E(link.produto||laudo.produto||'')}</div><div><small>Lote</small><b>${E(laudo.lote||'')}</b></div><div><small>Quantidade deste lote</small><b>${E(q)}</b></div>
        <div><small>Cliente</small>${E(link.cliente||'—')}</div><div><small>Ordem · pedido</small>${E(link.ordem_numero||'—')}${link.pedido_numero?' · '+E(link.pedido_numero):''}</div><div><small>Placa</small>${E(link.placa||'—')}</div><div><small>Expedição</small>${dBR(link.data)}</div></div>
        <div class="rlu-sec">${us[0].tipo==='bag'?'Bags':'Pallets'} carregados — um por linha, com os dados do rótulo</div>`:''}
      ${pg.map(u=>`<div class="rlu-l">${qrSvg(urlRastreio(u.codigo))}
        <div class="rlu-id"><div class="t">${UNI(u.tipo)}</div><div class="n">${u.n??'—'}</div><div class="c">${E(u.codigo)}</div></div>
        <div class="rlu-d">
          <div class="w2"><small>Produto</small><b>${E(u.produto)}</b></div><div><small>Lote</small><b>${E(u.lote||'—')}</b></div><div><small>${u.tipo==='bag'?'Peso líquido':'Sacos · peso'}</small><b>${u.tipo==='bag'?(u.kg||1000).toLocaleString('pt-BR')+' kg':u.sacos+' sc'+(u.kg?' · '+u.kg.toLocaleString('pt-BR')+' kg':'')}</b></div>
          <div><small>Fabricação</small>${dBR(u.data)}</div><div><small>Turno · linha</small>${E(turnoCurto(u.turno))} · ${E(u.linha||'—')}</div><div><small>Validade</small>${dBR(u.validade)}</div><div><small>Qualidade</small>${qualTxt(u.status)}</div>
          <div class="w2"><small>Ordem de produção</small>${E(u.op||'—')}</div><div class="w2"><small>Certificado</small>${E(laudo.numero||'')}</div>
        </div></div>`).join('')}
      <div class="rlu-rod"><span>Cada QR abre o rastreio da unidade. Conferido por QR no carregamento — ${us.length} ${us[0].tipo==='bag'?(us.length===1?'bag':'bags'):(us.length===1?'pallet':'pallets')}.</span><span>Página ${pi+1} de ${pags.length}</span></div>
    </div>`).join('');
  };

  // abre a lista de bags/pallets embaixo do certificado (carrega só na 1ª vez)
  window.certAbrirUnidades=async function(el){
    if(!el.open||el.dataset.ok)return; el.dataset.ok='1';
    const box=el.querySelector('.rlu-box');
    try{
      const {data:lk}=await _supabase.from('lab_laudo_carregamentos').select('*').eq('id',el.dataset.link).single();
      const us=await certUnidades(lk);
      box.innerHTML=certUnidadesTela(us);
      const sm=el.querySelector('summary'); if(sm&&us.length)sm.textContent=`📦 ${us.length} ${us[0].tipo==='bag'?(us.length===1?'bag':'bags'):(us.length===1?'pallet':'pallets')} deste certificado — ${UNI(us[0].tipo).toLowerCase()} ${certFaixas(us.map(u=>u.n))}`;
    }catch(e){ el.dataset.ok=''; box.textContent='Não consegui carregar a lista: '+(e.message||e); }
  };
  window.certImprimir=async function(laudoId,linkId){
    const {data:l}=await _supabase.from('lab_laudos').select('id,numero,arquivo_path,status,lote,produto').eq('id',laudoId).single();
    if(l&&l.arquivo_path){
      const w=window.open('','_blank'); if(!w){toast('Permita pop-ups para imprimir o certificado.','warning');return;}
      w.document.write('<p style="font-family:sans-serif;padding:20px;">Abrindo certificado '+E(l.numero||'')+'…</p>');
      const [{data:blob,error},lk]=await Promise.all([_supabase.storage.from('documentos').download(l.arquivo_path),
        linkId?_supabase.from('lab_laudo_carregamentos').select('*').eq('id',linkId).single():Promise.resolve({data:null})]);
      if(error||!blob){w.close();toast('Não consegui abrir o arquivo do certificado: '+(error&&error.message||''),'danger');return;}
      let html=await blob.text();
      if(lk&&lk.data){
        const marca='<div class="sec">Identificação do produto</div>';
        html=html.includes(marca)?html.replace(marca,blocoRemessa(lk.data)+marca):html.replace('</h1>','</h1>'+blocoRemessa(lk.data));
      }
      // folha anexa: a relação dos bags/pallets deste certificado, com QR e dados do rótulo
      if(lk&&lk.data){
        try{
          const [us,emp]=await Promise.all([certUnidades(lk.data),typeof carregarEmpresaPDF==='function'?carregarEmpresaPDF().catch(()=>({})):Promise.resolve({})]);
          const rel=certRelacaoHtml(lk.data,l,us,emp);
          if(rel)html=html.includes('</body>')?html.replace('</body>',rel+'</body>'):html+rel;
        }catch(e){console.warn('[certificados] relação das unidades:',e);}
      }
      w.document.open(); w.document.write(html); w.document.close();
      setTimeout(()=>{try{w.certFit&&w.certFit();w.focus();w.print();}catch(e){}},900);
      return;
    }
    // laudo sem arquivo (finalizado antes da 051): o laboratório monta e grava na hora
    window.open('laboratorio.html?laudo='+encodeURIComponent(laudoId)+'&imprimir=1','_blank');
  };

  /* bloco pronto para telas: um certificado por lote, com a quantidade dele nesta carga */
  window.certHtml=function(lista,opts){
    opts=opts||{};
    if(!lista||!lista.length)return opts.vazio||'';
    return `<div style="display:flex;flex-direction:column;gap:6px;">${lista.map(x=>{const l=x.laudo||x;
      const q=x.quantidade!=null?fmtQtd(x.quantidade,x.unidade):'';
      return `<div style="display:flex;justify-content:space-between;align-items:center;gap:10px;background:#f0fdf4;border:1.5px solid #bbf7d0;border-radius:10px;padding:8px 12px;font-size:13px;flex-wrap:wrap;">
        <span>📜 <b style="color:#042D4D;">${E(l.numero||'sem número')}</b> · lote <b>${E(l.lote||'—')}</b>${q?' · <b>'+E(q)+'</b>':''} <span style="color:#64748b;">· ${E(l.produto||x.produto||'')}${l.op_numero?' · OP '+E(l.op_numero):''}</span>
          ${x.sugerido?' <span title="Granel sem lote: é o certificado mais recente deste produto. Confira." style="font-size:11px;color:#92400e;font-weight:700;">(sugerido — conferir)</span>':''}</span>
        <button class="btn btn-secondary btn-sm" onclick="certImprimir('${l.id||x.laudo_id}','${x.laudo?x.id:''}')">🖨️ Imprimir${opts.unidades&&x.unidade!=='t'?' certificado + relação':''}</button></div>
        ${opts.unidades&&x.laudo&&x.unidade!=='t'&&x.carregamento_id?`<details class="rlu-det" data-link="${E(x.id)}" ontoggle="certAbrirUnidades(this)" style="border:1.5px solid #bbf7d0;border-top:0;border-radius:0 0 10px 10px;margin:-6px 0 0;padding:8px 12px;background:#fbfffc;">
          <summary style="cursor:pointer;font-size:12.5px;font-weight:800;color:#166534;">📦 Ver ${x.unidade==='bag'?'os '+E(fmtQtd(x.quantidade,'bag')):'os pallets'} deste certificado (QR e código)</summary><div class="rlu-box" style="margin-top:8px;font-size:12px;color:#64748b;">Carregando…</div></details>`:''}`;}).join('')}</div>`;
  };
})();
