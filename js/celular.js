/* ═══════════════════════════════════════════════════════════════════
   js/celular.js — visual de CELULAR (tela até 700px). No PC não muda nada.
   Usado hoje na Portaria (portaria.html, portaria-dsm.html).
   • cabeçalho compacto, cards 2 por linha, abas em grade (sem rolar de lado)
   • toda tabela da tela vira cartões "rótulo: valor" (rótulo vem do cabeçalho da tabela)
   Para uma tabela ficar como está no celular: class="no-cel" nela ou num pai.
   ═══════════════════════════════════════════════════════════════════ */
(function(){
  const CSS=`@media(max-width:700px){
  .main-content{overflow-x:hidden}
  .page-header{flex-direction:column;align-items:stretch;gap:8px;margin-bottom:12px}
  .page-header-left h1{font-size:20px}.page-header-left p{display:none}
  .page-header>div:last-child{display:grid !important;grid-template-columns:1fr 1fr;gap:8px;align-items:center}
  .page-header>div:last-child .btn{width:100%;justify-content:center;min-height:44px;white-space:normal;line-height:1.15}
  .page-header>div:last-child .btn-primary{grid-column:1/-1;min-height:54px;font-size:17px;order:-1}
  .page-header>div:last-child .relogio{grid-column:1/-1;text-align:center}
  .kpis,.d-kpis{grid-template-columns:repeat(2,minmax(0,1fr)) !important;gap:8px !important}
  .kpi,.d-k{padding:9px 11px !important;border-radius:12px !important;min-width:0}
  .kpi b,.d-k .v{font-size:22px !important}
  .tabs,.d-tabs,.mi-seg{display:grid !important;grid-template-columns:repeat(3,minmax(0,1fr));gap:6px !important;overflow:visible !important;border-bottom:0 !important;margin-bottom:12px}
  .tabs .tab-btn,.d-tabs button,.mi-seg button{white-space:normal !important;min-width:0;padding:9px 6px !important;font-size:12.5px !important;line-height:1.2;text-align:center;border:1.5px solid #e2e8f0 !important;border-radius:12px !important;background:#fff;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:2px;min-height:52px}
  .tabs .tab-btn.active,.tabs .tab-btn.on,.d-tabs button.on,.mi-seg button.on{background:#042D4D !important;border-color:#042D4D !important;color:#d9f99d !important}
  .tabs .tab-btn[style*="display: none"],.tabs .tab-btn[style*="display:none"]{display:none !important}
  .table-wrap{overflow:visible !important;border:0 !important;background:none !important}
  table.cel-t{display:block;width:100% !important;min-width:0 !important;border:0 !important;background:none !important}
  table.cel-t>thead{display:none}
  table.cel-t>tbody,table.cel-t>tfoot{display:block;width:100%}
  table.cel-t>tbody>tr,table.cel-t>tfoot>tr{display:block;background:#fff;border:1.5px solid #e2e8f0;border-radius:12px;padding:6px 12px;margin-bottom:8px}
  table.cel-t>tbody>tr>td,table.cel-t>tfoot>tr>td{display:flex;justify-content:space-between;align-items:baseline;gap:10px;padding:6px 0 !important;border:0 !important;border-bottom:1px dashed #edf2f7 !important;text-align:right !important;font-size:13.5px;min-width:0;width:auto !important;max-width:none !important;white-space:normal !important;overflow-wrap:anywhere}
  table.cel-t>tbody>tr>td:last-child{border-bottom:0 !important}
  table.cel-t>tbody>tr>td[data-l]::before{content:attr(data-l);flex:0 0 40%;text-align:left;font-size:11px;font-weight:800;color:#64748b;text-transform:uppercase;letter-spacing:.2px}
  table.cel-t>tbody>tr>td.cel-tit{font-size:15.5px;font-weight:800;color:#042D4D}
  table.cel-t>tbody>tr>td.cel-full{display:block;text-align:left !important}
  table.cel-t>tbody>tr>td.cel-acao{display:flex;flex-wrap:wrap;gap:6px;justify-content:flex-end}
  table.cel-t>tbody>tr>td.cel-acao .btn{min-height:42px;min-width:44px;font-size:15px}
  table.cel-t>tbody>tr>td:empty{display:none}
  table.cel-t>tbody>tr.cel-vazio,table.cel-t>tbody>tr:has(>td[colspan]:only-child){padding:10px 12px}
  .form-input,select.form-input,input.form-input{font-size:16px}
}`;
  const st=document.createElement('style');st.id='css-celular';st.textContent=CSS;document.head.appendChild(st);

  const mq=window.matchMedia('(max-width:700px)');
  function marcar(){
    if(!mq.matches)return;
    document.querySelectorAll('#main-content table').forEach(t=>{
      if(t.closest('.no-cel'))return;
      const head=t.querySelector(':scope>thead>tr:last-child');if(!head)return;
      const lab=[];[...head.children].forEach(th=>{const n=+th.colSpan||1;for(let k=0;k<n;k++)lab.push(k?'':th.textContent.replace(/\s+/g,' ').trim());});
      t.classList.add('cel-t');
      t.querySelectorAll(':scope>tbody>tr,:scope>tfoot>tr').forEach(tr=>{
        if(tr.dataset.cel==='1')return;tr.dataset.cel='1';
        let i=0,tit=false;
        [...tr.children].forEach(td=>{
          const n=+td.colSpan||1,l=lab[i]||'';
          if(n>1&&tr.children.length===1){td.classList.add('cel-full');}
          else if(!l){td.classList.add(td.querySelector('button,a,.btn')?'cel-acao':'cel-full');}
          else if(!tit){td.classList.add('cel-tit');td.setAttribute('data-l',l);tit=true;}
          else td.setAttribute('data-l',l);
          i+=n;
        });
      });
    });
  }
  let tm=null;const agenda=()=>{clearTimeout(tm);tm=setTimeout(marcar,60);};
  const iniciar=()=>{marcar();new MutationObserver(agenda).observe(document.getElementById('main-content')||document.body,{childList:true,subtree:true});};
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',iniciar);else iniciar();
  (mq.addEventListener?mq.addEventListener('change',agenda):mq.addListener(agenda));
})();
