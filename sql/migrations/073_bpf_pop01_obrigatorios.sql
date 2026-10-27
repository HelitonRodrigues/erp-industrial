-- 073 — BPF POP-01: Fornecedor e Nota fiscal obrigatórios no check list (quando não vierem do ERP, a pessoa preenche)
update public.bpf_formularios set campos=(select jsonb_agg(case when c->>'id' in ('fornecedor','nota_fiscal') then c||'{"obrigatorio":true}'::jsonb else c end order by o)
  from jsonb_array_elements(campos) with ordinality e(c,o)) where codigo='REG-POP01-01';
