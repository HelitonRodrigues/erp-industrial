-- 034 — Módulo de Férias no RH
--
-- A tabela `rh_ferias` JÁ EXISTIA no baseline e já é LIDA pelo dashboard,
-- pelas notificações e pelos relatórios (status 'agendada' e 'em_gozo').
-- Ninguém escrevia nela. A aba Férias do RH passa a ser a dona: esta migration
-- só ACRESCENTA o que faltava para programar de verdade, sem mexer no que existe.
--
-- Risco: baixo — tudo é ADD COLUMN IF NOT EXISTS + uma tabela nova.
-- Nenhuma coluna é removida ou renomeada; a tabela está vazia em produção.

-- ── 1. rh_ferias: campos que a programação precisa ────────────────────────
alter table public.rh_ferias add column if not exists dias integer;
alter table public.rh_ferias add column if not exists abono integer default 0;
alter table public.rh_ferias add column if not exists cobertura_id uuid;
alter table public.rh_ferias add column if not exists ciclo_vencimento date;
alter table public.rh_ferias add column if not exists atualizado_em timestamptz default now();

comment on column public.rh_ferias.dias   is 'Dias corridos de férias do período (1..30).';
comment on column public.rh_ferias.abono  is 'Dias de abono pecuniário vendidos (art. 143 CLT), até 10.';
comment on column public.rh_ferias.cobertura_id is 'Funcionário que cobre a ausência. Sem FK dura: a cobertura pode sair da empresa sem apagar o histórico.';
comment on column public.rh_ferias.ciclo_vencimento is
  'Vencimento do período aquisitivo a que estas férias pertencem. Preenchido quando o ciclo fecha — é o que separa o histórico do ciclo corrente.';

-- data_fim é obrigatório na tabela original; para linhas antigas sem `dias`,
-- deriva dos dois campos de data (nenhuma linha em produção hoje, mas fica correto).
update public.rh_ferias
   set dias = (data_fim - data_inicio) + 1
 where dias is null and data_inicio is not null and data_fim is not null;

create index if not exists rh_ferias_funcionario_idx on public.rh_ferias (funcionario_id);
create index if not exists rh_ferias_inicio_idx      on public.rh_ferias (data_inicio);
create index if not exists rh_ferias_status_idx      on public.rh_ferias (status);

-- Estados usados pelo módulo e pelos consumidores já existentes.
-- 'cancelada' entra para permitir descartar sem apagar o histórico.
alter table public.rh_ferias drop constraint if exists rh_ferias_status_check;
alter table public.rh_ferias add constraint rh_ferias_status_check
  check (status in ('agendada','em_gozo','gozada','cancelada'));

-- ── 2. rh_ferias_ciclo: período aquisitivo corrente, um por funcionário ───
-- Vencimento = fim do período aquisitivo (12 meses de trabalho).
-- Limite de concessão = última data em que as férias ainda PODEM COMEÇAR.
-- A conta (vencimento + 333 dias) é convenção da contabilidade da fábrica e
-- mora em app_preferencias.ferias_config, não aqui — pode mudar sem migration.
create table if not exists public.rh_ferias_ciclo (
  id               uuid primary key default gen_random_uuid(),
  funcionario_id   uuid not null references public.funcionarios(id) on delete cascade,
  vencimento       date,
  limite_concessao date,
  quitado          boolean default false,
  obs              text,
  criado_em        timestamptz default now(),
  atualizado_em    timestamptz default now()
);

create unique index if not exists rh_ferias_ciclo_funcionario_uk
  on public.rh_ferias_ciclo (funcionario_id);

comment on table public.rh_ferias_ciclo is
  'Ciclo de férias corrente de cada funcionário. Ao completar 30 dias gozados, o módulo avança o vencimento em 12 meses a partir do anterior (não pelo aniversário de admissão) e recalcula o limite.';

-- ── 3. RLS: mesma baseline das demais tabelas ─────────────────────────────
alter table public.rh_ferias_ciclo enable row level security;
drop policy if exists baseline_authenticated_all on public.rh_ferias_ciclo;
create policy baseline_authenticated_all on public.rh_ferias_ciclo
  for all to authenticated using (true) with check (true);

-- ── 4. Configuração do módulo ────────────────────────────────────────────
-- Editável pela engrenagem da aba Férias; o insert abaixo só cria o default.
insert into public.app_preferencias (chave, dados)
values ('ferias_config', '{"dias_concessao":333,"limite_simultaneo":2,"antecedencia":50}'::jsonb)
on conflict (chave) do nothing;

-- ── Para voltar atrás ────────────────────────────────────────────────────
-- drop table if exists public.rh_ferias_ciclo;
-- delete from public.app_preferencias where chave = 'ferias_config';
-- alter table public.rh_ferias drop column if exists dias;
-- alter table public.rh_ferias drop column if exists abono;
-- alter table public.rh_ferias drop column if exists cobertura_id;
-- alter table public.rh_ferias drop column if exists ciclo_vencimento;
-- alter table public.rh_ferias drop constraint if exists rh_ferias_status_check;
