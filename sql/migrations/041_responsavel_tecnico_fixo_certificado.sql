-- 041 — Responsável Técnico do certificado: FIXO, configurado uma vez para a
--       empresa (aba Laudo → ⚙️ Responsável Técnico). Aditiva.
alter table public.empresa_config add column if not exists rt_funcionario_id uuid;
alter table public.empresa_config add column if not exists rt_nome text;
alter table public.empresa_config add column if not exists rt_cargo text;
alter table public.empresa_config add column if not exists rt_registro text;
-- quem clicou em finalizar (o RT é quem aparece no certificado)
alter table public.lab_laudos add column if not exists emitido_por text;
notify pgrst, 'reload schema';
