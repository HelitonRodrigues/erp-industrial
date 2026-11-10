-- 113 — Filito: registrar a CHEGADA do caminhão sem a tara (nov/2026)
-- Fluxo novo: chegada (aguardando_tara) → tara (aguardando_bruto) → bruto (pendente_nf/concluido).
-- O fluxo antigo continua: chegada já com a tara entra direto em aguardando_bruto.
--   chegada_em   = hora que o caminhão chegou (servidor)
--   entrada_em   = hora da TARA (servidor) — "tempo na balança" continua tara → bruto
--   porteiro_tara = quem pesou a tara (quando foi depois da chegada)

alter table public.filito_viagens add column if not exists chegada_em timestamptz;
alter table public.filito_viagens add column if not exists porteiro_tara text;
update public.filito_viagens set chegada_em = entrada_em where chegada_em is null and entrada_em is not null;

alter table public.filito_viagens alter column tara_kg drop not null;

alter table public.filito_viagens drop constraint if exists filito_viagens_status_check;
alter table public.filito_viagens add constraint filito_viagens_status_check
  check (status in ('aguardando_tara','aguardando_bruto','pendente_nf','concluido'));

alter table public.filito_viagens drop constraint if exists filito_bruto_chk;
alter table public.filito_viagens add constraint filito_bruto_chk
  check (status in ('aguardando_tara','aguardando_bruto') or (bruto_kg is not null and bruto_kg > tara_kg));

alter table public.filito_viagens drop constraint if exists filito_tara_chk;
alter table public.filito_viagens add constraint filito_tara_chk
  check (status = 'aguardando_tara' or tara_kg is not null);

-- a mesma placa não pode estar aberta duas vezes (esperando tara OU bruto)
drop index if exists public.filito_viagens_placa_aberta_uq;
create unique index filito_viagens_placa_aberta_uq on public.filito_viagens (placa)
  where status in ('aguardando_tara','aguardando_bruto');

create or replace function public.filito_viagem_regras()
returns trigger
language plpgsql
set search_path to 'public'
as $function$
begin
  if new.origem = 'portaria' then
    if tg_op = 'INSERT' then
      new.chegada_em := now(); new.data := (now() at time zone 'America/Sao_Paulo')::date;
      if new.status <> 'aguardando_tara' then new.entrada_em := now(); end if;
    elsif old.status = 'aguardando_tara' and new.status <> 'aguardando_tara' then
      new.entrada_em := now();      -- hora da tara
    end if;
    if new.status not in ('aguardando_tara','aguardando_bruto')
       and (tg_op = 'INSERT' or old.status in ('aguardando_tara','aguardando_bruto')) then
      new.saida_em := now();
      if new.ticket is null then new.ticket := nextval('public.filito_ticket_seq'); end if;
    end if;
  end if;
  -- nota completa (nº + arquivo) ou PDF dispensado (histórico) → concluído; senão pendente
  if new.status not in ('aguardando_tara','aguardando_bruto') then
    new.status := case when new.nf_dispensada or (nullif(trim(new.nf_numero),'') is not null and new.nf_path is not null) then 'concluido' else 'pendente_nf' end;
  end if;
  return new;
end $function$;
