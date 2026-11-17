-- (17/11/2026) pallet do totem analisado ANTES da produção ser lançada: quando o pallet ganha OP, a análise ganha a mesma OP (o laudo procura por OP)
create or replace function public.tg_analise_segue_op() returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.lancamento_id is not null and new.lancamento_id is distinct from old.lancamento_id then
    update lab_pallet_analises set lancamento_id=new.lancamento_id
     where lancamento_id is null and (pallet_id=new.id or (pallets_ids is not null and to_jsonb(pallets_ids) ? new.id::text));
  end if;
  return new;
end $$;
drop trigger if exists tg_analise_segue_op on public.producao_pallets;
create trigger tg_analise_segue_op after update of lancamento_id on public.producao_pallets for each row execute function public.tg_analise_segue_op();
