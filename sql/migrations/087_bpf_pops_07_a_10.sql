-- 087 — BPF POPs 07 a 10 (aplicado direto no banco em 28/10/2026) — tudo desde a vigência (05/08/2026), em "A preencher"
-- POP-07: g_manut (REG-POP07-01 por OS) · g_verif07 (REG-POP07-02: início de cada turno, por balança) · g_calib (anual)
-- POP-08: g_pragas (REG-POP08-01 mensal) · POP-09: g_residuo (REG-POP09-01 diário) · g_fossa (REG-POP09-02 mensal)
-- POP-10: g_rastro (REG-POP10-01 por lote). Receitas em bpf.html (GATILHO_FONTES).
insert into bpf_gatilhos (codigo,pop_cod,formulario_cod,evento,fonte_tipo,fonte_tabela,periodicidade,prazo_horas,ativo,filtro,obs) values
 ('g_verif07','POP-07','REG-POP07-02','Início de cada turno de produção (verificação com peso-padrão por balança)','erp','producao','evento',8,true,'{}','POP-07, item 7: início de cada turno')
on conflict (codigo) do update set ativo=true, evento=excluded.evento, obs=excluded.obs;
update bpf_gatilhos set ativo=true, filtro='{}' where codigo in ('g_manut','g_calib','g_pragas','g_residuo','g_fossa','g_rastro');
update bpf_registros set campos=campos||'{"tipo":"Calibração externa"}' where formulario_cod='REG-POP07-02' and campos->>'tipo'='calibracao';
update bpf_registros set status='a_preencher', ficha_impressa_em=null, lancado_em=null, lancado_por=null, foto_ficha=null,
       assinaturas='[]'::jsonb, assinaturas_papel='{}'::jsonb, atualizado_em=now()
 where pop_cod in ('POP-07','POP-08','POP-09','POP-10') and cancelado_em is null and status not in ('concluido','cancelado');
