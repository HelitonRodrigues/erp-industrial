-- 018 — Folha de Pagamento passa a ser editada no módulo RH
--
-- ⚠️ RODE ESTE SCRIPT SOMENTE SE quiser que alguém do RH (que NÃO tem
--    permissão no módulo Custo & Precificação) possa ver e lançar a folha.
--
-- Situação hoje: a policy de `folhas_pagamento` é
--     auth_pode_modulo('custo_precificacao')
-- ou seja, só SADM e quem tem o módulo de custo enxerga salários.
-- Como o dono é SADM, a aba nova do RH JÁ FUNCIONA para ele sem este script.
--
-- O que muda: passa a valer para quem tem o módulo `rh` TAMBÉM. O módulo
-- Custo & Precificação continua com acesso porque ele ainda LÊ os salários
-- para calcular o custo de mão de obra (folha_mod / folha_admin) — tirar o
-- acesso dele zeraria a folha no custo.
--
-- Isso AMPLIA quem enxerga salário. Decisão do dono, não do sistema.

drop policy if exists folha_por_modulo on public.folhas_pagamento;

create policy folha_por_modulo on public.folhas_pagamento
  for all
  using      (public.auth_pode_modulo('custo_precificacao') or public.auth_pode_modulo('rh'))
  with check (public.auth_pode_modulo('custo_precificacao') or public.auth_pode_modulo('rh'));

-- Para voltar atrás:
-- drop policy if exists folha_por_modulo on public.folhas_pagamento;
-- create policy folha_por_modulo on public.folhas_pagamento
--   for all using (public.auth_pode_modulo('custo_precificacao'))
--   with check (public.auth_pode_modulo('custo_precificacao'));
