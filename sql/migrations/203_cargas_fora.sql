-- 203 · 🚧 CARGA FORA DA FÁBRICA — caminhão que já saiu carregado e quebrou (ou outro motivo).
-- Abrir (portaria, SADM/ADM): cria a ordem de RECOLETA (<nº>-2, -3…) com os mesmos pedidos para o caminhão que vem buscar
--   (carga nova sai do estoque normalmente na bipagem) e registra os pallets que ficaram no caminhão parado.
-- Enquanto aberta: aparece na Portaria (faixa no topo) e no Fechamento do Dia (aviso).
-- Resolver: 'voltou' (pallets voltam ao estoque + pa_ajustes motivo 'retorno_carga' para o fechamento),
--           'outros_pedidos' (a carga vira outros pedidos: marcados como carregados), 'perda' (baixa definitiva).
create table if not exists public.cargas_fora (
  id uuid primary key default gen_random_uuid(),
  criado_em timestamptz not null default now(),
  criado_por text,
  portaria_id uuid,
  romaneio_id uuid,
  ordem_numero text,
  placa text, motorista text, transportadora text,
  saiu_em timestamptz,
  motivo text not null default 'Caminhão quebrou',
  obs text,
  recoleta_numero text,
  recoleta_romaneio_id uuid,
  pallets jsonb not null default '[]',      -- [{id,codigo,produto,sacos,pedido}]
  produtos jsonb not null default '[]',     -- [{produto,pallets,sacos}]
  status text not null default 'aberta' check (status in ('aberta','voltou','outros_pedidos','perda')),
  resolvido_em timestamptz, resolvido_por text, resolucao_obs text, resolucao_pedidos text[]
);
create index if not exists cargas_fora_status on public.cargas_fora(status);
alter table public.cargas_fora enable row level security;
drop policy if exists baseline_authenticated_all on public.cargas_fora;
create policy baseline_authenticated_all on public.cargas_fora for all to authenticated using (true) with check (true);

-- abrir: a partir da passagem da portaria que já saiu
create or replace function public.carga_fora_abrir(p_portaria_id uuid, p_motivo text, p_obs text, p_usuario text)
returns jsonb language plpgsql set search_path to 'public' as $$
declare v record; o record; n int := 2; num text; rid uuid; cid uuid; pal jsonb; prods jsonb;
begin
  select * into v from portaria where id = p_portaria_id;
  if v.id is null then raise exception 'Passagem não encontrada.'; end if;
  if v.status <> 'finalizado' or v.numero_ordem is null then raise exception 'Só dá para usar em caminhão que já saiu carregado (com ordem).'; end if;
  if exists (select 1 from cargas_fora where portaria_id = p_portaria_id and status = 'aberta') then raise exception 'Esta carga já está aberta como fora da fábrica.'; end if;
  select * into o from romaneios where id = v.romaneio_id or numero = v.numero_ordem order by (id = v.romaneio_id) desc limit 1;
  if o.id is null then raise exception 'Ordem % não encontrada.', v.numero_ordem; end if;
  -- pallets que estavam no caminhão (o que foi bipado na ordem)
  select coalesce(jsonb_agg(jsonb_build_object('id', i->>'pallet_id', 'codigo', i->>'codigo', 'produto', i->>'produto',
           'sacos', coalesce(nullif(i->>'sacos','')::numeric, 0), 'pedido', i->>'pedido')), '[]')
    into pal from carregamentos c, jsonb_array_elements(c.itens) i where c.ordem_numero = v.numero_ordem and coalesce((i->>'doador')::boolean,false) = false;
  select coalesce(jsonb_agg(jsonb_build_object('produto', produto, 'pallets', np, 'sacos', sc) order by produto), '[]') into prods
    from (select x->>'produto' produto, count(*) np, sum((x->>'sacos')::numeric) sc from jsonb_array_elements(pal) x group by 1) t;
  -- ordem de recoleta: <nº>-2, -3…
  loop num := regexp_replace(o.numero, '-\d+$', '') || '-' || n; exit when not exists (select 1 from romaneios where numero = num); n := n + 1; end loop;
  insert into romaneios(numero, data_emissao, transportadora, motorista, placa, status, origem, importado_em, atualizado_em, caminhao, paletes, bags, sacos, mapa, arquivo_path)
    values (num, to_char(now() at time zone 'America/Sao_Paulo','DD/MM/YYYY'), o.transportadora, null, null, 'recebido', 'recoleta', now(), now(), o.caminhao, o.paletes, o.bags, o.sacos, o.mapa, o.arquivo_path)
    returning id into rid;
  insert into romaneio_itens(romaneio_id, numero, pedido, cidade, cliente, produto, quantidade, caixa, lote, frete, unidades, ordem_entrega, produto_id, produto_erp, felis_item_id)
    select rid, num, pedido, cidade, cliente, produto, quantidade, caixa, null, frete, unidades, ordem_entrega, produto_id, produto_erp, felis_item_id from romaneio_itens where romaneio_id = o.id;
  insert into cargas_fora(criado_por, portaria_id, romaneio_id, ordem_numero, placa, motorista, transportadora, saiu_em, motivo, obs, recoleta_numero, recoleta_romaneio_id, pallets, produtos)
    values (p_usuario, v.id, o.id, v.numero_ordem, v.placa, v.nome_motorista, v.transportadora, v.hora_saida, coalesce(nullif(trim(p_motivo),''),'Caminhão quebrou'), nullif(trim(p_obs),''), num, rid, pal, prods)
    returning id into cid;
  update portaria set anotacoes = coalesce(anotacoes,'[]'::jsonb) || jsonb_build_array(jsonb_build_object('em', now(), 'por', p_usuario,
    'txt', '🚧 ' || coalesce(nullif(trim(p_motivo),''),'Caminhão quebrou') || ' depois de sair. Recoleta pela ordem ' || num || '. CARGA FORA DA FÁBRICA: ' || jsonb_array_length(pal) || ' pallet(s).' || coalesce(' ' || nullif(trim(p_obs),''), '')))
    where id = v.id;
  insert into auditoria(acao, modulo, registro_id, descricao, usuario_email)
    values ('UPDATE', 'PORTARIA', v.placa, '🚧 Carga fora da fábrica: ' || v.placa || ' · ordem ' || v.numero_ordem || ' (' || coalesce(nullif(trim(p_motivo),''),'Caminhão quebrou') || ') — recoleta ' || num || ' [' || coalesce(p_usuario,'') || ']', null);
  return jsonb_build_object('id', cid, 'recoleta', num, 'pallets', jsonb_array_length(pal));
