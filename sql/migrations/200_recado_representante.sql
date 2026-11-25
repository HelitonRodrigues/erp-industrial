-- 200 · Recado da fábrica para o representante (programacao-cargas.html → representante.html via prog-rep)
-- {mot, ic, motivo, txt, em, por} — só informação; o pedido continua no dia. Some quando tirado ou quando carrega.
alter table public.programacao_cargas add column if not exists recado jsonb;
comment on column public.programacao_cargas.recado is 'Recado da fábrica ao representante: {mot,ic,motivo,txt,em,por}';
