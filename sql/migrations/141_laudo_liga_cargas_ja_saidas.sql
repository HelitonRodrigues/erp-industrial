-- (17/11/2026) laudo finalizado DEPOIS que o caminhão já saiu: liga sozinho o laudo às cargas que levaram aquele lote/produto
create or replace function public.lab_laudo_liga_cargas(p_laudo uuid) returns int language plpgsql security definer set search_path=public as $$
declare l record; n int := 0;
begin
  select * into l from lab_laudos where id=p_laudo;
  if l.id is null or coalesce(l.status,'')<>'finalizado' or coalesce(l.lote,'')='' then return 0; end if;
  insert into lab_laudo_carregamentos (data,placa,origem,cliente,peso_kg,produto,unidade,laudo_id,sugerido,op_numero,quantidade,romaneio_id,ordem_numero,pedido_numero,carregamento_id,criado_por)
  select c.data, c.placa, 'carregamento', max(i->>'cliente'),
         sum(coalesce(nullif(i->>'sacos','')::numeric,0))*coalesce((select peso_unidade_kg from produtos pr where norm_nome(pr.nome)=norm_nome(l.produto) limit 1),0),
         l.produto, case when norm_nome(l.produto) like 'bigbag%' then 'un' else 'sc' end, l.id, false, l.op_numero,
         sum(coalesce(nullif(i->>'sacos','')::numeric,0)), (select id from romaneios r where r.numero=c.ordem_numero limit 1), c.ordem_numero, max(i->>'pedido'), c.id, 'Laudo liberado depois da carga'
    from carregamentos c cross join lateral jsonb_array_elements(c.itens) i
   where i->>'lote'=l.lote and norm_nome(i->>'produto')=norm_nome(l.produto) and not coalesce((i->>'doador')::bool,false)
     and not exists (select 1 from lab_laudo_carregamentos x where x.ordem_numero=c.ordem_numero and x.laudo_id=l.id)
   group by c.id, c.data, c.placa, c.ordem_numero;
  get diagnostics n = row_count;
  return n;
end $$;
create or replace function public.tg_lab_laudo_liga_cargas() returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.status='finalizado' and (tg_op='INSERT' or old.status is distinct from 'finalizado' or old.lote is distinct from new.lote) then
    perform public.lab_laudo_liga_cargas(new.id);
  end if;
  return new;
end $$;
drop trigger if exists tg_lab_laudo_liga_cargas on public.lab_laudos;
create trigger tg_lab_laudo_liga_cargas after insert or update of status, lote on public.lab_laudos for each row execute function public.tg_lab_laudo_liga_cargas();
