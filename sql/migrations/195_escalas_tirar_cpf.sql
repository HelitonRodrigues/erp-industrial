-- 195 — Tira CPF e e-mail das escalas e do acompanhamento da ensacadeira.
-- As escalas guardavam uma cópia do CPF/e-mail de cada pessoa escalada, e a
-- ensacadeira copiava o encarregado da escala. As duas tabelas são abertas a
-- qualquer usuário logado. O código novo (escala.html) já não grava mais.
-- Antes de limpar, guarda cópia trancada (RLS ligado, sem policy).

create table if not exists public.escalas_cpf_backup_2026_11 as
  select id, encarregado, operador, linhas, limpeza, ferias, ausencias, turno2, turno3, operadores, historico, now() as copiado_em
  from public.escalas;
alter table public.escalas_cpf_backup_2026_11 enable row level security;

create table if not exists public.ensacadeira_acomp_cpf_backup_2026_11 as
  select id, encarregado, now() as copiado_em from public.ensacadeira_acompanhamento;
alter table public.ensacadeira_acomp_cpf_backup_2026_11 enable row level security;

-- remove as chaves "cpf" e "email" em qualquer nível do JSON
create or replace function public._jsonb_sem_pessoais(j jsonb) returns jsonb
language sql immutable as $$
  select case jsonb_typeof(j)
    when 'object' then (select coalesce(jsonb_object_agg(k, public._jsonb_sem_pessoais(v)), '{}'::jsonb)
                        from jsonb_each(j) e(k, v) where k not in ('cpf', 'email'))
    when 'array'  then (select coalesce(jsonb_agg(public._jsonb_sem_pessoais(v) order by n), '[]'::jsonb)
                        from jsonb_array_elements(j) with ordinality a(v, n))
    else j end;
$$;

update public.escalas set
  encarregado = public._jsonb_sem_pessoais(encarregado),
  operador    = public._jsonb_sem_pessoais(operador),
  linhas      = public._jsonb_sem_pessoais(linhas),
  limpeza     = public._jsonb_sem_pessoais(limpeza),
  ferias      = public._jsonb_sem_pessoais(ferias),
  ausencias   = public._jsonb_sem_pessoais(ausencias),
  turno2      = public._jsonb_sem_pessoais(turno2),
  turno3      = public._jsonb_sem_pessoais(turno3),
  operadores  = public._jsonb_sem_pessoais(operadores),
  historico   = public._jsonb_sem_pessoais(historico);

update public.ensacadeira_acompanhamento
  set encarregado = public._jsonb_sem_pessoais(encarregado)
  where encarregado::text ~* '"(cpf|email)"';

drop function public._jsonb_sem_pessoais(jsonb);
