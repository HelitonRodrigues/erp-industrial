-- 065 — BPF POP-15: dados do laboratório entram sozinhos
-- 001 boletim/aprovação da linha ← laboratorio · 002 certificado ← lab_laudos · 003 rótulo com croqui + 1º lote automático
update public.bpf_gatilhos set fonte_tabela='laboratorio', ativo=true, filtro='{"desde":"2026-10-26"}'::jsonb,
  evento='Análise de linha no laboratório (OK/Ajuste) — registro digital, valores do laboratório'
 where codigo='g_boletim';
update public.bpf_gatilhos set fonte_tabela='lab_laudos', ativo=true, filtro='{"desde":"2026-10-26"}'::jsonb,
  evento='Laudo emitido no laboratório — certificado entra no BPF'
 where codigo='g_cert';

-- REG-POP15-03: o croqui (arquivo do rótulo) é obrigatório e o 1º lote com a versão nova entra sozinho
update public.bpf_formularios set exige_anexo=true,
  campos = campos || jsonb_build_array(
    jsonb_build_object('id','primeiro_lote','tipo','texto','label','Primeiro lote com esta versão','ajuda','Preenchido pelo sistema com o 1º lote produzido depois da aprovação'),
    jsonb_build_object('id','op_primeiro','tipo','texto','label','OP do primeiro lote','ajuda','Preenchido pelo sistema'))
 where codigo='REG-POP15-03'
   and not exists (select 1 from jsonb_array_elements(campos) c where c->>'id'='primeiro_lote');

-- Formulário que não tem ficha em papel (preenchido direto no sistema): não pede foto
alter table public.bpf_formularios add column if not exists sem_papel boolean not null default false;
update public.bpf_formularios set sem_papel=true where codigo='REG-POP15-03';
