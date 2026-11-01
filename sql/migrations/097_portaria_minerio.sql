-- 097 — Portaria: entrada de minério da mineração (pesagem na balança) e notas.
-- Substitui as planilhas MATERIAL_CAULIM / MATERIAL_GRAFITOSO.
--  • minerio_viagens: cada viagem pesada (data, placa, motorista, unidade, frente, tara, bruto)
--  • minerio_notas  : um grupo de viagens que virou nota. O nº da NF é opcional
--                     (a portaria nem sempre tem a NF na mão — informa depois).
-- Pesos em KG, como na balança. Líquido é calculado pelo banco (bruto − tara).

create table if not exists public.minerio_notas (
  id                 uuid primary key default gen_random_uuid(),
  material           text not null,
  data               date not null default current_date,
  nf_numero          text,                       -- pode ficar vazio e ser informado depois
  total_kg           numeric not null default 0, -- soma das viagens da nota
  total_informado_kg numeric,                    -- só no histórico: total que estava escrito na planilha
  viagens            int not null default 0,
  origem             text not null default 'portaria',  -- portaria | planilha
  obs                text,
  criado_por         text,
  criado_em          timestamptz not null default now(),
  nf_informada_por   text,
  nf_informada_em    timestamptz
);
create index if not exists minerio_notas_data_idx on public.minerio_notas (material, data);

create table if not exists public.minerio_viagens (
  id          uuid primary key default gen_random_uuid(),
  data        date not null default current_date,
  material    text not null,
  motorista   text,
  placa       text not null,
  unidade     text,
  frente      text,
  tara_kg     numeric not null check (tara_kg >= 0),
  bruto_kg    numeric not null check (bruto_kg >= 0),
  liquido_kg  numeric generated always as (bruto_kg - tara_kg) stored,
  nota_id     uuid references public.minerio_notas(id) on delete set null,
  origem      text not null default 'portaria',
  ref_planilha text,                              -- histórico: "CAULIM/OUTUBRO/L23"
  obs         text,
  criado_por  text,
  criado_em   timestamptz not null default now()
);
create index if not exists minerio_viagens_data_idx on public.minerio_viagens (material, data);
create index if not exists minerio_viagens_nota_idx on public.minerio_viagens (nota_id);
create index if not exists minerio_viagens_pend_idx on public.minerio_viagens (material, data) where nota_id is null;
create index if not exists minerio_viagens_placa_idx on public.minerio_viagens (placa, data desc);

alter table public.minerio_notas   enable row level security;
alter table public.minerio_viagens enable row level security;
drop policy if exists baseline_authenticated_all on public.minerio_notas;
drop policy if exists baseline_authenticated_all on public.minerio_viagens;
create policy baseline_authenticated_all on public.minerio_notas   for all to authenticated using (true) with check (true);
create policy baseline_authenticated_all on public.minerio_viagens for all to authenticated using (true) with check (true);

-- Gera a nota com as viagens escolhidas, de forma atômica (ninguém pega a mesma viagem duas vezes).
create or replace function public.minerio_gerar_nota(
  p_material text, p_viagens uuid[], p_data date default current_date,
  p_nf text default null, p_obs text default null, p_criado_por text default null)
returns public.minerio_notas
language plpgsql security invoker set search_path = public as $$
declare v_nota public.minerio_notas; v_n int; v_tot numeric;
begin
  if p_viagens is null or array_length(p_viagens,1) is null then raise exception 'Escolha pelo menos uma viagem.'; end if;
  perform 1 from minerio_viagens where id = any(p_viagens) for update;
  if exists (select 1 from minerio_viagens where id = any(p_viagens) and nota_id is not null) then
    raise exception 'Alguma dessas viagens já entrou em outra nota. Atualize a tela e escolha de novo.'; end if;
  if exists (select 1 from minerio_viagens where id = any(p_viagens) and material <> p_material) then
    raise exception 'Todas as viagens da nota precisam ser do mesmo material.'; end if;
  select count(*), coalesce(sum(liquido_kg),0) into v_n, v_tot from minerio_viagens where id = any(p_viagens);
  if v_n <> array_length(p_viagens,1) then raise exception 'Alguma viagem não foi encontrada. Atualize a tela.'; end if;
  insert into minerio_notas (material, data, nf_numero, total_kg, viagens, obs, criado_por,
                             nf_informada_por, nf_informada_em)
  values (p_material, coalesce(p_data,current_date), nullif(trim(p_nf),''), v_tot, v_n, p_obs, p_criado_por,
          case when nullif(trim(p_nf),'') is not null then p_criado_por end,
          case when nullif(trim(p_nf),'') is not null then now() end)
  returning * into v_nota;
  update minerio_viagens set nota_id = v_nota.id where id = any(p_viagens);
  return v_nota;
end $$;

-- Desfaz a nota: as viagens voltam a ficar "sem nota".
create or replace function public.minerio_desfazer_nota(p_nota uuid)
returns void language plpgsql security invoker set search_path = public as $$
begin
  update minerio_viagens set nota_id = null where nota_id = p_nota;
  delete from minerio_notas where id = p_nota;
end $$;

revoke all on function public.minerio_gerar_nota(text,uuid[],date,text,text,text) from public, anon;
revoke all on function public.minerio_desfazer_nota(uuid) from public, anon;
grant execute on function public.minerio_gerar_nota(text,uuid[],date,text,text,text) to authenticated;
grant execute on function public.minerio_desfazer_nota(uuid) to authenticated;
