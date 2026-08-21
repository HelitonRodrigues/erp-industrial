-- ============================================================================
-- 024 — O retrato do fechamento passa a guardar a MEDIÇÃO de cada carga
--
-- `lenha_fechamentos.itens` guardava data, motorista, pesos e volume. Faltavam
-- as medidas que geraram o volume (lado 1, lado 2, largura, comprimento e a
-- média). Sem elas, a memória de medição do fechamento dependia de os
-- recebimentos continuarem existindo — e o retrato existe justamente para não
-- depender de nada.
--
-- Só a montagem do jsonb muda; nenhuma coluna é alterada e os fechamentos
-- antigos seguem válidos (a tela cai no recebimento quando o item é antigo).
-- ============================================================================

create or replace function public.rpc_fechar_lenha(p_dados jsonb, p_ids uuid[])
returns public.lenha_fechamentos
language plpgsql
as $function$
declare
  v_fech  public.lenha_fechamentos;
  v_forn  uuid    := nullif(p_dados->>'fornecedor_id','')::uuid;
  v_preco numeric := nullif(p_dados->>'preco_m3','')::numeric;
  v_qtd   integer;
begin
  if p_ids is null or coalesce(array_length(p_ids,1),0) = 0 then
    raise exception 'Nenhuma carga selecionada para o fechamento.';
  end if;
  if v_forn is null then
    raise exception 'Fechamento sem fornecedor.';
  end if;
  if v_preco is null or v_preco <= 0 then
    raise exception 'Fechamento sem preço do m³ — sem preço não há valor a faturar.';
  end if;
  if coalesce(trim(p_dados->>'assin_almox_nome'),'') = '' then
    raise exception 'Fechamento sem o nome de quem fechou (almoxarifado).';
  end if;

  perform 1 from public.lenha_recebimentos r where r.id = any(p_ids) for update;

  select count(*) into v_qtd
  from public.lenha_recebimentos r
  where r.id = any(p_ids)
    and r.status = 'ativo'
    and r.fechamento_id is null
    and r.fornecedor_id = v_forn;

  if v_qtd <> array_length(p_ids,1) then
    raise exception 'Alguma carga saiu da lista (já fechada, cancelada ou de outro fornecedor). Recarregue e tente de novo.';
  end if;

  insert into public.lenha_fechamentos (
    numero, fornecedor_id, fornecedor_nome, periodo_ini, periodo_fim, preco_m3,
    qtd_cargas, total_liquido_kg, total_m3, valor_total, itens, obs, status,
    assin_almox_nome, criado_por, atualizado_em)
  select
    nullif(p_dados->>'numero',''), v_forn, nullif(p_dados->>'fornecedor_nome',''),
    nullif(p_dados->>'periodo_ini','')::date, nullif(p_dados->>'periodo_fim','')::date, v_preco,
    count(*),
    coalesce(sum(r.peso_liquido),0),
    coalesce(sum(r.volume_m3),0),
    round(coalesce(sum(r.volume_m3),0) * v_preco, 2),
    coalesce(jsonb_agg(jsonb_build_object(
      'id',r.id,'numero',r.numero,'data',r.data,'hora',r.hora,
      'motorista',r.motorista_nome,'placa',r.placa,'almoxarife',r.almoxarife,
      'tara',r.peso_tara,'bruto',r.peso_bruto,'liquido',r.peso_liquido,
      'lado1',r.lado1,'lado2',r.lado2,'altura_media',r.altura_media,
      'largura',r.largura,'comprimento',r.comprimento,
      'kg_m3',r.kg_m3,'volume_m3',r.volume_m3,'especie',r.especie,'obs',r.obs)
      order by r.data, r.numero),'[]'::jsonb),
    nullif(p_dados->>'obs',''), 'fechado',
    trim(p_dados->>'assin_almox_nome'), nullif(p_dados->>'criado_por',''), now()
  from public.lenha_recebimentos r
  where r.id = any(p_ids)
  returning * into v_fech;

  update public.lenha_recebimentos
     set fechamento_id = v_fech.id, atualizado_em = now()
   where id = any(p_ids);

  return v_fech;
end
$function$;
