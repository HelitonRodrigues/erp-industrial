-- 194 — PASSO 2 de 2. RODAR SÓ DEPOIS que as telas novas estiverem no ar
-- e testadas (funcionarios, usuarios, rh, escala, custo-precificacao,
-- manutencao). Apaga as colunas pessoais da tabela aberta `funcionarios`.
-- Os dados já estão em funcionarios_pessoal (migration 193).

drop trigger if exists trg_func_pessoal_ins on public.funcionarios;
drop trigger if exists trg_func_pessoal_upd on public.funcionarios;
drop function if exists public._func_pessoal_sync();

alter table public.funcionarios
  drop column if exists cpf,      drop column if exists rg,
  drop column if exists nascimento, drop column if exists telefone,
  drop column if exists email,    drop column if exists endereco,
  drop column if exists pis,      drop column if exists cnh,
  drop column if exists ctps,     drop column if exists custos;
