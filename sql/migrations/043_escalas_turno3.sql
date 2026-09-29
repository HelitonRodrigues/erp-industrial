-- 043: 3º turno na escala (mesma estrutura de turno2)
alter table public.escalas add column if not exists turno3 jsonb;
comment on column public.escalas.turno3 is '3º turno da escala (mesma estrutura de turno2: turno_id, turno_nome, encarregado, operador, linhas, limpeza, ferias, ausencias)';
notify pgrst, 'reload schema';
