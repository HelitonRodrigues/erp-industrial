-- 101 — Portaria › Caulim e Grafitoso: tela nova "minerio_ind" (Indicadores) no catálogo de abas (js/utils.js).
-- Aplicado direto no banco em 03/11/2026. Porteiro não vê; Minério (consulta) vê.
update public.perfis set permissoes = jsonb_set(permissoes,'{portaria,abas,minerio_ind}','{"view":false,"create":false,"edit":false,"delete":false,"export":false}'::jsonb,true) where codigo='PRT';
update public.perfis set permissoes = jsonb_set(permissoes,'{portaria,abas,minerio_ind}','{"view":true,"create":false,"edit":false,"delete":false,"export":true,"imprimir":true}'::jsonb,true) where codigo='MIN';
