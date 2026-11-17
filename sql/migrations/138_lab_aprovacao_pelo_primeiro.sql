-- (17/11/2026) Laboratório — modo provisório: com a "regra completa" DESLIGADA, a 1ª aprovação de um produto no dia/linha vale para todos
-- os pallets/bags dele (os que já existem e os que forem bipados depois). LIGADA = como sempre foi (cada pallet).
alter table public.empresa_config add column if not exists lab_regra_completa boolean not null default true;

create or replace function public.lab_regra_completa() returns boolean language sql stable set search_path=public as
$$ select coalesce((select lab_regra_completa from empresa_config limit 1), true) $$;

create or replace function public.tg_lab_aprova_pelo_primeiro() returns trigger language plpgsql set search_path=public as $$
declare ap record;
begin
  if public.lab_regra_completa() then return new; end if;
  if coalesce(new.embalagem_tipo,'')='granel' then return new; end if;
  if tg_op='INSERT' then
    if coalesce(new.status,'pendente')='pendente' then
      select status, responsavel_lab, hora_lab, numero into ap from producao_pallets
       where data=new.data and linha=new.linha and norm_nome(produto)=norm_nome(new.produto) and status='aprovado'
       order by numero limit 1;
      if found then
        new.status:='aprovado';
        new.responsavel_lab:=coalesce(ap.responsavel_lab,'Laboratório')||' (1º aprovado #'||coalesce(ap.numero::text,'?')||')';
        new.hora_lab:=ap.hora_lab;
      end if;
    end if;
    return new;
  end if;
  if pg_trigger_depth()=1 and new.status='aprovado' and old.status is distinct from 'aprovado' then
    update producao_pallets set status='aprovado',
           responsavel_lab=coalesce(new.responsavel_lab,'Laboratório')||' (1º aprovado #'||coalesce(new.numero::text,'?')||')',
           hora_lab=new.hora_lab
     where data=new.data and linha=new.linha and norm_nome(produto)=norm_nome(new.produto)
       and status='pendente' and id<>new.id and coalesce(embalagem_tipo,'')<>'granel';
  end if;
  return new;
end $$;

drop trigger if exists tg_lab_aprova_pelo_primeiro_ins on public.producao_pallets;
create trigger tg_lab_aprova_pelo_primeiro_ins before insert on public.producao_pallets for each row execute function public.tg_lab_aprova_pelo_primeiro();
drop trigger if exists tg_lab_aprova_pelo_primeiro_upd on public.producao_pallets;
create trigger tg_lab_aprova_pelo_primeiro_upd after update of status on public.producao_pallets for each row execute function public.tg_lab_aprova_pelo_primeiro();

create or replace function public.lab_rotulo_pallet(p_rotulo uuid) returns setof producao_pallets language plpgsql set search_path=public as $$
declare lab record; v_pal uuid;
begin
  select * into lab from rotulos_impressos where id=p_rotulo;
  if lab.id is null then return; end if;
  perform pg_advisory_xact_lock(hashtext('rotulo|'||lab.dia||'|'||lab.linha||'|'||lab.produto));
  select pallet_id into v_pal from rotulos_impressos where id=lab.id;
  if v_pal is null then
    insert into producao_pallets (data,linha,produto,numero,status,codigo,rotulo_id,a_conferir)
    values (lab.dia,lab.linha,lab.produto,lab.numero,'pendente',lab.codigo,lab.id,true) returning id into v_pal;
    update rotulos_impressos set pallet_id=v_pal where id=lab.id;
  end if;
  return query select * from producao_pallets where id=v_pal;
end $$;
grant execute on function public.lab_rotulo_pallet(uuid) to authenticated;
