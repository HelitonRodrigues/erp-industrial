-- 005 — Carregamento transacional (Etapa 2)
--
-- Antes: gravarCarregamento() fazia N updates de pallet um a um, depois o
-- insert da carga, depois o update do romaneio. Rede caindo no meio deixava
-- pallet 'carregado' sem carga gravada (ou o contrário).
--
-- Agora: cada operação composta é UMA function = UM commit. Ou grava tudo,
-- ou nada muda. As guardas da migration 003 (trigger pallet_guarda_estado)
-- continuam valendo DENTRO da function: se um pallet já estiver em outra
-- ordem, a exceção do trigger aborta a transação inteira.
--
-- Três operações:
--   rpc_salvar_carregamento  → salvar/atualizar a carga (pallets + documento + romaneio)
--   rpc_reabrir_carga        → devolve todos os pallets; zera OU exclui o documento
--   rpc_devolver_pallet      → remove UM item da carga e devolve o pallet
--
-- SECURITY INVOKER (padrão): roda com a permissão de quem chama; as policies
-- RLS existentes se aplicam normalmente.

create or replace function public.rpc_salvar_carregamento(
  p_carga       jsonb,             -- {ordem_numero, data, hora, motorista, placa, transportadora}
  p_itens       jsonb,             -- [{pallet_id, codigo, produto, sacos, sacos_base, sacos_extra, pedido, cliente, cidade, ...}] (snapshot completo, gravado como está)
  p_edit_id     uuid  default null,-- id em carregamentos quando é edição; null = carga nova
  p_devolver    uuid[] default '{}',-- pallets que estavam na carga e foram retirados
  p_romaneio_id uuid  default null -- romaneio a marcar como 'carregado'
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
    raise exception 'Carga sem nenhum pallet.';
  end if;

  -- 1) devolve ao estoque os pallets retirados da carga (edição)
  update producao_pallets
     set estoque_status='estoque', ordem_numero=null, pedido_numero=null,
         cliente_dest=null, carregado_em=null
   where id = any(p_devolver);

  -- 2) marca cada pallet da carga como carregado (o trigger da 003 valida
  --    transição e duplicidade; qualquer erro aborta TUDO)
  for v_item in select * from jsonb_array_elements(p_itens) loop
    v_pid := (v_item->>'pallet_id')::uuid;
    if v_pid is null then
      raise exception 'Item sem pallet_id no snapshot da carga.';
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

  -- 3) documento da carga (insert ou update, na mesma transação)
  if p_edit_id is not null then
    update carregamentos
       set itens = p_itens, total_pallets = jsonb_array_length(p_itens)
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
            jsonb_array_length(p_itens),
            p_itens)
    returning id into v_id;
  end if;

  -- 4) romaneio
  if p_romaneio_id is not null then
    update romaneios set status='carregado', atualizado_em=v_agora where id=p_romaneio_id;
  end if;

  return jsonb_build_object('id', v_id, 'pallets', jsonb_array_length(p_itens), 'sacos', v_sacos);
end;
$$;

create or replace function public.rpc_reabrir_carga(
  p_carga_id uuid,
  p_excluir  boolean default false   -- false = reabrir (documento fica vazio); true = excluir o documento
) returns jsonb
language plpgsql
set search_path = public
as $$
declare
  v_carga carregamentos%rowtype;
  v_ids   uuid[];
  v_qtd   integer;
begin
  select * into v_carga from carregamentos where id = p_carga_id;
  if not found then
    raise exception 'Carga não encontrada (id %).', p_carga_id;
  end if;

  select coalesce(array_agg((x->>'pallet_id')::uuid), '{}')
    into v_ids
    from jsonb_array_elements(coalesce(v_carga.itens,'[]'::jsonb)) x
   where x->>'pallet_id' is not null;

  update producao_pallets
     set estoque_status='estoque', ordem_numero=null, pedido_numero=null,
         cliente_dest=null, carregado_em=null
   where id = any(v_ids) and estoque_status='carregado';
  get diagnostics v_qtd = row_count;

  if p_excluir then
    delete from carregamentos where id = p_carga_id;
  else
    update carregamentos set itens='[]'::jsonb, total_pallets=0 where id = p_carga_id;
    update romaneios set status='em_carregamento', atualizado_em=now()
     where numero = v_carga.ordem_numero;
  end if;

  return jsonb_build_object('pallets_devolvidos', v_qtd, 'excluida', p_excluir);
end;
$$;

create or replace function public.rpc_devolver_pallet(
  p_carga_id  uuid,
  p_pallet_id uuid
) returns jsonb
language plpgsql
set search_path = public
as $$
declare
  v_itens jsonb;
  v_novo  jsonb;
begin
  select itens into v_itens from carregamentos where id = p_carga_id for update;
  if not found then
    raise exception 'Carga não encontrada (id %).', p_carga_id;
  end if;

  select coalesce(jsonb_agg(x), '[]'::jsonb)
    into v_novo
    from jsonb_array_elements(coalesce(v_itens,'[]'::jsonb)) x
   where (x->>'pallet_id')::uuid is distinct from p_pallet_id;

  if jsonb_array_length(v_novo) = jsonb_array_length(coalesce(v_itens,'[]'::jsonb)) then
    raise exception 'Este pallet não está nesta carga.';
  end if;

  update producao_pallets
     set estoque_status='estoque', ordem_numero=null, pedido_numero=null,
         cliente_dest=null, carregado_em=null
   where id = p_pallet_id and estoque_status='carregado';

  update carregamentos
     set itens = v_novo, total_pallets = jsonb_array_length(v_novo)
   where id = p_carga_id;

  return jsonb_build_object('pallets_restantes', jsonb_array_length(v_novo));
end;
$$;
