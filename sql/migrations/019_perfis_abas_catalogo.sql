-- ============================================================================
-- 019 — Alinhar perfis.permissoes ao catálogo REAL de abas
--
-- Contexto: o catálogo MODULO_FUNCIONALIDADES (js/utils.js) é o que o
-- perfis.html desenha e o que enforceTabs() usa para ESCONDER aba ausente.
-- Ele estava desatualizado, e os perfis salvos herdaram a defasagem:
--
--   laboratorio        → tinha 'fluxo' (aba que não existe mais na tela) e
--                        não tinha 'laudo'/'ensaios'/'correcoes'/'caulim'
--   rh                 → tinha 'tab-escala' (o id real é 'tab-escalas') e
--                        'tab-ferias' (aba que nunca existiu no rh.html)
--   carregamento       → não tinha 'mes'
--   custo_precificacao → não tinha 'resumo' nem 'real'
--
-- Até agora dois remendos em laboratorio.html e carregamento.html completavam
-- isso no sessionStorage a cada carregamento de página. O commit que corrige o
-- catálogo apaga os remendos — então o dado precisa nascer certo aqui, senão a
-- aba desaparece para quem não é SADM/ADM.
--
-- REGRA: aba que falta HERDA a permissão de uma aba equivalente do mesmo
-- módulo (é o que os remendos faziam). Nada é concedido a mais:
--   laudo/ensaios/correcoes/caulim ← analises
--   mes                            ← carregados
--   resumo                         ← geral
--   real                           ← custos
--   tab-escalas                    ← tab-escala (mesmos flags, só o id certo)
-- 'tab-folha' NÃO é criada: quem não tinha acesso a salário continua sem.
--
-- Só toca perfil que JÁ usa o modelo por aba (tem a chave 'abas').
-- Perfil de tela única e SADM/ADM (acesso total) ficam intactos.
-- Idempotente: rodar de novo não muda nada.
-- ============================================================================

-- ── REDE DE SEGURANÇA: foto dos perfis antes de mexer ───────────────────────
-- Rollback: update perfis p set permissoes = b.permissoes
--           from perfis_bkp_019 b where b.id = p.id;
create table if not exists public.perfis_bkp_019 as
  select id, codigo, permissoes, now() as tirado_em from public.perfis;

-- Tabela nova nasce com RLS (nenhuma tabela deste banco fica aberta ao anon).
alter table public.perfis_bkp_019 enable row level security;
drop policy if exists baseline_authenticated_all on public.perfis_bkp_019;
create policy baseline_authenticated_all on public.perfis_bkp_019
  for all to authenticated using (true) with check (true);

do $$
declare
  r            record;
  perms        jsonb;
  abas         jsonb;
  base         jsonb;
  mudou        boolean;
  aba          text;
  lab_abas     text[] := array['analises','afericoes','composicao','pallets','ensaios','correcoes','caulim','laudo'];
begin
  for r in select id, codigo, permissoes from public.perfis where permissoes is not null loop
    perms := r.permissoes;
    mudou := false;

    -- ── laboratorio ────────────────────────────────────────────────────────
    if perms ? 'laboratorio' and (perms->'laboratorio') ? 'abas' then
      abas := perms->'laboratorio'->'abas';
      base := coalesce(abas->'analises', abas->'fluxo',
                       jsonb_build_object('view',false,'create',false,'edit',false,
                                          'delete',false,'aprovar',false,'export',false,'imprimir',false));
      if abas ? 'fluxo' then
        abas := abas - 'fluxo';                      -- aba removida da tela
        mudou := true;
      end if;
      foreach aba in array lab_abas loop
        if not (abas ? aba) then
          abas := jsonb_set(abas, array[aba], base, true);
          mudou := true;
        end if;
      end loop;
      if mudou then
        perms := jsonb_set(perms, array['laboratorio','abas'], abas, true);
      end if;
    end if;

    -- ── rh: id real é tab-escalas; não existe aba de férias ────────────────
    if perms ? 'rh' and (perms->'rh') ? 'abas' then
      abas := perms->'rh'->'abas';
      if abas ? 'tab-escala' then
        if not (abas ? 'tab-escalas') then
          abas := jsonb_set(abas, array['tab-escalas'], abas->'tab-escala', true);
        end if;
        abas := abas - 'tab-escala';
        mudou := true;
      end if;
      if abas ? 'tab-ferias' then
        abas := abas - 'tab-ferias';
        mudou := true;
      end if;
      perms := jsonb_set(perms, array['rh','abas'], abas, true);
    end if;

    -- ── carregamento: aba Mês herda de Carregados ─────────────────────────
    if perms ? 'carregamento' and (perms->'carregamento') ? 'abas' then
      abas := perms->'carregamento'->'abas';
      if not (abas ? 'mes') and abas ? 'carregados' then
        abas := jsonb_set(abas, array['mes'], abas->'carregados', true);
        perms := jsonb_set(perms, array['carregamento','abas'], abas, true);
        mudou := true;
      end if;
    end if;

    -- ── custo_precificacao: Resumo ← Geral, Planejado x Realizado ← Custos ─
    if perms ? 'custo_precificacao' and (perms->'custo_precificacao') ? 'abas' then
      abas := perms->'custo_precificacao'->'abas';
      if not (abas ? 'resumo') and abas ? 'geral' then
        abas := jsonb_set(abas, array['resumo'], abas->'geral', true);
        mudou := true;
      end if;
      if not (abas ? 'real') and abas ? 'custos' then
        abas := jsonb_set(abas, array['real'], abas->'custos', true);
        mudou := true;
      end if;
      perms := jsonb_set(perms, array['custo_precificacao','abas'], abas, true);
    end if;

    if mudou and perms <> r.permissoes then
      update public.perfis set permissoes = perms where id = r.id;
      raise notice 'perfil % atualizado', r.codigo;
    end if;
  end loop;
end $$;
