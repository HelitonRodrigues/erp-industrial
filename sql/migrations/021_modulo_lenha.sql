-- ============================================================================
-- 021 — Módulo LENHA (recebimento, fechamento semanal e cadastro)
--
-- Substitui a planilha RECEBIMENTO_DE_LENHA.xlsx (uma aba por caminhão, com a
-- via 1 e a via 2 do documento) e os FECHAMENTOS_*.xlsx (uma aba por fornecedor
-- por semana). O que era aba virou registro; o que era fórmula virou cálculo em
-- js/regras.js; o que era assinatura em papel virou assinatura na tela.
--
-- Contas espelhadas da planilha (mesmos nomes de campo do documento):
--   LIQUIDO        = BRUTO - TARA
--   MÉDIA (altura) = média de TODAS as medidas de LADO 1 + LADO 2 (=AVERAGE(C17:H18))
--   VOLUME (m³)    = MÉDIA × LARGURA × COMPRIMENTO
--   MÉDIA EM Kg/m³ = LIQUIDO ÷ VOLUME
--   Emitir nota de = TOTAL m³ do período × Preço do m³
--
-- Escopo: lenha para o pátio. Toras e serviço de corte seguem fora (decisão do dono).
-- Sem integração com estoque/custo nesta versão — o fluxo roda primeiro no galpão.
-- ============================================================================

-- ── Fornecedores (nome + espécie, como na aba APOIO da planilha) ─────────────
create table if not exists public.lenha_fornecedores (
  id             uuid primary key default gen_random_uuid(),
  nome           text not null,                    -- 'BATISTA'
  especie        text,                             -- EUCALIPTO | PINUS | LARANJA | PALANQUE | OUTRO
  rotulo         text not null,                    -- 'BATISTA - EUCALIPTO' (é o que sai no documento)
  transportadora text,
  cnpj_cpf       text,
  telefone       text,                             -- WhatsApp para enviar a via do fornecedor
  preco_m3       numeric,                          -- preço atual; NULL = não cadastrado (nunca chutar)
  obs            text,
  status         text not null default 'ativo',    -- ativo | inativo
  criado_por     text,
  created_at     timestamptz default now(),
  atualizado_em  timestamptz
);

-- ── Motoristas / veículos (tara e medidas que se repetem a cada carga) ───────
create table if not exists public.lenha_motoristas (
  id                 uuid primary key default gen_random_uuid(),
  fornecedor_id      uuid references public.lenha_fornecedores(id) on delete set null,
  nome               text not null,
  placa              text,
  veiculo            text default 'caminhao',      -- caminhao | trator | outro
  transportadora     text,
  telefone           text,
  tara_padrao        numeric,                      -- 11180 no caminhão, 4500 no trator...
  largura_padrao     numeric,
  comprimento_padrao numeric,
  obs                text,
  status             text not null default 'ativo',
  created_at         timestamptz default now(),
  atualizado_em      timestamptz
);

-- ── Fechamento (o "Emitir nota de" da planilha) ──────────────────────────────
create table if not exists public.lenha_fechamentos (
  id               uuid primary key default gen_random_uuid(),
  numero           text,                           -- FEC-2026-0001
  fornecedor_id    uuid references public.lenha_fornecedores(id) on delete set null,
  fornecedor_nome  text,
  periodo_ini      date,
  periodo_fim      date,
  preco_m3         numeric,                        -- preço usado NESTE fechamento (parte do cadastro, editável)
  qtd_cargas       integer default 0,
  total_liquido_kg numeric default 0,
  total_m3         numeric default 0,
  valor_total      numeric default 0,
  itens            jsonb default '[]'::jsonb,      -- retrato das cargas no momento do fechamento
  obs              text,
  status           text not null default 'fechado', -- fechado | cancelado
  criado_por       text,
  created_at       timestamptz default now(),
  atualizado_em    timestamptz
);

