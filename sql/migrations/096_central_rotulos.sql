-- 096 — Central de rótulos (totem)
-- Regra principal: RÓTULO IMPRESSO NÃO É ESTOQUE. O rótulo vive em
-- rotulos_impressos. O pallet (producao_pallets) só nasce quando:
--   • a OP confirma (totem_alocar, na ordem dos turnos do dia 3º→1º→2º), ou
--   • o carregamento lê o QR antes da OP (nasce com a_conferir = true).
-- Assim nenhuma outra tela (estoque, laboratório, dashboard) vê sobra de rótulo.
-- Numeração: por linha + produto + dia; continua quando o produto volta.

create table if not exists public.rotulos_emissoes (
  id uuid primary key default gen_random_uuid(),
  criado_em timestamptz not null default now(),
  dia date not null, linha text not null, produto text not null,
  qtd int not null check (qtd between 1 and 60),
  numero_ini int not null, numero_fim int not null,
  lote text, validade date, turno text, criado_por text
);
create index if not exists rotulos_emissoes_grupo_idx on public.rotulos_emissoes (dia, linha, produto);

create table if not exists public.rotulos_impressos (
  id uuid primary key default gen_random_uuid(),
  criado_em timestamptz not null default now(),
  emissao_id uuid not null references public.rotulos_emissoes(id) on delete cascade,
  dia date not null, linha text not null, produto text not null,
  numero int not null, codigo text not null unique,
  lote text, validade date, vias int not null default 1,
  lido boolean not null default false,   -- lido no carregamento/pátio: o pallet existe de verdade
  pallet_id uuid references public.producao_pallets(id) on delete set null
);
create index if not exists rotulos_impressos_grupo_idx on public.rotulos_impressos (dia, linha, produto, numero);
create index if not exists rotulos_impressos_pallet_idx on public.rotulos_impressos (pallet_id) where pallet_id is not null;

alter table public.rotulos_emissoes  enable row level security;
alter table public.rotulos_impressos enable row level security;
drop policy if exists baseline_authenticated_all on public.rotulos_emissoes;
drop policy if exists baseline_authenticated_all on public.rotulos_impressos;
create policy baseline_authenticated_all on public.rotulos_emissoes  for all to authenticated using (true) with check (true);
create policy baseline_authenticated_all on public.rotulos_impressos for all to authenticated using (true) with check (true);

alter table public.producao_pallets add column if not exists rotulo_id uuid;
alter table public.producao_pallets add column if not exists a_conferir boolean not null default false;
create index if not exists producao_pallets_rotulo_idx on public.producao_pallets (rotulo_id) where rotulo_id is not null;
create index if not exists producao_pallets_conferir_idx on public.producao_pallets (a_conferir) where a_conferir;

-- ── emitir: numera e grava os rótulos (não cria pallet) ──────────────────────
create or replace function public.totem_emitir(
  p_dia date, p_linha text, p_produto text, p_qtd int,
  p_lote text, p_validade date, p_turno text, p_prefixo text, p_criado_por text default null)
returns setof public.rotulos_impressos
language plpgsql security invoker set search_path = public as $$
declare v_id uuid; v_ini int;
begin
  if p_qtd is null or p_qtd < 1 or p_qtd > 60 then raise exception 'Quantidade inválida (1 a 60).'; end if;
  perform pg_advisory_xact_lock(hashtext('rotulo|'||p_dia||'|'||p_linha||'|'||p_produto));
  select coalesce(max(numero_fim),0)+1 into v_ini from rotulos_emissoes where dia=p_dia and linha=p_linha and produto=p_produto;
  insert into rotulos_emissoes (dia,linha,produto,qtd,numero_ini,numero_fim,lote,validade,turno,criado_por)
  values (p_dia,p_linha,p_produto,p_qtd,v_ini,v_ini+p_qtd-1,p_lote,p_validade,p_turno,p_criado_por) returning id into v_id;
  insert into rotulos_impressos (emissao_id,dia,linha,produto,numero,codigo,lote,validade)
  select v_id,p_dia,p_linha,p_produto,v_ini+g, p_prefixo||'P'||lpad((v_ini+g)::text,3,'0'), p_lote,p_validade
    from generate_series(0,p_qtd-1) g;
  return query select * from rotulos_impressos where emissao_id=v_id order by numero;
