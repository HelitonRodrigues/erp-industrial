-- 049 — Ensacadeiras: amostras, níveis programados e regra de 10 kg no servidor
--
-- • ensacadeira_amostras: subida rápida do bico (< 1 s) = amostra tirada pelo pessoal,
--   não é saco. O coletor manda no mesmo lote dos sacos com "tipo":"amostra".
-- • Níveis (setpoints) programados no indicador: ensacadeira_status.sp1_prog..sp3_prog
--   (valor atual) + ensacadeira_niveis_hist (cada mudança). Saco leva sp1_programado.
-- • RPC: saco abaixo de 10 kg é recusado no servidor (vale até para coletor antigo).
-- Risco: baixo — tabelas novas, colunas novas (nullable), função substituída (mesma assinatura).

create table if not exists public.ensacadeira_amostras (
  id           bigint generated always as identity primary key,
  evento_id    text not null unique,
  linha_id     uuid references public.linhas_producao(id),
  linha_nome   text,
  bico         smallint not null,
  peso_kg      numeric(7,3) not null,
  subida_ms    integer,
  sp1          boolean,
  produto      text,
  capturado_em timestamptz not null default now(),
  criado_em    timestamptz not null default now()
);
create index if not exists ensacadeira_amostras_linha_data_idx on public.ensacadeira_amostras (linha_id, capturado_em desc);
alter table public.ensacadeira_amostras enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where tablename='ensacadeira_amostras' and policyname='baseline_authenticated_all') then
    create policy baseline_authenticated_all on public.ensacadeira_amostras for all to authenticated using (true) with check (true); end if;
end $$;

alter table public.ensacadeira_status add column if not exists sp1_prog numeric(7,3);
alter table public.ensacadeira_status add column if not exists sp2_prog numeric(7,3);
alter table public.ensacadeira_status add column if not exists sp3_prog numeric(7,3);
alter table public.ensacadeira_sacos  add column if not exists sp1_programado numeric(7,3);

create table if not exists public.ensacadeira_niveis_hist (
  id           bigint generated always as identity primary key,
  linha_id     uuid references public.linhas_producao(id),
  bico         smallint not null,
  nivel        smallint not null,
  valor_kg     numeric(7,3),
  anterior_kg  numeric(7,3),
  alterado_em  timestamptz not null default now()
);
create index if not exists ensacadeira_niveis_hist_idx on public.ensacadeira_niveis_hist (linha_id, alterado_em desc);
alter table public.ensacadeira_niveis_hist enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where tablename='ensacadeira_niveis_hist' and policyname='baseline_authenticated_all') then
    create policy baseline_authenticated_all on public.ensacadeira_niveis_hist for all to authenticated using (true) with check (true); end if;
end $$;

-- RPC (mesma assinatura): amostras roteadas por "tipo", sacos >= 10 kg, histórico de níveis.
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
  v_amo   integer := 0;
  v_ac    public.ensacadeira_acompanhamento%rowtype;
