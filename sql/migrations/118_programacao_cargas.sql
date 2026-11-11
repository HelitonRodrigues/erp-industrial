-- 118 — Programação de Cargas (calendário de carregamento)
-- Junta a planilha CARREGAMENTOS (Google) e os Pedidos Disponíveis do Salescode.
-- Chave única = código do pedido (ex.: A01MRV): pedido nos dois lugares vira 1 registro só.
-- Data que vale: data_manual (arrastada no ERP) > data_planilha > data_salescode.

create table if not exists programacao_cargas (
  id                   uuid primary key default gen_random_uuid(),
  pedido               text not null unique,
  -- planilha
  em_planilha          boolean not null default false,
  data_planilha        date,
  planilha             jsonb,            -- linha da planilha como veio (cliente, cnpj, peso_t, material, embalagem, transp, obs, nota, preco)
  atualizado_planilha  timestamptz,
  -- salescode
  em_salescode         boolean not null default false,
  data_salescode       date,
  status_salescode     text,
  cliente_salescode    text,
  cidade               text,
  frete                text,
  salescode_view       text,
  itens                jsonb not null default '[]'::jsonb,   -- [{produto, qtd, unidade}]
  atualizado_salescode timestamptz,
  -- ERP
  data_manual          date,
  ordem_dia            integer,
  carregado            boolean not null default false,
  carregado_em         timestamptz,
  carregado_por        text,
  carregado_origem     text,             -- 'manual' | 'planilha' | 'salescode'
  carregado_manual     boolean not null default false,   -- usuário mexeu: sync não sobrescreve
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

create index if not exists programacao_cargas_carregado_idx on programacao_cargas (carregado);

alter table programacao_cargas enable row level security;
drop policy if exists baseline_authenticated_all on programacao_cargas;
create policy baseline_authenticated_all on programacao_cargas for all to authenticated using (true) with check (true);

-- Token das integrações (Apps Script da planilha / script do Salescode). Sem policy: só as funções abaixo leem.
-- Usuário logado no ERP (importar .xlsx na tela) não precisa de token.
create table if not exists integracao_tokens (
  nome  text primary key,
  token text not null default replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''),
  criado_em timestamptz not null default now()
);
alter table integracao_tokens enable row level security;
insert into integracao_tokens (nome) values ('programacao_cargas') on conflict do nothing;

create or replace function _prog_token_ok(p_token text) returns boolean
language sql security definer set search_path = public as $$
  select exists (select 1 from integracao_tokens where nome = 'programacao_cargas' and token = p_token);
$$;

-- dd/mm/aaaa ou aaaa-mm-dd -> date (vazio/errado = null)
create or replace function _prog_data(p text) returns date
language plpgsql immutable as $$
begin
  if p is null or btrim(p) = '' then return null; end if;
  if p ~ '^\d{4}-\d{2}-\d{2}' then return substr(p,1,10)::date; end if;
  if p ~ '^\d{1,2}/\d{1,2}/\d{4}' then return to_date(substring(p from '^\d{1,2}/\d{1,2}/\d{4}'), 'DD/MM/YYYY'); end if;
  return null;
exception when others then return null;
end $$;

