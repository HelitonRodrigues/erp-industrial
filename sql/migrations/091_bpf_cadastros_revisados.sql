-- 091 — BPF: cadastros revisados (aplicado direto no banco em 28/10/2026)
-- • Fornecedores: sai bpf_fornecedores_qualif (JRMFJR e BAUMIN repetidos 7x). A lista passa a ser a do COMPRAS
--   (almoxarifado_fornecedores com bpf_categoria) e a homologação é o REG-POP01-02. JRMFJR e BAUMIN incluídos no Compras.
-- • Pesos-padrão: sai o cadastro, a coluna peso_padrao_id das calibrações e a trava peso_padrao_vencido.
-- • Laboratórios: Eurofins estava 7x — fica 1. REG-POP17-01 passa a ser 1 por laboratório cadastrado por ano.
-- • Designações: as de funcionários inativos (Anderson, Damião, Genildo) foram desativadas.
--   O cadastro "Designações" sai do menu — quem participa de cada POP é definido em ⚙️ Configurar do POP.
insert into almoxarifado_fornecedores (razao_social, nome_fantasia, cnpj, categoria, bpf_categoria, obs)
select v.r, v.n, v.c, 'Matéria-prima', 'materia_prima', 'Mineração do grupo — fornecedor de matéria-prima (POP-01 6.b, risco A)'
  from (values ('JRMFJR Mineração','JRMFJR Mineração','01.106.382/0001-03'),('BAUMIN Mineração','BAUMIN Mineração','18.925.823/0001-78')) v(r,n,c)
 where not exists (select 1 from almoxarifado_fornecedores f where regexp_replace(coalesce(f.cnpj,''),'\D','','g')=regexp_replace(v.c,'\D','','g'));
drop table if exists public.bpf_fornecedores_qualif cascade;
delete from bpf_travas where codigo='peso_padrao_vencido';
alter table if exists public.bpf_calibracoes drop column if exists peso_padrao_id;
drop table if exists public.bpf_pesos_padrao cascade;
