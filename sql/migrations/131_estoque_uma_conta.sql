-- 131 — Carregamento: uma conta de estoque no banco (15/11/2026)
-- * producao_pallets.sacos_pallet = sacos do pallet calculado NO BANCO, mesma ordem do capDoPallet:
--   1) cap da OP para este nº de pallet (mesmo produto)  2) cap única do produto na OP  3) cap do nº (qualquer produto)
--   4) cap única no cadastro (produtos.capacidades)       5) cap mais comum do produto na OP
--   Sem resposta → mantém o valor que já estava (ex.: informado na tela "Informar sacos/pallet").
-- * Gatilhos: pallet novo / troca de produto, nº ou OP; OP com produtos_op alterado recalcula os pallets dela.
-- * View estoque_atual_produto: estoque físico por produto (pallets com QR em estoque + saldo sem QR).
-- * estoque_conferencia: contagem física do "Movimento do dia" (antes ficava só no navegador).

-- norm_nome(text) já existe no banco (mesma regra do Regras.normalizarNome) — reaproveitada.

create or replace function _int_seguro(s text) returns int language sql immutable as $$
  select case when s ~ '^\s*-?\d+(\.\d+)?\s*$' then floor(s::numeric)::int else 0 end $$;

create or replace function op_mapa_cap(p_lanc uuid) returns table(n bigint, prod text, cap int) language sql stable as $$
  select row_number() over (order by a.o, b.o, gs), norm_nome(coalesce(a.pp->>'produto',a.pp->>'nome','')), _int_seguro(b.g->>'cap')
    from producao pr,
         jsonb_array_elements(case when jsonb_typeof(pr.produtos_op)='array' then pr.produtos_op else '[]'::jsonb end) with ordinality a(pp,o),
         jsonb_array_elements(case when jsonb_typeof(a.pp->'pallets')='array' then a.pp->'pallets' else '[]'::jsonb end) with ordinality b(g,o),
         generate_series(1, greatest(_int_seguro(b.g->>'qtd'),0)) gs
   where pr.id = p_lanc $$;

create or replace function pallet_sacos_calc(p_lanc uuid, p_numero int, p_produto text) returns int
language plpgsql stable as $$
declare m jsonb; a_cap int; a_prod text; v int; alvo text := norm_nome(p_produto);
begin
  if p_lanc is not null then
    select jsonb_agg(jsonb_build_object('n',x.n,'p',x.prod,'c',x.cap)) into m from op_mapa_cap(p_lanc) x;
  end if;
  if m is not null then
    select (e->>'c')::int, e->>'p' into a_cap, a_prod from jsonb_array_elements(m) e where (e->>'n')::int = p_numero;
    if a_cap > 0 and (a_prod = '' or a_prod = alvo) then return a_cap; end if;
    select case when count(distinct (e->>'c')::int)=1 then min((e->>'c')::int) end into v
      from jsonb_array_elements(m) e where e->>'p' = alvo and (e->>'c')::int > 0;
    if v > 0 then return v; end if;
    if a_cap > 0 then return a_cap; end if;
  end if;
  select case when count(distinct c)=1 then min(c) end into v
    from produtos pd, unnest(coalesce(pd.capacidades,'{}'::int[])) c where norm_nome(pd.nome) = alvo and c > 0;
  if v > 0 then return v; end if;
  if m is not null then
    select (e->>'c')::int into v from jsonb_array_elements(m) e where e->>'p' = alvo and (e->>'c')::int > 0
     group by (e->>'c')::int order by count(*) desc, (e->>'c')::int desc limit 1;
    if v > 0 then return v; end if;
  end if;
  return null;
end $$;

alter table producao_pallets add column if not exists sacos_pallet int;

create or replace function tg_pallet_sacos() returns trigger language plpgsql as $$
begin
  new.sacos_pallet := coalesce(pallet_sacos_calc(new.lancamento_id, new.numero, new.produto), new.sacos_pallet);
  return new;
end $$;
drop trigger if exists tg_pallet_sacos on producao_pallets;
create trigger tg_pallet_sacos before insert or update of produto, numero, lancamento_id on producao_pallets
  for each row execute function tg_pallet_sacos();

create or replace function tg_op_recalc_sacos() returns trigger language plpgsql as $$
begin
  update producao_pallets p set sacos_pallet = coalesce(pallet_sacos_calc(p.lancamento_id, p.numero, p.produto), p.sacos_pallet)
   where p.lancamento_id = new.id;
  return null;
end $$;
drop trigger if exists tg_op_recalc_sacos on producao;
create trigger tg_op_recalc_sacos after update of produtos_op on producao
  for each row when (old.produtos_op is distinct from new.produtos_op) execute function tg_op_recalc_sacos();

-- backfill
update producao_pallets p set sacos_pallet = pallet_sacos_calc(p.lancamento_id, p.numero, p.produto) where p.sacos_pallet is null;

-- estoque físico por produto (sacos; granel fica fora — tem saldo próprio em t)
create or replace view estoque_atual_produto with (security_invoker=true) as
  with q as (
    select p.produto,
           case when lower(coalesce(p.status,'pendente'))='aprovado' then 'liberado'
                when lower(coalesce(p.status,'pendente')) in ('reprovado','aguardando_decisao') then 'bloqueado'
                else 'analise' end sit,
           greatest(coalesce(p.sacos_pallet,0) - coalesce(p.sacos_retirados,0), 0) sacos,
           (p.sacos_pallet is null) sem_cap
      from producao_pallets p
     where coalesce(p.estoque_status,'estoque') = 'estoque' and p.fora_estoque_em is null
       and p.produto not ilike '%granel%')
  select coalesce(a.produto, s.produto) produto,
         coalesce(a.liberado_sc,0) liberado_sc, coalesce(a.liberado_pal,0) liberado_pal,
         coalesce(a.analise_sc,0) analise_sc, coalesce(a.analise_pal,0) analise_pal,
         coalesce(a.bloqueado_sc,0) bloqueado_sc, coalesce(a.bloqueado_pal,0) bloqueado_pal,
         coalesce(a.sem_cap,0) pallets_sem_capacidade,
         coalesce(s.saldo,0) sem_qr_sc,
         coalesce(a.liberado_sc,0)+coalesce(a.analise_sc,0)+coalesce(a.bloqueado_sc,0)+coalesce(s.saldo,0) fisico_sc
    from (select produto,
                 sum(sacos) filter (where sit='liberado') liberado_sc, count(*) filter (where sit='liberado') liberado_pal,
                 sum(sacos) filter (where sit='analise') analise_sc, count(*) filter (where sit='analise') analise_pal,
                 sum(sacos) filter (where sit='bloqueado') bloqueado_sc, count(*) filter (where sit='bloqueado') bloqueado_pal,
                 count(*) filter (where sem_cap) sem_cap
            from q group by produto) a
    full join (select produto, saldo from estoque_sem_qr_saldo where produto not ilike '%granel%' and saldo <> 0) s
      on norm_nome(s.produto) = norm_nome(a.produto);
grant select on estoque_atual_produto to authenticated;

-- contagem física do Movimento do dia
create table if not exists estoque_conferencia (
  dia date not null, produto text not null, contagem numeric not null,
  contado_por text, contado_em timestamptz not null default now(),
  primary key (dia, produto));
alter table estoque_conferencia enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where tablename='estoque_conferencia' and policyname='baseline_authenticated_all') then
    create policy baseline_authenticated_all on estoque_conferencia for all to authenticated using (true) with check (true);
  end if; end $$;
