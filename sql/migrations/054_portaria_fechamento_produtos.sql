-- 054 — Portaria: fechamento diário + produtos da ordem ligados ao cadastro (produtos.html)
-- • romaneio_itens.produto_id / produto_erp: o produto do PDF ("CAULIM BIG BAG – BRANCO") ligado ao
--   produto do ERP ("Big Bag Caulim Branco 01"). carregamento.html passa a usar o nome do ERP.
-- • produto_aliases: cada nome de ordem já conferido vira "apelido" do produto — da próxima vez liga sozinho.
-- • portaria_fechamentos: 1 fechamento por dia (resumo congelado em jsonb), para reimprimir igual.
alter table public.romaneio_itens add column if not exists produto_id  uuid;
alter table public.romaneio_itens add column if not exists produto_erp text;
create table if not exists public.produto_aliases (
  id uuid primary key default gen_random_uuid(),
  alias_norm text not null unique, alias_texto text,
  produto_id uuid not null, produto_nome text,
  criado_por text, criado_em timestamptz not null default now());
alter table public.produto_aliases enable row level security;
create table if not exists public.portaria_fechamentos (
  id uuid primary key default gen_random_uuid(),
  data date not null unique, resumo jsonb not null, caminhoes integer, toneladas numeric,
  fechado_por text, fechado_em timestamptz not null default now(), observacao text);
alter table public.portaria_fechamentos enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where tablename='produto_aliases' and policyname='baseline_authenticated_all') then
    create policy baseline_authenticated_all on public.produto_aliases for all to authenticated using (true) with check (true); end if;
  if not exists (select 1 from pg_policies where tablename='portaria_fechamentos' and policyname='baseline_authenticated_all') then
    create policy baseline_authenticated_all on public.portaria_fechamentos for all to authenticated using (true) with check (true); end if;
end $$;
