-- 201 · Filito: dados fiscais lidos do PDF da nota (DANFE) para a aba 🧾 Faturamento da portaria-filito.html
-- Preenchidos ao subir o PDF (navegador) e, para as notas antigas, lidos uma vez dos PDFs já guardados.
alter table public.filito_viagens
  add column if not exists nf_valor numeric,
  add column if not exists nf_emissao timestamptz,
  add column if not exists nf_cliente text,
  add column if not exists nf_cliente_cnpj text,
  add column if not exists nf_produto text,
  add column if not exists nf_quantidade numeric,
  add column if not exists nf_unidade text,
  add column if not exists nf_preco_unit numeric,
  add column if not exists nf_peso_liquido numeric,
  add column if not exists nf_vencimento date,
  add column if not exists nf_chave text,
  add column if not exists nf_lido_em timestamptz;
comment on column public.filito_viagens.nf_valor is 'Valor total da NF lido do PDF (DANFE)';
comment on column public.filito_viagens.nf_lido_em is 'Quando os dados fiscais foram lidos do PDF (null = ainda não lidos)';
