-- 036 — Análise de pallet: justificativa da reprovação + anexos/fotos.
-- Aditiva: só cria colunas novas, não mexe no que existe.
alter table public.lab_pallet_analises add column if not exists justificativa text;
alter table public.lab_pallet_analises add column if not exists anexos jsonb not null default '[]'::jsonb;
comment on column public.lab_pallet_analises.anexos is
  'Anexos/fotos da análise: [{nome, path, mime, tamanho, enviado_em}] — path dentro do bucket lab-fotos.';
