-- 064 — BPF: fichas automáticas a partir da OP (POP-13, 14 e 18) + ajustes dos formulários
-- Os gatilhos destes POPs liam caulim_lotes_producao (vazia) e por isso nunca disparavam.
-- Agora nascem da OP (tabela producao), só de 26/10/2026 em diante.

update public.bpf_gatilhos set fonte_tabela='producao', ativo=true, filtro='{"desde":"2026-10-26"}'::jsonb,
  evento='OP de nutrição animal lançada (uma ficha por OP, com todos os lotes)'
 where codigo='g_lote_prod';
update public.bpf_gatilhos set fonte_tabela='producao', ativo=true, filtro='{"desde":"2026-10-26"}'::jsonb,
  evento='OP de nutrição animal lançada (uma ficha por lote produzido)'
 where codigo='g_amostra';
update public.bpf_gatilhos set fonte_tabela='producao', ativo=true, filtro='{"desde":"2026-10-26"}'::jsonb,
  evento='OP de nutrição animal lançada (uma ficha por lote; balança e calibração automáticas)'
 where codigo='g_ensaque';
-- POP-02 passa a nascer no próprio laboratório (já lançado e assinado por quem analisou)
update public.bpf_gatilhos set ativo=false, obs='Desligado: o registro REG-POP02-01 é criado pelo laboratorio.html ao salvar o lote de MP.'
 where codigo='g_lote_mp';

-- campo "OP" no topo das fichas que nascem da OP
update public.bpf_formularios
   set campos = jsonb_build_array(jsonb_build_object('id','op','tipo','texto','label','OP','ajuda','Vem da ordem de produção')) || campos
 where codigo in ('REG-POP13-01','REG-POP14-01','REG-POP18-01')
   and not exists (select 1 from jsonb_array_elements(campos) c where c->>'id'='op');

-- POP-13: sai tudo da "Homologação" para baixo (fica Observações)
update public.bpf_formularios
   set campos = (select jsonb_agg(c order by o) from jsonb_array_elements(campos) with ordinality e(c,o)
                  where c->>'id' not in ('homologacao','rotulo_aprovado','gatilho_fechamento','estrategia'))
 where codigo='REG-POP13-01';

-- POP-14: sai "Contraprova" e "Amostras identificadas"; quantidade = nº de amostras × 400 g (automática)
update public.bpf_formularios
   set campos = (select jsonb_agg(
                    case when c->>'id'='quantidade_g'
                         then c || '{"calc":"amostras*400","label":"Quantidade coletada (automático: nº de amostras × 400 g)","ajuda":"Calculada pelo sistema"}'::jsonb
                         else c end
                    order by case when c->>'id'='amostras' then 6.5 else o end)
                 from jsonb_array_elements(campos) with ordinality e(c,o)
                 where c->>'id' not in ('contraprova','identificadas'))
 where codigo='REG-POP14-01';
