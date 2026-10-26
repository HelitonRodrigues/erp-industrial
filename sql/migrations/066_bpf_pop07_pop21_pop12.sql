-- 066 — BPF etapa 3: POP-07 (manutenção L2/LV com OS + limpeza pós-manutenção; calibração),
--                    POP-21 (perguntas antes/depois do carregamento), gatilhos
-- POP-07/001
update public.bpf_formularios set campos =
  jsonb_build_array(jsonb_build_object('id','os','tipo','texto','label','Nº da OS de manutenção','ajuda','Vem da Manutenção'))
  || (select jsonb_agg(case when c->>'id'='linha' then c || '{"opcoes":["Linha 2","Longa Vida"]}'::jsonb else c end order by o)
        from jsonb_array_elements(campos) with ordinality e(c,o))
  || jsonb_build_array(
       jsonb_build_object('id','sec_pos','tipo','secao','label','Pós-manutenção'),
       jsonb_build_object('id','limpo_pos','tipo','sim_nao','label','Equipamento e área limpos após a manutenção (sem graxa, peças, ferramentas ou resíduos)?','conforme','sim','obrigatorio',true),
       jsonb_build_object('id','liberado','tipo','sim_nao','label','Liberado para voltar a produzir?','conforme','sim','obrigatorio',true))
 where codigo='REG-POP07-01' and not exists (select 1 from jsonb_array_elements(campos) c where c->>'id'='os');

-- POP-07/002: faixa de uso do instrumento vem do cadastro (Instrumentos)
update public.bpf_formularios set campos = campos || jsonb_build_array(
    jsonb_build_object('id','faixa','tipo','texto','label','Faixa de uso do instrumento','ajuda','Vem do cadastro de Instrumentos'))
 where codigo='REG-POP07-02' and not exists (select 1 from jsonb_array_elements(campos) c where c->>'id'='faixa');

-- POP-21: perguntas separadas em ANTES e DEPOIS do carregamento
update public.bpf_formularios set campos = (
  select jsonb_agg(x order by ord) from (
    select c as x, o::numeric as ord from jsonb_array_elements(campos) with ordinality e(c,o)
    union all select jsonb_build_object('id','sec_antes','tipo','secao','label','ANTES do carregamento — inspeção do veículo'),
      (select o from jsonb_array_elements(campos) with ordinality e(c,o) where c->>'id'='limpo')-0.5
    union all select jsonb_build_object('id','sec_depois','tipo','secao','label','DEPOIS do carregamento — conferência da carga'),
      (select o from jsonb_array_elements(campos) with ordinality e(c,o) where c->>'id'='lona_saida')-0.5
    union all select jsonb_build_object('id','depois_integra','tipo','sim_nao','label','Sacaria / Big Bags íntegros, sem rasgo, sujeira ou contaminação?','conforme','sim','obrigatorio',true),
      (select o from jsonb_array_elements(campos) with ordinality e(c,o) where c->>'id'='lona_saida')+0.3
    union all select jsonb_build_object('id','depois_amarrada','tipo','sim_nao','label','Carga amarrada / travada e conferida com o romaneio?','conforme','sim','obrigatorio',true),
      (select o from jsonb_array_elements(campos) with ordinality e(c,o) where c->>'id'='lona_saida')+0.6
  ) z)
 where codigo='REG-POP21-01' and not exists (select 1 from jsonb_array_elements(campos) c where c->>'id'='sec_antes');

-- gatilhos: só do fluxo novo em diante
update public.bpf_gatilhos set filtro = coalesce(filtro,'{}'::jsonb) || '{"desde":"2026-10-26"}'::jsonb,
  evento='Manutenção da Linha 2 / Longa Vida (com a OS)' where codigo='g_manut';
update public.bpf_gatilhos set filtro = coalesce(filtro,'{}'::jsonb) || '{"desde":"2026-10-26"}'::jsonb,
  evento='Carregamento de caulim 25 kg / Big Bag (antes e depois)' where codigo='g_veiculo';
update public.bpf_gatilhos set ativo=true, fonte_tabela='bpf_instrumentos', filtro='{"desde":"2026-10-26"}'::jsonb,
  evento='Instrumento sem calibração ou vencendo em 60 dias' where codigo='g_calib';
