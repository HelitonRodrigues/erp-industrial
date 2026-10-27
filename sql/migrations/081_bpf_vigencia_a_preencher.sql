-- 081 — BPF: versão = data de vigência do POP; registros buscados a partir dela; POP-01/02/03 em "A preencher"
-- (aplicado direto no banco em 27/10/2026)
-- • bpf_documentos_mestre.data_vigencia: POPs com a vigência do PDF (05/08/2026; POP-04/11/12/15 e MAN-01: 08/09/2026);
--   REG e IT herdam a vigência do POP.
-- • bpf_reg_pop02: o REG-POP02-01 nasce em "A preencher" com os dados do lote de MP.
-- • Registros não concluídos dos POPs 01, 02 e 03 voltaram para "A preencher".
-- • Tarefas diárias de limpeza canceladas na implantação foram apagadas para nascerem de novo desde a vigência.
alter table public.bpf_documentos_mestre add column if not exists data_vigencia date;
