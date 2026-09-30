-- 042 · CARREGAMENTO — PALLET ABERTO (sacos tirados para completar outro pallet)
-- ─────────────────────────────────────────────────────────────────────────────
-- Caso de uso: o cliente pede pallet de 200 e o estoque só tem pallet de 180.
-- O operador completa cada pallet da carga com 20 sacos tirados de OUTRO pallet
-- do mesmo produto e bipa esse pallet ("tirei sacos deste").
--
-- Antes: os sacos a mais saíam do estoque só no "Movimento do dia"; o pallet
-- de onde saíram continuava com 180 no estoque — um estoque que não existia.
--
-- Agora:
--   • producao_pallets.sacos_retirados guarda quantos sacos já saíram do pallet
--     (saldo do pallet = capacidade − sacos_retirados);
--   • o item da carga com  "doador": true  registra de qual pallet saíram e
--     quantos ("sacos_retirados"); "consumido": true quando o pallet zerou;
--   • pallet que zerou sai do estoque junto com a carga (estoque_status =
--     'carregado', com a ordem) — reabrir/excluir a carga devolve tudo.
-- Migração ADITIVA: coluna com default 0, as RPCs antigas continuam iguais para
-- cargas sem item doador.

alter table public.producao_pallets
  add column if not exists sacos_retirados numeric not null default 0;

comment on column public.producao_pallets.sacos_retirados is
  'Sacos tirados deste pallet para completar outros pallets numa carga (saldo = capacidade − sacos_retirados).';

-- aplica (+1) ou desfaz (−1) as retiradas de uma lista de itens de carga
create or replace function public._carga_aplicar_doacoes(p_itens jsonb, p_sinal integer, p_ordem text)
returns integer
language plpgsql
set search_path to 'public'
as $$
declare
  v_item jsonb;
  v_pid  uuid;
  v_q    numeric;
  v_n    integer := 0;
begin
  for v_item in select * from jsonb_array_elements(coalesce(p_itens,'[]'::jsonb)) loop
    if not coalesce((v_item->>'doador')::boolean,false) then continue; end if;
    v_pid := nullif(v_item->>'pallet_id','')::uuid;
    v_q   := coalesce((v_item->>'sacos_retirados')::numeric,0);
    if v_pid is null or v_q <= 0 then continue; end if;

    update producao_pallets
       set sacos_retirados = greatest(0, coalesce(sacos_retirados,0) + p_sinal * v_q)
     where id = v_pid;
    if not found then
      raise exception 'Pallet % (de onde saíram sacos) não existe mais — recarregue a tela.', v_pid;
    end if;

    if coalesce((v_item->>'consumido')::boolean,false) then
      if p_sinal > 0 then
        update producao_pallets
           set estoque_status='carregado', ordem_numero=p_ordem,
               pedido_numero=coalesce(v_item->>'pedido',''), cliente_dest=coalesce(v_item->>'cliente',''),
               carregado_em=now()
         where id = v_pid;
      else
        update producao_pallets
           set estoque_status='estoque', ordem_numero=null, pedido_numero=null,
               cliente_dest=null, carregado_em=null
         where id = v_pid and estoque_status='carregado';
      end if;
    end if;
    v_n := v_n + 1;
  end loop;
  return v_n;
end $$;

revoke all on function public._carga_aplicar_doacoes(jsonb,integer,text) from anon, authenticated;

-- ── SALVAR CARGA ─────────────────────────────────────────────────────────────
create or replace function public.rpc_salvar_carregamento(
  p_carga jsonb, p_itens jsonb, p_edit_id uuid default null,
  p_devolver uuid[] default '{}'::uuid[], p_romaneio_id uuid default null)
returns jsonb
language plpgsql
set search_path to 'public'
as $function$
declare
  v_agora  timestamptz := now();
  v_ordem  text := p_carga->>'ordem_numero';
  v_item   jsonb;
  v_pid    uuid;
  v_id     uuid;
  v_sacos  numeric := 0;
  v_old    jsonb;
  v_doa    integer := 0;
