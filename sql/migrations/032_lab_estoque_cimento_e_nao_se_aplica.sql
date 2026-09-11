-- 032 — Estoque de cimento no laboratório + "não se aplica" nos limites.

-- "Não se aplica" precisa ser uma DECISÃO gravada, não um campo em branco:
-- vazio pode ser "ainda não preenchi", e os dois não podem virar a mesma coisa.
alter table public.lab_produto_qualidade
  add column if not exists nao_se_aplica jsonb not null default '[]'::jsonb;
comment on column public.lab_produto_qualidade.nao_se_aplica is
  'Grupos de limite marcados como não aplicáveis a este produto (traco, umidade, agua, densidade, retido, mm, peso_esp).';

-- O cimento do laboratório passa a ter saldo próprio, em kg.
alter table public.lab_cimentos add column if not exists saldo_kg numeric not null default 0;
alter table public.lab_cimentos add column if not exists estoque_minimo_kg numeric not null default 0;

-- Extrato do saldo: entrada de saco/carga, consumo do ensaio e ajuste manual.
create table if not exists public.lab_cimentos_movimentos (
  id uuid primary key default gen_random_uuid(),
  cimento_id uuid not null references public.lab_cimentos(id) on delete cascade,
  tipo text not null,              -- entrada | consumo | ajuste
  qtd_kg numeric not null,         -- negativo = saída
  saldo_apos_kg numeric,
  nf text, fornecedor text,
  motivo text, responsavel text,
  data timestamptz default now() not null
);
create index if not exists ix_lab_cim_mov on public.lab_cimentos_movimentos(cimento_id, data desc);
