-- 115 — Compras enxuto (nov/2026): cotação em mapa, compra direta (⚡), aprovação do gerente no Compras.
-- Fluxo: solicitação aprovada (solicitacoes.html) → Compras cota ou compra direto → GERENTE aprova a compra
--        (aba Aprovação do compras.html) → o próprio banco gera o(s) pedido(s) → almoxarifado recebe.
-- Compra direta com motivo "máquina parada / urgência" e total até o limite (empresa_config) sai liberada na hora
-- e o gerente confirma depois (prazo em horas na mesma configuração).
-- Quem aprova: SADM/ADM ou perfil com compras → aba "aprovacao" → "aprovar" marcado em perfis.html.

-- ── colunas novas ─────────────────────────────────────────────────────────
alter table compras_cotacoes add column if not exists tipo text default 'cotacao';        -- cotacao | direta
alter table compras_cotacoes add column if not exists itens jsonb;                         -- [{k,insumo_id,nome,unidade,qtd}]
alter table compras_cotacoes add column if not exists escolha jsonb;                       -- {modo:'fornecedor'|'item', fornecedor_id, por_item:{k:fornecedor_id}}
alter table compras_cotacoes add column if not exists motivo_direto text;                  -- urgencia | unico | valor_pequeno | contrato
alter table compras_cotacoes add column if not exists total numeric;
alter table compras_cotacoes add column if not exists enviada_em timestamptz;
alter table compras_cotacoes add column if not exists aprovado_por text;
alter table compras_cotacoes add column if not exists aprovado_em timestamptz;
alter table compras_cotacoes add column if not exists decisao_obs text;

alter table compras_pedidos add column if not exists emergencial boolean default false;
alter table compras_pedidos add column if not exists motivo_direto text;
alter table compras_pedidos add column if not exists aprovado_por text;
alter table compras_pedidos add column if not exists aprovado_em timestamptz;
alter table compras_pedidos add column if not exists ratificar_ate timestamptz;
alter table compras_pedidos add column if not exists ratificado_por text;
alter table compras_pedidos add column if not exists ratificado_em timestamptz;
alter table compras_pedidos add column if not exists frete numeric;
alter table compras_pedidos add column if not exists prazo_dias integer;

alter table empresa_config add column if not exists compras_limite_emergencial numeric default 5000;
alter table empresa_config add column if not exists compras_prazo_ratificacao_h integer default 24;
alter table empresa_config add column if not exists compras_meta_emergencial_pct numeric default 30;
alter table empresa_config add column if not exists compras_alerta_preco_pct numeric default 10;

-- apelidos: "no DIAFER, 'PSX58-2' é o parafuso tal" — aprende na conferência da proposta
create table if not exists compras_aliases(
  id uuid primary key default gen_random_uuid(),
  fornecedor_id uuid,
  texto text not null,
  texto_norm text not null,
  insumo_id uuid not null,
  criado_por text,
  criado_em timestamptz default now()
);
alter table compras_aliases drop constraint if exists compras_aliases_uq;
alter table compras_aliases add constraint compras_aliases_uq unique (fornecedor_id, texto_norm);
alter table compras_aliases enable row level security;
drop policy if exists baseline_authenticated_all on compras_aliases;
create policy baseline_authenticated_all on compras_aliases for all to authenticated using (true) with check (true);

-- ── quem pode aprovar ────────────────────────────────────────────────────
create or replace function public.compras_pode_aprovar()
returns boolean language sql stable security definer set search_path to 'public' as $$
  select coalesce(public.auth_perfil(),'') in ('SADM','ADM')
      or coalesce((select (permissoes->'compras'->'abas'->'aprovacao'->>'aprovar')::boolean
                     from perfis where codigo = public.auth_perfil() or id::text = public.auth_perfil() limit 1), false);
$$;
grant execute on function public.compras_pode_aprovar() to authenticated;

create or replace function public._compras_eu() returns text language sql stable security definer set search_path to 'public' as $$
  select coalesce((select nome from usuarios where auth_id = auth.uid() limit 1),'—');
$$;

-- ── trava: cotação só vira aprovada/reprovada pelas funções abaixo ────────
create or replace function public.compras_cot_guard() returns trigger language plpgsql set search_path to 'public' as $$
begin
  if new.status in ('aprovada','aprovada_auto','reprovada')
     and (tg_op='INSERT' or old.status is distinct from new.status)
     and coalesce(current_setting('compras.rpc', true),'') <> '1' then
    raise exception 'A aprovação da compra é feita pelo gerente na aba Aprovação do Compras.';
  end if;
  return new;
end $$;
drop trigger if exists compras_cot_guard on compras_cotacoes;
create trigger compras_cot_guard before insert or update on compras_cotacoes for each row execute function public.compras_cot_guard();

-- ── gera os pedidos da cotação (1 por fornecedor escolhido) ──────────────
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
             'qtd',(it->>'qtd')::numeric,'preco_unit',(v_prop->'precos'->>(it->>'k'))::numeric,'qtd_recebida',0) order by it->>'k'),
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

