-- 048 — Ensacadeiras: acompanhamento da produção na aba "Ao vivo"
--
-- Turno e encarregado vêm da escala ativa (escalas.html) — não são gravados à mão.
-- O usuário fixa o produto (produtos.html); "Limpar tudo" fecha o acompanhamento
-- aberto e abre outro (contagem recomeça). Um aberto por linha (índice parcial).
-- A RPC do coletor passa a gravar em cada saco o produto e o acompanhamento abertos.
--
-- Risco: baixo — tabela nova + coluna nova (nullable) + função substituída.

create table if not exists public.ensacadeira_acompanhamento (
  id                uuid primary key default gen_random_uuid(),
  linha_id          uuid not null references public.linhas_producao(id),
  inicio_em         timestamptz not null default now(),
  fechado_em        timestamptz,
  turno_id          uuid,
  turno_nome        text,
  encarregado       jsonb,
  produto_id        uuid references public.produtos(id),
  produto_nome      text,
  nominal_kg        numeric(6,2),
  sacos_por_pallet  integer,
  cap_hora          numeric,
  aberto_por        text,
  fechado_por       text,
  criado_em         timestamptz not null default now()
);
create unique index if not exists ensacadeira_acomp_aberto_uk on public.ensacadeira_acompanhamento (linha_id) where fechado_em is null;
create index if not exists ensacadeira_acomp_linha_idx on public.ensacadeira_acompanhamento (linha_id, inicio_em desc);
alter table public.ensacadeira_acompanhamento enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where tablename='ensacadeira_acompanhamento' and policyname='baseline_authenticated_all') then
    create policy baseline_authenticated_all on public.ensacadeira_acompanhamento for all to authenticated using (true) with check (true); end if;
end $$;
comment on table public.ensacadeira_acompanhamento is 'Ensacadeiras: acompanhamento aberto na tela Ao vivo (produto fixado, turno/encarregado da escala). Um aberto por linha; "Limpar tudo" fecha e abre outro.';

alter table public.ensacadeira_sacos add column if not exists acompanhamento_id uuid references public.ensacadeira_acompanhamento(id);
create index if not exists ensacadeira_sacos_acomp_idx on public.ensacadeira_sacos (acompanhamento_id);

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
  v_ac    public.ensacadeira_acompanhamento%rowtype;
begin
  select * into v_col from public.ensacadeira_coletores
   where token_hash = encode(extensions.digest(coalesce(p_token,''), 'sha256'), 'hex') and ativo;
  if not found then
    raise exception 'coletor não autorizado' using errcode = '28000';
  end if;
  select nome into v_linha from public.linhas_producao where id = v_col.linha_id;
  -- acompanhamento aberto na tela (produto fixado): cada saco novo leva o produto
  select * into v_ac from public.ensacadeira_acompanhamento where linha_id = v_col.linha_id and fechado_em is null limit 1;

  if jsonb_typeof(p_sacos) = 'array' and jsonb_array_length(p_sacos) > 0 then
    if jsonb_array_length(p_sacos) > 1000 then raise exception 'lote grande demais (máx. 1000)'; end if;
    insert into public.ensacadeira_sacos (evento_id, linha_id, linha_nome, bico, peso_kg, nominal_kg, metodo, ciclo, tempo_ms, origem,
                                          capturado_em, produto, acompanhamento_id)
    select s->>'evento_id', v_col.linha_id, v_linha, (s->>'bico')::smallint, (s->>'peso_kg')::numeric,
           coalesce(case when v_ac.id is not null and coalesce(nullif(s->>'capturado_em','')::timestamptz, now()) >= v_ac.inicio_em then v_ac.nominal_kg end,
                    nullif(s->>'nominal_kg','')::numeric),
           s->>'metodo', nullif(s->>'ciclo','')::int, nullif(s->>'tempo_ms','')::int, 'coletor',
           coalesce(nullif(s->>'capturado_em','')::timestamptz, now()),
           case when v_ac.id is not null and coalesce(nullif(s->>'capturado_em','')::timestamptz, now()) >= v_ac.inicio_em then v_ac.produto_nome end,
           case when v_ac.id is not null and coalesce(nullif(s->>'capturado_em','')::timestamptz, now()) >= v_ac.inicio_em then v_ac.id end
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
