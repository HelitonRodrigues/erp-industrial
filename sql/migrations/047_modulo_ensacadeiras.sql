-- 047 — Módulo Ensacadeiras (pesagem saco a saco, Linha 3)
--
-- Um coletor no PC da linha (Node.js puro, sem Node-RED) lê o indicador de peso
-- por Modbus TCP, captura o peso de cada saco quando o SP1 liga e envia para cá.
-- O coletor NÃO tem login de usuário: ele chama a RPC ensacadeira_enviar com um
-- token próprio (só o hash fica no banco). Anon não lê nem grava as tabelas
-- direto — segue a baseline do item 1 (authenticated pode tudo, anon nada).
--
-- Risco: baixo — só tabelas e funções novas. Nenhuma tabela existente muda.
-- (Tabelas ensacadeira_sacos/_status já criadas em 2026-10-08; aqui com IF NOT EXISTS.)

-- ── 1. Sacos: um registro por saco capturado ─────────────────────────────
create table if not exists public.ensacadeira_sacos (
  id            bigint generated always as identity primary key,
  evento_id     text not null unique,               -- idempotência: reenvio não duplica
  linha_id      uuid references public.linhas_producao(id),
  linha_nome    text not null,
  bico          smallint not null check (bico between 1 and 8),
  peso_kg       numeric(7,3) not null,
  nominal_kg    numeric(6,2),
  metodo        text,                               -- 'estavel' | 'tempo'
  ciclo         integer,
  tempo_ms      integer,                            -- SP1 → captura
  produto       text,
  origem        text not null default 'coletor',
  capturado_em  timestamptz not null default now(),
  criado_em     timestamptz not null default now()
);
alter table public.ensacadeira_sacos alter column origem set default 'coletor';
create index if not exists ensacadeira_sacos_linha_data_idx on public.ensacadeira_sacos (linha_id, capturado_em desc);
create index if not exists ensacadeira_sacos_data_idx on public.ensacadeira_sacos (capturado_em desc);

-- ── 2. Status ao vivo de cada bico (upsert ~1 s pelo coletor) ─────────────
create table if not exists public.ensacadeira_status (
  linha_id        uuid not null references public.linhas_producao(id),
  bico            smallint not null,
  linha_nome      text not null,
  peso_kg         numeric(7,3),
  estavel         boolean,
  sp1             boolean,
  sp2             boolean,
  sp3             boolean,
  etapa           text,
  contador        integer,
  ultimo_peso_kg  numeric(7,3),
  ultimo_em       timestamptz,
  atualizado_em   timestamptz not null default now(),
  primary key (linha_id, bico)
);
alter table public.ensacadeira_status add column if not exists online boolean not null default true;
alter table public.ensacadeira_status add column if not exists erro text;

-- ── 3. Tolerância por peso nominal (editável na aba Configuração) ─────────
create table if not exists public.ensacadeira_tolerancias (
  nominal_kg    numeric(6,2) primary key,
  tol_abaixo_kg numeric(6,3) not null default 0.15 check (tol_abaixo_kg >= 0),
  tol_acima_kg  numeric(6,3) not null default 0.25 check (tol_acima_kg >= 0),
  atualizado_em timestamptz not null default now()
);
insert into public.ensacadeira_tolerancias (nominal_kg, tol_abaixo_kg, tol_acima_kg) values
  (10, 0.15, 0.20), (20, 0.20, 0.30), (25, 0.25, 0.35)
on conflict (nominal_kg) do nothing;

-- ── 4. Coletores (PC da linha). Só o hash do token. Sem policy = ninguém lê ──
create table if not exists public.ensacadeira_coletores (
  id              uuid primary key default gen_random_uuid(),
  nome            text not null,
  linha_id        uuid not null references public.linhas_producao(id),
  token_hash      text not null unique,             -- sha256 hex do token
  ativo           boolean not null default true,
  ultimo_contato  timestamptz,
  versao          text,
  criado_em       timestamptz not null default now()
);

-- ── 5. RLS: baseline (authenticated tudo, anon nada) ──────────────────────
alter table public.ensacadeira_sacos       enable row level security;
alter table public.ensacadeira_status      enable row level security;
alter table public.ensacadeira_tolerancias enable row level security;
alter table public.ensacadeira_coletores   enable row level security;

-- Policies provisórias da 1ª versão (2026-10-08) davam acesso ao anon: tiradas do anon.
-- (podem ser apagadas depois — a baseline abaixo já cobre o authenticated)
do $$ begin
  if exists (select 1 from pg_policies where tablename='ensacadeira_sacos' and policyname='ens_sacos_select') then
    alter policy ens_sacos_select  on public.ensacadeira_sacos  to authenticated;
    alter policy ens_sacos_insert  on public.ensacadeira_sacos  to authenticated;
    alter policy ens_status_select on public.ensacadeira_status to authenticated;
    alter policy ens_status_insert on public.ensacadeira_status to authenticated;
    alter policy ens_status_update on public.ensacadeira_status to authenticated;
  end if;
end $$;

do $$ begin
  if not exists (select 1 from pg_policies where tablename='ensacadeira_sacos' and policyname='baseline_authenticated_all') then
    create policy baseline_authenticated_all on public.ensacadeira_sacos for all to authenticated using (true) with check (true); end if;
  if not exists (select 1 from pg_policies where tablename='ensacadeira_status' and policyname='baseline_authenticated_all') then
    create policy baseline_authenticated_all on public.ensacadeira_status for all to authenticated using (true) with check (true); end if;
  if not exists (select 1 from pg_policies where tablename='ensacadeira_tolerancias' and policyname='baseline_authenticated_all') then
    create policy baseline_authenticated_all on public.ensacadeira_tolerancias for all to authenticated using (true) with check (true); end if;
  -- ensacadeira_coletores: sem policy de propósito (token só via função SECURITY DEFINER)
