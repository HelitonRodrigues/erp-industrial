-- 100 — Portaria › FILITO INTERCEMENT – CAMARGO (portaria-filito.html)
-- Substitui a planilha "INTERCEMENT 26.xlsx" (uma aba por mês).
-- Fluxo: ENTRADA (tara, hora do servidor) → aguardando_bruto → BRUTO (hora do servidor, nº do ticket)
--        → pendente_nf (porteiro informa o nº e sobe o arquivo da NF) → concluido.
-- Limite = peso máximo da caçamba (PBT) do caminhão; diferença = bruto − caçamba (igual à planilha).
-- Histórico de 2026 importado da planilha (origem 'planilha').

create table if not exists public.filito_produtos (
  codigo     text primary key,               -- INTERCEMENT, SUPREMO…
  nome       text not null,
  pedido_sap text,                           -- ex.: Intercement 4500780551
  ordem      int not null default 100,
  ativo      boolean not null default true,
  criado_por text,
  criado_em  timestamptz not null default now()
);
insert into public.filito_produtos (codigo,nome,pedido_sap,ordem) values
  ('INTERCEMENT','Intercement','4500780551',10), ('SUPREMO','Supremo',null,20)
on conflict (codigo) do nothing;

create table if not exists public.filito_pedidos (
  numero     text primary key,               -- ex.: 002790 (o "-002790" na frente do motorista)
  nome       text,                           -- nome que a portaria dá ao pedido
  ativo      boolean not null default true,
  obs        text,
  criado_por text,
  criado_em  timestamptz not null default now()
);

create table if not exists public.filito_motoristas (
  id             uuid primary key default gen_random_uuid(),
  nome           text not null unique,
  celular        text,
  placa          text,
  transportadora text,
  cacamba_kg     numeric,                    -- peso máximo da caçamba (limite)
  pedido         text references public.filito_pedidos(numero) on update cascade on delete set null,
  produto        text references public.filito_produtos(codigo) on update cascade,
  ativo          boolean not null default true,
  obs            text,
  criado_em      timestamptz not null default now(),
  atualizado_em  timestamptz not null default now()
);

create sequence if not exists public.filito_ticket_seq;

create table if not exists public.filito_viagens (
  id             uuid primary key default gen_random_uuid(),
  ticket         bigint unique,
  data           date not null default current_date,
  status         text not null default 'aguardando_bruto' check (status in ('aguardando_bruto','pendente_nf','concluido')),
  motorista_id   uuid references public.filito_motoristas(id) on delete set null,
  motorista      text not null,
  placa          text not null,
  transportadora text,
  produto        text not null default 'INTERCEMENT',
  pedido         text,
  cacamba_kg     numeric,
  tara_kg        numeric not null check (tara_kg > 0),
  bruto_kg       numeric,
  liquido_kg     numeric generated always as (bruto_kg - tara_kg) stored,
  diferenca_kg   numeric generated always as (bruto_kg - cacamba_kg) stored,   -- + passou do limite · − abaixo
  entrada_em     timestamptz,
  saida_em       timestamptz,
  porteiro       text,                       -- quem deu a entrada (usuário logado)
  porteiro_saida text,                       -- quem deu o bruto
  operador       text,                       -- digitado
  nf_numero      text,
  nf_path        text,                       -- arquivo no Storage (documentos/portaria/filito/…)
  nf_nome        text,
  nf_em          timestamptz,
  nf_por         text,
  obs            text,
  origem         text not null default 'portaria',
  ref_planilha   text,
  criado_em      timestamptz not null default now(),
  constraint filito_bruto_chk check (status = 'aguardando_bruto' or (bruto_kg is not null and bruto_kg > tara_kg))
);
create index if not exists filito_viagens_data_idx on public.filito_viagens (data desc);
create index if not exists filito_viagens_status_idx on public.filito_viagens (status) where status <> 'concluido';
create unique index if not exists filito_viagens_placa_aberta_uq on public.filito_viagens (placa) where status = 'aguardando_bruto';

-- horários pelo servidor, nº do ticket e status da NF
create or replace function public.filito_viagem_regras()
returns trigger language plpgsql set search_path = public as $$
begin
  if new.origem = 'portaria' then
    if tg_op = 'INSERT' then new.entrada_em := now(); new.data := (now() at time zone 'America/Sao_Paulo')::date; end if;
    if new.status <> 'aguardando_bruto' and (tg_op = 'INSERT' or old.status = 'aguardando_bruto') then
      new.saida_em := now();
      if new.ticket is null then new.ticket := nextval('public.filito_ticket_seq'); end if;
    end if;
    -- nota completa (nº + arquivo) → concluído; faltou algo → volta a pendente
    if new.status <> 'aguardando_bruto' then
      new.status := case when nullif(trim(new.nf_numero),'') is not null and new.nf_path is not null then 'concluido' else 'pendente_nf' end;
    end if;
  end if;
  return new;
end $$;
drop trigger if exists filito_viagem_regras on public.filito_viagens;
create trigger filito_viagem_regras before insert or update on public.filito_viagens
  for each row execute function public.filito_viagem_regras();

alter table public.filito_produtos   enable row level security;
alter table public.filito_pedidos    enable row level security;
alter table public.filito_motoristas enable row level security;
alter table public.filito_viagens    enable row level security;
drop policy if exists baseline_authenticated_all on public.filito_produtos;
drop policy if exists baseline_authenticated_all on public.filito_pedidos;
drop policy if exists baseline_authenticated_all on public.filito_motoristas;
drop policy if exists baseline_authenticated_all on public.filito_viagens;
create policy baseline_authenticated_all on public.filito_produtos   for all to authenticated using (true) with check (true);
create policy baseline_authenticated_all on public.filito_pedidos    for all to authenticated using (true) with check (true);
create policy baseline_authenticated_all on public.filito_motoristas for all to authenticated using (true) with check (true);
create policy baseline_authenticated_all on public.filito_viagens    for all to authenticated using (true) with check (true);
grant usage on sequence public.filito_ticket_seq to authenticated;

-- perfis: aba "filito" da portaria (catálogo em js/utils.js)
update public.perfis set permissoes = jsonb_set(permissoes,'{portaria,abas,filito}','{"view":true,"create":true,"edit":true,"delete":false,"export":true,"imprimir":true}'::jsonb,true) where codigo='PRT';
update public.perfis set permissoes = jsonb_set(permissoes,'{portaria,abas,filito}','{"view":false,"create":false,"edit":false,"delete":false,"export":false}'::jsonb,true) where codigo='MIN';

-- cadastro inicial (feito direto no banco em 03/11/2026, a partir da planilha INTERCEMENT 26.xlsx):
--  • 175 pedidos (os números na frente dos motoristas; ativos = usados desde set/2026)
--  • 116 motoristas (placa, transporte, peso caçamba, pedido e filito da última viagem; ativos = viajaram desde jul/2026)
--  • viagens de 03/11/2026 (origem 'planilha')

-- 03/11/2026 (ajuste): a regra da nota vale também para as viagens da planilha — só conclui com o nº E o PDF.
-- filito_viagem_regras(): o bloco "if new.status <> 'aguardando_bruto' then new.status := …" saiu de dentro do "if origem = 'portaria'".
-- As viagens importadas voltaram para pendente_nf (têm o nº, falta o PDF).
