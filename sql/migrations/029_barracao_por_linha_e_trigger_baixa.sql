-- 029 — De qual barracão cada linha puxa matéria-prima.
--
-- O barracão é propriedade da LINHA, não do movimento: a Linha 2 e a Linha 3
-- comem da pilha do barracão antigo, a Emitec do barracão dela, a Longa Vida
-- da dela. Gravar isso no cadastro da linha (e não numa regra escondida no
-- código) deixa o dia em que a fábrica mudar o arranjo ser um UPDATE.
alter table linhas_producao add column if not exists barracao text;

update linhas_producao set barracao = 'Barracão Antigo'     where nome in ('Linha 2','Linha 3') and barracao is null;
update linhas_producao set barracao = 'Barracão Imetec'     where nome = 'Emitec'     and barracao is null;
update linhas_producao set barracao = 'Barracão Longa Vida' where nome = 'Longa Vida' and barracao is null;

-- A baixa automática (rpc_baixa_insumos_op) não conhece barracão. Em vez de
-- reescrever a função inteira, um gatilho carimba o barracão nos movimentos de
-- MATÉRIA-PRIMA vindos de OP — assim o estoque de MP fica separado por pilha,
-- que é como a planilha e o encarregado enxergam.
create or replace function public.fn_mov_barracao_da_op()
returns trigger
language plpgsql
set search_path = public
as $$
declare v_barr text;
begin
  if new.barracao is not null or new.origem <> 'OP' or new.origem_id is null then
    return new;
  end if;
  if not exists (select 1 from insumos i where i.id = new.insumo_id and i.tipo = 'MP_MINERAL') then
    return new;
  end if;
  select l.barracao into v_barr
    from producao p join linhas_producao l on l.nome = p.linha
   where coalesce(nullif(p.op_numero,''), p.id::text) = new.origem_id
   limit 1;
  new.barracao := v_barr;
  return new;
end $$;

drop trigger if exists tg_mov_barracao_da_op on insumos_movimentos;
create trigger tg_mov_barracao_da_op
  before insert on insumos_movimentos
  for each row execute function public.fn_mov_barracao_da_op();