-- ── SALESCODE ───────────────────────────────────────────────
-- p_itens: [{pedido, produto, cliente, cidade, frete, qtd:"40 TL", data:"10/11/2026", status, view}]
create or replace function sync_salescode(p_token text, p_itens jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare n_up int := 0; n_saiu int := 0;
begin
  if auth.uid() is null and not _prog_token_ok(p_token) then raise exception 'token inválido'; end if;
  if p_itens is null or jsonb_array_length(p_itens) < 5 then
    return jsonb_build_object('ok', false, 'motivo', 'lista vazia ou muito curta — nada alterado');
  end if;

  with src as (
    select btrim(x->>'pedido') pedido, x
    from jsonb_array_elements(p_itens) x
    where coalesce(btrim(x->>'pedido'),'') <> ''
  ), agg as (
    select pedido,
      jsonb_agg(jsonb_build_object(
        'produto', x->>'produto',
        'qtd', nullif(replace(replace(regexp_replace(coalesce(x->>'qtd',''), '[^0-9,\.]', '', 'g'), '.', ''), ',', '.'), '')::numeric,
        'unidade', upper(btrim(regexp_replace(coalesce(x->>'qtd',''), '[0-9,\.\s]', '', 'g')))
      )) itens,
      max(x->>'cliente') cliente, max(x->>'cidade') cidade, max(x->>'frete') frete,
      min(_prog_data(x->>'data')) data_sc,
      max(nullif(btrim(x->>'status'),'')) status, max(x->>'view') view
    from src group by pedido
  ), up as (
    insert into programacao_cargas as p (pedido, em_salescode, data_salescode, status_salescode, cliente_salescode, cidade, frete, salescode_view, itens, atualizado_salescode)
    select pedido, true, data_sc, status, cliente, cidade, frete, view, itens, now() from agg
    on conflict (pedido) do update set
      em_salescode = true, data_salescode = excluded.data_salescode,
      status_salescode = coalesce(excluded.status_salescode, p.status_salescode),
      cliente_salescode = excluded.cliente_salescode, cidade = excluded.cidade, frete = excluded.frete,
      salescode_view = excluded.salescode_view, itens = excluded.itens,
      atualizado_salescode = now(), updated_at = now()
    returning 1
  ) select count(*) into n_up from up;

  -- saiu da lista de pedidos disponíveis = faturado/cancelado no Salescode
  with saiu as (
    update programacao_cargas p set
      em_salescode = false,
      carregado = case when p.carregado_manual then p.carregado else true end,
      carregado_em = case when p.carregado_manual or p.carregado then p.carregado_em else now() end,
      carregado_origem = case when p.carregado_manual or p.carregado then p.carregado_origem else 'salescode' end,
      updated_at = now()
    where p.em_salescode
      and p.pedido not in (select btrim(x->>'pedido') from jsonb_array_elements(p_itens) x)
    returning 1
  ) select count(*) into n_saiu from saiu;

  return jsonb_build_object('ok', true, 'pedidos', n_up, 'sairam', n_saiu, 'em', now());
end $$;

-- ── PLANILHA ────────────────────────────────────────────────
-- p_linhas: [{pedido, data:"2026-11-12", cliente, cnpj, peso_t, nota, preco, material, embalagem, transp, obs, carregado:bool}]
create or replace function sync_planilha(p_token text, p_linhas jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare n_up int := 0; n_saiu int := 0;
begin
  if auth.uid() is null and not _prog_token_ok(p_token) then raise exception 'token inválido'; end if;
  if p_linhas is null or jsonb_array_length(p_linhas) < 3 then
    return jsonb_build_object('ok', false, 'motivo', 'planilha vazia ou muito curta — nada alterado');
  end if;

  with src as (
    select distinct on (btrim(x->>'pedido')) btrim(x->>'pedido') pedido, x
    from jsonb_array_elements(p_linhas) x
    where coalesce(btrim(x->>'pedido'),'') <> ''
    order by btrim(x->>'pedido'), _prog_data(x->>'data') desc nulls last
  ), up as (
    insert into programacao_cargas as p (pedido, em_planilha, data_planilha, planilha, atualizado_planilha, carregado, carregado_em, carregado_origem)
    select pedido, true, _prog_data(x->>'data'), x - 'pedido', now(),
           coalesce((x->>'carregado')::boolean, false),
           case when coalesce((x->>'carregado')::boolean, false) then now() end,
           case when coalesce((x->>'carregado')::boolean, false) then 'planilha' end
    from src
    on conflict (pedido) do update set
      em_planilha = true, data_planilha = excluded.data_planilha, planilha = excluded.planilha,
      atualizado_planilha = now(), updated_at = now(),
      carregado = case when p.carregado_manual then p.carregado else (p.carregado or excluded.carregado) end,
      carregado_em = case when not p.carregado_manual and not p.carregado and excluded.carregado then now() else p.carregado_em end,
      carregado_origem = case when not p.carregado_manual and not p.carregado and excluded.carregado then 'planilha' else p.carregado_origem end
    returning 1
  ) select count(*) into n_up from up;

  with saiu as (
    update programacao_cargas p set em_planilha = false, data_planilha = null, updated_at = now()
    where p.em_planilha and not p.carregado
      and p.pedido not in (select btrim(x->>'pedido') from jsonb_array_elements(p_linhas) x)
    returning 1
  ) select count(*) into n_saiu from saiu;

  return jsonb_build_object('ok', true, 'linhas', n_up, 'removidas', n_saiu, 'em', now());
end $$;

revoke all on function sync_salescode(text, jsonb) from public;
revoke all on function sync_planilha(text, jsonb) from public;
grant execute on function sync_salescode(text, jsonb) to anon, authenticated;
grant execute on function sync_planilha(text, jsonb) to anon, authenticated;
revoke all on function _prog_token_ok(text) from public, anon, authenticated;
