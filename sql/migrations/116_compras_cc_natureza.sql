-- 116 — Compras: centro de custo e natureza acompanham o item até o pedido (nov/2026).
-- Antes, CC e natureza ficavam só na solicitação (compras_solicitacoes.itens) e se perdiam na cotação e no pedido.
-- 1) _compras_gerar_pedidos passa a copiar centro_custo / natureza (e ids) de cada item da cotação para o pedido.
-- 2) Preenche cotações e pedidos já existentes com o CC/natureza do item da solicitação (só onde estava vazio).

create or replace function public._compras_gerar_pedidos(p_cot uuid, p_por text, p_emerg boolean)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare
  c compras_cotacoes%rowtype; v_fid text; v_prop jsonb; v_itens jsonb; v_total numeric; v_num int;
  v_out jsonb := '[]'::jsonb; v_id uuid; v_h int; v_hoje date := (now() at time zone 'America/Sao_Paulo')::date; v_prazo int;
begin
  select * into c from compras_cotacoes where id = p_cot for update;
  if not found then raise exception 'Cotação não encontrada.'; end if;
  select coalesce(compras_prazo_ratificacao_h,24) into v_h from empresa_config limit 1;
  perform pg_advisory_xact_lock(hashtext('compras_pedidos_numero'));
  for v_fid in
    select distinct case when c.escolha->>'modo'='item' then c.escolha->'por_item'->>(it->>'k') else c.escolha->>'fornecedor_id' end
      from jsonb_array_elements(coalesce(c.itens,'[]'::jsonb)) it
  loop
    continue when v_fid is null or v_fid = '';
    select p into v_prop from jsonb_array_elements(coalesce(c.propostas,'[]'::jsonb)) p where p->>'fornecedor_id' = v_fid limit 1;
    if v_prop is null then raise exception 'Fornecedor escolhido sem proposta na cotação.'; end if;
    select jsonb_agg(jsonb_build_object('insumo_id',it->>'insumo_id','nome',it->>'nome','unidade',coalesce(it->>'unidade','un'),
             'qtd',(it->>'qtd')::numeric,'preco_unit',(v_prop->'precos'->>(it->>'k'))::numeric,'qtd_recebida',0,
             'centro_custo',coalesce(it->>'centro_custo',''),'natureza',coalesce(it->>'natureza',''),
             'centro_custo_id',it->>'centro_custo_id','natureza_id',it->>'natureza_id') order by it->>'k'),
           sum((it->>'qtd')::numeric * coalesce((v_prop->'precos'->>(it->>'k'))::numeric,0))
      into v_itens, v_total
      from jsonb_array_elements(c.itens) it
     where (case when c.escolha->>'modo'='item' then c.escolha->'por_item'->>(it->>'k') else c.escolha->>'fornecedor_id' end) = v_fid;
    if v_itens is null then continue; end if;
    if exists(select 1 from jsonb_array_elements(v_itens) x where (x->>'preco_unit') is null) then
      raise exception 'Fornecedor % sem preço para algum item escolhido.', v_prop->>'fornecedor';
    end if;
    v_prazo := nullif(v_prop->>'prazo_dias','')::int;
    select coalesce(max(numero),0)+1 into v_num from compras_pedidos;
    insert into compras_pedidos(numero,solicitacao_id,cotacao_id,data,comprador,fornecedor_id,fornecedor,condicao_pagamento,prazo_entrega,
        status,valor_total,itens,historico,obs,emergencial,motivo_direto,aprovado_por,aprovado_em,ratificar_ate,frete,prazo_dias,atualizado_em)
    values (v_num,c.solicitacao_id,c.id,v_hoje,c.comprador,nullif(v_fid,'')::uuid,v_prop->>'fornecedor',v_prop->>'pagamento',
        case when v_prazo is not null then v_hoje + v_prazo end,
        'emitido', round(v_total + coalesce(nullif(v_prop->>'frete','')::numeric,0),2), v_itens,
        jsonb_build_array(jsonb_build_object('acao','emitido','por',p_por,'em',now(),
          'obs',case when p_emerg then 'Compra emergencial liberada (máquina parada / urgência) — gerente confirma depois' else 'Aprovado pelo gerente' end)),
        case when c.tipo='direta' then 'Compra direta' else 'Cotação #'||c.numero end,
        p_emerg, c.motivo_direto,
        case when p_emerg then null else p_por end, case when p_emerg then null else now() end,
        case when p_emerg then now() + make_interval(hours => v_h) end,
        nullif(v_prop->>'frete','')::numeric, v_prazo, now())
    returning id into v_id;
    v_out := v_out || jsonb_build_object('id',v_id,'numero',v_num,'fornecedor',v_prop->>'fornecedor');
  end loop;
  if jsonb_array_length(v_out)=0 then raise exception 'Nenhum item escolhido para comprar.'; end if;
  update compras_solicitacoes set status='em_pedido', atualizado_em=now(),
     historico = coalesce(historico,'[]'::jsonb) || jsonb_build_object('acao','em_pedido','por',p_por,'em',now(),
       'obs','Pedido(s) '||(select string_agg('#'||lpad(x->>'numero',4,'0'),', ') from jsonb_array_elements(v_out) x))
   where id = c.solicitacao_id;
  return v_out;
end $$;


-- ── preencher o que já existe (só onde está vazio) ──
update compras_cotacoes c set itens = x.novo
from (
  select c2.id, jsonb_agg(
    case when coalesce(it->>'centro_custo','')<>'' and coalesce(it->>'natureza','')<>'' then it
         else it || jsonb_strip_nulls(jsonb_build_object(
           'centro_custo', coalesce(nullif(it->>'centro_custo',''), m->>'centro_custo'),
           'natureza',     coalesce(nullif(it->>'natureza',''),     m->>'natureza'))) end
    order by t.ord) as novo
  from compras_cotacoes c2
  join compras_solicitacoes s on s.id = c2.solicitacao_id
  cross join lateral jsonb_array_elements(c2.itens) with ordinality t(it, ord)
  left join lateral (
    select si from jsonb_array_elements(case when jsonb_typeof(s.itens)='array' then s.itens else '[]'::jsonb end) si
     where (si->>'insumo_id' is not null and si->>'insumo_id' = it->>'insumo_id') or lower(si->>'nome') = lower(it->>'nome')
     limit 1) mm(m) on true
  where jsonb_typeof(c2.itens) = 'array'
  group by c2.id) x
where x.id = c.id and x.novo is distinct from c.itens;

update compras_pedidos c set itens = x.novo
from (
  select c2.id, jsonb_agg(
    case when coalesce(it->>'centro_custo','')<>'' and coalesce(it->>'natureza','')<>'' then it
         else it || jsonb_strip_nulls(jsonb_build_object(
           'centro_custo', coalesce(nullif(it->>'centro_custo',''), m->>'centro_custo'),
           'natureza',     coalesce(nullif(it->>'natureza',''),     m->>'natureza'))) end
    order by t.ord) as novo
  from compras_pedidos c2
  join compras_solicitacoes s on s.id = c2.solicitacao_id
  cross join lateral jsonb_array_elements(c2.itens) with ordinality t(it, ord)
  left join lateral (
    select si from jsonb_array_elements(case when jsonb_typeof(s.itens)='array' then s.itens else '[]'::jsonb end) si
     where (si->>'insumo_id' is not null and si->>'insumo_id' = it->>'insumo_id') or lower(si->>'nome') = lower(it->>'nome')
     limit 1) mm(m) on true
  where jsonb_typeof(c2.itens) = 'array'
  group by c2.id) x
where x.id = c.id and x.novo is distinct from c.itens;
