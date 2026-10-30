-- 095 — Ordem de carregamento: itens da Felisbina (aplicado direto no banco em 30/10/2026)
-- Produto da Felisbina (felis_itens: produto/revenda) não tem QR — o Carregamento não pede bipagem.
alter table public.romaneio_itens add column if not exists felis_item_id uuid references public.felis_itens(id);
