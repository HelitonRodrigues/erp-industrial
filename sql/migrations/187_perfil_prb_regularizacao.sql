-- (23/11/2026) aplicado no Supabase. Perfil PRB = Porteiro + BPF só da própria regularização (Thiago Rodrigues).
-- bpf.html: perfil PRB (PERFIS_SO_MINHA_REG) só vê a aba Regularização, filtrada pelos registros com o nome dele, e só assina por ele.
insert into perfis (codigo,nome,descricao,cor,permissoes)
select 'PRB','Porteiro + BPF (só a própria regularização)','Portaria completa + no BPF só a aba Regularização com os registros da própria pessoa (assinar).',cor,
  jsonb_set(permissoes,'{bpf}','{"view":true,"edit":true,"create":false,"delete":false,"export":false}'::jsonb)
from perfis where codigo='PRT' and not exists(select 1 from perfis where codigo='PRB');
update usuarios set perfil='PRB', atualizado_em=now() where id='920a10d7-e088-48ec-a4ef-59fdaa75472b';   -- Thiago Rodrigues