end $$;

-- ── alocar: a OP confirma os rótulos na ordem dos turnos ──────────────────────
create or replace function public.totem_alocar(p_dia date, p_linha text, p_produto text)
returns void language plpgsql security invoker set search_path = public as $$
declare r record; lab record; v_need int; v_eq text; v_ids uuid[]; v_i int := 1; v_lab uuid; v_pal uuid; v_usados uuid[] := '{}';
begin
  perform pg_advisory_xact_lock(hashtext('rotulo|'||p_dia||'|'||p_linha||'|'||p_produto));
  select array_agg(id order by numero) into v_ids from rotulos_impressos where dia=p_dia and linha=p_linha and produto=p_produto;
  if v_ids is null then return; end if;
  for r in select id, turno, equipe, produtos_op from producao
           where data=p_dia and linha=p_linha
           order by case when turno like '3%' then 0 when turno like '1%' then 1 when turno like '2%' then 2 else 3 end, created_at loop
    select coalesce(sum((pl->>'qtd')::int),0) into v_need
      from jsonb_array_elements(case when jsonb_typeof(r.produtos_op)='array' then r.produtos_op else '[]'::jsonb end) it,
           jsonb_array_elements(case when jsonb_typeof(it->'pallets')='array' then it->'pallets' else '[]'::jsonb end) pl
     where it->>'produto' = p_produto;
    continue when v_need <= 0;
    v_eq := (select string_agg(x, ', ') from jsonb_array_elements_text(case when jsonb_typeof(r.equipe)='array' then r.equipe else '[]'::jsonb end) x);
    while v_need > 0 and v_i <= array_length(v_ids,1) loop
      v_lab := v_ids[v_i];
      select * into lab from rotulos_impressos where id=v_lab;
      if lab.pallet_id is not null then
        update producao_pallets set lancamento_id=r.id, turno=r.turno, equipe=v_eq, a_conferir=false where id=lab.pallet_id;
      else
        insert into producao_pallets (data,linha,turno,produto,numero,status,codigo,lancamento_id,equipe,rotulo_id)
        values (lab.dia,lab.linha,r.turno,lab.produto,lab.numero,'pendente',lab.codigo,r.id,v_eq,lab.id) returning id into v_pal;
        update rotulos_impressos set pallet_id=v_pal where id=lab.id;
      end if;
      v_usados := v_usados || v_lab; v_i := v_i+1; v_need := v_need-1;
    end loop;
  end loop;
  -- rótulo que nenhuma OP cobre: se foi lido (carregamento/pátio) ou carregado, o pallet existe → "a conferir"; senão deixa de existir
  for lab in select * from rotulos_impressos where id = any(v_ids) and not (id = any(v_usados)) and pallet_id is not null loop
    if lab.lido or exists (select 1 from producao_pallets where id=lab.pallet_id and estoque_status in ('carregado','expedido')) then
      update producao_pallets set lancamento_id=null, a_conferir=true where id=lab.pallet_id;
    else
      delete from producao_pallets where id=lab.pallet_id;
    end if;
  end loop;
end $$;

-- ── carregamento leu um rótulo que ainda não virou pallet ────────────────────
create or replace function public.totem_pallet_por_rotulo(p_cod text)
returns setof public.producao_pallets
language plpgsql security invoker set search_path = public as $$
declare lab record; v_pal uuid; v_key text := upper(regexp_replace(coalesce(p_cod,''),'[^A-Za-z0-9]','','g'));
begin
  select * into lab from rotulos_impressos where upper(regexp_replace(codigo,'[^A-Za-z0-9]','','g')) = v_key limit 1;
  if lab.id is null then return; end if;
  perform pg_advisory_xact_lock(hashtext('rotulo|'||lab.dia||'|'||lab.linha||'|'||lab.produto));
  select pallet_id into v_pal from rotulos_impressos where id=lab.id;
  if v_pal is null then
    insert into producao_pallets (data,linha,produto,numero,status,codigo,rotulo_id,a_conferir)
    values (lab.dia,lab.linha,lab.produto,lab.numero,'pendente',lab.codigo,lab.id,true) returning id into v_pal;
  end if;
  update rotulos_impressos set pallet_id=v_pal, lido=true where id=lab.id;
  return query select * from producao_pallets where id=v_pal;
