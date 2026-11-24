-- (24/11/2026) Lançamento do Dia — rascunho por data/linha/turno (lancamento-dia.html)
create table if not exists public.lancamento_dia (
  id uuid primary key default gen_random_uuid(),
  data date not null,
  linha text not null,
  turno text not null,
  status text not null default 'rascunho',  -- rascunho | pronto | lancado | nao_rodou
  dados jsonb not null default '{}'::jsonb,
  fotos jsonb not null default '[]'::jsonb,
  producao_id uuid,
  atualizado_por text,
  atualizado_em timestamptz not null default now(),
  lancado_por text,
  lancado_em timestamptz,
  criado_em timestamptz not null default now(),
  unique (data, linha, turno)
);
alter table public.lancamento_dia enable row level security;
create policy baseline_authenticated_all on public.lancamento_dia for all to authenticated using (true) with check (true);
create index if not exists lancamento_dia_data_idx on public.lancamento_dia(data);
