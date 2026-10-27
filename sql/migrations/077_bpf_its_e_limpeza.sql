-- 077 — BPF: instruções de trabalho (IT) de uma página + limpeza do que era antigo
-- (aplicado direto no banco em 27/10/2026; o texto das 16 ITs está em bpf_documentos_mestre.conteudo)
alter table public.bpf_documentos_mestre add column if not exists conteudo jsonb;   -- texto da IT de uma página
-- formulários antigos em papel/planilha (fora de POP e registros): saem
delete from public.bpf_documentos;
-- gatilho marcado como 'não usado'
delete from public.bpf_gatilhos where codigo='g_emb_almox';
-- pendências anteriores à implantação (26/10/2026) que nunca viraram ficha
update public.bpf_tarefas set status='cancelada', cancelada_por='Sistema', cancelada_motivo='Limpeza da implantação do BPF — pendência anterior a 26/10/2026 sem ficha' where status='aberta' and registro_id is null and criado_em < '2026-10-26';
-- arquivos do Storage que nada mais usa (o ERP apaga pela API de Storage ao abrir o BPF)
create or replace function public.bpf_arquivos_orfaos() returns setof text language sql stable security definer set search_path=public,storage as $$
  select o.name from storage.objects o where o.bucket_id='documentos' and o.name like 'bpf/%'
    and o.name not in (select arquivo_path from bpf_documentos_mestre where arquivo_path is not null)
    and o.name not in (select arquivo_path from bpf_documento_revisoes where arquivo_path is not null)
    and not exists (select 1 from bpf_reclamacoes r where r::text like '%'||o.name||'%')
    and not exists (select 1 from bpf_registros r where r::text like '%'||o.name||'%')
    and not exists (select 1 from bpf_treinamentos r where r::text like '%'||o.name||'%');
$$;
grant execute on function public.bpf_arquivos_orfaos() to authenticated;
update public.bpf_documentos_mestre set status='vigente', revisao='00', data_emissao=coalesce(data_emissao,current_date), data_revisao=coalesce(data_revisao,current_date) where tipo='it' and conteudo is not null;
