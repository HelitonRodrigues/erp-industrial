-- 030 — Equipe presente na análise de linha.
-- O encarregado já vem da escala do período; a equipe é quem mais participou
-- da coleta ou do teste. Lista de nomes: pode vir do cadastro de funcionários
-- ou ser digitada (terceiro, visita, temporário).
alter table laboratorio add column if not exists equipe jsonb not null default '[]'::jsonb;
comment on column laboratorio.equipe is 'Nomes de quem participou, além do encarregado e do responsável pelo teste.';