-- ── Recebimento e descarga (o documento de 2 vias) ──────────────────────────
create table if not exists public.lenha_recebimentos (
  id                uuid primary key default gen_random_uuid(),
  numero            text,                          -- LEN-2026-0001
  data              date not null,
  hora              text,
  almoxarife        text,
  fornecedor_id     uuid references public.lenha_fornecedores(id) on delete set null,
  fornecedor_nome   text,                          -- retrato do rótulo (o documento não muda se o cadastro mudar)
  especie           text,
  transportadora    text,
  motorista_id      uuid references public.lenha_motoristas(id) on delete set null,
  motorista_nome    text,
  placa             text,
  destino           text default 'PATIO',
  peso_bruto        numeric,
  peso_tara         numeric,
  peso_liquido      numeric,
  lado1             jsonb default '[]'::jsonb,      -- medidas do LADO 1 (até 6, como na planilha)
  lado2             jsonb default '[]'::jsonb,
  altura_media      numeric,
  largura           numeric,
  comprimento       numeric,
  volume_m3         numeric,
  kg_m3             numeric,
  assin_almox         text, assin_almox_nome   text,
  assin_transp        text, assin_transp_nome  text,
  assin_fabrica       text, assin_fabrica_nome text,
  obs               text,
  status            text not null default 'ativo',  -- ativo | cancelado
  fechamento_id     uuid references public.lenha_fechamentos(id) on delete set null,
  criado_por        text,
  created_at        timestamptz default now(),
  atualizado_em     timestamptz
);

-- ── Índices (as telas filtram por data, fornecedor e "em aberto") ───────────
create unique index if not exists uq_lenha_receb_numero on public.lenha_recebimentos (numero) where numero is not null;
create index if not exists idx_lenha_receb_data        on public.lenha_recebimentos (data desc);
create index if not exists idx_lenha_receb_fornecedor  on public.lenha_recebimentos (fornecedor_id);
create index if not exists idx_lenha_receb_aberto      on public.lenha_recebimentos (fornecedor_id, data) where fechamento_id is null and status = 'ativo';
create unique index if not exists uq_lenha_fech_numero on public.lenha_fechamentos (numero) where numero is not null;
create index if not exists idx_lenha_fech_forn         on public.lenha_fechamentos (fornecedor_id, periodo_ini desc);
create index if not exists idx_lenha_mot_forn          on public.lenha_motoristas (fornecedor_id);

-- ── RLS: nenhuma tabela deste banco nasce aberta ao anon ────────────────────
alter table public.lenha_fornecedores  enable row level security;
alter table public.lenha_motoristas    enable row level security;
alter table public.lenha_recebimentos  enable row level security;
alter table public.lenha_fechamentos   enable row level security;

drop policy if exists baseline_authenticated_all on public.lenha_fornecedores;
create policy baseline_authenticated_all on public.lenha_fornecedores  for all to authenticated using (true) with check (true);
drop policy if exists baseline_authenticated_all on public.lenha_motoristas;
create policy baseline_authenticated_all on public.lenha_motoristas    for all to authenticated using (true) with check (true);
drop policy if exists baseline_authenticated_all on public.lenha_recebimentos;
create policy baseline_authenticated_all on public.lenha_recebimentos  for all to authenticated using (true) with check (true);
drop policy if exists baseline_authenticated_all on public.lenha_fechamentos;
create policy baseline_authenticated_all on public.lenha_fechamentos   for all to authenticated using (true) with check (true);