-- ── gerente decide a cotação ─────────────────────────────────────────────
create or replace function public.compras_decidir_cotacao(p_cot uuid, p_decisao text, p_obs text default null)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare c compras_cotacoes%rowtype; v_eu text := public._compras_eu(); v_ped jsonb := '[]'::jsonb;
begin
  if not public.compras_pode_aprovar() then raise exception 'Sem permissão para aprovar compras.'; end if;
  select * into c from compras_cotacoes where id = p_cot for update;
  if not found then raise exception 'Cotação não encontrada.'; end if;
  if c.status <> 'aguardando_aprovacao' then raise exception 'Esta cotação não está aguardando aprovação.'; end if;
  if lower(coalesce(c.comprador,'')) = lower(v_eu) and coalesce(public.auth_perfil(),'') <> 'SADM' then
    raise exception 'Quem montou a compra não pode aprovar a própria compra.';
  end if;
  if p_decisao in ('devolver','reprovar') and nullif(trim(coalesce(p_obs,'')),'') is null then
    raise exception 'Escreva o motivo.';
  end if;
  perform set_config('compras.rpc','1',true);
  if p_decisao = 'aprovar' then
    update compras_cotacoes set status='aprovada', aprovado_por=v_eu, aprovado_em=now(), decisao_obs=p_obs, atualizado_em=now(),
      historico = coalesce(historico,'[]'::jsonb) || jsonb_build_object('acao','aprovada','por',v_eu,'em',now(),'obs',p_obs) where id=p_cot;
    v_ped := public._compras_gerar_pedidos(p_cot, v_eu, false);
  elsif p_decisao = 'devolver' then
    update compras_cotacoes set status='devolvida', decisao_obs=p_obs, atualizado_em=now(),
      historico = coalesce(historico,'[]'::jsonb) || jsonb_build_object('acao','devolvida','por',v_eu,'em',now(),'obs',p_obs) where id=p_cot;
  elsif p_decisao = 'reprovar' then
    update compras_cotacoes set status='reprovada', aprovado_por=v_eu, aprovado_em=now(), decisao_obs=p_obs, atualizado_em=now(),
      historico = coalesce(historico,'[]'::jsonb) || jsonb_build_object('acao','reprovada','por',v_eu,'em',now(),'obs',p_obs) where id=p_cot;
    update compras_solicitacoes set status='cancelada', cancelado_motivo='Compra reprovada pelo gerente — '||p_obs, cancelado_por=v_eu,
      cancelado_em=now(), atualizado_em=now(),
      historico = coalesce(historico,'[]'::jsonb) || jsonb_build_object('acao','cancelada','por',v_eu,'em',now(),'obs','Compra reprovada: '||p_obs)
     where id = c.solicitacao_id;
  else
    raise exception 'Decisão inválida.';
  end if;
  return jsonb_build_object('ok',true,'pedidos',v_ped);
end $$;
grant execute on function public.compras_decidir_cotacao(uuid,text,text) to authenticated;

-- ── compra emergencial: sai na hora (até o limite), gerente confirma depois ─
create or replace function public.compras_emergencial(p_cot uuid)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare c compras_cotacoes%rowtype; v_lim numeric; v_eu text := public._compras_eu(); v_ped jsonb;
begin
  select coalesce(compras_limite_emergencial,5000) into v_lim from empresa_config limit 1;
  select * into c from compras_cotacoes where id = p_cot for update;
  if not found then raise exception 'Cotação não encontrada.'; end if;
  if c.tipo <> 'direta' or c.motivo_direto <> 'urgencia' then raise exception 'Só compra direta por máquina parada / urgência sai sem aprovação.'; end if;
  if c.status not in ('aberta','devolvida') then raise exception 'Esta compra já foi enviada.'; end if;
  if coalesce(c.total,0) <= 0 then raise exception 'Informe os preços.'; end if;
  if c.total > v_lim then raise exception 'Acima de R$ % a compra espera o gerente aprovar.', v_lim; end if;
  perform set_config('compras.rpc','1',true);
  update compras_cotacoes set status='aprovada_auto', enviada_em=now(), atualizado_em=now(),
    historico = coalesce(historico,'[]'::jsonb) || jsonb_build_object('acao','emergencial','por',v_eu,'em',now(),'obs','Liberada como emergencial (até R$ '||v_lim||')')
   where id=p_cot;
  v_ped := public._compras_gerar_pedidos(p_cot, v_eu, true);
  return jsonb_build_object('ok',true,'pedidos',v_ped);
end $$;
grant execute on function public.compras_emergencial(uuid) to authenticated;

-- ── gerente confirma (ou questiona) a compra emergencial ─────────────────
create or replace function public.compras_ratificar(p_pedido uuid, p_acao text, p_obs text default null)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare v_eu text := public._compras_eu(); p compras_pedidos%rowtype;
begin
  if not public.compras_pode_aprovar() then raise exception 'Sem permissão para aprovar compras.'; end if;
  select * into p from compras_pedidos where id = p_pedido for update;
  if not found or not coalesce(p.emergencial,false) then raise exception 'Pedido emergencial não encontrado.'; end if;
  if p_acao = 'confirmar' then
    update compras_pedidos set ratificado_por=v_eu, ratificado_em=now(), aprovado_por=coalesce(aprovado_por,v_eu), aprovado_em=coalesce(aprovado_em,now()),
      historico = coalesce(historico,'[]'::jsonb) || jsonb_build_object('acao','ratificado','por',v_eu,'em',now(),'obs',p_obs), atualizado_em=now()
     where id=p_pedido;
    perform set_config('compras.rpc','1',true);
    update compras_cotacoes set status='aprovada', aprovado_por=v_eu, aprovado_em=now(), atualizado_em=now() where id=p.cotacao_id and status='aprovada_auto';
  elsif p_acao = 'questionar' then
    if nullif(trim(coalesce(p_obs,'')),'') is null then raise exception 'Escreva a pergunta para o comprador.'; end if;
    update compras_pedidos set historico = coalesce(historico,'[]'::jsonb) || jsonb_build_object('acao','questionado','por',v_eu,'em',now(),'obs',p_obs), atualizado_em=now()
     where id=p_pedido;
  else raise exception 'Ação inválida.'; end if;
  return jsonb_build_object('ok',true);
end $$;
grant execute on function public.compras_ratificar(uuid,text,text) to authenticated;
