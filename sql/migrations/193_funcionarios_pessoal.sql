-- 193 — Dados pessoais e salário dos funcionários saem da tabela aberta.
-- PASSO 1 de 2 (aditivo, não apaga nada):
--   • cria funcionarios_pessoal (CPF, RG, nascimento, telefone, e-mail,
--     endereço, PIS, CNH, CTPS, custos/salário) — só RH/Funcionários/
--     Usuários/Custos enxergam.
--   • copia os dados atuais.
--   • gatilho de transição: se alguma tela antiga ainda gravar nas colunas
--     velhas, copia para a tabela nova. Sai no passo 2 (migration 194).
--   • funcionarios_custo_hora(): a Manutenção recebe só o custo/hora,
--     sem ver CPF nem salário.

create table if not exists public.funcionarios_pessoal (
  funcionario_id uuid primary key references public.funcionarios(id) on delete cascade,
  cpf text, rg text, nascimento date, telefone text, email text,
  endereco text, pis text, cnh text, ctps text, custos jsonb,
  atualizado_em timestamptz not null default now()
);

insert into public.funcionarios_pessoal
  (funcionario_id, cpf, rg, nascimento, telefone, email, endereco, pis, cnh, ctps, custos)
select id, cpf, rg, nascimento, telefone, email, endereco, pis, cnh, ctps, custos
from public.funcionarios
on conflict (funcionario_id) do nothing;

alter table public.funcionarios_pessoal enable row level security;
drop policy if exists por_modulo on public.funcionarios_pessoal;
create policy por_modulo on public.funcionarios_pessoal for all to authenticated
  using (auth_pode_modulo('funcionarios') or auth_pode_modulo('rh') or auth_pode_modulo('usuarios')
         or auth_pode_modulo('custo_precificacao') or auth_pode_modulo('custos'))
  with check (auth_pode_modulo('funcionarios') or auth_pode_modulo('rh') or auth_pode_modulo('usuarios')
         or auth_pode_modulo('custo_precificacao') or auth_pode_modulo('custos'));

-- gatilho de transição (removido na 194)
create or replace function public._func_pessoal_sync() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    insert into funcionarios_pessoal (funcionario_id, cpf, rg, nascimento, telefone, email, endereco, pis, cnh, ctps, custos)
    values (new.id, new.cpf, new.rg, new.nascimento, new.telefone, new.email, new.endereco, new.pis, new.cnh, new.ctps, new.custos)
    on conflict (funcionario_id) do nothing;
  else
    insert into funcionarios_pessoal (funcionario_id, cpf, rg, nascimento, telefone, email, endereco, pis, cnh, ctps, custos)
    values (new.id, new.cpf, new.rg, new.nascimento, new.telefone, new.email, new.endereco, new.pis, new.cnh, new.ctps, new.custos)
    on conflict (funcionario_id) do update set
      cpf=excluded.cpf, rg=excluded.rg, nascimento=excluded.nascimento, telefone=excluded.telefone,
      email=excluded.email, endereco=excluded.endereco, pis=excluded.pis, cnh=excluded.cnh,
      ctps=excluded.ctps, custos=excluded.custos, atualizado_em=now();
  end if;
  return new;
end $$;

drop trigger if exists trg_func_pessoal_ins on public.funcionarios;
create trigger trg_func_pessoal_ins after insert on public.funcionarios
  for each row execute function public._func_pessoal_sync();
drop trigger if exists trg_func_pessoal_upd on public.funcionarios;
create trigger trg_func_pessoal_upd after update of cpf, rg, nascimento, telefone, email, endereco, pis, cnh, ctps, custos
  on public.funcionarios for each row execute function public._func_pessoal_sync();

-- custo/hora para Manutenção e Custos, sem expor o resto
create or replace function public.funcionarios_custo_hora()
returns jsonb language sql stable security definer set search_path = public as $$
  select case when auth_pode_modulo('manutencao') or auth_pode_modulo('custos') or auth_pode_modulo('custo_precificacao')
    then coalesce((select jsonb_agg(jsonb_build_object('id', f.id, 'nome', f.nome, 'custo_hora', p.custos->>'custo_hora'))
                   from funcionarios f join funcionarios_pessoal p on p.funcionario_id = f.id
                   where f.status = 'ativo' and p.custos ? 'custo_hora'), '[]'::jsonb)
    else '[]'::jsonb end;
$$;
revoke all on function public.funcionarios_custo_hora() from public, anon;
grant execute on function public.funcionarios_custo_hora() to authenticated;
