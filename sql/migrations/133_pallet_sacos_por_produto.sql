-- 133 — sacos do pallet numerados POR PRODUTO na OP (16/11/2026) — já aplicada no banco
-- Bug da 131: pallet_sacos_calc numerava os pallets da OP no total; numa OP com 2 produtos (ex.: Imperm50 + Topdry)
-- o P001 do 2º produto pegava o tamanho do 1º. Agora o nº do pallet é contado dentro do produto (k-ésimo pallet daquele
-- produto no op_mapa_cap). Granel fica na regra antiga. Sem achar, cai na pallet_sacos_calc da 131.
create or replace function pallet_sacos_calc_v2(p_lanc uuid, p_numero int, p_produto text) returns int language plpgsql stable as $$
declare v int; alvo text := norm_nome(p_produto);
begin
  if p_lanc is not null and p_produto not ilike '%granel%' then
    select cap into v from (select prod, cap, row_number() over (partition by prod order by n) k from op_mapa_cap(p_lanc)) x
     where prod = alvo and k = p_numero and cap > 0;
    if v > 0 then return v; end if;
  end if;
  return pallet_sacos_calc(p_lanc, p_numero, p_produto);
end $$;

create or replace function tg_pallet_sacos() returns trigger language plpgsql as $$
begin
  new.sacos_pallet := coalesce(pallet_sacos_calc_v2(new.lancamento_id, new.numero, new.produto), new.sacos_pallet);
  return new;
end $$;

create or replace function tg_op_recalc_sacos() returns trigger language plpgsql as $$
begin
  update producao_pallets p set sacos_pallet = coalesce(pallet_sacos_calc_v2(p.lancamento_id, p.numero, p.produto), p.sacos_pallet)
   where p.lancamento_id = new.id;
  return null;
end $$;

-- recálculo feito em 16/11 (474 pallets, granel fora):
-- update producao_pallets set sacos_pallet = pallet_sacos_calc_v2(lancamento_id, numero, produto)
--  where produto not ilike '%granel%' and pallet_sacos_calc_v2(lancamento_id, numero, produto) is distinct from sacos_pallet;
