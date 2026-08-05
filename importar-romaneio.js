/* ============================================================
   importar-romaneio.js  —  hospedado no seu ERP (Vercel)
   Acionado pelo bookmarklet curtinho. Lê o romaneio aberto no
   salescode e envia para o Supabase. Robusto a ordens sem
   transportadora e a respostas vazias.
============================================================ */
(function(){
  var SB='https://zodgbitbflkepbszshmu.supabase.co';
  var KEY='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpvZGdiaXRiZmxrZXBic3pzaG11Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYwNjYwNjgsImV4cCI6MjA5MTY0MjA2OH0.iWROA5X7CkxOunt7Cn46wWODa7SQ5nU8OJcD52NhCgA';
  var O=document.getElementById('ordem');
  if(!O){alert('Abra a tela do "Romaneio de Embarque" do salescode (aguarde o quadro aparecer) e clique de novo.');return;}
  function txt(el){return el?el.textContent.replace(/\s+/g,' ').trim():'';}
  function val(label){
    var ds=O.querySelectorAll('div');
    for(var i=0;i<ds.length;i++){
      if(txt(ds[i]).toUpperCase()===label){
        var n=ds[i].nextElementSibling;
        while(n&&!/(^|\s)a(\s|$)/.test(n.className||'')) n=n.nextElementSibling;
        if(n) return txt(n);
      }
    }
    return '';
  }
  var rom={
    numero:(val('ROMANEIO')||'').replace(/[^0-9]/g,''),
    data_emissao:txt(O.querySelector('.col-xs-3.a')),
    transportadora:val('TRANSPORTADORA'),
    motorista:val('MOTORISTA'),
    placa:val('PLACA'),
    origem:'salescode'
  };
  if(!rom.numero){alert('Não encontrei o número do romaneio nesta tela.');return;}
  var itens=[];
  var trs=O.querySelectorAll('table tbody tr');
  for(var r=0;r<trs.length;r++){
    var td=trs[r].querySelectorAll('td');
    if(td.length<7) continue;
    itens.push({numero:rom.numero,pedido:txt(td[0]),cidade:txt(td[1]),cliente:txt(td[2]),produto:txt(td[3]),quantidade:txt(td[4]),caixa:txt(td[5]),lote:txt(td[6])});
  }
  var H={'apikey':KEY,'Authorization':'Bearer '+KEY,'Content-Type':'application/json'};
  function chk(r){ if(r.ok) return r.text(); return r.text().then(function(t){ throw new Error('HTTP '+r.status+' '+t); }); }
  // RPC única (SECURITY DEFINER) — com a chave anon, só é possível importar romaneio, nada mais.
  fetch(SB+'/rest/v1/rpc/importar_romaneio',{method:'POST',headers:H,body:JSON.stringify({rom:rom,itens:itens})})
    .then(chk)
    .then(function(t){
      var res=t?JSON.parse(t):{};
      var n=(res&&res.itens!=null)?res.itens:itens.length;
      alert('✅ Romaneio '+rom.numero+' importado!\n'+(rom.transportadora||rom.motorista||'')+'\n'+n+' item(ns).');
    })
    .catch(function(e){alert('❌ Erro ao importar: '+(e&&e.message?e.message:e));});
})();
