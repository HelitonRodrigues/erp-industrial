-- (23/11/2026) aplicado no Supabase. Revisão das designações dos 34 formulários (tabela do Heliton, 23/11).
-- Funções novas: escala_linha (Pessoal da linha — escala; assina só no papel, lançado por quem coleta) e portaria.
-- Cadeias: POP03-01, 06-01, 18-01 executante = pessoal da linha; 18-02 = Ryan → pessoal da linha → Qualidade;
--   04-02 = Portaria → encarregado; 21-01 = Portaria → encarregado → Qualidade; 07-02, 09-01, 09-02 = terceiros (só papel).
-- Designações: Ryan só POP-04 (encarregado, uniformes), 05, 08, 14, 18; saíram Juraci, Heliton no POP-09, Kaique (auditor),
--   operadores Lucas/Henrique (POP-06/18 agora pela escala); entraram os 5 porteiros em POP-04 e POP-21. Diretoria (POP-11) e auditor: sem ninguém.
insert into bpf_funcoes (codigo,nome,ordem,ativo) values ('escala_linha','Pessoal da linha (escala)',90,true),('portaria','Portaria',91,true)
 on conflict (codigo) do update set nome=excluded.nome, ativo=true;
update bpf_formularios set assinaturas='[{"id":"exec","label":"Executante (pessoal da linha)","funcao":"escala_linha","obrigatoria":true},{"id":"encar","label":"Encarregado","funcao":"encarregado_prod","obrigatoria":true},{"id":"qual","label":"Qualidade","funcao":"gerente_qual"}]'::jsonb where codigo='REG-POP03-01';
update bpf_formularios set assinaturas='[{"id":"port","label":"Portaria","funcao":"portaria","obrigatoria":true},{"id":"resp","label":"Liberação (encarregado)","funcao":"encarregado_prod","obrigatoria":true}]'::jsonb where codigo='REG-POP04-02';
update bpf_formularios set assinaturas='[{"id":"exec","label":"Executante (pessoal da linha)","funcao":"escala_linha","obrigatoria":true},{"id":"encar","label":"Encarregado","funcao":"encarregado_prod"},{"id":"qual","label":"Qualidade","funcao":"gerente_qual"}]'::jsonb where codigo in ('REG-POP06-01','REG-POP18-01');
update bpf_formularios set assinaturas='[{"id":"resp","label":"Manutenção (terceiros)","funcao":"terceirizada","obrigatoria":true},{"id":"qual","label":"Qualidade","funcao":"gerente_qual","obrigatoria":true}]'::jsonb where codigo='REG-POP07-02';
update bpf_formularios set assinaturas='[{"id":"exec","label":"Executante (terceiros)","funcao":"terceirizada","obrigatoria":true}]'::jsonb where codigo='REG-POP09-01';
update bpf_formularios set assinaturas='[{"id":"resp","label":"Responsável (terceiros)","funcao":"terceirizada","obrigatoria":true},{"id":"qual","label":"Qualidade","funcao":"gerente_qual"}]'::jsonb where codigo='REG-POP09-02';
update bpf_formularios set assinaturas='[{"id":"exec","label":"Executante","funcao":"servicos_gerais","obrigatoria":true},{"id":"linha","label":"Pessoal da linha","funcao":"escala_linha","obrigatoria":true},{"id":"qual","label":"Qualidade","funcao":"gerente_qual","obrigatoria":true}]'::jsonb where codigo='REG-POP18-02';
update bpf_formularios set assinaturas='[{"id":"port","label":"Portaria","funcao":"portaria","obrigatoria":true},{"id":"insp","label":"Inspetor (encarregado)","funcao":"encarregado_prod","obrigatoria":true},{"id":"qual","label":"Qualidade","funcao":"gerente_qual"}]'::jsonb where codigo='REG-POP21-01';
update bpf_designacoes set ativo=false, data_fim=current_date-1, obs=coalesce(obs||' · ','')||'23/11: saiu na revisão das designações (Heliton)'
 where ativo and ((funcionario_nome='Ryan Almeida da Silva' and pop_cod is null) or funcionario_nome='Juraci Machado de Proenca'
   or (funcionario_nome='Heliton José de Almeida Rodrigues' and pop_cod='POP-09') or (funcionario_nome='Kaique Oliveira Proença' and funcao_cod='auditor_interno')
   or (funcao_cod='operador_maq' and pop_cod in ('POP-06','POP-18')));
insert into bpf_designacoes (funcionario_id,funcionario_nome,funcao_cod,pop_cod,data_inicio,ativo,designado_por,obs,usuario_id,papeis)
select f.id,'Ryan Almeida da Silva',x.fn,x.pop,current_date,true,'Heliton (revisão 23/11)','Revisão das designações 23/11',(select id from usuarios where nome='Ryan Almeida da Silva' limit 1),'{assina}'
from (values ('encarregado_prod','POP-04'),('servicos_gerais','POP-05'),('servicos_gerais','POP-08'),('servicos_gerais','POP-14'),('servicos_gerais','POP-18')) x(fn,pop)
left join funcionarios f on f.nome ilike 'Ryan Almeida da Silva';
insert into bpf_designacoes (funcionario_id,funcionario_nome,funcao_cod,pop_cod,data_inicio,ativo,designado_por,obs,usuario_id,papeis)
select null,u.nome,'portaria',p.pop,current_date,true,'Heliton (revisão 23/11)','Portaria — revisão 23/11',u.id,'{assina}'
from usuarios u cross join (values ('POP-04'),('POP-21')) p(pop) where u.perfil in ('PRT','PRB') and u.status='ativo';
update bpf_tarefas set funcao_cod='escala_linha' where status='aberta' and formulario_cod in ('REG-POP03-01','REG-POP06-01','REG-POP18-01');
update bpf_tarefas set funcao_cod='terceirizada' where status='aberta' and formulario_cod in ('REG-POP07-02','REG-POP09-01','REG-POP09-02');
update bpf_tarefas set funcao_cod='portaria' where status='aberta' and formulario_cod in ('REG-POP04-02','REG-POP21-01');
