-- 044 — Módulo Felisbina (unidade separada)
--
-- A Felisbina é outra operação: produz itens de varejo (Liga AD, Sikal 1L/5L,
-- sachês 50g, Chapistec, Veda Massa, Topdry em caixa) e revende o Preparador
-- e as Tintas. Não tem turno, horímetro, pallet nem laboratório.
--
-- Por isso NADA aqui toca producao, producao_pallets, insumos, insumos_movimentos
-- nem o laboratório: são tabelas próprias, com prefixo felis_. O estoque é um
-- livro-razão (felis_movimentos): saldo = soma das quantidades, com sinal.
--
-- Risco: baixo — só tabelas e funções novas. Nenhuma tabela existente muda.

-- ── 1. Itens: produto acabado, revenda e insumo, num cadastro só ──────────
create table if not exists public.felis_itens (
  id             uuid primary key default gen_random_uuid(),
  nome           text not null,
  categoria      text not null check (categoria in ('produto','revenda','insumo')),
  grupo          text not null check (grupo in ('Silicate','Topdry','Preparador','Tintas')),
  unidade        text not null default 'un',
  estoque_minimo numeric not null default 0,
  ordem          integer not null default 0,
  status         text not null default 'ativo' check (status in ('ativo','inativo')),
  obs            text,
  criado_em      timestamptz not null default now(),
  atualizado_em  timestamptz not null default now()
);
create unique index if not exists felis_itens_nome_uk on public.felis_itens (upper(nome));
comment on table public.felis_itens is
  'Cadastro da Felisbina. produto = fabricado lá (baixa insumo pela ficha); revenda = só entra e sai (Preparador, Tintas); insumo = embalagem, rótulo, tampa, caixa, sachê, material.';

-- ── 2. Ficha: quanto de cada insumo sai por unidade produzida ─────────────
create table if not exists public.felis_ficha (
  id          uuid primary key default gen_random_uuid(),
  produto_id  uuid not null references public.felis_itens(id) on delete cascade,
  insumo_id   uuid not null references public.felis_itens(id) on delete restrict,
  qtd         numeric not null check (qtd > 0),
  criado_em   timestamptz not null default now(),
  constraint felis_ficha_uk unique (produto_id, insumo_id),
  constraint felis_ficha_dif check (produto_id <> insumo_id)
);
comment on column public.felis_ficha.qtd is 'Insumo por UMA unidade do produto. Ex.: caixa com 12 frascos → 0,0833.';

-- ── 3. Movimentos (livro-razão) ───────────────────────────────────────────
-- quantidade já vem com o sinal do efeito no estoque:
--   + inicial, producao, entrada          − carregamento, consumo, perda, doacao
--   ± diferenca (acerto de contagem)
create table if not exists public.felis_movimentos (
  id          uuid primary key default gen_random_uuid(),
  item_id     uuid not null references public.felis_itens(id) on delete restrict,
  data        date not null,
  tipo        text not null check (tipo in ('inicial','producao','entrada','carregamento','consumo','perda','doacao','diferenca')),
  quantidade  numeric not null check (quantidade <> 0),
  lote        text,
  documento   text,
  origem      text not null default 'manual' check (origem in ('manual','ficha','planilha')),
  origem_id   uuid references public.felis_movimentos(id) on delete cascade,
  obs         text,
  usuario     text,
  criado_em   timestamptz not null default now(),
  constraint felis_mov_sinal check (
       (tipo in ('inicial','producao','entrada') and quantidade > 0)
    or (tipo in ('carregamento','consumo','perda','doacao') and quantidade < 0)
    or  tipo = 'diferenca')
);
create index if not exists felis_mov_item_data_idx on public.felis_movimentos (item_id, data);
create index if not exists felis_mov_data_idx      on public.felis_movimentos (data);
create index if not exists felis_mov_origem_idx    on public.felis_movimentos (origem_id);
comment on column public.felis_movimentos.origem_id is
  'Consumo gerado pela ficha aponta para a produção que o gerou. Apagar a produção apaga os consumos dela (cascade).';

