/* ═══════════════════════════════════════════════════════════════════
   js/balanca.js — leitura direta do indicador de pesagem da portaria
   (Weightech WT3000-i → serial → USB no PC da portaria), pelo próprio navegador
   (Web Serial: Chrome/Edge no computador). No celular não aparece nada.

   • Indicador em transmissão contínua, 9600 8N1, linha tipo:  "ST,GS,+  21200  kg"
       ST = estável · US = em movimento · GS = bruto · NT = líquido · sinal · valor · unidade
   • Só UMA aba consegue abrir a porta. A primeira aba aberta vira a "dona" da porta
     (Web Locks) e repassa o peso para as outras abas do mesmo PC (BroadcastChannel).
     Fechou a aba dona? A próxima assume sozinha.
   • A primeira vez em cada PC alguém toca em "🔌 Conectar balança" e escolhe a porta COM;
     depois o navegador lembra e conecta sozinho.
   • Ao lado dos campos de peso aparece o peso ao vivo + "⚖️ Usar peso da balança".
     O porteiro ainda pode digitar (balança fora do ar não trava a portaria).
   ═══════════════════════════════════════════════════════════════════ */
(function(){
  const TEM=('serial' in navigator)&&!!window.BroadcastChannel;
  const CANAL='erp-balanca',LOCK='erp-balanca-porta';
  const CFG={baudRate:9600,dataBits:8,parity:'none',stopBits:1,bufferSize:4096};
  let lido=null;            // {kg, estavel, liquido, ts}
  let estado=TEM?'iniciando':'sem-suporte';   // iniciando | sem-porta | lendo | sem-sinal | erro | sem-suporte
  let erroMsg='';
  let lider=false,porta=null,leitor=null,abrindo=false;
  const ouvintes=new Set();
  const bc=TEM?new BroadcastChannel(CANAL):null;

  const avisa=()=>ouvintes.forEach(f=>{try{f(lido,estado);}catch(e){}});
  const setEstado=(e,m)=>{estado=e;erroMsg=m||'';if(lider&&bc)bc.postMessage({t:'estado',estado,erroMsg});avisa();};

  /* "ST,GS,+  21200  kg" → {kg:21200, estavel:true, liquido:false} */
  function interpretar(l){
    const m=String(l).match(/(ST|US|OL)\s*,\s*(GS|NT|TR)\s*,\s*([+-])\s*([\d.,]+)\s*(kg|t|g)?/i);
    if(!m)return null;
    let v=Number(m[4].replace(',','.'));if(!isFinite(v))return null;
    const u=(m[5]||'kg').toLowerCase();if(u==='t')v*=1000;if(u==='g')v/=1000;
    if(m[3]==='-')v=-v;
    return {kg:Math.round(v*1000)/1000,estavel:m[1].toUpperCase()==='ST',liquido:m[2].toUpperCase()==='NT',sobrecarga:m[1].toUpperCase()==='OL',ts:Date.now()};
  }

  async function abrirEler(){
    if(!lider||abrindo||porta)return;
    abrindo=true;
    try{
      const ps=await navigator.serial.getPorts();
      if(!ps.length){setEstado('sem-porta');return;}
      porta=ps[0];
      await porta.open(CFG);
      setEstado('lendo');
      const dec=new TextDecoder();let buf='';
      while(porta&&porta.readable){
        leitor=porta.readable.getReader();
        try{
          for(;;){const {value,done}=await leitor.read();if(done)break;
            buf+=dec.decode(value,{stream:true});
            const partes=buf.split(/\r?\n|\r/);buf=partes.pop();if(buf.length>500)buf='';
            for(const p of partes){const r=interpretar(p);if(r){lido=r;if(estado!=='lendo')setEstado('lendo');bc.postMessage({t:'peso',r});avisa();}}
          }
        }finally{try{leitor.releaseLock();}catch(e){}}
      }
    }catch(e){
      const m=String(e&&e.message||e);
      setEstado('erro',/open/i.test(m)?'A porta da balança está em uso por outro programa (ou outra aba fora do ERP). Feche e tente de novo.':m);
    }finally{
      try{if(porta)await porta.close();}catch(e){}
      porta=null;leitor=null;abrindo=false;
      if(lider)setTimeout(abrirEler,4000);   // cabo caiu / porta ocupada → tenta de novo
    }
  }

  if(TEM){
    bc.onmessage=ev=>{const d=ev.data||{};
      if(d.t==='peso'){lido=d.r;if(estado!=='lendo'){estado='lendo';}avisa();}
      else if(d.t==='estado'&&!lider){estado=d.estado;erroMsg=d.erroMsg||'';avisa();}
      else if(d.t==='ping'&&lider){bc.postMessage({t:'estado',estado,erroMsg});if(lido)bc.postMessage({t:'peso',r:lido});}
      else if(d.t==='tentar'&&lider){abrirEler();}
    };
    if(navigator.locks){
      navigator.locks.request(LOCK,{mode:'exclusive'},()=>{lider=true;abrirEler();return new Promise(()=>{});});
      setTimeout(()=>{if(!lider)bc.postMessage({t:'ping'});},300);
    }else{lider=true;abrirEler();}
    navigator.serial.addEventListener('connect',()=>{if(lider)abrirEler();else bc.postMessage({t:'tentar'});});
    // sem leitura nova há 3 s → "sem sinal"
    setInterval(()=>{if(estado==='lendo'&&(!lido||Date.now()-lido.ts>3000)){estado='sem-sinal';avisa();}
      else if(estado==='sem-sinal'&&lido&&Date.now()-lido.ts<=3000){estado='lendo';avisa();}},1000);
  }

  /* precisa de um toque do usuário (o navegador pede para escolher a porta COM) */
  async function conectar(){
    if(!TEM)return;
    try{await navigator.serial.requestPort();}catch(e){return;}
    if(lider)abrirEler();else bc.postMessage({t:'tentar'});
  }

  /* ── quadrinho ao lado do campo de peso ── */
  const CSS=`.bal-w{display:flex;align-items:center;gap:10px;flex-wrap:wrap;margin-top:8px;padding:8px 10px;border-radius:12px;border:1.5px solid #e2e8f0;background:#f8fafc;font-family:inherit}
  .bal-w .bal-v{font-size:22px;font-weight:900;color:#042D4D;font-variant-numeric:tabular-nums;min-width:120px}
  .bal-w .bal-s{font-size:11px;font-weight:800;border-radius:99px;padding:3px 9px;background:#fef3c7;color:#92400e}
  .bal-w .bal-s.ok{background:#dcfce7;color:#166534}.bal-w .bal-s.off{background:#f1f5f9;color:#64748b}.bal-w .bal-s.er{background:#fee2e2;color:#991b1b}
  .bal-w button{margin-left:auto;border:0;border-radius:10px;padding:10px 14px;font-family:inherit;font-weight:800;font-size:14px;cursor:pointer;background:#16a34a;color:#fff;white-space:nowrap}
  .bal-w button:disabled{background:#cbd5e1;color:#64748b;cursor:default}
  .bal-w button.cx{background:#042D4D;color:#d9f99d}
  .bal-w .bal-m{flex-basis:100%;font-size:12px;color:#991b1b}`;
  function css(){if(document.getElementById('css-balanca'))return;const s=document.createElement('style');s.id='css-balanca';s.textContent=CSS;document.head.appendChild(s);}
  const fmt=(kg,t)=>t?(kg/1000).toLocaleString('pt-BR',{minimumFractionDigits:3,maximumFractionDigits:3}):Math.round(kg).toLocaleString('pt-BR');

  function widget(inp,emT){
    if(!TEM||!inp||inp.dataset.bal)return;
    inp.dataset.bal='1';css();
    const w=document.createElement('div');w.className='bal-w';
    const par=inp.parentElement;
    if(par&&getComputedStyle(par).display.includes('flex')&&par.children.length>1)par.after(w);else inp.after(w);
    w.innerHTML='<span style="font-size:18px;">⚖️</span><span class="bal-v">—</span><span class="bal-s off"></span><button type="button"></button><div class="bal-m" style="display:none;"></div>';
    const eV=w.querySelector('.bal-v'),eS=w.querySelector('.bal-s'),b=w.querySelector('button'),eM=w.querySelector('.bal-m');
    b.onclick=()=>{
      if(b.dataset.m==='cx'){conectar();return;}
      if(!lido||!lido.estavel||lido.kg<=0||Date.now()-lido.ts>3000)return;
      inp.value=emT?(inp.type==='number'?(lido.kg/1000).toFixed(3):fmt(lido.kg,true)):String(Math.round(lido.kg));   // campo numérico usa ponto
      inp.dataset.balKg=String(lido.kg);
      inp.dispatchEvent(new Event('input',{bubbles:true}));inp.dispatchEvent(new Event('change',{bubbles:true}));
      inp.focus();
    };
    const pinta=()=>{
      if(!w.isConnected){ouvintes.delete(pinta);return;}
      const fresco=lido&&Date.now()-lido.ts<3000;
      let v='—',st='',cls='off',modo='',dis=true,msg='';
      if(estado==='sem-porta'){st='balança não conectada';modo='cx';dis=false;}
      else if(estado==='erro'){st='erro na balança';cls='er';msg=erroMsg;modo='cx';dis=false;}
      else if(estado==='iniciando'){st='procurando a balança…';}
      else if(!fresco){st='balança sem sinal';cls='er';}
      else{v=fmt(lido.kg,emT)+(emT?' t':' kg');modo='usa';
        if(lido.sobrecarga){st='SOBRECARGA';cls='er';}
        else if(!lido.estavel){st='em movimento…';cls='';}
        else if(lido.kg<=0){st='balança vazia';}
        else{st='ESTÁVEL'+(lido.liquido?' · líquido':'');cls='ok';dis=false;}}
      eV.textContent=v;eS.textContent=st;eS.className='bal-s '+cls;
      b.style.display=modo?'':'none';b.dataset.m=modo;b.className=modo==='cx'?'cx':'';
      b.textContent=modo==='cx'?'🔌 Conectar balança':'⚖️ Usar peso da balança';b.disabled=dis;
      eM.style.display=msg?'':'none';eM.textContent=msg;
    };
    ouvintes.add(pinta);pinta();
  }

  /* liga o quadrinho em todo campo da lista assim que ele aparece na tela (janelas fixas ou criadas na hora) */
  let campos={};
  function procurar(){for(const id in campos){const e=document.getElementById(id);if(e&&!e.dataset.bal)widget(e,campos[id]==='t');}}
  function ligar(mapa){
    if(!TEM)return;campos=Object.assign(campos,mapa||{});procurar();
    let tm=null;new MutationObserver(()=>{clearTimeout(tm);tm=setTimeout(procurar,80);}).observe(document.body,{childList:true,subtree:true});
  }

  window.Balanca={ligar,conectar,widget,on:f=>{ouvintes.add(f);return ()=>ouvintes.delete(f);},atual:()=>lido,estado:()=>estado,interpretar,suportado:TEM};
})();
