-- 008 — Fechamento Diário automático (Etapa 4)
--
-- Substitui a montagem manual do PDF "FECHAMENTO DIÁRIO DA FÁBRICA".
-- Uma chamada — rpc_fechamento_dia(data) — devolve o relatório completo:
--
--   • ESTOQUE DE PRODUTO ACABADO por produto:
--       produção do dia   = produtos_op das OPs do dia
--       em análise        = produção acumulada de OPs ainda com status 'em_analise'
--       carregado no dia  = itens das cargas do dia (carregamentos)
--       estoque total     = ajustes + produção acumulada − carregado acumulado
--       estoque liberado  = estoque total − em análise
--   • ESTOQUE DE INSUMOS na data (saldo do ledger até a data) com mínimo
--     e status Comprar/OK — igual à segunda seção do PDF.
--
-- pa_ajustes é o "acerto de estoque" do produto acabado (carga inicial e
-- inventários futuros): mesmo papel dos ajustes de insumos, com data, autor
-- e motivo. Começa vazia — o estoque inicial de PA entra quando o Heliton
-- fizer a contagem física (os números do sistema até lá refletem apenas o
-- que foi produzido e carregado DENTRO do ERP).

create table if not exists public.pa_ajustes (
  id          uuid primary key default gen_random_uuid(),
  data        date not null default current_date,
  produto     text not null,
  sacos       numeric not null,
  motivo      text,
  responsavel text,
  obs         text,
  criado_em   timestamptz default now()
);
alter table public.pa_ajustes enable row level security;
do $$ begin
  create policy baseline_authenticated_all on public.pa_ajustes
    for all to authenticated using (true) with check (true);
exception when duplicate_object then null; end $$;

create or replace function public.rpc_fechamento_dia(p_data date default current_date)
returns jsonb
language sql stable
set search_path = public
as $$
with prod as (
  select norm_nome(item->>'produto') as k,
         max(item->>'produto') as nome,
         sum(coalesce(nullif(item->>'total_sacos','')::numeric,
                      nullif(item->>'sacos_pallets','')::numeric,0))
             filter (where pr.data = p_data) as prod_dia,
         sum(coalesce(nullif(item->>'total_sacos','')::numeric,
                      nullif(item->>'sacos_pallets','')::numeric,0)) as prod_acum,
         sum(coalesce(nullif(item->>'total_sacos','')::numeric,
                      nullif(item->>'sacos_pallets','')::numeric,0))
             filter (where pr.status = 'em_analise') as em_analise
  from producao pr
  cross join lateral jsonb_array_elements(coalesce(pr.produtos_op,'[]'::jsonb)) item
  where pr.data <= p_data
  group by 1),
carr as (
  select norm_nome(it->>'produto') as k,
         max(it->>'produto') as nome,
         sum(coalesce((it->>'sacos')::numeric,0)) filter (where c.data = p_data) as carr_dia,
         sum(coalesce((it->>'sacos')::numeric,0)) as carr_acum
  from carregamentos c
  cross join lateral jsonb_array_elements(coalesce(c.itens,'[]'::jsonb)) it
  where c.data <= p_data
  group by 1),
aj as (
  select norm_nome(produto) as k, sum(sacos) as sacos
  from pa_ajustes where data <= p_data group by 1),
base as (
  select coalesce(p.k, c.k, a.k) as k,
         coalesce(
           (select pd.nome from produtos pd
             where norm_nome(pd.nome) = coalesce(p.k, c.k, a.k) limit 1),
           p.nome, c.nome, coalesce(p.k, c.k, a.k)) as nome,
         coalesce(p.prod_dia,0)   as producao_dia,
         coalesce(p.em_analise,0) as em_analise,
         coalesce(c.carr_dia,0)   as carregado_dia,
         coalesce(a.sacos,0) + coalesce(p.prod_acum,0) - coalesce(c.carr_acum,0) as estoque_total
  from prod p
  full join carr c on c.k = p.k
  full join aj a on a.k = coalesce(p.k, c.k))
select jsonb_build_object(
  'data', p_data,
  'produtos', coalesce((
     select jsonb_agg(jsonb_build_object(
       'produto', nome,
       'producao_dia', producao_dia,
       'em_analise', em_analise,
       'carregado_dia', carregado_dia,
       'estoque_total', estoque_total,
       'estoque_liberado', estoque_total - em_analise
     ) order by nome) from base), '[]'::jsonb),
  'totais', (select jsonb_build_object(
       'producao_dia', coalesce(sum(producao_dia),0),
       'em_analise', coalesce(sum(em_analise),0),
       'carregado_dia', coalesce(sum(carregado_dia),0),
       'estoque_total', coalesce(sum(estoque_total),0),
       'estoque_liberado', coalesce(sum(estoque_total - em_analise),0)
     ) from base),
  'insumos', coalesce((
     select jsonb_agg(jsonb_build_object(
       'nome', i.nome,
       'grupo', i.grupo,
       'unidade', i.unidade_estoque,
       'saldo', s.saldo,
       'minimo', coalesce(i.estoque_minimo,0),
       'status', case when s.saldo <= 0 or (coalesce(i.estoque_minimo,0) > 0 and s.saldo <= i.estoque_minimo)
                      then 'Comprar' else 'OK' end
     ) order by i.grupo, i.nome)
     from insumos i
     cross join lateral (
       select coalesce(sum(case m.tipo
         when 'entrada' then m.quantidade when 'devolucao' then m.quantidade
         when 'retorno' then m.quantidade when 'ajuste' then m.quantidade
         when 'consumo' then -m.quantidade when 'perda' then -m.quantidade
         when 'saida' then -m.quantidade else 0 end),0) as saldo
       from insumos_movimentos m
       where m.insumo_id = i.id and m.data <= p_data) s
     where coalesce(i.status,'ativo') <> 'inativo'), '[]'::jsonb)
);
$$;
