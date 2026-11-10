-- 111 · Laudo é do LOTE (lote + linha), não da OP (nov/2026)
-- Uma OP com dois lotes (ex.: Big Bag Creme 02 + Cinza c/ Impermeabilizante no mesmo turno)
-- tem dois laudos. O índice único antigo (1 laudo por OP) barrava o 2º laudo
-- ("duplicate key value violates unique constraint ux_lab_laudos_producao").
drop index if exists public.ux_lab_laudos_producao;
create unique index if not exists ux_lab_laudos_producao_lote on public.lab_laudos (producao_id, coalesce(lote,''));