-- ── 4. Saldo atual ────────────────────────────────────────────────────────
create or replace view public.felis_saldos with (security_invoker = on) as
  select i.id as item_id, coalesce(sum(m.quantidade), 0) as saldo
    from public.felis_itens i
    left join public.felis_movimentos m on m.item_id = i.id
   group by i.id;

-- ── 5. Lançamento do dia (atômico) ────────────────────────────────────────
-- p_itens: [{item_id, tipo, quantidade, lote?, documento?, obs?}]
--   quantidade positiva para todos os tipos; para 'diferenca' o sinal é o efeito
--   (negativo = faltou). Produção baixa os insumos da ficha na mesma transação.
create or replace function public.felis_lancar(p_data date, p_itens jsonb, p_usuario text default null)
returns jsonb language plpgsql as $$
declare
  it jsonb; v_tipo text; v_q numeric; v_id uuid; n_mov int := 0; n_cons int := 0; f record;
begin
  if p_data is null then raise exception 'Data obrigatória'; end if;
  for it in select * from jsonb_array_elements(coalesce(p_itens,'[]'::jsonb)) loop
    v_tipo := it->>'tipo';
    v_q := nullif(it->>'quantidade','')::numeric;
    if v_q is null or v_q = 0 then continue; end if;
    if v_tipo in ('inicial','producao','entrada') then v_q := abs(v_q);
    elsif v_tipo in ('carregamento','consumo','perda','doacao') then v_q := -abs(v_q);
    elsif v_tipo <> 'diferenca' then raise exception 'Tipo inválido: %', v_tipo; end if;
    insert into public.felis_movimentos (item_id, data, tipo, quantidade, lote, documento, obs, usuario, origem)
    values ((it->>'item_id')::uuid, p_data, v_tipo, v_q, nullif(it->>'lote',''), nullif(it->>'documento',''),
            nullif(it->>'obs',''), p_usuario, 'manual')
    returning id into v_id;
    n_mov := n_mov + 1;
    if v_tipo = 'producao' then
      for f in select insumo_id, qtd from public.felis_ficha where produto_id = (it->>'item_id')::uuid loop
        insert into public.felis_movimentos (item_id, data, tipo, quantidade, origem, origem_id, usuario, obs)
        values (f.insumo_id, p_data, 'consumo', -round(f.qtd * v_q, 4), 'ficha', v_id, p_usuario, 'Baixa pela ficha');
        n_cons := n_cons + 1;
      end loop;
    end if;
  end loop;
  return jsonb_build_object('movimentos', n_mov, 'consumos', n_cons);
end $$;

-- ── 6. Resumo por período (base da aba Resumo e do PDF) ───────────────────
-- anterior = tudo antes de p_ini + os 'inicial' do período (estoque que já existia).
create or replace function public.felis_resumo(p_ini date, p_fim date)
returns table (item_id uuid, anterior numeric, producao numeric, entrada numeric, carregamento numeric,
               consumo numeric, perda numeric, doacao numeric, diferenca numeric, final numeric)
language sql stable as $$
  select i.id,
    coalesce(sum(m.quantidade) filter (where m.data < p_ini or (m.tipo='inicial' and m.data <= p_fim)),0),
    coalesce(sum(m.quantidade) filter (where m.data between p_ini and p_fim and m.tipo='producao'),0),
    coalesce(sum(m.quantidade) filter (where m.data between p_ini and p_fim and m.tipo='entrada'),0),
    coalesce(-sum(m.quantidade) filter (where m.data between p_ini and p_fim and m.tipo='carregamento'),0),
    coalesce(-sum(m.quantidade) filter (where m.data between p_ini and p_fim and m.tipo='consumo'),0),
    coalesce(-sum(m.quantidade) filter (where m.data between p_ini and p_fim and m.tipo='perda'),0),
    coalesce(-sum(m.quantidade) filter (where m.data between p_ini and p_fim and m.tipo='doacao'),0),
    coalesce(-sum(m.quantidade) filter (where m.data between p_ini and p_fim and m.tipo='diferenca'),0),
    coalesce(sum(m.quantidade) filter (where m.data <= p_fim),0)
  from public.felis_itens i
  left join public.felis_movimentos m on m.item_id = i.id
  group by i.id;
