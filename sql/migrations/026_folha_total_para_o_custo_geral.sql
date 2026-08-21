-- ============================================================================
-- 026 — A FOLHA PRECISA APARECER NO CUSTO GERAL (sem abrir salário individual)
--
-- Problema: v_custos_consolidado é security_invoker, ou seja, roda com as
-- permissões de quem consulta. Todas as tabelas-fonte liberam leitura para
-- usuário autenticado, MENOS folhas_pagamento, que a migration 020 restringiu a
--     auth_pode_modulo('custo_precificacao') OR auth_pode_aba('rh','tab-folha')
--
-- Resultado: quem tem o módulo "Gestão de Custos" mas não tem Custo &
-- Precificação nem a aba Folha do RH abria o DRE e via R$ 230 mil em vez de
-- R$ 450 mil — sem erro, sem aviso, só o número menor. Metade do custo da
-- fábrica desaparecendo em silêncio é exatamente o que não pode acontecer.
--
-- Correção: uma policy SELECT adicional para quem tem o módulo 'custos'.
--   • É só SELECT — a policy existente (ALL) continua sendo a única que grava.
--   • É só folhas_pagamento, que guarda o TOTAL do mês (totais jsonb).
--   • folha_dados_funcionario (salário de cada pessoa) NÃO é tocada: o módulo
--     de custo vê o total da folha, não quanto cada funcionário recebe.
-- ============================================================================

drop policy if exists folha_total_para_custos on public.folhas_pagamento;

create policy folha_total_para_custos
  on public.folhas_pagamento
  for select
  to authenticated
  using ( public.auth_pode_modulo('custos') );

-- Conferência: as duas policies convivem (PERMISSIVE = OR no SELECT).
--   select policyname, cmd from pg_policies
--    where tablename='folhas_pagamento' order by policyname;
