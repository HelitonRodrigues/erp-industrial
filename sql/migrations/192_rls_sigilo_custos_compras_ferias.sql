-- 192 — Dados sigilosos: só quem tem acesso à tela vê.
-- Vale para as tabelas usadas SOMENTE pelas telas de Custos, Compras e Férias.
-- Tabelas compartilhadas (funcionarios, rh_ferias, compras_pedidos,
-- lancamentos_custo...) ficam para depois: são lidas por dashboard,
-- relatórios, manutenção etc. e fechar agora quebraria essas telas.
-- SADM sempre passa (auth_pode_modulo já trata).

create or replace function public._rls_por_modulo(p_tab text, p_cond text)
returns void language plpgsql as $$
declare pol record;
begin
  for pol in select policyname from pg_policies where schemaname='public' and tablename=p_tab loop
    execute format('drop policy %I on public.%I', pol.policyname, p_tab);
  end loop;
  execute format('alter table public.%I enable row level security', p_tab);
  execute format('create policy por_modulo on public.%I for all to authenticated using (%s) with check (%s)', p_tab, p_cond, p_cond);
end $$;

-- Gestão de Custos
select public._rls_por_modulo('fechamentos_custo', $c$auth_pode_modulo('custos')$c$);
select public._rls_por_modulo('metas_custo',       $c$auth_pode_modulo('custos')$c$);
select public._rls_por_modulo('orcamentos_custo',  $c$auth_pode_modulo('custos')$c$);

-- Compras (cotações e NC também são lidas pela tela Solicitações)
select public._rls_por_modulo('compras_aliases',   $c$auth_pode_modulo('compras')$c$);
select public._rls_por_modulo('compras_contratos', $c$auth_pode_modulo('compras')$c$);
select public._rls_por_modulo('compras_cotacoes',  $c$auth_pode_modulo('compras') or auth_pode_modulo('solicitacoes')$c$);
select public._rls_por_modulo('compras_nc',        $c$auth_pode_modulo('compras') or auth_pode_modulo('solicitacoes')$c$);

-- Férias
select public._rls_por_modulo('rh_ferias_ciclo',   $c$auth_pode_modulo('ferias') or auth_pode_modulo('rh')$c$);

drop function public._rls_por_modulo(text, text);
