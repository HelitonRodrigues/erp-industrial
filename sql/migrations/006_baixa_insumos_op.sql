-- 006 — Baixa automática de insumos no fechamento da OP (Etapa 3)
--
-- O comentário em insumos.html sempre prometeu: "quando producao.html for
-- revisado, é a mesma conta chamada no fechamento da OP". Esta migration
-- cumpre a promessa levando o MOTOR DA FICHA TÉCNICA para o banco:
--
--   producao.html salva a OP → chama rpc_baixa_insumos_op(producao_id)
--   → o Postgres lê produtos_op + insumos_ficha + insumos e gera os
--     movimentos de consumo (com teórico, custo médio, FEFO por lote)
--     NUMA TRANSAÇÃO SÓ.
--
-- Regras replicadas 1:1 de calcularComponente() (insumos.html §18b):
--   base 'unidade' → sacos ×/÷ qtd_por
--   base 'kg'/'ton' → sacos × peso_unidade_kg, convertido para a unidade
--                     de ESTOQUE do insumo via fator de massa (mg/g/kg/ton)
--                     — a regra que já causou o bug de 1000×
--   base 'pallet'  → pallets reais da OP (usar_pallets_reais) ou
--                     ceil(sacos ÷ sacos_por_pallet)
--   base 'caixa'   → sacos ÷ unidades_por_caixa
--   perda          → perda_embalagem da OP (usar_perda_op) ou perda_pct%
--   arredondamento → para CIMA só em unidade discreta (sc, un, cx, pallet,
--                     pç, rolo); massa fica fracionária
--   FEFO           → lotes 'liberado' com saldo, validade mais curta primeiro,
--                     saldo do lote decrementado
--   origem         → 'OP' + op_numero (o índice único uq_mov_op impede a
--                     mesma OP baixar duas vezes o mesmo insumo/lote)
--
-- Reprocesso (edição de OP): p_regravar=true apaga os movimentos 'OP' desta
-- OP (devolvendo saldo aos lotes) e regrava com os números novos — tudo na
-- mesma transação. A tela de Insumos continua funcionando como reprocesso
-- manual e para divergências (real ≠ teórico).

-- Nome normalizado igual ao Regras.normalizarNome do front:
-- minúsculas, sem acento, sem espaço, só a-z0-9.
create or replace function public.norm_nome(p text)
returns text
language sql immutable
set search_path = public
as $$
  select regexp_replace(
    translate(lower(coalesce(p,'')),
      'áàâãäåéèêëíìîïóòôõöúùûüçñ',
      'aaaaaaeeeeiiiiooooouuuucn'),
    '[^a-z0-9]', '', 'g');
$$;

create or replace function public.rpc_baixa_insumos_op(
  p_producao_id uuid,
  p_regravar    boolean default false
) returns jsonb
language plpgsql
set search_path = public
as $$
declare
  v_op        producao%rowtype;
  v_opkey     text;
  v_item      jsonb;
  v_ficha     record;
  v_lote      record;

  v_sacos     numeric;
  v_pal_reais numeric;
  v_cap_op    numeric;
  v_perda_emb numeric;
  v_produto   text;

  v_q         numeric;
  v_peso      numeric;
  v_un        text;
  v_fator     numeric;
  v_massa     numeric;
  v_pal       numeric;
  v_cap       numeric;
  v_bruto     numeric;
  v_perda     numeric;
  v_total     numeric;
  v_qtd       numeric;
  v_custo     numeric;
  v_resta     numeric;
  v_usa       numeric;
  v_texto     text;

  v_gerados   integer := 0;
  v_devolvido integer := 0;
  v_alertas   jsonb := '[]'::jsonb;
  v_sem_ficha jsonb := '[]'::jsonb;
  v_existiam  integer;
