-- 132 — Programação de Cargas reconhece a SAÍDA pela Portaria (16/11/2026)
-- Quando a portaria.html dá saída no caminhão (portaria.status = 'finalizado' + hora_saida), cada pedido da ordem
-- (romaneio_itens.pedido, normalizado igual ao Salescode: ^[A-Za-z0-9]+ maiúsculo) vira CARREGADO na Programação:
--   não carregado ............................ carregado_em = hora_saida, origem 'portaria', por 'Portaria · ordem N · placa'
--   carregado automático (salescode/planilha) .. data corrigida para a saída
--   carregado pela balança ou marcado na mão .... só guarda a informação da portaria
-- Guarda programacao_cargas.portaria {id, ordem, placa, saida, liquido_kg, pedido_qtd, carregado_qtd, motivo_menos}.
-- Desfazer a saída (↩ voltar para o carregamento) volta o pedido que a portaria tinha marcado.
alter table programacao_cargas add column if not exists portaria jsonb;

create or replace function prog_portaria_saida() returns trigger language plpgsql security definer set search_path = public as $$
declare rom record; ped text; r record; info jsonb; q_ped numeric; q_car numeric; mot text;
begin
  -- saída desfeita (finalizado -> outro status): devolve o que a portaria marcou
  if tg_op = 'UPDATE' and old.status = 'finalizado' and new.status is distinct from 'finalizado' then
    update programacao_cargas set carregado = false, carregado_em = null, carregado_por = null, carregado_origem = null, portaria = null, updated_at = now()
     where carregado_origem = 'portaria' and not coalesce(carregado_manual, false) and portaria->>'id' = old.id::text;
    update programacao_cargas set portaria = null, updated_at = now()
     where portaria->>'id' = old.id::text;
    return new;
  end if;
  if new.status is distinct from 'finalizado' or new.hora_saida is null or new.romaneio_id is null then return new; end if;
  if tg_op = 'UPDATE' and old.status = 'finalizado' and old.hora_saida is not distinct from new.hora_saida
     and old.romaneio_id is not distinct from new.romaneio_id then return new; end if;
  select id, numero into rom from romaneios where id = new.romaneio_id;
  if rom.id is null then return new; end if;
  for ped in select distinct upper(substring(btrim(i.pedido) from '^[A-Za-z0-9]+'))
               from romaneio_itens i where i.romaneio_id = rom.id and coalesce(btrim(i.pedido), '') <> '' loop
    if ped is null or ped = '' then continue; end if;
    select * into r from programacao_cargas where pedido = ped;
    if r.id is null then continue; end if;
    -- o que de fato saiu deste pedido (cargas da ordem) e se saiu menos
    select sum(coalesce(nullif(it->>'pedido_qtd','')::numeric, 0)) filter (where it ? 'pedido_qtd'),
           sum(coalesce(nullif(it->>'sacos','')::numeric, 0)),
           max(it->>'motivo_menos')
      into q_ped, q_car, mot
      from carregamentos c, jsonb_array_elements(c.itens) it
     where c.ordem_numero = rom.numero and not coalesce((it->>'doador')::boolean, false)
       and upper(substring(btrim(coalesce(it->>'pedido','')) from '^[A-Za-z0-9]+')) = ped;
    info := jsonb_strip_nulls(jsonb_build_object('id', new.id, 'ordem', rom.numero, 'placa', new.placa, 'saida', new.hora_saida,
              'liquido_kg', coalesce(new.peso_produto, new.peso_liquido), 'carregado_qtd', q_car, 'motivo_menos', mot));
    update programacao_cargas p set
      portaria = info,
      carregado = case when p.carregado_manual then p.carregado else true end,
      carregado_em = case when p.carregado_manual then p.carregado_em
                          when not p.carregado or p.carregado_origem in ('salescode','planilha','portaria') then new.hora_saida else p.carregado_em end,
      carregado_origem = case when p.carregado_manual then p.carregado_origem
                              when not p.carregado or p.carregado_origem in ('salescode','planilha','portaria') then 'portaria' else p.carregado_origem end,
      carregado_por = case when p.carregado_manual then p.carregado_por
                           when not p.carregado or p.carregado_origem in ('salescode','planilha','portaria')
                             then 'Portaria · ordem ' || rom.numero || coalesce(' · ' || new.placa, '') else p.carregado_por end,
      updated_at = now()
     where p.id = r.id;
  end loop;
  return new;
end $$;

create or replace trigger tg_prog_portaria_saida after insert or update of status, hora_saida, romaneio_id on portaria
  for each row execute function prog_portaria_saida();
