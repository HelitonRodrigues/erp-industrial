-- 051 — Certificado de análise (laudo do Laboratório) acompanha a carga
--
-- O laudo continua sendo da OP (laboratorio.html → aba Laudo). O que muda:
-- • Ao FINALIZAR, o laboratório grava a folha pronta no Storage
--   (documentos/laudos/<numero>.html) → lab_laudos.arquivo_path. Assim Carregamento
--   e Portaria imprimem o certificado sem precisar montar nada.
-- • Ao SALVAR a carga, carregamento.html liga sozinho cada OP carregada ao laudo dela
--   em lab_laudo_carregamentos (origem='carregamento'), com quantidade, cliente e ordem.
-- • lab_laudo_carregamentos ganha as colunas que o registro MANUAL da aba Laudo já
--   mandava (nota_fiscal, obs, criado_por) e o insert falhava sem elas.
-- Risco: baixo — só colunas novas.

alter table public.lab_laudos add column if not exists arquivo_path text;

alter table public.lab_laudo_carregamentos add column if not exists nota_fiscal  text;
alter table public.lab_laudo_carregamentos add column if not exists obs          text;
alter table public.lab_laudo_carregamentos add column if not exists criado_por   text;
alter table public.lab_laudo_carregamentos add column if not exists origem       text not null default 'manual';  -- 'manual' | 'carregamento'
alter table public.lab_laudo_carregamentos add column if not exists ordem_numero text;
alter table public.lab_laudo_carregamentos add column if not exists placa        text;
alter table public.lab_laudo_carregamentos add column if not exists produto      text;
alter table public.lab_laudo_carregamentos add column if not exists op_numero    text;
alter table public.lab_laudo_carregamentos add column if not exists sugerido     boolean not null default false; -- granel: laudo mais recente do produto (sem OP no pallet)
create index if not exists lab_laudo_carr_carga_idx on public.lab_laudo_carregamentos (carregamento_id);
create index if not exists lab_laudo_carr_rom_idx   on public.lab_laudo_carregamentos (romaneio_id);
create index if not exists lab_laudo_carr_laudo_idx on public.lab_laudo_carregamentos (laudo_id);
