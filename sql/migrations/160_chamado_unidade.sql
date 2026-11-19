-- (18/11/2026) portaria_chamados.unidade: o pátio escolhe para qual unidade chama o caminhão. Aplicada (160_chamado_unidade).
alter table public.portaria_chamados add column if not exists unidade text;
