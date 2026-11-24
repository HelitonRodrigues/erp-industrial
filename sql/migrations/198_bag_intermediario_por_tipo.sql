-- (24/11/2026) O intermediário "Bag Cinza p/ Impermeabilizante" mudou de código (INT-0001 → ALM-0556):
-- tg_bag_intermediario e mp_lote_alocar_intermediario passam a achar pelo tipo INTERMEDIARIO + nome.
create or replace function public.tg_bag_intermediario()
 returns trigger language plpgsql security definer set search_path to 'public' as $function$
declare v_int uuid; v_cinza uuid;
begin
  select id into v_int from insumos where tipo='INTERMEDIARIO' and nome ilike 'Bag Cinza%' order by (codigo='INT-0001') desc limit 1;
  select id into v_cinza from insumos where nome='MP (Cinza)';
  if v_int is not null and new.tipo='consumo' and new.insumo_id=v_cinza and new.produto ilike 'big bag caulim cinza c/ imp%' then
    insert into insumos_movimentos (insumo_id,data,tipo,quantidade,qtd_teorica,custo_unitario,origem,origem_id,responsavel,obs,produto,barracao)
    values (v_int,new.data,'entrada',new.quantidade,new.quantidade,new.custo_unitario,'OP',new.origem_id,new.responsavel,
            'Bag Cinza da mistura (intermediário) — gerado pela OP '||coalesce(new.origem_id,''),new.produto,new.barracao);
  end if;
  return new;
end $function$;
-- mp_lote_alocar_intermediario: trocado "where i.codigo='INT-0001'" por "where i.tipo='INTERMEDIARIO' and i.nome ilike 'Bag Cinza%'" (aplicado direto no banco).
