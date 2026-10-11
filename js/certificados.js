/* ═══════════════════════════════════════════════════════════════════════════
   CERTIFICADO DE ANÁLISE NA CARGA  (migração 051)
   ───────────────────────────────────────────────────────────────────────────
   O laudo é da OP (laboratorio.html → aba Laudo). Ao finalizar, o laboratório
   grava a folha pronta no Storage (lab_laudos.arquivo_path).
   Aqui:
   • certVincularCarga() — chamado ao salvar a carga (carregamento.html): descobre
     a OP de cada pallet de caulim/bag carregado, acha o laudo dela e grava a
     ligação em lab_laudo_carregamentos (origem 'carregamento'). Granel não tem
     pallet → usa o laudo finalizado mais recente do produto e marca 'sugerido'.
   • certDaCarga() / certDaOrdem() — lista os certificados de uma carga/ordem.
   • certImprimir() — abre a folha do Storage; sem arquivo, abre o laboratório.
   Usado por carregamento.html e portaria.html. Precisa de _supabase e esc().
   ═══════════════════════════════════════════════════════════════════════════ */
(function(){
  const N=s=>String(s||'').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/\s+/g,' ').trim();
  const E=s=>String(s==null?'':s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  // mesmos produtos do laudo do laboratório (LAUDO_PRODUTOS): caulim em saco, bag e granel
  const ehProdutoCert=nome=>/caulim|\bbag\b|big ?bag/.test(N(nome));
  const unidadeCert=nome=>/granel|bag/.test(N(nome))?'t':'sc';
  window.certEhProduto=ehProdutoCert;

  async function pesoUnidade(nomes){
    const m={}; if(!nomes.length)return m;
    const {data}=await _supabase.from('produtos').select('nome,peso_unidade_kg').in('nome',nomes);
    (data||[]).forEach(p=>m[N(p.nome)]=Number(p.peso_unidade_kg)||null);
    return m;
  }

  /* itens = snapshot da carga (carregamentos.itens). Devolve {links, semLaudo, rascunho} */
  window.certVincularCarga=async function({cargaId,romaneioId,ordemNumero,placa,data,itens}){
    const its=(itens||[]).filter(i=>i&&!i.doador&&ehProdutoCert(i.produto));
    const out={links:[],semLaudo:[],rascunho:[]};
    if(!cargaId)return out;
    // limpa a ligação automática anterior desta carga/ordem (re-salvar não duplica)
    await _supabase.from('lab_laudo_carregamentos').delete().eq('origem','carregamento').eq('carregamento_id',cargaId);
    if(romaneioId)await _supabase.from('lab_laudo_carregamentos').delete().eq('origem','carregamento').eq('romaneio_id',romaneioId);
    if(!its.length)return out;

    // 1) pallet → OP
    const palIds=[...new Set(its.map(i=>i.pallet_id).filter(Boolean))], opDoPallet={};
    for(let k=0;k<palIds.length;k+=150){
      const {data:ps}=await _supabase.from('producao_pallets').select('id,lancamento_id').in('id',palIds.slice(k,k+150));
      (ps||[]).forEach(p=>opDoPallet[p.id]=p.lancamento_id);
    }
    const opIds=[...new Set(Object.values(opDoPallet).filter(Boolean))];
    // 2) laudos das OPs + laudo mais recente de cada produto granel
    const laudos=[];
    if(opIds.length){const {data:l}=await _supabase.from('lab_laudos').select('id,numero,status,produto,lote,op_numero,producao_id,unidade_qtd,emitido_em').in('producao_id',opIds);laudos.push(...(l||[]));}
    const {data:ops}=opIds.length?await _supabase.from('producao').select('id,op_numero,data').in('id',opIds):{data:[]};
    const opInfo={}; (ops||[]).forEach(o=>opInfo[o.id]=o);
    const granelProds=[...new Set(its.filter(i=>!i.pallet_id).map(i=>i.produto).filter(Boolean))], ultimoDoProduto={};
    for(const pn of granelProds){
      const {data:l}=await _supabase.from('lab_laudos').select('id,numero,status,produto,lote,op_numero,producao_id,unidade_qtd,emitido_em')
        .eq('status','finalizado').ilike('produto',pn).order('assinado_em',{ascending:false}).limit(1);
      if(l&&l[0])ultimoDoProduto[N(pn)]=l[0];
    }
    const pesos=await pesoUnidade([...new Set(its.map(i=>i.produto))]);
    // 3) soma por laudo
    const grupos={};
    its.forEach(i=>{
      let laudo=null, sugerido=false, opId=i.pallet_id?opDoPallet[i.pallet_id]:null;
      if(opId){
        const ls=laudos.filter(l=>l.producao_id===opId), fin=ls.find(l=>l.status==='finalizado');
        laudo=fin||null;
        if(!fin){const op=opInfo[opId]||{};(ls.length?out.rascunho:out.semLaudo).push({op:op.op_numero||'?',produto:i.produto,lote:i.lote||''});return;}
      }else if(!i.pallet_id){
        laudo=ultimoDoProduto[N(i.produto)]||null; sugerido=true;
        if(!laudo){out.semLaudo.push({op:'granel',produto:i.produto,lote:i.lote||''});return;}
      }else{out.semLaudo.push({op:'?',produto:i.produto,lote:i.lote||''});return;}
      const un=laudo.unidade_qtd||unidadeCert(i.produto), pu=pesos[N(i.produto)]||(un==='t'?1000:null);
      const kg=i.unidade==='t'?(Number(i.ton)||0)*1000:(Number(i.sacos)||0)*(pu||0);
      const qtd=un==='t'?(i.unidade==='t'?Number(i.ton)||0:kg/1000):(Number(i.sacos)||0);
      const g=grupos[laudo.id]=grupos[laudo.id]||{laudo,sugerido,qtd:0,kg:0,unidade:un,clientes:new Set(),pedidos:new Set(),produto:i.produto};
      g.qtd+=qtd; g.kg+=kg; if(i.cliente)g.clientes.add(i.cliente); if(i.pedido)g.pedidos.add(i.pedido);
    });
    // dedup das pendências
    const dd=a=>[...new Map(a.map(x=>[x.op+'|'+x.produto,x])).values()];
    out.semLaudo=dd(out.semLaudo); out.rascunho=dd(out.rascunho);
    const rows=Object.values(grupos).map(g=>({laudo_id:g.laudo.id,carregamento_id:cargaId,romaneio_id:romaneioId||null,data:data||new Date().toISOString().slice(0,10),
      cliente:[...g.clientes].join(', ').slice(0,500)||null,pedido_numero:[...g.pedidos].join(', ').slice(0,300)||null,
      quantidade:Math.round(g.qtd*1000)/1000,unidade:g.unidade,peso_kg:Math.round(g.kg)||null,origem:'carregamento',ordem_numero:ordemNumero||null,placa:placa||null,
      produto:g.produto,op_numero:g.laudo.op_numero||null,sugerido:g.sugerido,criado_por:(typeof getUser==='function'&&getUser()?.nome)||null}));
    if(rows.length){
      const r=await _supabase.from('lab_laudo_carregamentos').insert(rows);
      if(r.error){console.error('[certificados] vincular:',r.error.message);out.erro=r.error.message;return out;}
    }
    out.links=Object.values(grupos).map(g=>({...g.laudo,quantidade:g.qtd,unidade:g.unidade,sugerido:g.sugerido}));
    return out;
  };

  async function listar(col,val){
    const {data:lc,error}=await _supabase.from('lab_laudo_carregamentos').select('*').eq(col,val);
    if(error||!lc||!lc.length)return [];
    const ids=[...new Set(lc.map(x=>x.laudo_id))];
    const {data:ls}=await _supabase.from('lab_laudos').select('id,numero,status,produto,lote,op_numero,arquivo_path,validade,veredito').in('id',ids);
    return lc.map(x=>({...x,laudo:(ls||[]).find(l=>l.id===x.laudo_id)||null})).filter(x=>x.laudo);
  }
  window.certDaCarga=id=>listar('carregamento_id',id);
  window.certDaOrdem=id=>listar('romaneio_id',id);

  window.certImprimir=async function(laudoId){
    const {data:l}=await _supabase.from('lab_laudos').select('id,numero,arquivo_path,status').eq('id',laudoId).single();
    if(l&&l.arquivo_path){
      const w=window.open('','_blank'); if(!w){toast('Permita pop-ups para imprimir o certificado.','warning');return;}
      w.document.write('<p style="font-family:sans-serif;padding:20px;">Abrindo certificado '+E(l.numero||'')+'…</p>');
      const {data:blob,error}=await _supabase.storage.from('documentos').download(l.arquivo_path);
      if(error||!blob){w.close();toast('Não consegui abrir o arquivo do certificado: '+(error&&error.message||''),'danger');return;}
      const html=await blob.text(); w.document.open(); w.document.write(html); w.document.close();
      setTimeout(()=>{try{w.focus();w.print();}catch(e){}},900);
      return;
    }
    // laudo sem arquivo (finalizado antes da 051): o laboratório monta e grava na hora
    window.open('laboratorio.html?laudo='+encodeURIComponent(laudoId)+'&imprimir=1','_blank');
  };

  /* bloco pronto para telas: lista + botões de imprimir */
  window.certHtml=function(lista,opts){
    opts=opts||{};
    if(!lista||!lista.length)return opts.vazio||'';
    return `<div style="display:flex;flex-direction:column;gap:6px;">${lista.map(x=>{const l=x.laudo||x;
      const q=x.quantidade!=null?Number(x.quantidade).toLocaleString('pt-BR',{maximumFractionDigits:x.unidade==='t'?2:0})+' '+(x.unidade||''):'';
      return `<div style="display:flex;justify-content:space-between;align-items:center;gap:10px;background:#f0fdf4;border:1.5px solid #bbf7d0;border-radius:10px;padding:8px 12px;font-size:13px;">
        <span>📜 <b style="color:#042D4D;">${E(l.numero||'sem número')}</b> · ${E(l.produto||x.produto||'')}${l.lote?' · lote '+E(l.lote):''}${l.op_numero?' · OP '+E(l.op_numero):''}${q?' · <b>'+q+'</b>':''}
          ${x.sugerido?' <span title="Granel não tem pallet: é o certificado mais recente deste produto. Confira." style="font-size:11px;color:#92400e;font-weight:700;">(sugerido — conferir)</span>':''}</span>
        <button class="btn btn-secondary btn-sm" onclick="certImprimir('${l.id||x.laudo_id}')">🖨️ Imprimir</button></div>`;}).join('')}</div>`;
  };
})();
