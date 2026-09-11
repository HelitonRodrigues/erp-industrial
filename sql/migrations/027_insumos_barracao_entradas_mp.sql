-- 027 — Barracão nos movimentos/lotes + Entradas de MP com documentos anexados.
-- Aditiva: nenhuma coluna existente muda de tipo, nada é removido.

alter table insumos_movimentos add column if not exists barracao text;
alter table insumos_lotes     add column if not exists barracao text;
alter table insumos_lotes     add column if not exists entrada_id uuid;

create index if not exists ix_ins_mov_barracao on insumos_movimentos(barracao);
create index if not exists ix_ins_mov_insumo_data on insumos_movimentos(insumo_id, data);

-- Entrada de matéria-prima: um registro por carga recebida, com o documento anexado.
create table if not exists insumos_entradas_mp (
  id               uuid primary key default uuid_generate_v4(),
  numero           text unique,                 -- EMP-20260911-0001
  data             date not null,
  insumo_id        uuid not null references insumos(id),
  barracao         text,                        -- Barracão Antigo | Barracão Imetec | Barracão Longa Vida
  frente           text,                        -- frente de lavra / origem do material
  fornecedor       text,
  fornecedor_id    uuid,
  viagens          numeric default 0,
  peso_por_viagem  numeric default 20000,       -- kg por viagem (padrão da planilha)
  quantidade       numeric not null default 0,  -- na unidade de estoque do insumo (ton)
  quantidade_kg    numeric,                     -- espelho em kg, como a fábrica fala
  umidade_pct      numeric,
  lote             text,
  lote_id          uuid references insumos_lotes(id),
  doc_tipo         text,                        -- NF-e | Ticket de pesagem | Romaneio | Outro
  doc_numero       text,
  doc_serie        text,
  doc_chave        text,
  doc_emissao      date,
  doc_valor        numeric,
  placa            text,
  motorista        text,
  anexos           jsonb not null default '[]'::jsonb,  -- [{nome,path,mime,tamanho,enviado_em}]
  obs              text,
  status           text not null default 'lancado',     -- rascunho | lancado | cancelado
  movimento_id     uuid references insumos_movimentos(id),
  criado_por       text,
  criado_em        timestamptz default now(),
  atualizado_em    timestamptz default now()
);

create index if not exists ix_emp_data     on insumos_entradas_mp(data);
create index if not exists ix_emp_insumo   on insumos_entradas_mp(insumo_id, data);
create index if not exists ix_emp_barracao on insumos_entradas_mp(barracao);
create index if not exists ix_emp_lote     on insumos_entradas_mp(lote);

-- Bucket privado para os documentos das entradas de MP (Storage, não base64 no Postgres).
insert into storage.buckets (id, name, public, file_size_limit)
values ('insumos-docs', 'insumos-docs', false, 26214400)
on conflict (id) do nothing;
