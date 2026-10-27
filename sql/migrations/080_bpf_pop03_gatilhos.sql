-- 080 — BPF POP-03: REG-POP03-01 nasce em todos os momentos do item 7 do POP (aplicado direto no banco em 27/10/2026)
-- g_limpeza (diária, fim do expediente) + g_limp_lote (fim de cada lote) + g_limp_var (troca de variação na linha)
-- + g_limp_parada (parada não programada) + g_limp_manut (manutenção concluída na linha). Desde 26/10/2026.
-- Receitas de busca: GATILHO_FONTES em bpf.html. REG-POP03-01-000004 (teste manual de setembro) cancelado.
update bpf_gatilhos set evento='Fim do expediente (limpeza diária)', obs='POP-03, item 7: diária, ao final do expediente' where codigo='g_limpeza';
insert into bpf_gatilhos (codigo,pop_cod,formulario_cod,evento,fonte_tipo,fonte_tabela,periodicidade,prazo_horas,ativo,filtro,obs) values
 ('g_limp_lote','POP-03','REG-POP03-01','Fim de lote (cada lote da OP)','erp','producao','evento',2,true,'{"desde":"2026-10-26"}','POP-03, item 7: ao término de cada lote em produção'),
 ('g_limp_var','POP-03','REG-POP03-01','Troca de variação na linha','erp','producao','evento',2,true,'{"desde":"2026-10-26"}','POP-03, item 7: na troca de variação'),
 ('g_limp_parada','POP-03','REG-POP03-01','Parada não programada','erp','producao','evento',2,true,'{"desde":"2026-10-26"}','POP-03, item 7: após parada não programada'),
 ('g_limp_manut','POP-03','REG-POP03-01','Manutenção concluída na linha','erp','manutencao','evento',2,true,'{"desde":"2026-10-26"}','POP-03, item 7: após intervenção de manutenção na linha')
on conflict (codigo) do update set evento=excluded.evento, ativo=true, filtro=excluded.filtro, obs=excluded.obs;
