-- 031 — Fecha o que faltava do laboratório.
--
-- As abas Cimentos, MP & Entrada e Entrada (CAI) já existiam no código, mas as
-- tabelas nunca foram criadas — por isso "não estou conseguindo": a tela
-- chamava lab_cimentos e o Postgres respondia que a relação não existe.
-- O schema abaixo é o que o próprio laboratorio.html documenta no cabeçalho.

create table if not exists public.lab_cimentos (
  id uuid primary key default gen_random_uuid(),
  tipo text not null, marca text not null,
  padrao boolean default false not null,
  ativo boolean default true not null,
  criado_em timestamptz default now() not null
);

create table if not exists public.lab_mp_limites (
  id uuid primary key default gen_random_uuid(),
  nome text not null unique,
  tipo text default 'pedra',
  cor_hex text,
  agua_min_ml numeric, agua_max_ml numeric,
  densidade_min numeric, densidade_max numeric,
  umidade_min numeric,  umidade_max numeric,
  mf_min numeric,       mf_max numeric,
  std_l numeric, std_a numeric, std_b numeric, delta_e_max numeric,
  exige_lab boolean default true not null,
  peneiras jsonb default '[]'::jsonb not null,
  ativo boolean default true not null,
  atualizado_em timestamptz default now() not null
);

create table if not exists public.lab_entradas_cai (
  id uuid primary key default gen_random_uuid(),
  lote text not null unique,
  produto_nome text not null,
  mp_id uuid references public.lab_mp_limites(id),
  fornecedor text, nf text,
  data_ensaio date not null,
  qtd_kg numeric not null default 0,
  saldo_g numeric not null default 0,
  cimento_id uuid references public.lab_cimentos(id),
  peso_amostra_g numeric,
  granulometria jsonb default '[]'::jsonb not null,
  total_retido_g numeric, total_pct numeric, modulo_finura numeric,
  agua_ml numeric, densidade numeric, umidade numeric,
  cor_l numeric, cor_a numeric, cor_b numeric, delta_e numeric,
  ensaios_fora jsonb default '[]'::jsonb not null,
  status text default 'pendente' not null,
  aprovado_por text, aprovado_em timestamptz,
  motivo text, obs text, responsavel text, criado_por text,
  criado_em timestamptz default now() not null,
  atualizado_em timestamptz default now() not null
);

create table if not exists public.lab_entradas_movimentos (
  id uuid primary key default gen_random_uuid(),
  entrada_id uuid not null references public.lab_entradas_cai(id) on delete cascade,
  tipo text not null,            -- entrada | consumo | ajuste
  qtd_g numeric not null,        -- negativo = saída
  saldo_apos_g numeric,
  motivo text, responsavel text,
  data timestamptz default now() not null
);
create index if not exists ix_lab_ent_mov on public.lab_entradas_movimentos(entrada_id, data desc);

alter table public.lab_produto_qualidade add column if not exists limite_umidade_min numeric;
alter table public.lab_produto_qualidade add column if not exists limite_agua_min_ml numeric;
alter table public.lab_produto_qualidade add column if not exists limite_agua_max_ml numeric;
alter table public.lab_produto_qualidade add column if not exists cor_hex text;
alter table public.lab_produto_qualidade add column if not exists aditivo_padrao text;
alter table public.lab_produto_qualidade add column if not exists aditivo_dosagem_g numeric;

alter table public.lab_pallet_analises add column if not exists consumos jsonb;

-- O traço deixa de dizer só "quantos gramas de cimento": passa a dizer QUAL
-- cimento (tipo e marca, do cadastro) e de QUAL lote de entrada veio a areia.
alter table public.lab_tracos add column if not exists cimento_id uuid references public.lab_cimentos(id);
alter table public.lab_tracos add column if not exists areia_entrada_id uuid references public.lab_entradas_cai(id);

-- Ciclo da aferição dentro do laboratório: ela nasce no aferidor e caminha
-- aguardando análise → em análise → analisado. Quem fez o quê fica gravado.
alter table public.aferidor_aditivacao add column if not exists status_lab text not null default 'aguardando_analise';
alter table public.aferidor_aditivacao add column if not exists status_lab_em timestamptz;
alter table public.aferidor_aditivacao add column if not exists status_lab_por text;
alter table public.aferidor_aditivacao add column if not exists obs_lab text;
create index if not exists ix_afer_status_lab on public.aferidor_aditivacao(status_lab, data desc);
