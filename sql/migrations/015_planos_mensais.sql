-- 015 — Fundação do módulo novo "Planejamento & Custos" (plancustos.html)
--
-- Substitui, quando maduro, as tabelas `planejamentos` (planejamento.html) e
-- `planejamentos_custo` (custo-precificacao.html). Decisões de desenho que
-- corrigem os problemas conhecidos dos dois:
--
-- 1. ITENS PLANOS (não árvore): cada item é (linha_id, turno_id, produto_nome).
--    O realizado das OPs entra por (produto, linha) SEM precisar existir no
--    plano — produto produzido em linha não planejada vira linha de comparação
--    "não planejado", nunca um buraco.
-- 2. VÍNCULOS POR ID (linha_id/turno_id referenciam linhas_producao/turnos):
--    renomear uma linha ou turno no cadastro NÃO quebra planos salvos
--    (nos módulos antigos o vínculo era por nome e as horas zeravam mudos).
-- 3. `config` guarda preços/réguas importadas do Custo & Precificação (seed) —
--    consumidas pelo motor de custos na Fase 3.
-- 4. `ajustes_realizado` (Fase 2): overrides manuais por cima do realizado
--    automático — a digitação vira exceção, não fonte.
-- 5. RLS habilitado desde o nascimento (as antigas nasceram sem).

create table if not exists public.planos_mensais (
  id                     uuid primary key default gen_random_uuid(),
  ano                    integer not null,
  mes                    integer not null check (mes between 1 and 12),
  nome                   text,
  status                 text not null default 'ativo' check (status in ('ativo','excluido')),
  calendario             jsonb not null default '{}'::jsonb,  -- {'AAAA-MM-DD': 'trabalha'|'folga'|'feriado'|'domingo-especial'}
  feriados_locais        jsonb not null default '[]'::jsonb,  -- [{dia, nome}]
  horas_domingo_especial numeric default 8,
  itens                  jsonb not null default '[]'::jsonb,  -- [{id, linha_id, turno_id, produto_nome, cap_hora, demanda, qtd_manual, eficiencia, extras, paradas_h, lenha_m3_turno, ativo}]
  config                 jsonb not null default '{}'::jsonb,  -- preços, réguas, pesos, mapa de buckets (seed importada do CP)
  ajustes_realizado      jsonb not null default '{}'::jsonb,  -- Fase 2
  totais                 jsonb,                               -- resumo para a listagem
  criado_por             text,
  created_at             timestamptz not null default now(),
  atualizado_em          timestamptz not null default now()
);

create index if not exists idx_planos_mensais_mes on public.planos_mensais (ano desc, mes desc) where status='ativo';

alter table public.planos_mensais enable row level security;

do $$
begin
  if not exists (select 1 from pg_policies
                  where schemaname='public' and tablename='planos_mensais') then
    create policy "authenticated_all" on public.planos_mensais
      for all to authenticated using (true) with check (true);
  end if;
end $$;
