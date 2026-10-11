-- 052 — Portaria: tara e unidade de carregamento no "Iniciar carregamento"
-- O porteiro só libera o caminhão depois de pesar vazio (tara) e dizer em qual
-- unidade (barracão: Unidade 01/02/03…) ele vai carregar. A unidade vai para a
-- ordem e aparece no carregamento.html. Risco: baixo — só colunas novas.
alter table public.portaria  add column if not exists unidade_carregamento text;
alter table public.portaria  add column if not exists tara_em  timestamptz;
alter table public.portaria  add column if not exists tara_por text;
alter table public.romaneios add column if not exists unidade_carregamento text;