end $$;

-- resolver: voltou / outros_pedidos / perda
create or replace function public.carga_fora_resolver(p_id uuid, p_tipo text, p_obs text, p_pedidos text[], p_usuario text)
returns jsonb language plpgsql set search_path to 'public' as $$
declare c record; ids uuid[]; hoje date := (now() at time zone 'America/Sao_Paulo')::date; np int := 0; nped int := 0; r record;
begin
  select * into c from cargas_fora where id = p_id for update;
  if c.id is null then raise exception 'Registro não encontrado.'; end if;
  if c.status <> 'aberta' then raise exception 'Esta carga já foi resolvida.'; end if;
  if p_tipo not in ('voltou','outros_pedidos','perda') then raise exception 'Tipo inválido.'; end if;
  select array_agg((x->>'id')::uuid) into ids from jsonb_array_elements(c.pallets) x where coalesce(x->>'id','') ~ '^[0-9a-f-]{36}$';
  if p_tipo = 'voltou' then
    update producao_pallets set estoque_status = 'estoque', carregado_em = null, ordem_numero = null, romaneio_numero = null, pedido_numero = null, cliente_dest = null
      where id = any(coalesce(ids,'{}')) and estoque_status = 'carregado';
    get diagnostics np = row_count;
    for r in select x->>'produto' produto, sum((x->>'sacos')::numeric) sc from jsonb_array_elements(c.pallets) x group by 1 loop
      insert into pa_ajustes(data, produto, sacos, motivo, responsavel, obs)
        values (hoje, r.produto, r.sc, 'retorno_carga', p_usuario, 'Carga que voltou para a fábrica: ' || c.placa || ' · ordem ' || c.ordem_numero || coalesce(' · ' || nullif(trim(p_obs),''), ''));
    end loop;
  elsif p_tipo = 'outros_pedidos' then
    if coalesce(array_length(p_pedidos,1),0) = 0 then raise exception 'Informe os pedidos que levaram esta carga.'; end if;
    update programacao_cargas set carregado = true, carregado_em = now(), carregado_por = p_usuario, carregado_origem = 'carga_fora', updated_at = now(),
        portaria = jsonb_build_object('placa', c.placa, 'ordem', c.ordem_numero, 'carga_fora', c.id, 'obs', 'carga que estava no caminhão parado')
      where pedido = any(p_pedidos) and carregado = false and cancelado = false;
    get diagnostics nped = row_count;
    update producao_pallets set fora_estoque_motivo = 'Carga fora da fábrica (' || c.placa || ') foi para os pedidos ' || array_to_string(p_pedidos, ', ')
      where id = any(coalesce(ids,'{}'));
    get diagnostics np = row_count;
  else
    update producao_pallets set fora_estoque_motivo = 'Perda/avaria — carga fora da fábrica (' || c.placa || ')' || coalesce(': ' || nullif(trim(p_obs),''), '')
      where id = any(coalesce(ids,'{}'));
    get diagnostics np = row_count;
  end if;
  update cargas_fora set status = p_tipo, resolvido_em = now(), resolvido_por = p_usuario, resolucao_obs = nullif(trim(p_obs),''), resolucao_pedidos = p_pedidos where id = p_id;
  update portaria set anotacoes = coalesce(anotacoes,'[]'::jsonb) || jsonb_build_array(jsonb_build_object('em', now(), 'por', p_usuario,
    'txt', '🚧 Carga fora da fábrica resolvida: ' || case p_tipo when 'voltou' then 'VOLTOU para a fábrica (pallets de volta ao estoque)' when 'outros_pedidos' then 'foi para os pedidos ' || array_to_string(p_pedidos, ', ') else 'PERDA/avaria' end || coalesce(' — ' || nullif(trim(p_obs),''), '')))
    where id = c.portaria_id;
  insert into auditoria(acao, modulo, registro_id, descricao, usuario_email)
    values ('UPDATE', 'PORTARIA', c.placa, '🚧 Carga fora da fábrica ' || c.placa || ' · ordem ' || c.ordem_numero || ' resolvida: ' || p_tipo || coalesce(' (' || array_to_string(p_pedidos, ', ') || ')', '') || ' [' || coalesce(p_usuario,'') || ']', null);
  return jsonb_build_object('ok', true, 'pallets', np, 'pedidos', nped);
