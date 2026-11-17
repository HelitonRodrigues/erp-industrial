-- (17/11/2026) chamado do pátio: resposta da portaria ('vou_chamar' | 'ausente' = motorista não está no pátio)
alter table public.portaria_chamados add column if not exists resposta text;
