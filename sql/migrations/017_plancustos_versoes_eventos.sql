-- 017 — Versões e trilha de eventos do Planejamento & Custos (plancustos.html)
--
-- Migração ADITIVA (protocolo #3): nada existente é alterado ou removido.
--
-- 1. `planos_mensais.versao` — contador incrementado a cada salvamento.
-- 2. `planos_mensais_eventos` — trilha de auditoria do plano:
--    criação, cada versão salva (com retrato jsonb de itens+config) e
--    ajustes manuais do custo realizado. Nunca se apaga um evento —
--    histórico é append-only, alinhado à exigência de não destruir
--    informações anteriores.
-- RLS habilitado desde o nascimento (mesma policy baseline do sistema).

alter table public.planos_mensais
  add column if not exists versao integer not null default 1;

create table if not exists public.planos_mensais_eventos (
  id         uuid primary key default gen_random_uuid(),
  plano_id   uuid not null references public.planos_mensais(id) on delete cascade,
  versao     integer,
  acao       text not null,          -- 'criar' | 'salvar' | 'ajuste'
  resumo     text,
  usuario    text,
  snapshot   jsonb,                  -- retrato da versão (itens, config, calendário, totais)
  created_at timestamptz not null default now()
);

create index if not exists idx_planos_eventos_plano
  on public.planos_mensais_eventos (plano_id, created_at desc);

alter table public.planos_mensais_eventos enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies
                  where schemaname='public' and tablename='planos_mensais_eventos') then
    create policy "authenticated_all" on public.planos_mensais_eventos
      for all to authenticated using (true) with check (true);
  end if;
end $$;
