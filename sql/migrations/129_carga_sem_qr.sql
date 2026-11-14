-- 129 — Carregamento: item "rótulo antigo (sem QR)" enquanto houver rótulos antigos.
-- Chave geral em empresa_config.carga_sem_qr (true = aceita). Desligada, o banco recusa o item.
-- total_pallets da carga passa a somar os pallets/bags informados no sem QR (itens[].pallets_sem_qr).
alter table empresa_config add column if not exists carga_sem_qr boolean not null default true;

CREATE OR REPLACE FUNCTION public.rpc_salvar_carregamento(p_carga jsonb, p_itens jsonb, p_edit_id uuid DEFAULT NULL::uuid, p_devolver uuid[] DEFAULT '{}'::uuid[], p_romaneio_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb LANGUAGE plpgsql SET search_path TO 'public'
AS $function$
declare
  v_agora timestamptz := now(); v_ordem text := p_carga->>'ordem_numero';
  v_item jsonb; v_pid uuid; v_id uuid; v_sacos numeric := 0; v_old jsonb; v_doa integer := 0;
  v_npal integer; v_semqr_ok boolean;
begin
  if v_ordem is null or v_ordem = '' then raise exception 'Carga sem número de ordem.'; end if;
  if coalesce(jsonb_array_length(p_itens),0) = 0 then raise exception 'Carga sem nenhum item.'; end if;
  if exists (select 1 from jsonb_array_elements(p_itens) x where x->>'motivo_avulso' = 'rotulo_antigo') then
    select coalesce(bool_or(carga_sem_qr), true) into v_semqr_ok from empresa_config;
    if not coalesce(v_semqr_ok, true) then
      raise exception 'Carga sem QR (rótulo antigo) está desligada — bipe o QR de cada pallet.';
    end if;
  end if;
  if p_edit_id is not null then
    select itens into v_old from carregamentos where id = p_edit_id for update;
    perform _carga_aplicar_doacoes(v_old, -1, v_ordem);
  end if;
  update producao_pallets set estoque_status='estoque', ordem_numero=null, pedido_numero=null,
         cliente_dest=null, carregado_em=null where id = any(p_devolver);
  for v_item in select * from jsonb_array_elements(p_itens) loop
    if coalesce((v_item->>'doador')::boolean,false) then continue; end if;
    v_pid := nullif(v_item->>'pallet_id','')::uuid;
    if v_pid is null then
      if coalesce((v_item->>'avulso')::boolean, false) and coalesce((v_item->>'sacos')::numeric, 0) > 0 then
        v_sacos := v_sacos + (v_item->>'sacos')::numeric; continue; end if;
      if coalesce((v_item->>'avulso')::boolean, false) and coalesce((v_item->>'ton')::numeric, 0) > 0 then continue; end if;
      raise exception 'Item sem pallet_id no snapshot da carga (e não marcado como avulso).';
    end if;
    update producao_pallets set estoque_status='carregado', ordem_numero = v_ordem,
           pedido_numero = coalesce(v_item->>'pedido',''), cliente_dest = coalesce(v_item->>'cliente',''), carregado_em = v_agora
     where id = v_pid;
    if not found then raise exception 'Pallet % não existe mais no banco — recarregue a tela.', v_pid; end if;
    v_sacos := v_sacos + coalesce((v_item->>'sacos')::numeric, 0);
  end loop;
  select count(*) filter (where nullif(x->>'pallet_id','') is not null and not coalesce((x->>'doador')::boolean,false))
         + coalesce(sum(coalesce(nullif(x->>'pallets_sem_qr','')::numeric,0)),0)::int
    into v_npal from jsonb_array_elements(p_itens) x;
  if p_edit_id is not null then
    update carregamentos set itens = p_itens, total_pallets = v_npal where id = p_edit_id returning id into v_id;
    if v_id is null then raise exception 'Carga em edição não encontrada (id %).', p_edit_id; end if;
  else
    insert into carregamentos (ordem_numero, data, hora, motorista, placa, transportadora, total_pallets, itens)
    values (v_ordem, coalesce((p_carga->>'data')::date, current_date), p_carga->>'hora', nullif(p_carga->>'motorista',''),
            nullif(p_carga->>'placa',''), nullif(p_carga->>'transportadora',''), v_npal, p_itens)
    returning id into v_id;
  end if;
  v_doa := _carga_aplicar_doacoes(p_itens, 1, v_ordem);
  if p_romaneio_id is not null then update romaneios set status='carregado', atualizado_em=v_agora where id=p_romaneio_id; end if;
  return jsonb_build_object('id', v_id, 'itens', jsonb_array_length(p_itens), 'pallets', v_npal, 'pallets_abertos', v_doa, 'sacos', v_sacos);
end;
$function$;