begin
  if v_ordem is null or v_ordem = '' then
    raise exception 'Carga sem número de ordem.';
  end if;
  if coalesce(jsonb_array_length(p_itens),0) = 0 then
    raise exception 'Carga sem nenhum item.';
  end if;

  -- editando: desfaz as retiradas gravadas antes (serão reaplicadas abaixo)
  if p_edit_id is not null then
    select itens into v_old from carregamentos where id = p_edit_id for update;
    perform _carga_aplicar_doacoes(v_old, -1, v_ordem);
  end if;

  update producao_pallets
     set estoque_status='estoque', ordem_numero=null, pedido_numero=null,
         cliente_dest=null, carregado_em=null
   where id = any(p_devolver);

  for v_item in select * from jsonb_array_elements(p_itens) loop
    -- pallet de onde saíram sacos: tratado depois, não é pallet carregado
    if coalesce((v_item->>'doador')::boolean,false) then continue; end if;

    v_pid := nullif(v_item->>'pallet_id','')::uuid;

    if v_pid is null then
      if coalesce((v_item->>'avulso')::boolean, false)
         and coalesce((v_item->>'sacos')::numeric, 0) > 0 then
        v_sacos := v_sacos + (v_item->>'sacos')::numeric;
        continue;
      end if;
      if coalesce((v_item->>'avulso')::boolean, false)
         and coalesce((v_item->>'ton')::numeric, 0) > 0 then
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
              where nullif(x->>'pallet_id','') is not null
                and not coalesce((x->>'doador')::boolean,false))
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
              where nullif(x->>'pallet_id','') is not null
                and not coalesce((x->>'doador')::boolean,false)),
            p_itens)
    returning id into v_id;
  end if;

  v_doa := _carga_aplicar_doacoes(p_itens, 1, v_ordem);

  if p_romaneio_id is not null then
    update romaneios set status='carregado', atualizado_em=v_agora where id=p_romaneio_id;
  end if;

  return jsonb_build_object('id', v_id,
    'itens', jsonb_array_length(p_itens),
    'pallets', (select count(*) from jsonb_array_elements(p_itens) x
                 where nullif(x->>'pallet_id','') is not null
                   and not coalesce((x->>'doador')::boolean,false)),
    'pallets_abertos', v_doa,
    'sacos', v_sacos);
end;
$function$;

-- ── REABRIR / EXCLUIR CARGA ──────────────────────────────────────────────────
create or replace function public.rpc_reabrir_carga(p_carga_id uuid, p_excluir boolean default false)
returns jsonb
language plpgsql
set search_path to 'public'
as $function$
declare
  v_carga carregamentos%rowtype;
  v_ids   uuid[];
  v_qtd   integer;
begin
  select * into v_carga from carregamentos where id = p_carga_id for update;
  if not found then
    raise exception 'Carga não encontrada (id %).', p_carga_id;
  end if;

  -- devolve os sacos tirados dos pallets abertos (e o pallet que tinha zerado)
  perform _carga_aplicar_doacoes(v_carga.itens, -1, v_carga.ordem_numero);

  select coalesce(array_agg((x->>'pallet_id')::uuid), '{}')
    into v_ids
    from jsonb_array_elements(coalesce(v_carga.itens,'[]'::jsonb)) x
   where x->>'pallet_id' is not null
     and not coalesce((x->>'doador')::boolean,false);

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
$function$;

-- ── REMOVER UM ITEM DA CARGA ─────────────────────────────────────────────────
create or replace function public.rpc_remover_item_carga(p_carga_id uuid, p_item_index integer)
returns jsonb
language plpgsql
set search_path to 'public'
as $function$
declare
  v_itens jsonb;
  v_item  jsonb;
  v_pid   uuid;
  v_novo  jsonb;
  v_ordem text;
begin
  select itens, ordem_numero into v_itens, v_ordem from carregamentos where id = p_carga_id for update;
  if not found then
    raise exception 'Carga não encontrada (id %).', p_carga_id;
  end if;
  if p_item_index < 0 or p_item_index >= coalesce(jsonb_array_length(v_itens),0) then
    raise exception 'Item % não existe nesta carga.', p_item_index;
  end if;

  v_item := v_itens->p_item_index;
  v_pid  := nullif(v_item->>'pallet_id','')::uuid;

  if coalesce((v_item->>'doador')::boolean,false) then
    perform _carga_aplicar_doacoes(jsonb_build_array(v_item), -1, v_ordem);
  elsif v_pid is not null then
    update producao_pallets
       set estoque_status='estoque', ordem_numero=null, pedido_numero=null,
           cliente_dest=null, carregado_em=null
     where id = v_pid and estoque_status='carregado';
  end if;

  v_novo := (v_itens - p_item_index);
  update carregamentos
     set itens = v_novo,
         total_pallets = (select count(*) from jsonb_array_elements(v_novo) x
                           where nullif(x->>'pallet_id','') is not null
                             and not coalesce((x->>'doador')::boolean,false))
   where id = p_carga_id;

  return jsonb_build_object('itens_restantes', jsonb_array_length(v_novo),
                            'pallet_devolvido', v_pid is not null);
end;
$function$;
