-- 062 — BPF: histórico de versões dos documentos (POP, IT, REG, Manual)
-- Cada "Nova versão" guarda a versão anterior (com o arquivo dela) em
-- bpf_documento_revisoes e a lista mestra passa a apontar para a nova.
-- Aqui só entram os campos que descrevem a versão ATUAL (o que mudou e quem fez).
alter table public.bpf_documentos_mestre
  add column if not exists alteracao_atual text,   -- o que mudou nesta versão
  add column if not exists revisado_por    text;   -- quem publicou esta versão
create index if not exists bpf_documento_revisoes_cod_idx on public.bpf_documento_revisoes (documento_cod, created_at desc);
