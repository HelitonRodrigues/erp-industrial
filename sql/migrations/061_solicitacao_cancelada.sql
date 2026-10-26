-- 061 — Cancelar solicitação (substituída, não é mais necessária, comprada por outro meio, duplicada…)
-- A solicitação cancelada some do Compras e do "Em andamento", mas fica guardada com o motivo.
-- Só acrescenta colunas; nada existente muda.
alter table public.almoxarifado_solicitacoes
  add column if not exists cancelado_motivo     text,
  add column if not exists cancelado_substituta text,        -- nº da solicitação que substituiu (ex.: SOL162)
  add column if not exists cancelado_por        text,
  add column if not exists cancelado_em         timestamptz;

alter table public.compras_solicitacoes
  add column if not exists cancelado_motivo     text,
  add column if not exists cancelado_substituta text,
  add column if not exists cancelado_por        text,
  add column if not exists cancelado_em         timestamptz;
