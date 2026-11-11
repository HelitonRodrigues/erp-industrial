-- 120 — Programação de Cargas: dados da página do pedido no Salescode (representante etc.)
-- Inclui a correção da 119 (pedido normalizado) — pode rodar mesmo se a 119 não foi rodada.
alter table programacao_cargas add column if not exists representante text;
alter table programacao_cargas add column if not exists comprador text;
alter table programacao_cargas add column if not exists detalhes jsonb;
alter table programacao_cargas add column if not exists detalhes_em timestamptz;
create index if not exists programacao_cargas_rep_idx on programacao_cargas (representante);

create or replace function sync_salescode(p_token text, p_itens jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare n_up int := 0; n_saiu int := 0;
begin
  if auth.uid() is null and not _prog_token_ok(p_token) then raise exception 'token inválido'; end if;
  if p_itens is null or jsonb_array_length(p_itens) < 5 then
    return jsonb_build_object('ok', false, 'motivo', 'lista vazia ou muito curta — nada alterado');
  end if;
  create temp table _sc on commit drop as
    select distinct on (pedido, produto) pedido, produto, x from (
      select upper(substring(btrim(x->>'pedido') from '^[A-Za-z0-9]+')) pedido, btrim(x->>'produto') produto, x
      from jsonb_array_elements(p_itens) x) s
    where coalesce(pedido,'') <> ''
    order by pedido, produto, (nullif(btrim(x->>'status'),'') is null);
  with agg as (
    select pedido,
      jsonb_agg(jsonb_build_object(
        'produto', produto,
        'qtd', nullif(replace(replace(regexp_replace(coalesce(x->>'qtd',''), '[^0-9,\.]', '', 'g'), '.', ''), ',', '.'), '')::numeric,
        'unidade', upper(btrim(regexp_replace(coalesce(x->>'qtd',''), '[0-9,\.\s]', '', 'g')))
      )) itens,
      max(x->>'cliente') cliente, max(x->>'cidade') cidade, max(x->>'frete') frete,
      min(_prog_data(x->>'data')) data_sc,
      max(nullif(btrim(x->>'status'),'')) status, max(x->>'view') view
    from _sc group by pedido
  ), up as (
    insert into programacao_cargas as p (pedido, em_salescode, data_salescode, status_salescode, cliente_salescode, cidade, frete, salescode_view, itens, atualizado_salescode)
    select pedido, true, data_sc, status, cliente, cidade, frete, view, itens, now() from agg
    on conflict (pedido) do update set
      em_salescode = true, data_salescode = excluded.data_salescode,
      status_salescode = coalesce(excluded.status_salescode, p.status_salescode),
      cliente_salescode = excluded.cliente_salescode, cidade = excluded.cidade, frete = excluded.frete,
      salescode_view = excluded.salescode_view, itens = excluded.itens,
      atualizado_salescode = now(), updated_at = now()
    returning 1
  ) select count(*) into n_up from up;
  with saiu as (
    update programacao_cargas p set
      em_salescode = false,
      carregado = case when p.carregado_manual then p.carregado else true end,
      carregado_em = case when p.carregado_manual or p.carregado then p.carregado_em else now() end,
      carregado_origem = case when p.carregado_manual or p.carregado then p.carregado_origem else 'salescode' end,
      updated_at = now()
    where p.em_salescode and p.pedido not in (select pedido from _sc)
    returning 1
  ) select count(*) into n_saiu from saiu;
  return jsonb_build_object('ok', true, 'pedidos', n_up, 'sairam', n_saiu, 'em', now(),
    'precisa_detalhe', coalesce((select jsonb_agg(jsonb_build_object('pedido', p.pedido, 'view', p.salescode_view))
      from programacao_cargas p
      where p.em_salescode and not p.carregado and p.salescode_view is not null
        and (p.detalhes_em is null or p.detalhes_em < now() - interval '20 hours'
             or p.status_salescode is distinct from p.detalhes->>'_status')), '[]'::jsonb));
end $$;


-- p_det: [{pedido, representante, comprador, emissao, entrega, obs, transportadora, placa_motorista, pagamento,
--          condicoes, entrega_cidade, valor_total, _status, _bruto:[...]}]
create or replace function sync_salescode_detalhes(p_token text, p_det jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare n int := 0;
begin
  if auth.uid() is null and not _prog_token_ok(p_token) then raise exception 'token inválido'; end if;
  with d as (
    select upper(substring(btrim(x->>'pedido') from '^[A-Za-z0-9]+')) pedido, x from jsonb_array_elements(coalesce(p_det,'[]'::jsonb)) x
  ), up as (
    update programacao_cargas p set
      representante = nullif(btrim(d.x->>'representante'),''),
      comprador     = nullif(btrim(d.x->>'comprador'),''),
      detalhes      = (d.x - 'pedido') || jsonb_build_object('_status', p.status_salescode),
      detalhes_em   = now(), updated_at = now()
    from d where p.pedido = d.pedido
    returning 1
  ) select count(*) into n from up;
  return jsonb_build_object('ok', true, 'detalhes', n);
end $$;
revoke all on function sync_salescode_detalhes(text, jsonb) from public;
grant execute on function sync_salescode_detalhes(text, jsonb) to anon, authenticated;

-- limpa as cópias "XXXX prog." criadas antes da correção (o pedido certo continua)
delete from programacao_cargas where pedido ~ '\s' and not em_planilha and not carregado_manual and data_manual is null;
