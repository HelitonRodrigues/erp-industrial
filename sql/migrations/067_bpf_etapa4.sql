-- 067 — BPF etapa 4: POP-01, POP-04 (vídeo DDS), POP-20 e travas
-- POP-20: preenche, imprime e anexa a folha → concluído (sem assinatura no sistema)
alter table public.bpf_formularios add column if not exists conclui_com_anexo boolean not null default false;
update public.bpf_formularios set conclui_com_anexo=true where codigo in ('REG-POP20-01','REG-POP20-03');

-- POP-20/002: 15 dias depois do treinamento → avaliação de cada pessoa (observação prática em campo)
update public.bpf_gatilhos set ativo=true, fonte_tabela='bpf_registros', prazo_horas=360,
  filtro='{"desde":"2026-10-26"}'::jsonb, evento='15 dias após o treinamento (REG-POP20-01) — avaliação de cada participante'
 where codigo='g_treino';

-- POP-04: vídeo de integração (DDS curto) é um documento controlado, com versão
insert into public.bpf_documentos_mestre (codigo,tipo,titulo,revisao,status,pop_cod,grupo,ordem,observacao)
select 'IT-POP04-03','it','Vídeo de integração BPF — motoristas e visitantes (DDS)','00','rascunho','POP-04','pre_requisito',43,
       'Anexe o vídeo (mp4) em 📎 Anexar. Cada troca de vídeo = nova versão; o registro do visitante grava qual versão ele viu.'
 where not exists (select 1 from public.bpf_documentos_mestre where codigo='IT-POP04-03');
update public.bpf_formularios set campos = (
  select jsonb_agg(x order by ord) from (
    select c x, o::numeric ord from jsonb_array_elements(campos) with ordinality e(c,o)
    union all select jsonb_build_object('id','video_versao','tipo','texto','label','Versão do vídeo assistido','ajuda','Preenchido pelo sistema'),
      (select o from jsonb_array_elements(campos) with ordinality e(c,o) where c->>'id'='video_assistido')+0.5) z)
 where codigo='REG-POP04-02' and not exists (select 1 from jsonb_array_elements(campos) c where c->>'id'='video_versao');

-- POP-01/002: fichas de qualificação para levar aos fornecedores de embalagem
insert into public.bpf_registros (formulario_cod,pop_cod,data,campos,status,conforme,anexos,assinaturas,assinaturas_papel,criado_por)
select 'REG-POP01-02','POP-01',current_date,
       jsonb_build_object('nome',f.nome,'categoria','A — contato direto (MP e embalagens)','tipo_forn',f.tipo,'status','Em homologação'),
       'a_preencher',true,'[]'::jsonb,'[]'::jsonb,'{}'::jsonb,'Sistema (POP-01)'
  from (values ('Logpel','Embalagem — confirmar o tipo'),('Baumin','Embalagem — confirmar o tipo'),('José Reinaldo','Embalagem — confirmar o tipo')) f(nome,tipo)
 where not exists (select 1 from public.bpf_registros r where r.formulario_cod='REG-POP01-02' and r.campos->>'nome'=f.nome);