end $$;
grant execute on function public.carga_fora_abrir(uuid, text, text, text) to authenticated;
grant execute on function public.carga_fora_resolver(uuid, text, text, text[], text) to authenticated;
revoke execute on function public.carga_fora_abrir(uuid, text, text, text) from anon;
revoke execute on function public.carga_fora_resolver(uuid, text, text, text[], text) from anon;

-- caso de 25/11: NRZ2I41 (Pedro Mattos, Ynfinity) saiu em 24/11 com a ordem 028576 e quebrou; recoleta 028576-2 pelo ISV2A39
insert into public.cargas_fora(criado_por, portaria_id, romaneio_id, ordem_numero, placa, motorista, transportadora, saiu_em, motivo, obs, recoleta_numero, recoleta_romaneio_id, pallets, produtos)
select 'Heliton José de Almeida Rodrigues', p.id, p.romaneio_id, p.numero_ordem, p.placa, p.nome_motorista, p.transportadora, p.hora_saida, 'Caminhão quebrou',
       'Carga nova recoletada pelo ISV2A39 (Marcos Antonio) em 25/11; sem previsão de volta do NRZ2I41.', '028576-2',
       (select id from public.romaneios where numero = '028576-2'), pal.j,
       (select coalesce(jsonb_agg(jsonb_build_object('produto', produto, 'pallets', np, 'sacos', sc) order by produto), '[]')
          from (select x->>'produto' produto, count(*) np, sum((x->>'sacos')::numeric) sc from jsonb_array_elements(pal.j) x group by 1) t)
  from public.portaria p,
  lateral (select coalesce(jsonb_agg(jsonb_build_object('id', i->>'pallet_id', 'codigo', i->>'codigo', 'produto', i->>'produto',
              'sacos', coalesce(nullif(i->>'sacos','')::numeric, 0), 'pedido', i->>'pedido')), '[]') j
             from public.carregamentos c, jsonb_array_elements(c.itens) i where c.ordem_numero = p.numero_ordem) pal
 where p.id = '32967968-21df-483b-9b1f-0bc140d6911c'
   and not exists (select 1 from public.cargas_fora where portaria_id = p.id);
