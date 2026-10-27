/* ═══════════════════════════════════════════════════════════════════════════
   BPF · DOCUMENTOS GERADOS PELO SISTEMA (10/2026)
   • PDF de cada REGISTRO (ficha) e de cada INSTRUÇÃO no mesmo layout dos POPs
     (logo, cabeçalho de controle, Elaborado/Revisado/Aprovado, rodapé com página).
   • REG = montado a partir do cadastro da ficha (campos, critérios, assinaturas).
     IT  = montado a partir do texto do POP (bpf_documentos_mestre.conteudo).
   • Editor de campos da ficha → nova revisão "aguardando aprovação" (com o que
     mudou escrito sozinho) → aprovada: vale na tela e no papel, gera o PDF novo,
     a anterior vai para o histórico e abre o recolhimento (POP-12).
   O ERP manda; o PDF acompanha.
   ═══════════════════════════════════════════════════════════════════════════ */
const PDF_COR={navy:'#0b2a4a',lime:'#c9ff64',txt:'#475569',mu:'#64748b',borda:'#c8d5e2',claro:'#f5f8fb'};
const PDF_ASSIN=[['Cesar Santos','Gerente de Qualidade'],['Cesar Müzel Gonçalves','Responsável Técnico'],['João Paulo Dias Rodrigues','Diretor Industrial']];
let _fversoes=[];          // bpf_formulario_versoes
let _pdfMakeOk=null,_logoPdf=null;

async function carregarVersoesFichas(){
  try{ _fversoes=await lst(_supabase.from('bpf_formulario_versoes').select('*').neq('status','descartada').order('criado_em',{ascending:false})); }catch(e){ _fversoes=[]; }
}
function versaoVigente(cod){ return _fversoes.find(v=>v.formulario_cod===cod&&v.status==='vigente'); }
function versaoAguardando(cod){ return _fversoes.find(v=>v.formulario_cod===cod&&v.status==='aguardando'); }
// a ficha COMO ERA na revisão em que o registro foi feito (registro antigo não muda)
function formDoRegistro(r){
  const f=_forms.find(x=>x.codigo===r.formulario_cod);if(!f)return f;
  if(!r.form_revisao)return f;
  const vg=versaoVigente(f.codigo); if(!vg||vg.revisao===r.form_revisao)return f;
  const v=_fversoes.find(x=>x.formulario_cod===f.codigo&&x.revisao===r.form_revisao);
  return v?{...f,campos:v.campos,assinaturas:v.assinaturas,titulo:v.titulo||f.titulo,_rev:v.revisao}:f;
}

// ── pdfmake + fonte DejaVu Serif (a mesma dos POPs) ─────────────────────────
async function carregarPdfMake(){
  if(_pdfMakeOk)return _pdfMakeOk;
  _pdfMakeOk=new Promise((ok,er)=>{const s=document.createElement('script');
    s.src='https://cdn.jsdelivr.net/npm/pdfmake@0.2.10/build/pdfmake.min.js';s.onload=ok;s.onerror=er;document.head.appendChild(s);})
  .then(()=>{const B='https://cdn.jsdelivr.net/npm/dejavu-fonts-ttf@2.37.3/ttf/';
    window.pdfMake.fonts={DejaVu:{normal:B+'DejaVuSerif.ttf',bold:B+'DejaVuSerif-Bold.ttf',italics:B+'DejaVuSerif-Italic.ttf',bolditalics:B+'DejaVuSerif-BoldItalic.ttf'}};
    return window.pdfMake;});
  return _pdfMakeOk;
}
async function logoPdf(){
  if(_logoPdf)return _logoPdf;
  const b=await (await fetch('img/silicate-logo.png')).blob();
  _logoPdf=await new Promise(ok=>{const r=new FileReader();r.onload=()=>ok(r.result);r.readAsDataURL(b);});
  return _logoPdf;
}
const _d=s=>s?String(s).slice(0,10).split('-').reverse().join('/'):'—';
function secPdf(n,t){ return {margin:[0,14,0,8],stack:[
  {columns:[{width:'auto',table:{body:[[{text:n+'.',color:PDF_COR.lime,bold:true,fontSize:11.5,margin:[2,0,2,0]}]]},layout:{fillColor:()=>PDF_COR.navy,hLineWidth:()=>0,vLineWidth:()=>0,paddingTop:()=>1,paddingBottom:()=>1}},
    {text:t,bold:true,color:PDF_COR.navy,fontSize:13,margin:[8,1,0,0]}]},
  {canvas:[{type:'line',x1:0,y1:3,x2:505,y2:3,lineWidth:1.2,lineColor:PDF_COR.navy}]}]}; }
function ulPdf(itens){ return {ul:itens.map(x=>Array.isArray(x)?{text:x,margin:[0,0,0,3]}:{text:x,margin:[0,0,0,3]}),markerColor:PDF_COR.lime,type:'square',margin:[0,0,0,6]}; }
function negrito(t){ // "**x**" → negrito
  return String(t||'').split(/(\*\*[^*]+\*\*)/).filter(Boolean).map(p=>p.startsWith('**')?{text:p.slice(2,-2),bold:true,color:PDF_COR.navy}:p);
}
const tabLayout={hLineColor:()=>PDF_COR.borda,vLineColor:()=>PDF_COR.borda,fillColor:(i)=>i===0?PDF_COR.navy:(i%2===0?PDF_COR.claro:null),paddingTop:()=>4,paddingBottom:()=>4};
function tabPdf(cab,linhas,widths){ return {table:{headerRows:1,widths:widths||cab.map(()=>'*'),
  body:[cab.map(c=>({text:c,bold:true,color:'#fff',fontSize:8})),...linhas]},layout:tabLayout,fontSize:8.6,margin:[0,4,0,10]}; }