begin
  select * into v_col from public.ensacadeira_coletores
   where token_hash = encode(extensions.digest(coalesce(p_token,''), 'sha256'), 'hex') and ativo;
  if not found then
    raise exception 'coletor não autorizado' using errcode = '28000';
  end if;
  select nome into v_linha from public.linhas_producao where id = v_col.linha_id;
  select * into v_ac from public.ensacadeira_acompanhamento where linha_id = v_col.linha_id and fechado_em is null limit 1;

  if jsonb_typeof(p_sacos) = 'array' and jsonb_array_length(p_sacos) > 0 then
    if jsonb_array_length(p_sacos) > 1000 then raise exception 'lote grande demais (máx. 1000)'; end if;

    insert into public.ensacadeira_amostras (evento_id, linha_id, linha_nome, bico, peso_kg, subida_ms, sp1, produto, capturado_em)
    select s->>'evento_id', v_col.linha_id, v_linha, (s->>'bico')::smallint, (s->>'peso_kg')::numeric,
           nullif(s->>'tempo_ms','')::int, coalesce((s->>'sp1')::boolean, false), v_ac.produto_nome,
           coalesce(nullif(s->>'capturado_em','')::timestamptz, now())
      from jsonb_array_elements(p_sacos) s
     where s->>'tipo' = 'amostra' and coalesce(s->>'evento_id','') <> ''
    on conflict (evento_id) do nothing;
    get diagnostics v_amo = row_count;

    insert into public.ensacadeira_sacos (evento_id, linha_id, linha_nome, bico, peso_kg, nominal_kg, metodo, ciclo, tempo_ms, origem,
                                          capturado_em, produto, acompanhamento_id, sp1_programado)
    select s->>'evento_id', v_col.linha_id, v_linha, (s->>'bico')::smallint, (s->>'peso_kg')::numeric,
           coalesce(case when v_ac.id is not null and coalesce(nullif(s->>'capturado_em','')::timestamptz, now()) >= v_ac.inicio_em then v_ac.nominal_kg end,
                    nullif(s->>'nominal_kg','')::numeric),
           s->>'metodo', nullif(s->>'ciclo','')::int, nullif(s->>'tempo_ms','')::int, 'coletor',
           coalesce(nullif(s->>'capturado_em','')::timestamptz, now()),
           case when v_ac.id is not null and coalesce(nullif(s->>'capturado_em','')::timestamptz, now()) >= v_ac.inicio_em then v_ac.produto_nome end,
           case when v_ac.id is not null and coalesce(nullif(s->>'capturado_em','')::timestamptz, now()) >= v_ac.inicio_em then v_ac.id end,
           nullif(s->>'sp1_programado','')::numeric
      from jsonb_array_elements(p_sacos) s
     where coalesce(s->>'tipo','saco') <> 'amostra' and coalesce(s->>'evento_id','') <> ''
       and (s->>'peso_kg')::numeric between 10 and 100
    on conflict (evento_id) do nothing;
    get diagnostics v_ins = row_count;
  end if;

  if jsonb_typeof(p_status) = 'array' and jsonb_array_length(p_status) > 0 then
    insert into public.ensacadeira_niveis_hist (linha_id, bico, nivel, valor_kg, anterior_kg)
    select v_col.linha_id, (s->>'bico')::smallint, n.nivel, n.novo, n.ant
      from jsonb_array_elements(p_status) s
      left join public.ensacadeira_status t on t.linha_id = v_col.linha_id and t.bico = (s->>'bico')::smallint
      cross join lateral (values (1, nullif(s->>'sp1_prog','')::numeric, t.sp1_prog),
                                 (2, nullif(s->>'sp2_prog','')::numeric, t.sp2_prog),
                                 (3, nullif(s->>'sp3_prog','')::numeric, t.sp3_prog)) n(nivel, novo, ant)
     where n.novo is not null and n.novo is distinct from n.ant;

    insert into public.ensacadeira_status as t (linha_id, bico, linha_nome, peso_kg, estavel, sp1, sp2, sp3, etapa, contador,
                                                ultimo_peso_kg, ultimo_em, online, erro, sp1_prog, sp2_prog, sp3_prog, atualizado_em)
    select v_col.linha_id, (s->>'bico')::smallint, v_linha, nullif(s->>'peso_kg','')::numeric, (s->>'estavel')::boolean,
           (s->>'sp1')::boolean, (s->>'sp2')::boolean, (s->>'sp3')::boolean, s->>'etapa', nullif(s->>'contador','')::int,
           nullif(s->>'ultimo_peso_kg','')::numeric, nullif(s->>'ultimo_em','')::timestamptz,
           coalesce((s->>'online')::boolean, true), s->>'erro',
           nullif(s->>'sp1_prog','')::numeric, nullif(s->>'sp2_prog','')::numeric, nullif(s->>'sp3_prog','')::numeric, now()
      from jsonb_array_elements(p_status) s
    on conflict (linha_id, bico) do update set
      peso_kg = excluded.peso_kg, estavel = excluded.estavel, sp1 = excluded.sp1, sp2 = excluded.sp2, sp3 = excluded.sp3,
      etapa = excluded.etapa, contador = excluded.contador, ultimo_peso_kg = excluded.ultimo_peso_kg,
      ultimo_em = excluded.ultimo_em, online = excluded.online, erro = excluded.erro,
      sp1_prog = coalesce(excluded.sp1_prog, t.sp1_prog), sp2_prog = coalesce(excluded.sp2_prog, t.sp2_prog),
      sp3_prog = coalesce(excluded.sp3_prog, t.sp3_prog), atualizado_em = now();
  end if;

  update public.ensacadeira_coletores set ultimo_contato = now(), versao = coalesce(p_versao, versao) where id = v_col.id;
  return jsonb_build_object('ok', true, 'inseridos', v_ins, 'amostras', v_amo, 'linha', v_linha);
end $$;
revoke all on function public.ensacadeira_enviar(text, jsonb, jsonb, text) from public;
grant execute on function public.ensacadeira_enviar(text, jsonb, jsonb, text) to anon, authenticated;
