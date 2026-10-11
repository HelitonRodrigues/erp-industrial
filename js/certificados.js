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
  const COLS='id,numero,status,produto,lote,op_numero,producao_id,unidade_qtd,emitido_em,assinado_em';

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
    const LS=[...laudos.values()];
    const {data:ops}=opIds.length?await _supabase.from('producao').select('id,op_numero').in('id',opIds):{data:[]};
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
      const doOp=opId?LS.filter(l=>l.producao_id===opId):[];
      const doLote=lt?LS.filter(l=>L(l.lote)===lt):[];
      // se a OP tem mais de um laudo, fica o do lote bipado
      let cand=doOp.length>1&&lt?doOp.filter(l=>L(l.lote)===lt):doOp;
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
      const g=grupos[laudo.id]=grupos[laudo.id]||{laudo,sugerido,qtd:0,kg:0,itens:0,unidade:un,clientes:new Set(),pedidos:new Set(),produto:i.produto};
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
  window.certImprimir=async function(laudoId,linkId){
    const {data:l}=await _supabase.from('lab_laudos').select('id,numero,arquivo_path,status').eq('id',laudoId).single();
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
        <button class="btn btn-secondary btn-sm" onclick="certImprimir('${l.id||x.laudo_id}','${x.laudo?x.id:''}')">🖨️ Imprimir</button></div>`;}).join('')}</div>`;
  };
})();
