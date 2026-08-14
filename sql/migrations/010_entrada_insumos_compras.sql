-- 010 — Entrada de insumos direto do recebimento de Compras (Etapa 5A)
--
-- Fecha o ciclo do ledger de insumos: até aqui só existiam consumo (OPs) e
-- ajuste (carga inicial/inventário) — a entrada era digitação manual na tela
-- de Insumos. Agora:
--
--   Compras: recebimento da NF salvo → rpc_entrada_compras(recebimento_id)
--   → para cada item do recebimento cujo NOME bate com um insumo cadastrado
--     (norm_nome, mesma régua da baixa por OP), gera movimento de ENTRADA
--     no ledger, com NF, custo unitário e lote (FEFO ganha validade depois,
--     quando o lote for complementado em Insumos → Lotes).
--
-- Regras:
--   • qualidade 'reprovado' NÃO entra (fica bloqueada no almoxarifado, como já era);
--   • item sem correspondência em `insumos` = material de almoxarifado/MRO —
--     segue o fluxo antigo e é reportado como fora_do_ledger (não é erro);
--   • custo unitário: valor_unitario do item → preco_unit do pedido → custo
--     do cadastro do insumo;
--   • idempotente: o índice único uq_mov_compra impede o mesmo recebimento de
--     dar entrada duas vezes; p_regravar=true refaz (edição de recebimento);
--   • lote: se o insumo controla_lote e o item traz lote, cria/atualiza
--     insumos_lotes (saldo e qtd_inicial somam) e amarra o movimento ao lote.

create unique index if not exists uq_mov_compra on public.insumos_movimentos
  using btree (origem, origem_id, insumo_id,
               coalesce(lote_id, '00000000-0000-0000-0000-000000000000'::uuid))
  where (origem = 'COMPRA'::text);

create or replace function public.rpc_entrada_compras(
  p_recebimento_id uuid,
  p_regravar       boolean default false
) returns jsonb
language plpgsql
set search_path = public
as $$
declare
  v_rec      compras_recebimentos%rowtype;
  v_pedido   compras_pedidos%rowtype;
  v_item     jsonb;
  v_insumo   insumos%rowtype;
  v_qtd      numeric;
  v_custo    numeric;
  v_lote_txt text;
  v_lote_id  uuid;
  v_existiam integer;
  v_gerados  integer := 0;
  v_fora     jsonb := '[]'::jsonb;
begin
  select * into v_rec from compras_recebimentos where id = p_recebimento_id;
  if not found then
    raise exception 'Recebimento não encontrado (id %).', p_recebimento_id;
  end if;
  if v_rec.pedido_id is not null then
    select * into v_pedido from compras_pedidos where id = v_rec.pedido_id;
  end if;

  select count(*) into v_existiam
    from insumos_movimentos where origem='COMPRA' and origem_id=p_recebimento_id::text;

  if v_existiam > 0 and not p_regravar then
    return jsonb_build_object('ja_lancado', true, 'movimentos', v_existiam);
  end if;

  if v_existiam > 0 then
    -- edição de recebimento: desfaz saldo de lote e apaga a entrada anterior
    update insumos_lotes l
       set saldo = l.saldo - m.qtd,
           qtd_inicial = greatest(0, l.qtd_inicial - m.qtd)
      from (select lote_id, sum(quantidade) qtd
              from insumos_movimentos
             where origem='COMPRA' and origem_id=p_recebimento_id::text and lote_id is not null
             group by lote_id) m
     where l.id = m.lote_id;
    delete from insumos_movimentos where origem='COMPRA' and origem_id=p_recebimento_id::text;
  end if;

  for v_item in select * from jsonb_array_elements(coalesce(v_rec.itens,'[]'::jsonb)) loop
    v_qtd := coalesce(nullif(v_item->>'qtd','')::numeric, 0);
    if v_qtd <= 0 then continue; end if;
    if coalesce(v_item->>'qualidade','aprovado') = 'reprovado' then continue; end if;

    select * into v_insumo from insumos
     where norm_nome(nome) = norm_nome(v_item->>'nome')
       and coalesce(status,'ativo') <> 'inativo'
     limit 1;
    if not found then
      v_fora := v_fora || to_jsonb(v_item->>'nome');
      continue;
    end if;

    -- custo: item do recebimento → item do pedido → cadastro do insumo
    v_custo := coalesce(
      nullif(v_item->>'valor_unitario','')::numeric,
      (select nullif(x->>'preco_unit','')::numeric
         from jsonb_array_elements(coalesce(v_pedido.itens,'[]'::jsonb)) x
        where norm_nome(x->>'nome') = norm_nome(v_item->>'nome')
           or x->>'insumo_id' = v_item->>'insumo_id'
        limit 1),
      v_insumo.custo_unitario, 0);

    -- lote (quando o insumo controla e o item informa)
    v_lote_id := null;
    v_lote_txt := nullif(btrim(coalesce(v_item->>'lote','')),'');
    if v_insumo.controla_lote and v_lote_txt is not null then
      insert into insumos_lotes (insumo_id, lote, qtd_inicial, saldo, custo_unitario, nota_fiscal, fornecedor, status)
      values (v_insumo.id, v_lote_txt, v_qtd, v_qtd, nullif(v_custo,0), v_rec.nota_fiscal,
              coalesce(v_pedido.fornecedor, null), 'liberado')
      on conflict (insumo_id, lote) do update
        set qtd_inicial = insumos_lotes.qtd_inicial + excluded.qtd_inicial,
            saldo       = insumos_lotes.saldo + excluded.saldo,
            custo_unitario = coalesce(excluded.custo_unitario, insumos_lotes.custo_unitario),
            nota_fiscal = coalesce(excluded.nota_fiscal, insumos_lotes.nota_fiscal)
      returning id into v_lote_id;
    end if;

    insert into insumos_movimentos (insumo_id, lote_id, data, tipo, quantidade, qtd_teorica,
                                    custo_unitario, origem, origem_id, responsavel, obs, produto)
    values (v_insumo.id, v_lote_id, coalesce(v_rec.data, current_date), 'entrada', round(v_qtd,3), null,
            round(v_custo,4), 'COMPRA', p_recebimento_id::text, v_rec.recebido_por,
            'Recebimento'||coalesce(' pedido #'||lpad(v_pedido.numero::text,4,'0'),'')||
            coalesce(' · NF '||v_rec.nota_fiscal,'')||
            coalesce(' · fornecedor '||v_pedido.fornecedor,'')||
            coalesce(' · lote '||v_lote_txt,''),
            null);
    v_gerados := v_gerados + 1;
  end loop;

  return jsonb_build_object(
    'movimentos', v_gerados,
    'regravados', v_existiam,
    'fora_do_ledger', v_fora);
end;
$$;
