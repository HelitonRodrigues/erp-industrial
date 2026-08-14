-- 012 — Melhorias do módulo de EPIs
--
-- 1. epi_entradas: o epi.html SEMPRE tentou gravar o histórico de entradas
--    nesta tabela — que nunca existiu no banco. A função verificarColunaEntradas()
--    detectava a ausência e o histórico era descartado em silêncio (console.warn).
--    Schema idêntico ao que já estava embutido no código.
--
-- 2. epi_entregas ganha colunas para os novos fluxos da tela:
--    • tamanho          — numeração/tamanho do EPI entregue (bota 42, luva G...)
--    • motivo_troca     — por que trocou antes do prazo (perda, dano, defeito...)
--    • devolvido_em     — data da devolução/descarte do EPI
--    • devolucao_motivo — motivo da devolução (desligamento, defeito, troca...)
--
-- Colunas novas são opcionais: entregas antigas continuam válidas sem alteração.

create table if not exists public.epi_entradas (
  id             uuid primary key default gen_random_uuid(),
  epi_id         uuid references public.epi_cadastro(id) on delete cascade,
  data_entrada   date,
  quantidade     numeric,
  custo_unitario numeric,
  fornecedor     text,
  nota_fiscal    text,
  obs            text,
  created_at     timestamptz default now()
);

create index if not exists idx_epi_entradas_epi on public.epi_entradas (epi_id, data_entrada desc);

alter table public.epi_entradas enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies
                  where schemaname='public' and tablename='epi_entradas') then
    create policy "authenticated_all" on public.epi_entradas
      for all to authenticated using (true) with check (true);
  end if;
end $$;

alter table public.epi_entregas
  add column if not exists tamanho          text,
  add column if not exists motivo_troca     text,
  add column if not exists devolvido_em     date,
  add column if not exists devolucao_motivo text;