begin
  select * into v_op from producao where id = p_producao_id;
  if not found then
    raise exception 'OP não encontrada (id %).', p_producao_id;
  end if;
  v_opkey := coalesce(nullif(v_op.op_numero,''), v_op.id::text);

  -- já existe baixa desta OP?
  select count(*) into v_existiam
    from insumos_movimentos where origem='OP' and origem_id=v_opkey;

  if v_existiam > 0 and not p_regravar then
    return jsonb_build_object('op', v_opkey, 'ja_baixado', true, 'movimentos', v_existiam);
  end if;

  if v_existiam > 0 then
    -- devolve saldo aos lotes e apaga a baixa anterior (edição de OP)
    update insumos_lotes l
       set saldo = l.saldo + m.qtd
      from (select lote_id, sum(quantidade) qtd
              from insumos_movimentos
             where origem='OP' and origem_id=v_opkey and lote_id is not null
             group by lote_id) m
     where l.id = m.lote_id;
    delete from insumos_movimentos where origem='OP' and origem_id=v_opkey;
    v_devolvido := v_existiam;
  end if;

  -- um item da OP por produto produzido
  for v_item in select * from jsonb_array_elements(coalesce(v_op.produtos_op,'[]'::jsonb)) loop
    v_produto   := v_item->>'produto';
    v_sacos     := coalesce(nullif(v_item->>'total_sacos','')::numeric,
                            nullif(v_item->>'sacos_pallets','')::numeric, 0);
    v_perda_emb := coalesce(nullif(v_item->>'perda_embalagem','')::numeric, 0);
    select coalesce(sum((p->>'qtd')::numeric),0), max(case when ord=1 then (p->>'cap')::numeric end)
      into v_pal_reais, v_cap_op
      from jsonb_array_elements(coalesce(v_item->'pallets','[]'::jsonb)) with ordinality t(p,ord);

    if v_sacos <= 0 then continue; end if;

    -- sem ficha técnica = sem baixa automática (avisar, nunca chutar)
    if not exists (
      select 1 from insumos_ficha f where norm_nome(f.produto)=norm_nome(v_produto)
    ) then
      v_sem_ficha := v_sem_ficha || to_jsonb(v_produto);
      continue;
    end if;

    for v_ficha in
      select f.*, i.unidade_estoque, i.controla_lote, i.custo_unitario as custo_cadastro, i.nome as insumo_nome
        from insumos_ficha f
        join insumos i on i.id = f.insumo_id
       where norm_nome(f.produto) = norm_nome(v_produto)
         and coalesce(i.status,'ativo') <> 'inativo'
    loop
      v_q    := coalesce(v_ficha.qtd_por,0);
      v_peso := coalesce(v_ficha.peso_unidade_kg,0);
      v_un   := lower(coalesce(v_ficha.unidade_estoque,'un'));
      v_fator := case v_un
        when 'mg' then 0.000001 when 'g' then 0.001
        when 'kg' then 1 when 'quilo' then 1 when 'quilos' then 1
        when 't' then 1000 when 'ton' then 1000
        when 'tonelada' then 1000 when 'toneladas' then 1000
        else null end;
      v_bruto := null; v_texto := null;

      if v_ficha.base in ('kg','ton') then
        if v_peso <= 0 then
          v_alertas := v_alertas || jsonb_build_object('insumo', v_ficha.insumo_nome, 'produto', v_produto, 'alerta', 'falta o peso da unidade na ficha');
          continue;
        end if;
        if v_fator is null then
          v_alertas := v_alertas || jsonb_build_object('insumo', v_ficha.insumo_nome, 'produto', v_produto, 'alerta', 'insumo medido em "'||v_un||'", que não é unidade de massa');
          continue;
        end if;
        v_massa := v_sacos * v_peso / (case when v_ficha.base='ton' then 1000 else 1 end);
        v_massa := case when v_ficha.modo='dividir' then (case when v_q<>0 then v_massa/v_q else 0 end) else v_massa*v_q end;
        v_bruto := v_massa * (case when v_ficha.base='ton' then 1000 else 1 end) / v_fator;
        v_texto := v_sacos||' sacos × '||v_peso||' kg → '||round(v_bruto,3)||' '||v_un;

      elsif v_ficha.base = 'pallet' then
        if v_ficha.usar_pallets_reais and v_pal_reais > 0 then
          v_pal := v_pal_reais;
          v_texto := v_pal||' pallets lançados na OP';
        else
          v_cap := coalesce(nullif(v_ficha.sacos_por_pallet,0), nullif(v_cap_op,0));
          if coalesce(v_cap,0) <= 0 then
            v_alertas := v_alertas || jsonb_build_object('insumo', v_ficha.insumo_nome, 'produto', v_produto, 'alerta', 'falta "sacos por pallet"');
            continue;
          end if;
          v_pal := ceil(v_sacos / v_cap - 0.000001);
          v_texto := v_sacos||' sc ÷ '||v_cap||' sc/pallet = '||v_pal||' pallets';
        end if;
        v_bruto := case when v_ficha.modo='dividir' then (case when v_q<>0 then v_pal/v_q else 0 end) else v_pal*v_q end;

      elsif v_ficha.base = 'caixa' then
        if coalesce(v_ficha.unidades_por_caixa,0) <= 0 then
          v_alertas := v_alertas || jsonb_build_object('insumo', v_ficha.insumo_nome, 'produto', v_produto, 'alerta', 'falta "unidades por caixa"');
          continue;
        end if;
        v_bruto := v_sacos / v_ficha.unidades_por_caixa;
        v_bruto := case when v_ficha.modo='dividir' then (case when v_q<>0 then v_bruto/v_q else 0 end) else v_bruto*v_q end;
        v_texto := v_sacos||' un ÷ '||v_ficha.unidades_por_caixa||' un/caixa';

      else  -- base 'unidade'
        v_bruto := case when v_ficha.modo='dividir' then (case when v_q<>0 then v_sacos/v_q else 0 end) else v_sacos*v_q end;
        v_texto := v_sacos||' un '||(case when v_ficha.modo='dividir' then '÷' else '×' end)||' '||v_q||' '||v_un;
      end if;

      -- perda: da OP (unidades reais) ou percentual da ficha
      v_perda := 0;
      if v_ficha.usar_perda_op and v_perda_emb > 0 then
        v_perda := v_perda_emb;
        v_texto := v_texto||' + '||v_perda_emb||' de perda da OP';
      elsif coalesce(v_ficha.perda_pct,0) > 0 then
        v_perda := v_bruto * v_ficha.perda_pct / 100;
        v_texto := v_texto||' + '||v_ficha.perda_pct||'% de perda';
      end if;

      v_total := v_bruto + v_perda;
      -- arredonda para cima só em unidade discreta (não se consome meio saco)
      if v_un in ('sc','un','cx','pallet','pç','pc','rolo') and v_fator is null then
        v_qtd := ceil(v_total - 0.000001);
      else
        v_qtd := round(v_total, 6);
      end if;
      if v_qtd <= 0 then continue; end if;

      -- custo médio das entradas (fallback: custo do cadastro)
      select coalesce(
               (select sum(quantidade*custo_unitario)/nullif(sum(quantidade),0)
                  from insumos_movimentos
                 where insumo_id=v_ficha.insumo_id
                   and tipo in ('entrada','devolucao','retorno')
                   and coalesce(custo_unitario,0) > 0),
               v_ficha.custo_cadastro, 0)
        into v_custo;

      if v_ficha.controla_lote then
        -- FEFO: consome dos lotes liberados, validade mais curta primeiro
        v_resta := v_qtd;
        for v_lote in
          select * from insumos_lotes
           where insumo_id=v_ficha.insumo_id and status='liberado' and saldo > 0
           order by validade nulls last, criado_em
        loop
          exit when v_resta <= 0.0000001;
          v_usa := least(v_resta, v_lote.saldo);
          insert into insumos_movimentos (insumo_id, lote_id, data, tipo, quantidade, qtd_teorica,
                                          custo_unitario, origem, origem_id, responsavel, obs, produto)
          values (v_ficha.insumo_id, v_lote.id, v_op.data, 'consumo', round(v_usa,3), round(v_qtd,3),
                  round(v_custo,4), 'OP', v_opkey, v_op.encarregado,
                  'Produto: '||v_produto||' · '||v_sacos||' sacos'||
                  coalesce(' · '||v_op.linha,'')||coalesce(' · '||v_op.turno,'')||' · '||v_texto||' · lote '||v_lote.lote,
                  v_produto);
          update insumos_lotes set saldo = round(saldo - v_usa,3) where id = v_lote.id;
          v_resta := v_resta - v_usa;
          v_gerados := v_gerados + 1;
        end loop;
        if v_resta > 0.0000001 then
          -- o que não coube em lote sai sem lote (fica visível na divergência)
          insert into insumos_movimentos (insumo_id, lote_id, data, tipo, quantidade, qtd_teorica,
                                          custo_unitario, origem, origem_id, responsavel, obs, produto)
          values (v_ficha.insumo_id, null, v_op.data, 'consumo', round(v_resta,3), round(v_qtd,3),
                  round(v_custo,4), 'OP', v_opkey, v_op.encarregado,
                  'Produto: '||v_produto||' · '||v_sacos||' sacos · '||v_texto||' · SEM LOTE (saldo de lote insuficiente)',
                  v_produto);
          v_gerados := v_gerados + 1;
        end if;
      else
        insert into insumos_movimentos (insumo_id, lote_id, data, tipo, quantidade, qtd_teorica,
                                        custo_unitario, origem, origem_id, responsavel, obs, produto)
        values (v_ficha.insumo_id, null, v_op.data, 'consumo', round(v_qtd,3), round(v_qtd,3),
                round(v_custo,4), 'OP', v_opkey, v_op.encarregado,
                'Produto: '||v_produto||' · '||v_sacos||' sacos'||
                coalesce(' · '||v_op.linha,'')||coalesce(' · '||v_op.turno,'')||' · '||v_texto,
                v_produto);
        v_gerados := v_gerados + 1;
      end if;
    end loop;
  end loop;

  return jsonb_build_object(
    'op', v_opkey,
    'movimentos', v_gerados,
    'regravados', v_devolvido,
    'sem_ficha', v_sem_ficha,
    'alertas', v_alertas);
