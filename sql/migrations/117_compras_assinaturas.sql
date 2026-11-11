-- 117 — Compras: assinatura de próprio punho do comprador e do gerente (nov/2026).
-- Comprador assina ao enviar a compra ao gerente (ou ao liberar a emergencial);
-- gerente assina ao aprovar/reprovar a cotação ou ao confirmar a emergencial.
-- A assinatura (PNG base64, mesmo padrão do padAssinatura do utils.js) vai para a cotação
-- e é copiada para a(s) compra(s) gerada(s). Sai no PDF do mapa e da compra.
alter table compras_cotacoes add column if not exists assinatura_comprador text;
alter table compras_cotacoes add column if not exists assinatura_gerente  text;
alter table compras_pedidos  add column if not exists assinatura_comprador text;
alter table compras_pedidos  add column if not exists assinatura_gerente  text;
