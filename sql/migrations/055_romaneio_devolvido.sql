-- 055 — Portaria devolve a ordem ao Carregamento (antes da saída) para tirar/trocar pallet ou bag.
-- O Carregamento mostra "A PORTARIA DEVOLVEU" enquanto a ordem estiver em_carregamento com devolvido_em.
-- Risco: baixo — só colunas novas.
alter table public.romaneios add column if not exists devolvido_em timestamptz;
alter table public.romaneios add column if not exists devolvido_por text;
