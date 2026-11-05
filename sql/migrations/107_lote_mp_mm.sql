-- 107 · M.M (material mineral) passa a ser do LOTE DE MP (nov/2026) — já aplicado no banco
-- Limites por Produto deixa de ter o campo; o mínimo do lote de MP mais novo da variação
-- vai para lab_produto_qualidade.limite_mm_min dos produtos dessa variação (feito pela tela, ao salvar o lote).
alter table public.caulim_lotes_mp add column if not exists mm_min numeric, add column if not exists mm_result numeric;
-- lotes existentes herdaram o mínimo que estava nos produtos da mesma variação (95 %)
update caulim_lotes_mp l set mm_min = s.v
from (select l2.id, max(q.limite_mm_min) v from caulim_lotes_mp l2 join lab_produto_qualidade q
        on (q.variacao_id = l2.variacao_declarada_id or q.produto_id = l2.produto_id)
       where q.limite_mm_min is not null and not (coalesce(q.nao_se_aplica,'[]'::jsonb) ? 'mm') group by l2.id) s
where s.id = l.id and l.mm_min is null;