function capaPdf({cod,tit,ref,rev,emissao,revisao,ciclo,metodo,vig,aprov}){
  const cel=(t,o={})=>({text:t,alignment:'center',...o});const cab=t=>({text:t,bold:true,color:'#fff',fontSize:8,alignment:'center'});
  const pess=p=>({stack:[{text:p[0],bold:true,color:PDF_COR.navy,fontSize:9.5},{text:p[1],color:PDF_COR.mu,fontSize:8.5},
    {text:' ',margin:[0,26,0,0]},{canvas:[{type:'line',x1:0,y1:0,x2:150,y2:0,lineWidth:.6,lineColor:PDF_COR.mu}]},
    {text:'Assinatura',fontSize:7.5,color:PDF_COR.mu,margin:[0,2,0,0]},
    aprov?{text:aprov,fontSize:7.5,color:'#166534',margin:[0,4,0,0]}:{text:'pendente de aprovação',fontSize:7.5,color:'#92400e',background:'#fef3c7',margin:[0,4,0,0]}],margin:[2,4,2,6]});
  const lay={hLineColor:()=>'#9fb3c8',vLineColor:()=>'#9fb3c8',fillColor:(i,n,c)=>null,paddingTop:()=>5,paddingBottom:()=>5};
  return [{text:`${cod} — ${tit}`,fontSize:18,bold:true,color:PDF_COR.navy,margin:[0,0,0,4]},{text:ref,fontSize:9,color:PDF_COR.mu,margin:[0,0,0,16]},
    {text:'Cabeçalho de controle',fontSize:12.5,bold:true,color:PDF_COR.navy,margin:[0,0,0,8]},
    {table:{widths:['*','*','*','*'],body:[
      [cab('Código'),cab('Revisão'),cab('Data de emissão'),cab('Data de revisão')],
      [cel(cod,{bold:true,color:PDF_COR.navy}),cel(rev,{bold:true,color:PDF_COR.navy}),cel(emissao,{bold:true,color:PDF_COR.navy}),cel(revisao,{bold:true,color:PDF_COR.navy})],
      [{...cab('Ciclo de revisão'),colSpan:2},{},{...cab('Método de assinatura'),colSpan:2},{}],
      [{...cel(ciclo),colSpan:2},{},{...cel(metodo),colSpan:2},{}],
      [{...cab('Data de vigência'),colSpan:4},{},{},{}],[{...cel(vig),colSpan:4},{},{},{}]]},
     layout:{...lay,fillColor:(i)=>[0,2,4].includes(i)?PDF_COR.navy:null},fontSize:9},
    {text:'Elaboração, revisão e aprovação',fontSize:10.5,bold:true,color:PDF_COR.navy,margin:[0,20,0,8]},
    {table:{widths:['*','*','*'],body:[[cab('ELABORADO POR'),cab('REVISADO POR'),cab('APROVADO POR (DIREÇÃO)')],PDF_ASSIN.map(pess)]},
     layout:{...lay,fillColor:(i)=>i===0?PDF_COR.navy:null}}];
}
function revisoesPdf(cod,rev,data,desc){
  const hs=(typeof revsDe==='function'?revsDe(cod):[]).slice().reverse();
  return tabPdf(['Revisão','Data','Descrição da alteração'],
    hs.map(r=>[{text:r.revisao||'—',alignment:'center'},{text:_d(r.data),alignment:'center'},r.alteracao||'—'])
      .concat([[{text:rev,alignment:'center',bold:true},{text:data,alignment:'center'},desc||'—']]),[50,70,'*']);
}
const _TIPO={hora:'Hora (hh:mm)',texto:'Texto',numero:'Número',sim_nao:'Sim / Não / N/A',textarea:'Texto livre',select:'Lista de opções',data:'Data',funcionario:'Nome do colaborador',produto:'Produto',secao:'—'};
function critCampo(c){
  if(c.conforme){const x={sim:'Sim',nao:'Não'}[c.conforme]||c.conforme;return [{text:x,bold:true,color:PDF_COR.navy},' — outra resposta = não conformidade'];}
  const l=[];if(c.min!==undefined&&c.min!==null&&c.min!=='')l.push('mín. '+c.min);if(c.max!==undefined&&c.max!==null&&c.max!=='')l.push('máx. '+c.max);
  if(l.length)return l.join(' · ')+(c.unidade?' '+c.unidade:'');
  if(c.calc)return 'Calculado pelo sistema';
  return '—';
}
function comoCampo(c){
  if(c.ajuda)return c.ajuda;
  if(c.tipo==='select'&&Array.isArray(c.opcoes))return 'Escolher: '+c.opcoes.join(' · ');
  return _TIPO[c.tipo]||c.tipo;
}
// ── documento de REGISTRO (a partir da ficha) ──────────────────────────────
function defPdfRegistro(d,f,{rev,data,alteracao,aprov}){
  const pop=_docs.find(x=>x.codigo===f.pop_cod&&x.tipo==='pop');
  const campos=(f.campos||[]).filter(c=>c.tipo!=='secao');
  const per={por_evento:'A cada evento',diaria:'Diária',semanal:'Semanal',mensal:'Mensal',anual:'Anual',por_lote:'A cada lote',por_ensaque:'A cada ensaque',por_turno:'A cada turno'}[f.periodicidade]||cap(String(f.periodicidade||'—').replace(/_/g,' '));
  const ass=f.assinaturas||[];
  return [...capaPdf({cod:d.codigo,tit:f.titulo,ref:`Registro do ${pop?pop.codigo+' — '+pop.titulo:f.pop_cod} · IN MAPA nº 04/2007 (item 7.2)`,rev,emissao:d.data_emissao?_d(d.data_emissao):data,revisao:data,
      ciclo:`A cada alteração do ${f.pop_cod} ou dos campos do registro`,metodo:'Eletrônica (assinatura no sistema) e manuscrita na ficha',vig:aprov?data:'Após aprovação',aprov}),
    {text:'',pageBreak:'after'},
    secPdf(1,'Objetivo'),{text:`Registrar ${String(f.titulo||'').toLowerCase()}, conforme o ${pop?pop.codigo+' — '+pop.titulo:f.pop_cod}, de forma que o resultado possa ser verificado e auditado.`,alignment:'justify'},
    secPdf(2,'Quando preencher'),{text:[{text:per,bold:true,color:PDF_COR.navy},`. Quando a ficha nasce de um evento do sistema (OP, recebimento, laboratório, manutenção…), ela já vem com os dados conhecidos preenchidos.`],alignment:'justify'},
    secPdf(3,'Quem assina'),ass.length?ulPdf(ass.map(a=>[{text:a.label+': ',bold:true,color:PDF_COR.navy},(typeof nomeFuncao==='function'?nomeFuncao(a.funcao):a.funcao)||'—',a.obrigatoria?' (obrigatória)':''])):{text:'Sem assinatura exigida.'},
    secPdf(4,'Campos do registro'),
    tabPdf(['Campo','Como preencher','Critério de conformidade','Obrig.'],
      campos.map(c=>[{text:c.label,bold:true,color:PDF_COR.navy},comoCampo(c),{text:critCampo(c)},{text:c.obrigatorio?'Sim':'—',alignment:'center'}]),['24%','36%','*',36]),
    secPdf(5,'Fluxo do registro no sistema'),
    ulPdf([[{text:'Gerado',bold:true,color:PDF_COR.navy},' pelo evento do ERP ou manualmente no POP; '],
      [{text:'Ficha impressa → preenchida no papel → digitada no ERP',bold:true,color:PDF_COR.navy},' exatamente como está no papel;'],
      [{text:'Foto da ficha preenchida',bold:true,color:PDF_COR.navy},' anexada → assinaturas no sistema → concluído.']]),
    secPdf(6,'Guarda do registro'),
    tabPdf(['Guarda','Retenção','Local','Formato'],[['Qualidade',(f.retencao_anos||4)+' anos','SGQ / 03_APROVADOS','Eletrônico (ERP) + ficha em papel fotografada']]),
    {text:'',pageBreak:'before'},secPdf(7,'Modelo da ficha'),
    {table:{headerRows:1,widths:['42%','*'],body:[[{text:`${d.codigo} · Nº do registro: __________ · Data: ___/___/______`,colSpan:2,bold:true,color:'#fff',fontSize:8.5},{}],
      ...(f.campos||[]).map(c=>c.tipo==='secao'?[{text:c.label,colSpan:2,bold:true,color:PDF_COR.navy,fillColor:'#eef3f8'},{}]
        :c.tipo==='textarea'?[{text:c.label,colSpan:2,bold:true,color:PDF_COR.navy,margin:[0,0,0,34]},{}]
        :[{text:c.label+(c.obrigatorio?' *':''),bold:true,color:PDF_COR.navy},{text:c.tipo==='sim_nao'?'□ Sim     □ Não     □ N/A':(c.unidade?'                                  '+c.unidade:''),color:PDF_COR.mu}])]},
     layout:{...tabLayout,fillColor:(i)=>i===0?PDF_COR.navy:null,paddingTop:()=>6,paddingBottom:()=>6},fontSize:8.8,margin:[0,4,0,10]},
    ass.length?{table:{widths:ass.map(()=>'*'),body:[ass.map(a=>({text:a.label+' (nome e assinatura)',bold:true,color:'#fff',fontSize:8})),ass.map(()=>({text:' ',margin:[0,22,0,0]}))]},layout:{...tabLayout,fillColor:(i)=>i===0?PDF_COR.navy:null}}:'',
    {text:'* Campos obrigatórios. Depois de preenchida, a ficha é digitada no sistema e a foto dela é anexada ao registro.',fontSize:8,color:PDF_COR.mu,margin:[0,8,0,0]},
    secPdf(8,'Controle de revisões'),revisoesPdf(d.codigo,rev,data,alteracao)];
}
// ── documento de INSTRUÇÃO (a partir do texto do POP) ──────────────────────
function defPdfInstrucao(d,{rev,data,alteracao,aprov}){
  const c=d.conteudo||{};const pop=_docs.find(x=>x.codigo===d.pop_cod&&x.tipo==='pop');
  const paragr=t=>String(t||'').split('\n').map(x=>x.trim()).filter(Boolean);
  const corpo=t=>{const ls=paragr(t);const bs=ls.filter(x=>x.startsWith('▪')).map(x=>x.replace(/^▪\s*/,''));const ps=ls.filter(x=>!x.startsWith('▪'));
    return [...ps.map(p=>({text:p,alignment:'justify',margin:[0,0,0,5]})),bs.length?ulPdf(bs):''];};
  const refs=(c.passos||[]).map(p=>p.ref).join(', ');
  const regs=_forms.filter(f=>f.pop_cod===d.pop_cod);
  return [...capaPdf({cod:d.codigo,tit:d.titulo,ref:`Instrução de trabalho do ${pop?pop.codigo+' — '+pop.titulo:d.pop_cod} · IN MAPA nº 04/2007 (item 7.2)`,rev,emissao:d.data_emissao?_d(d.data_emissao):data,revisao:data,
      ciclo:`A cada alteração do ${d.pop_cod}`,metodo:'Eletrônica (assinatura no sistema)',vig:aprov?data:'Após aprovação',aprov}),
    {text:'',pageBreak:'after'},
    {table:{widths:['*'],body:[[{text:[`Conteúdo extraído do `,{text:`${c.pop||d.pop_cod} rev. ${c.pop_rev||'—'}`,bold:true,color:PDF_COR.navy},` (itens 2, 5, ${refs||'6'} e 10), organizado para quem executa a atividade.`],fontSize:8.8}]]},
     layout:{hLineColor:()=>PDF_COR.borda,vLineColor:(i)=>i===0?PDF_COR.lime:PDF_COR.borda,vLineWidth:(i)=>i===0?4:1,fillColor:()=>'#f8fbf2',paddingTop:()=>6,paddingBottom:()=>6,paddingLeft:()=>8}},
    secPdf(1,'Objetivo'),{text:`Orientar a execução de: ${String(d.titulo||'').toLowerCase()}, conforme o ${pop?pop.codigo+' — '+pop.titulo:d.pop_cod}.`,alignment:'justify'},
    secPdf(2,'Onde se aplica'),...corpo(c.aplicacao),
    secPdf(3,'Responsáveis'),ulPdf((c.responsabilidades||[]).filter(x=>x&&!/^As responsabilidades/i.test(x)).map(x=>{const m=x.match(/^([^:]{3,60}):\s*(.*)$/);return m?[{text:m[1]+': ',bold:true,color:PDF_COR.navy},m[2]]:x;})),
    secPdf(4,'Como fazer'),
    ...(c.passos||[]).flatMap(p=>[{text:`${p.ref} ${p.titulo}`,bold:true,color:PDF_COR.navy,fontSize:10.5,margin:[0,6,0,4]},...corpo(p.texto)]),
    c.acoes_corretivas?secPdf(5,'Se algo sair do padrão'):'',c.acoes_corretivas?{text:c.acoes_corretivas,alignment:'justify'}:'',
    secPdf(6,'Registros'),regs.length?ulPdf(regs.map(f=>[{text:f.codigo+' — ',bold:true,color:PDF_COR.navy},f.titulo])):{text:'—'},
    secPdf(7,'Referências'),ulPdf([[{text:(pop?pop.codigo:d.pop_cod)+' — ',bold:true,color:PDF_COR.navy},(pop?pop.titulo:'')+(c.pop_rev?' (rev. '+c.pop_rev+')':'')],[{text:'IN MAPA nº 04/2007 (item 7.2)',bold:true,color:PDF_COR.navy}]]),
    secPdf(8,'Controle de revisões'),revisoesPdf(d.codigo,rev,data,alteracao)];
}
// monta o PDF e devolve um Blob
async function gerarPdfDoc(d,opt={}){
  const pm=await carregarPdfMake();const logo=await logoPdf();
  const rev=opt.rev||d.revisao||'00', data=opt.data||_d(new Date().toISOString());
  let conteudo;
  if(d.tipo==='reg'){ const f=opt.form||_forms.find(x=>x.codigo===d.codigo); if(!f)throw new Error('ficha '+d.codigo+' não encontrada'); conteudo=defPdfRegistro(d,f,{rev,data,alteracao:opt.alteracao,aprov:opt.aprov}); }
  else if(d.tipo==='it'){ if(!d.conteudo)throw new Error('sem conteúdo para '+d.codigo); conteudo=defPdfInstrucao(d,{rev,data,alteracao:opt.alteracao,aprov:opt.aprov}); }
  else throw new Error('tipo não gerado pelo sistema: '+d.tipo);
  const tit=d.tipo==='reg'?((opt.form||{}).titulo||d.titulo):d.titulo;
  const def={pageSize:'A4',pageMargins:[45,78,45,58],defaultStyle:{font:'DejaVu',fontSize:9.6,color:PDF_COR.txt,lineHeight:1.15},images:{logo},
    info:{title:`${d.codigo} — ${tit}`,author:'Silicate — SGQ'},
    header:()=>({margin:[45,24,45,0],stack:[{columns:[{image:'logo',width:96},{stack:[{text:`${d.codigo} — ${tit}`,bold:true,fontSize:7.5,color:PDF_COR.navy,alignment:'right'},
        {text:`Revisão ${rev} · ${data} · Documento controlado`,fontSize:6.5,color:PDF_COR.mu,alignment:'right'}]}]},
      {canvas:[{type:'line',x1:0,y1:5,x2:505,y2:5,lineWidth:1.2,lineColor:PDF_COR.navy}]}]}),
    footer:(p,t)=>({margin:[45,14,45,0],stack:[{canvas:[{type:'line',x1:0,y1:0,x2:505,y2:0,lineWidth:1.2,lineColor:PDF_COR.lime}]},
      {columns:[{text:'Silicate Indústria e Comércio Ltda · Sistema de Gestão da Qualidade',fontSize:6.5,color:PDF_COR.mu},
        {text:[{text:'Página ',bold:true,color:PDF_COR.navy},`${p} de ${t}`],alignment:'right',fontSize:6.5,color:PDF_COR.mu}],margin:[0,4,0,0]}]}),
    content:conteudo};
  return await new Promise((ok,er)=>{try{pm.createPdf(def).getBlob(ok);}catch(e){er(e);}});
}
// grava o PDF como arquivo do documento (a versão anterior, se houver, vai para o histórico)
async function publicarPdfDoc(d,blob,{rev,alteracao,data}){
  const u=getUser(),quem=u?.nome||u?.email||'Sistema';
  const path=`bpf/mestre/${d.codigo}_r${String(rev).replace(/\W/g,'')}_${Date.now()}_${d.codigo}_rev${rev}.pdf`;
  const up=await _supabase.storage.from('documentos').upload(path,blob,{contentType:'application/pdf'});
  if(up.error)throw up.error;
  if(d.arquivo_path&&d.revisao!==rev){
    const h=await db(_supabase.from('bpf_documento_revisoes').insert({documento_cod:d.codigo,revisao:d.revisao,data:dataVersao(d),
      alteracao:d.alteracao_atual||null,autor:d.revisado_por||d.aprovado_por||null,arquivo_path:d.arquivo_path}),'histórico');
    if(h.error)throw h.error;
  }
  const hojeIso=new Date().toISOString().slice(0,10);
  const patch={arquivo_path:path,revisao:rev,data_revisao:hojeIso,alteracao_atual:alteracao||null,revisado_por:quem,atualizado_em:new Date().toISOString()};
  if(!d.data_emissao)patch.data_emissao=hojeIso;
  const r=await db(_supabase.from('bpf_documentos_mestre').update(patch).eq('id',d.id),'publicar PDF');
  if(r.error)throw r.error;
  Object.assign(d,patch);
}
// 📄 gera de uma vez os PDFs dos REG/IT que ainda não têm arquivo (rev. atual)
async function gerarPdfsPendentes(){
  if(!guardAction('bpf','edit'))return;
  // conteúdo das ITs (texto dos POPs) entra no banco na primeira vez
  const semConteudo=_docs.filter(d=>d.tipo==='it'&&!d.conteudo&&!d.arquivo_path);
  if(semConteudo.length){
    try{ const j=await (await fetch('dados/bpf_its_rev00.json',{cache:'no-store'})).json();
      for(const d of semConteudo){ if(j[d.codigo]){ const r=await db(_supabase.from('bpf_documentos_mestre').update({conteudo:j[d.codigo]}).eq('id',d.id),'conteúdo IT'); if(!r.error)d.conteudo=j[d.codigo]; } } }
    catch(e){ console.warn('[ITs]',e); }
  }
  const l=_docs.filter(d=>(d.tipo==='reg'&&_forms.some(f=>f.codigo===d.codigo))||(d.tipo==='it'&&d.conteudo)).filter(d=>!d.arquivo_path);
  if(!l.length){toast('Todos os registros e instruções já têm PDF.','info');return;}
  if(!(await uiConfirma(`Gerar o PDF de <b>${l.length} documento(s)</b> no layout dos POPs e gravar como arquivo oficial (rev. ${'atual'})?<div style="margin-top:6px;font-size:12px;color:#64748b;">${l.map(d=>esc(d.codigo)).join(', ')}</div>`,{titulo:'Gerar PDFs',ok:'Gerar'})))return;
  const box=document.createElement('div');box.className='toast-prog';box.style.cssText='position:fixed;bottom:20px;right:20px;z-index:9999;background:#042D4D;color:#fff;padding:12px 16px;border-radius:12px;font-size:13px;box-shadow:0 8px 24px rgba(0,0,0,.25);';
  document.body.appendChild(box);let ok=0,erros=[];
  for(const [i,d] of l.entries()){
    box.textContent=`Gerando PDFs… ${i+1}/${l.length} · ${d.codigo}`;
    try{ const blob=await gerarPdfDoc(d,{rev:d.revisao||'00'}); await publicarPdfDoc(d,blob,{rev:d.revisao||'00',alteracao:'Emissão do documento gerada pelo sistema'}); ok++; }
    catch(e){ erros.push(d.codigo+': '+(e.message||e)); }
  }
  box.remove();
  await addLog('UPDATE','BPF','documentos',`${ok} PDF(s) de REG/IT gerados pelo sistema`);
  if(erros.length)await uiAlerta(`${ok} gerado(s). Com erro:<br>${erros.map(esc).join('<br>')}`,{titulo:'PDFs',tipo:'warn'});
  else toast(`${ok} PDF(s) gerados e gravados.`,'success');
  renderDocs();
}

