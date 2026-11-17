-- (17/11/2026) LAUDO DO CAULIM GRANEL CINZA (sem QR) para a DSM — aplicada no Supabase em 17/11.
-- empresa_config.granel_lote_atual/_em/_por (lote "saindo agora", marcado pelo laboratório); dsm_caminhoes.lote_granel
-- tg_dsm_lote_granel (novo caminhão pega o lote atual) · lab_granel_liga_dsm(id) + tg_dsm_liga_laudo (liga/religa o certificado,
-- lab_laudo_carregamentos origem 'dsm', obs 'dsm:<id>') · tg_lab_laudo_liga_cargas também liga a DSM do lote ·
-- lab_granel_liberar(dia, usuario): OP provisória (se não houver) + registro de granel aprovado para o laudo sair.
-- Definições completas: ver o histórico de migrações do Supabase (145_granel_laudo_dsm).
alter table public.empresa_config add column if not exists granel_lote_atual text, add column if not exists granel_lote_em timestamptz, add column if not exists granel_lote_por text;
alter table public.dsm_caminhoes add column if not exists lote_granel text;
