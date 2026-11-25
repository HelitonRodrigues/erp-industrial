-- 202 · Portal do representante: relatórios da portaria (DSM e Intercement) liberados por conta.
-- Só quem tem o código em prog_rep_contas.relatorios recebe os dados (conferido no servidor, função prog-rep).
alter table public.prog_rep_contas add column if not exists relatorios text[] not null default '{}';
comment on column public.prog_rep_contas.relatorios is 'Relatórios da portaria liberados no portal do representante: dsm, int (Intercement). Vazio = nenhum.';
update public.prog_rep_contas set relatorios = '{dsm,int}' where login = 'marcio';   -- Marcio Dias Cordeiro (275)