-- ── Seed: fornecedores da aba APOIO e motoristas das abas da planilha ───────
-- PREÇO fica NULL de propósito: preço errado num fechamento vira nota errada.
-- O dono preenche na tela (Fornecedores → editar), e o fechamento já abre com ele.
insert into public.lenha_fornecedores (nome, especie, rotulo, transportadora, criado_por)
select f.nome, f.especie, f.rotulo, f.transp, 'migration 021'
from (values
  ('SILICATE',              'EUCALIPTO', 'SILICATE - EUCALIPTO PATIO',        null),
  ('SILICATE',              'EUCALIPTO', 'SILICATE - EUCALIPTO',              null),
  ('FAZENDA DA MATA',       'PINUS',     'FAZENDA DA MATA - PINUS',           null),
  ('FAZENDA DA MATA',       'EUCALIPTO', 'FAZENDA DA MATA - EUCALIPTO',       null),
  ('BATISTA',               'EUCALIPTO', 'BATISTA - EUCALIPTO',               'BATISTA'),
  ('BATISTA',               'LARANJA',   'BATISTA - LARANJA',                 'BATISTA'),
  ('BATISTA',               'PINUS',     'BATISTA - PINUS',                   'BATISTA'),
  ('ALAN PATRIKE',          'EUCALIPTO', 'ALAN PATRIKE - EUCALIPTO',          'ALAN PATRIKE'),
  ('MARCILIO (MARCELO)',    'OUTRO',     'MARCILIO(MARCELO) PATIO LENHA',     null),
  ('J. AUGUSTO',            'EUCALIPTO', 'J. AUGUSTO - EUCALIPTO',            null),
  ('J. AUGUSTO',            'PINUS',     'J. AUGUSTO - PINUS',                null),
  ('DIVANIL (DIL)',         'LARANJA',   'DIVANIL(DIL) - LARANJA',            'DIVANIL (DIL)'),
  ('CARLINHO',              'EUCALIPTO', 'CARLINHO - EUCALIPTO',              null),
  ('MOREIRA FLORESTAL',     'EUCALIPTO', 'MOREIRA FLORESTAL',                 null),
  ('JOSE REINALDO',         'PINUS',     'JOSE REINALDO - PINUS',             null),
  ('JOSE REINALDO',         'EUCALIPTO', 'JOSE REINALDO - EUCALIPTO',         null),
  ('JOSE REINALDO',         'EUCALIPTO', 'JOSE REINALDO - EUCALIPTO-BATISTA', 'BATISTA'),
  ('JOSE REINALDO',         'PALANQUE',  'JOSÉ REINALDO - PALANQUE',          null),
  ('GUSTAVO',               'EUCALIPTO', 'GUSTAVO - EUCALIPTO',               null)
) as f(nome, especie, rotulo, transp)
where not exists (select 1 from public.lenha_fornecedores x where x.rotulo = f.rotulo);

insert into public.lenha_motoristas (nome, placa, veiculo, transportadora, tara_padrao, largura_padrao, comprimento_padrao, fornecedor_id)
select m.nome, m.placa, m.veiculo, m.transp, m.tara, m.larg, m.comp,
       (select id from public.lenha_fornecedores f where f.rotulo = m.forn_rotulo)
from (values
  ('PATRIKE',        'AEJ1794',         'caminhao', 'ALAN PATRIKE',  11180, 2.4,  7.8,  'ALAN PATRIKE - EUCALIPTO'),
  ('MARCELO',        'TRATOR VERMELHO', 'trator',   'BATISTA',       null,  1.3,  2.7,  'SILICATE - EUCALIPTO'),
  ('GENILSON',       'BJO4A73',         'caminhao', 'GENILSON',      11180, 2.35, 7.5,  'JOSE REINALDO - EUCALIPTO'),
  ('GENILSON',       'TRATOR',          'trator',   'GENILSON',      4500,  2.5,  2.5,  'JOSE REINALDO - EUCALIPTO'),
  ('DIVANIL (DIL)',  'TRATOR',          'trator',   'DIVANIL (DIL)', 11180, 2.1,  6.17, 'DIVANIL(DIL) - LARANJA')
) as m(nome, placa, veiculo, transp, tara, larg, comp, forn_rotulo)
where not exists (select 1 from public.lenha_motoristas x where x.nome = m.nome and coalesce(x.placa,'') = coalesce(m.placa,''));