end $$;

-- ── OP salva/editada/excluída → realoca sozinho (qualquer tela) ──────────────
create or replace function public._totem_realocar_op()
returns trigger language plpgsql security invoker set search_path = public as $$
declare g record;
begin
  if tg_op = 'DELETE' then
    for g in select distinct produto from rotulos_impressos where dia=old.data and linha=old.linha loop
      perform totem_alocar(old.data, old.linha, g.produto); end loop;
    return old;
  end if;
  for g in select distinct produto from rotulos_impressos where dia=new.data and linha=new.linha loop
    perform totem_alocar(new.data, new.linha, g.produto); end loop;
  if tg_op = 'UPDATE' and (old.data is distinct from new.data or old.linha is distinct from new.linha) then
    for g in select distinct produto from rotulos_impressos where dia=old.data and linha=old.linha loop
      perform totem_alocar(old.data, old.linha, g.produto); end loop;
  end if;
  return new;
end $$;
-- antes de excluir a OP: solta os pallets do totem para o cascade não apagá-los
create or replace function public._totem_soltar_op()
returns trigger language plpgsql security invoker set search_path = public as $$
begin
  update producao_pallets set lancamento_id=null where lancamento_id=old.id and rotulo_id is not null;
  return old;
end $$;
drop trigger if exists trg_totem_soltar_op on public.producao;
create trigger trg_totem_soltar_op before delete on public.producao for each row execute function public._totem_soltar_op();
drop trigger if exists trg_totem_realocar_op on public.producao;
create trigger trg_totem_realocar_op after insert or delete or update of produtos_op, data, linha, turno, equipe on public.producao
  for each row execute function public._totem_realocar_op();

-- ── rastreio público: rótulo ainda sem pallet também aparece ─────────────────
create or replace function public.rastreio_por_codigo(cod text)
returns jsonb language sql stable security definer set search_path to 'public' as $function$
  select case when public._rastreio_liberado() then coalesce(
    (select to_jsonb(pp) || jsonb_build_object('producao',
       (select to_jsonb(pr) from (select op_numero,produtos_op,encarregado,equipe,turno,data,lote_mp from producao where id = pp.lancamento_id) pr))
       from producao_pallets pp where pp.codigo = cod limit 1),
    (select to_jsonb(pp) || jsonb_build_object('producao',
       (select to_jsonb(pr) from (select op_numero,produtos_op,encarregado,equipe,turno,data,lote_mp from producao where id = pp.lancamento_id) pr))
       from producao_pallets pp where upper(pp.codigo) = upper(cod) limit 1),
    (select jsonb_build_object('codigo',ri.codigo,'numero',ri.numero,'produto',ri.produto,'linha',ri.linha,'data',ri.dia,
            'lote',ri.lote,'validade',ri.validade,'status','pendente','estoque_status','estoque','producao',null)
       from rotulos_impressos ri where upper(ri.codigo) = upper(cod) limit 1)) end;
$function$;

revoke all on function public.totem_emitir(date,text,text,int,text,date,text,text,text) from public, anon;
revoke all on function public.totem_alocar(date,text,text) from public, anon;
revoke all on function public.totem_pallet_por_rotulo(text) from public, anon;
grant execute on function public.totem_emitir(date,text,text,int,text,date,text,text,text) to authenticated;
grant execute on function public.totem_alocar(date,text,text) to authenticated;
grant execute on function public.totem_pallet_por_rotulo(text) to authenticated;

