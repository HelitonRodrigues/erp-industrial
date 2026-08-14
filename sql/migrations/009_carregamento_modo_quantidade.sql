-- 009 — Modo quantidade no carregamento (Etapa 4, última peça)
--
-- O Excel prova que a operação sobrevive com "um número por produto/dia".
-- O sistema não pode ser mais lento que o caderninho: quando não dá para
-- bipar (granel/cebolão, sacos avulsos, pallet sem rótulo, contingência),
-- o operador lança produto + quantidade e a carga segue.
--
-- Mudanças:
--   1. rpc_salvar_carregamento aceita itens com avulso=true e pallet_id null:
--      entram no documento da carga (contam sacos) sem mexer em pallet algum.
--      O estoque de produto acabado do Fechamento Diário já desconta esses
--      sacos, porque ele soma os itens de `carregamentos` — com ou sem pallet.
--   2. rpc_remover_item_carga(p_carga_id, p_item_index): remove UM item da
--      carga salva pela posição (0-based). Se o item tem pallet, devolve o
--      pallet ao estoque; se é avulso, só sai do documento. Substitui a
--      rpc_devolver_pallet no fluxo de remoção (que não cobria avulsos).

create or replace function public.rpc_salvar_carregamento(
  p_carga       jsonb,
  p_itens       jsonb,
  p_edit_id     uuid  default null,
  p_devolver    uuid[] default '{}',
  p_romaneio_id uuid  default null
) returns jsonb
language plpgsql
set search_path = public
as $$
declare
  v_agora  timestamptz := now();
  v_ordem  text := p_carga->>'ordem_numero';
  v_item   jsonb;
  v_pid    uuid;
  v_id     uuid;
  v_sacos  numeric := 0;
begin
  if v_ordem is null or v_ordem = '' then
    raise exception 'Carga sem número de ordem.';
  end if;
  if coalesce(jsonb_array_length(p_itens),0) = 0 then
    raise exception 'Carga sem nenhum item.';
  end if;

  update producao_pallets
     set estoque_status='estoque', ordem_numero=null, pedido_numero=null,
         cliente_dest=null, carregado_em=null
   where id = any(p_devolver);

  for v_item in select * from jsonb_array_elements(p_itens) loop
    v_pid := nullif(v_item->>'pallet_id','')::uuid;

    -- item SEM pallet (modo quantidade): só entra no documento
    if v_pid is null then
      if coalesce((v_item->>'avulso')::boolean, false)
         and coalesce((v_item->>'sacos')::numeric, 0) > 0 then
        v_sacos := v_sacos + (v_item->>'sacos')::numeric;
        continue;
      end if;
      raise exception 'Item sem pallet_id no snapshot da carga (e não marcado como avulso).';
    end if;

    update producao_pallets
       set estoque_status='carregado',
           ordem_numero  = v_ordem,
           pedido_numero = coalesce(v_item->>'pedido',''),
           cliente_dest  = coalesce(v_item->>'cliente',''),
           carregado_em  = v_agora
     where id = v_pid;
    if not found then
      raise exception 'Pallet % não existe mais no banco — recarregue a tela.', v_pid;
    end if;
    v_sacos := v_sacos + coalesce((v_item->>'sacos')::numeric, 0);
  end loop;

  if p_edit_id is not null then
    update carregamentos
       set itens = p_itens, total_pallets = (
             select count(*) from jsonb_array_elements(p_itens) x
              where nullif(x->>'pallet_id','') is not null)
     where id = p_edit_id
     returning id into v_id;
    if v_id is null then
      raise exception 'Carga em edição não encontrada (id %).', p_edit_id;
    end if;
  else
    insert into carregamentos (ordem_numero, data, hora, motorista, placa, transportadora, total_pallets, itens)
    values (v_ordem,
            coalesce((p_carga->>'data')::date, current_date),
            p_carga->>'hora',
            nullif(p_carga->>'motorista',''),
            nullif(p_carga->>'placa',''),
            nullif(p_carga->>'transportadora',''),
            (select count(*) from jsonb_array_elements(p_itens) x
              where nullif(x->>'pallet_id','') is not null),
            p_itens)
    returning id into v_id;
  end if;

  if p_romaneio_id is not null then
    update romaneios set status='carregado', atualizado_em=v_agora where id=p_romaneio_id;
  end if;

  return jsonb_build_object('id', v_id,
    'itens', jsonb_array_length(p_itens),
    'pallets', (select count(*) from jsonb_array_elements(p_itens) x
                 where nullif(x->>'pallet_id','') is not null),
    'sacos', v_sacos);
end;
$$;

create or replace function public.rpc_remover_item_carga(
  p_carga_id   uuid,
  p_item_index integer   -- posição do item em carregamentos.itens (0-based)
) returns jsonb
language plpgsql
set search_path = public
as $$
declare
  v_itens jsonb;
  v_item  jsonb;
  v_pid   uuid;
  v_novo  jsonb;
begin
  select itens into v_itens from carregamentos where id = p_carga_id for update;
  if not found then
    raise exception 'Carga não encontrada (id %).', p_carga_id;
  end if;
  if p_item_index < 0 or p_item_index >= coalesce(jsonb_array_length(v_itens),0) then
    raise exception 'Item % não existe nesta carga.', p_item_index;
  end if;

  v_item := v_itens->p_item_index;
  v_pid  := nullif(v_item->>'pallet_id','')::uuid;

  if v_pid is not null then
    update producao_pallets
       set estoque_status='estoque', ordem_numero=null, pedido_numero=null,
           cliente_dest=null, carregado_em=null
     where id = v_pid and estoque_status='carregado';
  end if;

  v_novo := (v_itens - p_item_index);
  update carregamentos
     set itens = v_novo,
         total_pallets = (select count(*) from jsonb_array_elements(v_novo) x
                           where nullif(x->>'pallet_id','') is not null)
   where id = p_carga_id;

  return jsonb_build_object('itens_restantes', jsonb_array_length(v_novo),
                            'pallet_devolvido', v_pid is not null);
end;
$$;
