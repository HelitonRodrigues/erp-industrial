-- 046 — Folha de pagamento: quem foi tirado com o botão −
-- A folha mais recente puxa sozinha os funcionários ativos do cadastro; os IDs daqui não voltam.
alter table public.folhas_pagamento add column if not exists excluidos jsonb not null default '[]'::jsonb;
notify pgrst, 'reload schema';
