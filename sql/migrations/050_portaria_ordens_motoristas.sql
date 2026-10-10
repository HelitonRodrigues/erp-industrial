-- 050 — Portaria: ordem de carregamento lida do PDF, cadastro de motoristas, fila por chegada
--
-- • motoristas            → cadastro de motoristas de carga (aba Motoristas da Portaria).
--                            (lenha_motoristas é outro cadastro — fornecedores de lenha — não mexe.)
-- • romaneios             → + dados que vêm no PDF (caminhão, paletes, bags, mapa do baú, sacos),
--                            arquivo no Storage, e quando a portaria liberou para carregar.
-- • romaneio_itens        → + frete, unidades (plt) e ordem de entrega do cliente.
-- • portaria              → + vínculo com a ordem e o motorista, horários de chamada/início,
--                            motivo quando alguém passa na frente da fila.
-- Fluxo: chegada (fila) → vincula ordem → "Iniciar carregamento" (respeita a ordem de chegada)
--        → romaneios.status = 'em_carregamento' → aparece em carregamento.html
--        → carregamento salva → 'carregado' → portaria pesa a saída → 'finalizado'.
-- Risco: baixo — só tabela nova e colunas novas (todas opcionais).

create table if not exists public.motoristas (
  id             uuid primary key default gen_random_uuid(),
  nome           text not null,
  cpf            text,
  cnh            text,
  cnh_validade   date,
  celular        text,
  transportadora text,
  placa          text,                 -- cavalo / caminhão
  placa2         text,                 -- carreta
  tipo_veiculo   text,
  observacao     text,
  ativo          boolean not null default true,
  visitas        integer not null default 0,
  ultima_visita  timestamptz,
  criado_em      timestamptz not null default now(),
  atualizado_em  timestamptz not null default now()
);
create unique index if not exists motoristas_cpf_uk on public.motoristas (cpf) where cpf is not null and cpf <> '';
create index if not exists motoristas_nome_idx on public.motoristas (lower(nome));
alter table public.motoristas enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where tablename='motoristas' and policyname='baseline_authenticated_all') then
    create policy baseline_authenticated_all on public.motoristas for all to authenticated using (true) with check (true); end if;
end $$;

alter table public.romaneios add column if not exists caminhao        text;
alter table public.romaneios add column if not exists paletes         integer;
alter table public.romaneios add column if not exists bags            integer;
alter table public.romaneios add column if not exists sacos           numeric;
alter table public.romaneios add column if not exists mapa            jsonb;      -- [{fila,esq:{ordem,pedido},dir:{...}}] frente → fundo
alter table public.romaneios add column if not exists arquivo_path    text;       -- Storage: documentos/portaria/ordens/...
alter table public.romaneios add column if not exists portaria_id     uuid;
alter table public.romaneios add column if not exists liberado_em     timestamptz; -- portaria clicou "Iniciar carregamento"
alter table public.romaneios add column if not exists liberado_por    text;

alter table public.romaneio_itens add column if not exists frete         text;
alter table public.romaneio_itens add column if not exists unidades      text;
alter table public.romaneio_itens add column if not exists ordem_entrega smallint;

alter table public.portaria add column if not exists romaneio_id        uuid references public.romaneios(id) on delete set null;
alter table public.portaria add column if not exists motorista_id       uuid references public.motoristas(id) on delete set null;
alter table public.portaria add column if not exists placa2             text;
alter table public.portaria add column if not exists cpf                text;
alter table public.portaria add column if not exists observacao         text;
alter table public.portaria add column if not exists registrado_por     text;
alter table public.portaria add column if not exists inicio_carregamento timestamptz;
alter table public.portaria add column if not exists iniciado_por       text;
alter table public.portaria add column if not exists fura_fila_motivo   text;   -- preenchido quando passou na frente de quem chegou antes
alter table public.portaria add column if not exists finalizado_por     text;
create index if not exists portaria_chegada_idx on public.portaria (hora_chegada);
create index if not exists portaria_romaneio_idx on public.portaria (romaneio_id);

comment on table public.motoristas is 'Portaria: cadastro de motoristas de carga (chegada puxa celular, placa, transportadora).';
