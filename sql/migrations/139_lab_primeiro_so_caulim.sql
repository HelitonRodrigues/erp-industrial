-- (17/11/2026) a aprovação pelo 1º (modo provisório) vale só para Big Bag, Caulim 25 kg e Caulim Granel
create or replace function public.lab_produto_pelo_primeiro(p text) returns boolean language sql immutable set search_path=public as
$$ select norm_nome(p) like 'bigbag%' or norm_nome(p) like 'caulim25kg%' or norm_nome(p) like 'caulimgranel%' $$;

create or replace function public.tg_lab_aprova_pelo_primeiro() returns trigger language plpgsql set search_path=public as $$
declare ap record;
begin
  if public.lab_regra_completa() then return new; end if;
  if not public.lab_produto_pelo_primeiro(new.produto) then return new; end if;
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
       and status='pendente' and id<>new.id;
  end if;
  return new;
end $$;
