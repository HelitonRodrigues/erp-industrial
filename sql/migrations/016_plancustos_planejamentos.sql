-- 016 — Tabela EXCLUSIVA do módulo novo Planejamento & Custos (plancustos.html)
--
-- Mesmo formato da planejamentos_custo, porém 100% independente: criar, editar
-- ou excluir um planejamento aqui NÃO toca nos módulos antigos (e vice-versa).
-- A importação do C&P é uma CÓPIA one-way feita pelo botão na tela.
-- Nasce com RLS habilitado (as antigas nasceram sem).

create table if not exists public.plancustos_planejamentos (
  id            uuid primary key default gen_random_uuid(),
  codigo        text not null,          -- 'PC-0001'
  numero        integer not null,
  nome          text,
  mes           integer,
  ano           integer,
  estado        jsonb not null,
  totais        jsonb,
  status        text not null default 'ativo',
  criado_por    text,
  created_at    timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create index if not exists idx_plancustos_plan_numero on public.plancustos_planejamentos (numero desc);

alter table public.plancustos_planejamentos enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies
                  where schemaname='public' and tablename='plancustos_planejamentos') then
    create policy "authenticated_all" on public.plancustos_planejamentos
      for all to authenticated using (true) with check (true);
  end if;
end $$;
