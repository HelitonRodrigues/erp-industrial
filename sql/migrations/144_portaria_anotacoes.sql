-- (17/11/2026) 📝 anotações na fila da portaria: [{txt, por, em}]
alter table public.portaria add column if not exists anotacoes jsonb not null default '[]'::jsonb;