end;
$$;

-- ── 006b — uq_mov_op ganha o produto na chave ────────────────────────────────
-- Uma OP pode produzir DOIS produtos que consomem o MESMO insumo (ex.: Big Bag
-- e Caulim 25kg, ambos de MP Caulim). O índice antigo tratava isso como
-- duplicidade; o novo continua impedindo a mesma OP de baixar duas vezes o
-- mesmo insumo DO MESMO PRODUTO, que é a proteção real.
drop index if exists uq_mov_op;
create unique index uq_mov_op on public.insumos_movimentos
  using btree (origem, origem_id, insumo_id,
               coalesce(produto,''),
               coalesce(lote_id, '00000000-0000-0000-0000-000000000000'::uuid))
  where (origem = 'OP'::text);

-- ── 006c — Estorno da baixa quando a OP é excluída ───────────────────────────
-- Devolve o saldo aos lotes e remove os movimentos 'OP' daquela OP,
-- na mesma transação. Chamado por producao.html ANTES de excluir a OP.
create or replace function public.rpc_estornar_baixa_op(p_producao_id uuid)
returns jsonb
language plpgsql
set search_path = public
as $$
declare
  v_opkey text;
  v_qtd   integer;
begin
  select coalesce(nullif(op_numero,''), id::text) into v_opkey
    from producao where id = p_producao_id;
  if not found then
    return jsonb_build_object('movimentos_removidos', 0);
  end if;

  update insumos_lotes l
     set saldo = l.saldo + m.qtd
    from (select lote_id, sum(quantidade) qtd
            from insumos_movimentos
           where origem='OP' and origem_id=v_opkey and lote_id is not null
           group by lote_id) m
   where l.id = m.lote_id;

  delete from insumos_movimentos where origem='OP' and origem_id=v_opkey;
  get diagnostics v_qtd = row_count;

  return jsonb_build_object('op', v_opkey, 'movimentos_removidos', v_qtd);
end;
$$;

-- ── 006d — LENHA baixa a partir do CAMPO da OP ───────────────────────────────
-- A lenha não passa pela ficha técnica: é apontada dentro de cada OP
-- (producao.consumo_lenha, em m³), igual ao Excel (coluna CONSUMO DE LENHA).
-- rpc_baixa_insumos_op foi redefinida com um bloco final que gera 1 movimento
-- de consumo por OP para o insumo tipo LENHA (aplicada no banco em 14/08 como
-- migration "baixa_lenha_op" — a definição vigente da function é a de lá).
-- Se a OP apontar lenha e não existir insumo tipo LENHA ativo, vira alerta.
