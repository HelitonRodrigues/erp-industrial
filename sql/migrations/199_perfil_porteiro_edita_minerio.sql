-- (25/11) Perfil PRE = cópia do Porteiro (PRT) + edição na aba Caulim e Grafitoso (minério) da Portaria.
-- Wagner Rafael (wagner.portaria) passou de PRT para PRE.
insert into perfis (codigo,nome,descricao,cor,permissoes)
select 'PRE','Porteiro + edição Caulim e Grafitoso','Igual ao Porteiro (PRT), com edição na aba Caulim e Grafitoso (minério) da Portaria.',cor,
  jsonb_set(permissoes,'{portaria,abas,minerio,edit}','true'::jsonb)
from perfis where codigo='PRT' and not exists (select 1 from perfis where codigo='PRE');
update usuarios set perfil='PRE', atualizado_em=now() where login='wagner.portaria' and perfil='PRT';