$$;
comment on function public.felis_resumo is
  'Resumo do período por item. carregamento/consumo/perda/doacao saem positivos; diferenca positiva = faltou (mesma convenção da planilha).';

-- ── 7. RLS no padrão do projeto ───────────────────────────────────────────
alter table public.felis_itens      enable row level security;
alter table public.felis_ficha      enable row level security;
alter table public.felis_movimentos enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where tablename='felis_itens' and policyname='baseline_authenticated_all') then
    create policy baseline_authenticated_all on public.felis_itens for all to authenticated using (true) with check (true); end if;
  if not exists (select 1 from pg_policies where tablename='felis_ficha' and policyname='baseline_authenticated_all') then
    create policy baseline_authenticated_all on public.felis_ficha for all to authenticated using (true) with check (true); end if;
  if not exists (select 1 from pg_policies where tablename='felis_movimentos' and policyname='baseline_authenticated_all') then
    create policy baseline_authenticated_all on public.felis_movimentos for all to authenticated using (true) with check (true); end if;
end $$;

notify pgrst, 'reload schema';

-- ── 8. (044b, aplicado em seguida) ficha com divisor ──────────────────────
-- "1 caixa a cada 12 frascos" sem dízima: consumo = produzido × qtd ÷ por.
alter table public.felis_ficha add column if not exists por numeric not null default 1 check (por > 0);
comment on column public.felis_ficha.qtd is 'Quantidade do insumo a cada POR unidades do produto.';
comment on column public.felis_ficha.por is 'Divisor: 1 caixa (qtd=1) a cada 12 frascos (por=12). Evita dízima (1/12).';
create or replace function public.felis_lancar(p_data date, p_itens jsonb, p_usuario text default null)
returns jsonb language plpgsql as $$
declare
  it jsonb; v_tipo text; v_q numeric; v_id uuid; n_mov int := 0; n_cons int := 0; f record; v_c numeric;
begin
  if p_data is null then raise exception 'Data obrigatória'; end if;
  for it in select * from jsonb_array_elements(coalesce(p_itens,'[]'::jsonb)) loop
    v_tipo := it->>'tipo';
    v_q := nullif(it->>'quantidade','')::numeric;
    if v_q is null or v_q = 0 then continue; end if;
    if v_tipo in ('inicial','producao','entrada') then v_q := abs(v_q);
    elsif v_tipo in ('carregamento','consumo','perda','doacao') then v_q := -abs(v_q);
    elsif v_tipo <> 'diferenca' then raise exception 'Tipo inválido: %', v_tipo; end if;
    insert into public.felis_movimentos (item_id, data, tipo, quantidade, lote, documento, obs, usuario, origem)
    values ((it->>'item_id')::uuid, p_data, v_tipo, v_q, nullif(it->>'lote',''), nullif(it->>'documento',''),
            nullif(it->>'obs',''), p_usuario, 'manual')
    returning id into v_id;
    n_mov := n_mov + 1;
    if v_tipo = 'producao' then
      for f in select insumo_id, qtd, por from public.felis_ficha where produto_id = (it->>'item_id')::uuid loop
        v_c := round(f.qtd * v_q / f.por, 4);
        if v_c > 0 then
          insert into public.felis_movimentos (item_id, data, tipo, quantidade, origem, origem_id, usuario, obs)
          values (f.insumo_id, p_data, 'consumo', -v_c, 'ficha', v_id, p_usuario, 'Baixa pela ficha');
          n_cons := n_cons + 1;
        end if;
      end loop;
    end if;
  end loop;
  return jsonb_build_object('movimentos', n_mov, 'consumos', n_cons);
end $$;
notify pgrst, 'reload schema';
