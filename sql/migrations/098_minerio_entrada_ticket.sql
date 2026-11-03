-- 098 — Minério: pesagem em 2 tempos + ticket de pesagem (com assinatura digital opcional do porteiro).
--  1) ENTRADA: data, material, placa, motorista, unidade, frente e TARA → status 'aguardando_bruto'
--  2) BRUTO: o porteiro digita o bruto → status 'pesado', sai o ticket (nº sequencial) para o motorista assinar.
-- Só viagem 'pesado' entra em "Viagens do mês" e pode ir para nota.
-- Aditiva: as viagens antigas (planilha e portaria) ficam 'pesado'.

alter table public.minerio_viagens alter column bruto_kg drop not null;

alter table public.minerio_viagens add column if not exists status     text not null default 'pesado';
alter table public.minerio_viagens add column if not exists entrada_em timestamptz;   -- hora da entrada (tara)
alter table public.minerio_viagens add column if not exists bruto_em   timestamptz;   -- hora do bruto (servidor)
alter table public.minerio_viagens add column if not exists bruto_por  text;
alter table public.minerio_viagens add column if not exists ticket     bigint;        -- nº do ticket de pesagem
alter table public.minerio_viagens add column if not exists bruto_assinatura text;    -- assinatura digital de quem pesou o bruto (PNG pequeno, data URL)

update public.minerio_viagens set entrada_em = criado_em where entrada_em is null;
update public.minerio_viagens set bruto_em = criado_em, bruto_por = criado_por
 where origem = 'portaria' and bruto_em is null and bruto_kg is not null;
alter table public.minerio_viagens alter column entrada_em set default now();

do $$ begin
  alter table public.minerio_viagens add constraint minerio_viagens_status_chk
    check (status in ('aguardando_bruto','pesado'));
exception when duplicate_object then null; end $$;
do $$ begin
  alter table public.minerio_viagens add constraint minerio_viagens_pesado_bruto_chk
    check (status <> 'pesado' or (bruto_kg is not null and bruto_kg > tara_kg));
exception when duplicate_object then null; end $$;

-- um caminhão não pode ter duas entradas abertas
create unique index if not exists minerio_viagens_aguardando_placa_uq
  on public.minerio_viagens (placa) where status = 'aguardando_bruto';
create unique index if not exists minerio_viagens_ticket_uq
  on public.minerio_viagens (ticket) where ticket is not null;

-- "usar minha última assinatura": acha rápido a última de cada usuário
create index if not exists minerio_viagens_assinatura_idx
  on public.minerio_viagens (bruto_por, bruto_em desc) where bruto_assinatura is not null;

create sequence if not exists public.minerio_ticket_seq;

-- tickets das viagens já lançadas pela portaria (em ordem de lançamento)
do $$ declare r record; begin
  for r in select id from public.minerio_viagens
            where origem = 'portaria' and status = 'pesado' and ticket is null order by criado_em loop
    update public.minerio_viagens set ticket = nextval('public.minerio_ticket_seq') where id = r.id;
  end loop;
end $$;

-- ao virar 'pesado' (portaria): hora do bruto pelo servidor + nº do ticket
create or replace function public.minerio_viagem_bruto()
returns trigger language plpgsql set search_path = public as $$
begin
  if new.status = 'pesado' and (tg_op = 'INSERT' or old.status is distinct from 'pesado') then
    if new.bruto_em is null or tg_op = 'UPDATE' then new.bruto_em := now(); end if;
    if new.ticket is null and new.origem = 'portaria' then new.ticket := nextval('public.minerio_ticket_seq'); end if;
  end if;
  return new;
end $$;
drop trigger if exists minerio_viagem_bruto on public.minerio_viagens;
create trigger minerio_viagem_bruto before insert or update on public.minerio_viagens
  for each row execute function public.minerio_viagem_bruto();

grant usage on sequence public.minerio_ticket_seq to authenticated;

-- nota: só viagem com pesagem concluída
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
  if exists (select 1 from minerio_viagens where id = any(p_viagens) and status <> 'pesado') then
    raise exception 'Alguma dessas viagens ainda está aguardando o bruto.'; end if;
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
