-- 045 — Desgaste: horímetro e produção puxados das OPs
-- Usado pelo desgaste.html (botão 🔄 e preenchimento automático ao informar as datas).
-- Regra = a dos lançamentos manuais:
--   horímetro inicial = último hf da linha antes da retirada (ou 1º hi do dia, se não houver anterior)
--   horímetro final   = último hf das OPs entre a retirada e a véspera da devolução
--   produção          = soma de total_sacos das OPs da retirada até a véspera da devolução
-- Só a sequência principal do horímetro (>= 85% do maior) — ignora o secundário da Linha 3.
-- Risco: baixo — só função nova, leitura.
create or replace function public.desgaste_puxar_producao(p_linha text, p_ret date, p_dev date default null)
returns jsonb language sql stable as $$
  with p as (
    select pr.data, (x->>'hi')::numeric hi, (x->>'hf')::numeric hf,
           coalesce(nullif(x->>'total_sacos','')::numeric,0) sc
      from producao pr, jsonb_array_elements(coalesce(pr.produtos_op,'[]'::jsonb)) x
     where pr.linha = p_linha and pr.data between p_ret - 20 and coalesce(p_dev, p_ret) + 3),
  mx as (select max(hf) m from p),
  pm as (select p.* from p, mx where p.hi >= mx.m*0.85 and p.hf >= p.hi)
  select jsonb_build_object(
    'hi', coalesce((select max(hf) from pm where data < p_ret),
                   (select min(hi) from pm where data between p_ret and p_ret + 3)),
    'hf', case when p_dev is null or p_dev <= p_ret then null else
             (select max(hf) from pm where data >= p_ret and data < p_dev) end,
    'sacos', case when p_dev is null or p_dev <= p_ret then null else
             (select sum(sc) from p where data >= p_ret and data < p_dev) end,
    'ops', (select count(*) from p where data >= p_ret and data < coalesce(p_dev, current_date + 1))
  );
$$;
notify pgrst, 'reload schema';
