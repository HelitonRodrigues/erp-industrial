-- 118 — Laudo separado por embalagem (nov/2026).
-- Mesmo lote e mesma linha, mas Bag e Ensacado 25 kg passam a ter um laudo cada.
-- A trava antiga (uma OP + lote = um laudo) impedia o 2º laudo; agora a chave inclui o produto.
drop index if exists public.ux_lab_laudos_producao_lote;
create unique index if not exists ux_lab_laudos_producao_lote_produto
  on public.lab_laudos (producao_id, coalesce(lote,''), coalesce(produto,''));