end $$;

-- ── 6. RPC do coletor ─────────────────────────────────────────────────────
-- p_sacos  = [{evento_id,bico,peso_kg,nominal_kg,metodo,ciclo,tempo_ms,capturado_em}]
-- p_status = [{bico,peso_kg,estavel,sp1,sp2,sp3,etapa,contador,ultimo_peso_kg,ultimo_em,online,erro}]
create or replace function public.ensacadeira_enviar(p_token text, p_sacos jsonb default '[]'::jsonb,
                                                     p_status jsonb default '[]'::jsonb, p_versao text default null)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_col   public.ensacadeira_coletores%rowtype;
  v_linha text;
  v_ins   integer := 0;
begin
  select * into v_col from public.ensacadeira_coletores
   where token_hash = encode(extensions.digest(coalesce(p_token,''), 'sha256'), 'hex') and ativo;
  if not found then
    raise exception 'coletor não autorizado' using errcode = '28000';
  end if;
  select nome into v_linha from public.linhas_producao where id = v_col.linha_id;

  if jsonb_typeof(p_sacos) = 'array' and jsonb_array_length(p_sacos) > 0 then
    if jsonb_array_length(p_sacos) > 1000 then raise exception 'lote grande demais (máx. 1000)'; end if;
    insert into public.ensacadeira_sacos (evento_id, linha_id, linha_nome, bico, peso_kg, nominal_kg, metodo, ciclo, tempo_ms, origem, capturado_em)
    select s->>'evento_id', v_col.linha_id, v_linha, (s->>'bico')::smallint, (s->>'peso_kg')::numeric,
           nullif(s->>'nominal_kg','')::numeric, s->>'metodo', nullif(s->>'ciclo','')::int, nullif(s->>'tempo_ms','')::int,
           'coletor', coalesce(nullif(s->>'capturado_em','')::timestamptz, now())
      from jsonb_array_elements(p_sacos) s
     where coalesce(s->>'evento_id','') <> '' and (s->>'peso_kg')::numeric between -5 and 100
    on conflict (evento_id) do nothing;
    get diagnostics v_ins = row_count;
  end if;

  if jsonb_typeof(p_status) = 'array' and jsonb_array_length(p_status) > 0 then
    insert into public.ensacadeira_status as t (linha_id, bico, linha_nome, peso_kg, estavel, sp1, sp2, sp3, etapa, contador,
                                                ultimo_peso_kg, ultimo_em, online, erro, atualizado_em)
    select v_col.linha_id, (s->>'bico')::smallint, v_linha, nullif(s->>'peso_kg','')::numeric, (s->>'estavel')::boolean,
           (s->>'sp1')::boolean, (s->>'sp2')::boolean, (s->>'sp3')::boolean, s->>'etapa', nullif(s->>'contador','')::int,
           nullif(s->>'ultimo_peso_kg','')::numeric, nullif(s->>'ultimo_em','')::timestamptz,
           coalesce((s->>'online')::boolean, true), s->>'erro', now()
      from jsonb_array_elements(p_status) s
    on conflict (linha_id, bico) do update set
      peso_kg = excluded.peso_kg, estavel = excluded.estavel, sp1 = excluded.sp1, sp2 = excluded.sp2, sp3 = excluded.sp3,
      etapa = excluded.etapa, contador = excluded.contador, ultimo_peso_kg = excluded.ultimo_peso_kg,
      ultimo_em = excluded.ultimo_em, online = excluded.online, erro = excluded.erro, atualizado_em = now();
  end if;

  update public.ensacadeira_coletores set ultimo_contato = now(), versao = coalesce(p_versao, versao) where id = v_col.id;
  return jsonb_build_object('ok', true, 'inseridos', v_ins, 'linha', v_linha);
end $$;

revoke all on function public.ensacadeira_enviar(text, jsonb, jsonb, text) from public;
grant execute on function public.ensacadeira_enviar(text, jsonb, jsonb, text) to anon, authenticated;

comment on table public.ensacadeira_sacos       is 'Ensacadeiras: um registro por saco capturado no SP1 (coletor Modbus).';
comment on table public.ensacadeira_status      is 'Ensacadeiras: estado ao vivo de cada bico (coletor, ~1 s).';
comment on table public.ensacadeira_tolerancias is 'Ensacadeiras: tolerância abaixo/acima por peso nominal.';
comment on table public.ensacadeira_coletores   is 'Ensacadeiras: PCs coletores autorizados (hash do token). Sem policy: só a RPC lê.';

-- ── 7. Coletor da Linha 3 (token entregue no config.json do coletor) ──────
-- Para trocar o token: gere outro e faça
--   update ensacadeira_coletores set token_hash = encode(extensions.digest('NOVO_TOKEN','sha256'),'hex') where nome = 'PC Linha 3';
insert into public.ensacadeira_coletores (nome, linha_id, token_hash)
select 'PC Linha 3', id, 'd6117981033941d6b83e69e9a9c412f1765a76d000993cd0346d6c58613ee23d' from public.linhas_producao where nome = 'Linha 3'
on conflict (token_hash) do nothing;