// ═══ EDITOR DE CAMPOS DA FICHA ════════════════════════════════════════════
let _ed=null;
const TIPOS_CAMPO=[['texto','Texto'],['numero','Número'],['sim_nao','Sim / Não / N/A'],['select','Lista de opções'],['data','Data'],['hora','Hora'],['textarea','Texto longo'],['funcionario','Colaborador'],['secao','— Seção (título) —']];
function podeAprovarFicha(cod){
  const u=getUser()||{};const f=_forms.find(x=>x.codigo===cod);
  if(['SADM','ADM','QLD','DIR','GPR'].includes(u.perfil))return true;
  return _desig.some(d=>d.ativo&&d.pop_cod===(f&&f.pop_cod)&&(d.papeis||[]).includes('responsavel')&&_normP(d.funcionario_nome)===_normP(u.nome));
}
function abrirEditorCampos(cod){
  if(!guardAction('bpf','edit'))return;
  const f=_forms.find(x=>x.codigo===cod);if(!f)return;
  const ag=versaoAguardando(cod);
  const base=ag||{campos:f.campos,assinaturas:f.assinaturas,titulo:f.titulo};
  _ed={cod,f,campos:JSON.parse(JSON.stringify(base.campos||[])),assinaturas:JSON.parse(JSON.stringify(base.assinaturas||[])),titulo:base.titulo||f.titulo,ag};
  pintarEditor();
  document.getElementById('m-ent').classList.remove('hidden');
}
function pintarEditor(){
  const e=_ed,rev=String((parseInt(String((_docs.find(d=>d.codigo===e.cod)||{}).revisao||'0').replace(/\D/g,''))||0)+1).padStart(2,'0');
  document.getElementById('m-ent-tit').textContent=`✏️ Editar campos — ${e.cod}`;
  const linha=(c,i)=>`<div class="ed-l${c.tipo==='secao'?' ed-sec':''}">
    <div class="ed-ord"><button onclick="edMover(${i},-1)" title="Subir">▲</button><button onclick="edMover(${i},1)" title="Descer">▼</button></div>
    <div class="ed-c">
      <div class="ed-r1"><input class="form-input" value="${esc(c.label||'')}" placeholder="Nome do campo" oninput="_ed.campos[${i}].label=this.value">
        <select class="form-input" onchange="_ed.campos[${i}].tipo=this.value;pintarEditor()">${TIPOS_CAMPO.map(([v,t])=>`<option value="${v}" ${c.tipo===v?'selected':''}>${t}</option>`).join('')}</select>
        ${c.tipo!=='secao'?`<label class="ed-ck"><input type="checkbox" ${c.obrigatorio?'checked':''} onchange="_ed.campos[${i}].obrigatorio=this.checked||undefined"> obrigatório</label>`:''}
        <button class="btn btn-ghost btn-sm" style="color:#b91c1c" title="Remover campo" onclick="_ed.campos.splice(${i},1);pintarEditor()">✕</button></div>
      ${c.tipo==='sim_nao'?`<div class="ed-r2">Resposta conforme: <select class="form-input" onchange="_ed.campos[${i}].conforme=this.value||undefined">
          <option value="" ${!c.conforme?'selected':''}>— não avalia —</option><option value="sim" ${c.conforme==='sim'?'selected':''}>Sim</option><option value="nao" ${c.conforme==='nao'?'selected':''}>Não</option></select></div>`:''}
      ${c.tipo==='numero'?`<div class="ed-r2">Mín.: <input class="form-input" style="width:90px" value="${c.min??''}" oninput="_ed.campos[${i}].min=this.value===''?undefined:Number(String(this.value).replace(',','.'))">
          Máx.: <input class="form-input" style="width:90px" value="${c.max??''}" oninput="_ed.campos[${i}].max=this.value===''?undefined:Number(String(this.value).replace(',','.'))">
          Unidade: <input class="form-input" style="width:80px" value="${esc(c.unidade||'')}" oninput="_ed.campos[${i}].unidade=this.value||undefined"></div>`:''}
      ${c.tipo==='select'?`<div class="ed-r2">Opções (separe por ;): <input class="form-input" style="flex:1" value="${esc((c.opcoes||[]).join('; '))}" oninput="_ed.campos[${i}].opcoes=this.value.split(';').map(x=>x.trim()).filter(Boolean)">
          Conforme: <input class="form-input" style="width:140px" value="${esc(c.conforme||'')}" placeholder="opção certa" oninput="_ed.campos[${i}].conforme=this.value||undefined"></div>`:''}
      ${c.tipo!=='secao'?`<div class="ed-r2">Ajuda: <input class="form-input" style="flex:1" value="${esc(c.ajuda||'')}" placeholder="como preencher (aparece na tela e no PDF)" oninput="_ed.campos[${i}].ajuda=this.value||undefined"></div>`:''}
    </div></div>`;
  const fs=(typeof _funcs!=='undefined'?_funcs:[]);
  document.getElementById('m-ent-body').innerHTML=`
    <div class="bx-nv-info">As mudanças viram a <b>revisão ${rev}</b> "aguardando aprovação". Até ser aprovada, continua valendo a revisão atual — na tela de lançamento e no papel.${e.ag?' <b>Já existe uma revisão aguardando:</b> você está editando ela.':''}</div>
    <div class="form-group"><label class="form-label">Título do registro</label><input class="form-input" value="${esc(e.titulo||'')}" oninput="_ed.titulo=this.value"></div>
    <div class="cf-lb">Campos (${e.campos.length})</div>
    <div id="ed-lista">${e.campos.map(linha).join('')}</div>
    <button class="btn btn-secondary btn-sm" onclick="_ed.campos.push({id:'c'+Date.now().toString(36),tipo:'texto',label:''});pintarEditor();setTimeout(()=>{const l=document.querySelectorAll('#ed-lista .ed-l input');l[l.length-1]?.focus()},50)">＋ Adicionar campo</button>
    <div class="cf-lb" style="margin-top:16px;">Quem assina</div>
    ${e.assinaturas.map((a,i)=>`<div class="ed-r1" style="margin-bottom:6px;"><input class="form-input" value="${esc(a.label||'')}" placeholder="Papel (ex.: Executante)" oninput="_ed.assinaturas[${i}].label=this.value">
      <select class="form-input" onchange="_ed.assinaturas[${i}].funcao=this.value">${fs.map(x=>`<option value="${esc(x.codigo)}" ${x.codigo===a.funcao?'selected':''}>${esc(x.nome)}</option>`).join('')||`<option>${esc(a.funcao||'')}</option>`}</select>
      <label class="ed-ck"><input type="checkbox" ${a.obrigatoria?'checked':''} onchange="_ed.assinaturas[${i}].obrigatoria=this.checked"> obrigatória</label>
      <button class="btn btn-ghost btn-sm" style="color:#b91c1c" onclick="_ed.assinaturas.splice(${i},1);pintarEditor()">✕</button></div>`).join('')}
    <button class="btn btn-secondary btn-sm" onclick="_ed.assinaturas.push({id:'a'+Date.now().toString(36),label:'',funcao:(${JSON.stringify((fs[0]||{}).codigo||'')}),obrigatoria:true});pintarEditor()">＋ Adicionar assinatura</button>`;
  document.getElementById('m-ent-foot').innerHTML=`<button class="btn btn-secondary" onclick="closeModal('m-ent')">Cancelar</button>
    <button class="btn btn-primary" onclick="salvarEditorCampos()">💾 Salvar como revisão ${rev}</button>`;
}
function edMover(i,d){const a=_ed.campos,j=i+d;if(j<0||j>=a.length)return;[a[i],a[j]]=[a[j],a[i]];pintarEditor();}
function diffFicha(antes,depois){
  const out=[];const A=Object.fromEntries((antes.campos||[]).map(c=>[c.id,c])),B=Object.fromEntries((depois.campos||[]).map(c=>[c.id,c]));
  if((antes.titulo||'')!==(depois.titulo||''))out.push(`título: "${depois.titulo}"`);
  for(const c of depois.campos||[]){const o=A[c.id];
    if(!o){out.push(`+ campo ${c.label}${c.obrigatorio?' (obrigatório)':''}`);continue;}
    if(o.label!==c.label)out.push(`campo "${o.label}" → "${c.label}"`);
    if(o.tipo!==c.tipo)out.push(`${c.label}: tipo ${_TIPO[o.tipo]||o.tipo} → ${_TIPO[c.tipo]||c.tipo}`);
    if(!!o.obrigatorio!==!!c.obrigatorio)out.push(`${c.label} ${c.obrigatorio?'agora obrigatório':'deixa de ser obrigatório'}`);
    if((o.conforme||'')!==(c.conforme||''))out.push(`${c.label}: conforme ${o.conforme||'—'} → ${c.conforme||'—'}`);
    if((o.min??'')!==(c.min??'')||(o.max??'')!==(c.max??''))out.push(`${c.label}: limite ${o.min??'—'}–${o.max??'—'} → ${c.min??'—'}–${c.max??'—'}${c.unidade?' '+c.unidade:''}`);
    if(JSON.stringify(o.opcoes||[])!==JSON.stringify(c.opcoes||[]))out.push(`${c.label}: opções alteradas`);
    if((o.ajuda||'')!==(c.ajuda||''))out.push(`${c.label}: ajuda alterada`);}
  for(const o of antes.campos||[])if(!B[o.id])out.push(`– campo ${o.label}`);
  const ordA=(antes.campos||[]).map(c=>c.id).filter(id=>B[id]).join(),ordB=(depois.campos||[]).map(c=>c.id).filter(id=>A[id]).join();
  if(ordA!==ordB)out.push('ordem dos campos alterada');
  const sa=(antes.assinaturas||[]).map(a=>a.label+':'+a.funcao+':'+!!a.obrigatoria).join('|'),sb=(depois.assinaturas||[]).map(a=>a.label+':'+a.funcao+':'+!!a.obrigatoria).join('|');
  if(sa!==sb)out.push('assinaturas: '+(depois.assinaturas||[]).map(a=>a.label).join(', '));
  return out;
}
async function salvarEditorCampos(){
  const e=_ed;if(!e)return;
  const vazios=e.campos.filter(c=>!String(c.label||'').trim());if(vazios.length){await uiAlerta('Dê nome a todos os campos.',{titulo:'Falta o nome',tipo:'warn'});return;}
  e.campos.forEach(c=>{Object.keys(c).forEach(k=>c[k]===undefined&&delete c[k]);});
  const atual={campos:e.f.campos,assinaturas:e.f.assinaturas,titulo:e.f.titulo};
  const novo={campos:e.campos,assinaturas:e.assinaturas,titulo:e.titulo};
  const dif=diffFicha(atual,novo);
  if(!dif.length){ if(e.ag){ await db(_supabase.from('bpf_formulario_versoes').update({status:'descartada'}).eq('id',e.ag.id),'descartar'); }
    toast('Nada mudou em relação à revisão atual.','info');closeModal('m-ent');await carregarVersoesFichas();if(_sec==='pop')abrirPop(_popSel);return;}
  const d=_docs.find(x=>x.codigo===e.cod);
  const rev=e.ag?e.ag.revisao:String((parseInt(String((d||{}).revisao||'0').replace(/\D/g,''))||0)+1).padStart(2,'0');
  const u=getUser(),quem=u?.nome||u?.email||'—';
  const row={formulario_cod:e.cod,revisao:rev,titulo:e.titulo,periodicidade:e.f.periodicidade,campos:e.campos,assinaturas:e.assinaturas,status:'aguardando',alteracoes:dif.join(' · '),criado_por:quem};
  const r=e.ag?await db(_supabase.from('bpf_formulario_versoes').update(row).eq('id',e.ag.id),'revisão'):await db(_supabase.from('bpf_formulario_versoes').insert(row),'revisão');
  if(r.error)return;
  await addLog('UPDATE','BPF',e.cod,`Revisão ${rev} da ficha aguardando aprovação: ${row.alteracoes}`);
  try{ const dest=[...new Set(pessoasDoPop(e.f.pop_cod,'responsavel').concat(pessoasDoPop(e.f.pop_cod,'aviso')).map(x=>x.funcionario_nome).filter(Boolean))];
    await _supabase.from('notificacoes').insert({tipo:'aviso',modulo:'bpf',titulo:`BPF ${e.cod}: revisão ${rev} aguardando aprovação`,descricao:row.alteracoes,chave:'bpf_rev_'+e.cod+'_'+rev+'_'+Date.now(),fonte:'bpf',destinatarios:dest}); }catch(x){}
  closeModal('m-ent');toast(`Revisão ${rev} salva — aguardando aprovação.`,'success');
  await carregarVersoesFichas();if(_sec==='pop')abrirPop(_popSel);
}
async function descartarVersaoFicha(cod){
  const ag=versaoAguardando(cod);if(!ag)return;
  if(!(await uiConfirma(`Descartar a revisão ${esc(ag.revisao)} (${esc(ag.alteracoes||'')})?`,{titulo:'Descartar',ok:'Descartar'})))return;
  await db(_supabase.from('bpf_formulario_versoes').update({status:'descartada'}).eq('id',ag.id),'descartar');
  await carregarVersoesFichas();abrirPop(_popSel);
}
async function aprovarVersaoFicha(cod){
  const ag=versaoAguardando(cod);if(!ag)return;
  if(!podeAprovarFicha(cod)){await uiAlerta('Só a Qualidade, a Direção ou o responsável pelo POP aprova a revisão.',{titulo:'Sem permissão',tipo:'warn'});return;}
  const f=_forms.find(x=>x.codigo===cod);const d=_docs.find(x=>x.codigo===cod);
  if(!(await uiConfirma(`Aprovar a <b>revisão ${esc(ag.revisao)}</b> do ${esc(cod)}?<div style="margin:8px 0;font-size:12.5px;">${esc(ag.alteracoes||'')}</div>
    <div style="font-size:12px;color:#64748b;">Ela passa a valer na tela de lançamento e na ficha em branco, o PDF novo é gerado, a revisão atual vai para o histórico e abre o recolhimento das cópias antigas (POP-12). Registros já lançados não mudam.</div>`,{titulo:'Aprovar revisão',ok:'✅ Aprovar'})))return;
  const u=getUser(),quem=u?.nome||u?.email||'—',agora=new Date().toISOString();
  const box=document.createElement('div');box.style.cssText='position:fixed;bottom:20px;right:20px;z-index:9999;background:#042D4D;color:#fff;padding:12px 16px;border-radius:12px;font-size:13px;';box.textContent='Aplicando a revisão e gerando o PDF…';document.body.appendChild(box);
  try{
    const r1=await db(_supabase.from('bpf_formularios').update({campos:ag.campos,assinaturas:ag.assinaturas,titulo:ag.titulo||f.titulo}).eq('codigo',cod),'aplicar campos');if(r1.error)throw r1.error;
    await db(_supabase.from('bpf_formulario_versoes').update({status:'obsoleta'}).eq('formulario_cod',cod).eq('status','vigente'),'obsoletar');
    const r2=await db(_supabase.from('bpf_formulario_versoes').update({status:'vigente',aprovado_por:quem,aprovado_em:agora}).eq('id',ag.id),'vigente');if(r2.error)throw r2.error;
    const fNova={...f,campos:ag.campos,assinaturas:ag.assinaturas,titulo:ag.titulo||f.titulo};
    if(d){
      const antes=d.revisao;
      const blob=await gerarPdfDoc(d,{rev:ag.revisao,form:fNova,alteracao:ag.alteracoes,aprov:`Aprovado eletronicamente por ${quem} em ${_d(agora)}`});
      await publicarPdfDoc(d,blob,{rev:ag.revisao,alteracao:ag.alteracoes});
      if(_forms.some(x=>x.codigo==='REG-POP12-02')){
        try{ await gerarRegistro('REG-POP12-02',{abrir:false,pre:{documento:d.codigo+' — '+(ag.titulo||d.titulo),revisao_entregue:ag.revisao,revisao_recolhida:antes||'',
          obs:'Recolher todas as cópias da rev. '+(antes||'—')+' (impressas e na linha). O que mudou: '+ag.alteracoes}}); }catch(x){}
      }
    }
    await addLog('UPDATE','BPF',cod,`Revisão ${ag.revisao} da ficha aprovada por ${quem}: ${ag.alteracoes}`);
    box.remove();toast(`${cod} agora está na revisão ${ag.revisao}.`,'success');
    await carregar();await carregarVersoesFichas();renderNav();abrirPop(_popSel);
  }catch(e){ box.remove(); await uiAlerta('Não foi possível aprovar: '+esc(e.message||e),{titulo:'Erro',tipo:'dang'}); }
}
// PDF de UM documento (re)gerado na hora — para quem quer só baixar o modelo atual
async function baixarPdfGerado(id){
  const d=_docs.find(x=>x.id===id);if(!d)return;
  try{ const blob=await gerarPdfDoc(d,{}); const u=URL.createObjectURL(blob); const a=document.createElement('a');a.href=u;a.download=`${d.codigo}_rev${d.revisao||'00'}.pdf`;document.body.appendChild(a);a.click();a.remove(); }
  catch(e){ uiAlerta('Não foi possível gerar: '+esc(e.message||e),{titulo:'Erro',tipo:'dang'}); }
}
