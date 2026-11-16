-- (16/11/2026) Fechamento da portaria: quem fecha o dia assina (desenho) — sai no PDF no lugar de Portaria
alter table public.portaria_fechamentos add column if not exists assinatura_img text;
alter table public.portaria_fechamentos add column if not exists assinatura_nome text;
