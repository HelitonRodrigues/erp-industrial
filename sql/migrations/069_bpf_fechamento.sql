-- 069 — BPF: fechamento das pendências
-- (1) os 17 formulários antigos (PDF de papel) ficam ligados ao documento de cada um
alter table public.bpf_documentos add column if not exists documento_cod text;
update public.bpf_documentos d set documento_cod = m.cod
  from (values
    ('%form002%','REG-POP01-01'),('%form003%','REG-POP03-01'),('%form004%','REG-POP04-01'),
    ('%form005%','REG-POP05-01'),('%form006%','REG-POP06-01'),('%form007%','REG-POP08-01'),
    ('%form008%','REG-POP09-01'),('%form009%','REG-POP14-01'),('%form010%','REG-POP18-01'),
    ('%form011%','REG-POP18-02'),('%form012_check%','REG-POP07-01'),('%form012_reclama%','REG-POP19-01'),
    ('%homologa%forn%','REG-POP01-02'),('%manuten%corretiva%','REG-POP07-01'),
    ('%manual silicate%','MAN-01'),('%lista_mestra%','REG-POP12-01')) m(padrao,cod)
 where lower(d.nome) like m.padrao and d.documento_cod is null;

-- (2) POP-13: o lote de MP precisa ser compatível com o produto da OP (limite de MP por produto)
update public.bpf_formularios set campos = campos || jsonb_build_array(
    jsonb_build_object('id','mp_produto','tipo','texto','label','Produto/variação do lote de MP','ajuda','Vem do Laboratório (lote de MP)'),
    jsonb_build_object('id','mp_aprovada','tipo','sim_nao','label','Lote de MP aprovado no Laboratório (cor/ΔE)?','conforme','sim'),
    jsonb_build_object('id','mp_compativel','tipo','sim_nao','label','Lote de MP dentro do limite do produto da OP?','conforme','sim'))
 where codigo='REG-POP13-01' and not exists (select 1 from jsonb_array_elements(campos) c where c->>'id'='mp_compativel');
