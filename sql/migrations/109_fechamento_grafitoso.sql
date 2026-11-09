-- 109 · Fechamento Grafitoso (nov/2026) — FRETE dos caminhões terceiros
-- A portaria registra o MATERIAL (minerio_viagens: Caulim, Grafitoso, Caulim creme 2…).
-- Este módulo (Suprimentos → Fechamento Grafitoso) fecha o FRETE: escolhe o motorista
-- e o período, as viagens pesadas entram, coloca o R$/tonelada de cada material e os
-- abastecimentos (desconto) e gera o relatório para o motorista emitir a nota.
-- NÃO mexe em minerio_viagens: a ligação viagem → fechamento fica numa tabela própria.
-- Uma viagem só entra em UM fechamento ativo (PK em viagem_id). Cancelar solta as viagens.
-- Só viagens de 03/11/2026 em diante (pedido do dono).

create table if not exists public.frete_fechamentos (
  id uuid primary key default gen_random_uuid(),
  numero text unique not null,                       -- FG-2026-0001
  motorista text not null,
  placas text[] not null default '{}',
  periodo_ini date not null,
  periodo_fim date not null,
  precos jsonb not null default '{}',                -- {"GRAFITOSO":12.8,"CAULIM":12.8}
  resumo jsonb not null default '[]',                -- [{material,nome,toneladas,valor_t,total}]
  viagens jsonb not null default '[]',               -- foto das viagens como saíram no relatório
  abastecimentos jsonb not null default '[]',        -- [{periodo,data,carregada,autorizada,abastecida}]
  preco_litro numeric,
  qtd_viagens int not null default 0,
  total_toneladas numeric not null default 0,
  total_frete numeric not null default 0,
  total_abastecimento numeric not null default 0,
  total_nota numeric not null default 0,
  status text not null default 'fechado' check (status in ('fechado','cancelado')),
  obs text,
  criado_por text,
  criado_em timestamptz not null default now(),
  cancelado_em timestamptz,
  cancelado_por text,
  motivo_cancelamento text
);
create index if not exists idx_frete_fech_motorista on public.frete_fechamentos (motorista, periodo_ini);

create table if not exists public.frete_fechamento_viagens (
  viagem_id uuid primary key references public.minerio_viagens(id) on delete cascade,
  fechamento_id uuid not null references public.frete_fechamentos(id) on delete cascade
);
create index if not exists idx_frete_fv_fech on public.frete_fechamento_viagens (fechamento_id);

alter table public.frete_fechamentos enable row level security;
alter table public.frete_fechamento_viagens enable row level security;
drop policy if exists baseline_authenticated_all on public.frete_fechamentos;
create policy baseline_authenticated_all on public.frete_fechamentos for all to authenticated using (true) with check (true);
drop policy if exists baseline_authenticated_all on public.frete_fechamento_viagens;
create policy baseline_authenticated_all on public.frete_fechamento_viagens for all to authenticated using (true) with check (true);

-- Fecha numa transação só: número sequencial + cabeçalho + ligação das viagens.
-- Viagem que já está em outro fechamento → erro claro (não fecha pela metade).
create or replace function public.frete_fechar(p jsonb, p_viagens uuid[]) returns jsonb
language plpgsql set search_path = public as $$
declare v_id uuid; v_num text; v_ano text := to_char(now() at time zone 'America/Sao_Paulo','YYYY'); v_n int; v_dup text;
begin
  if p_viagens is null or array_length(p_viagens,1) is null then raise exception 'Escolha ao menos uma viagem.'; end if;
  -- só entram viagens de 03/11/2026 em diante (antes disso o frete já foi pago fora do ERP)
  if exists (select 1 from minerio_viagens where id = any(p_viagens) and data < date '2026-11-03') then
    raise exception 'Só entram viagens de 03/11/2026 em diante.'; end if;
  if exists (select 1 from minerio_viagens where id = any(p_viagens) and (status <> 'pesado' or liquido_kg is null)) then
    raise exception 'Há viagem sem peso bruto (ainda não pesada na portaria).'; end if;
  select string_agg(coalesce(f.numero,'?')||' ('||to_char(v.data,'DD/MM')||')', ', ') into v_dup
    from frete_fechamento_viagens fv join frete_fechamentos f on f.id=fv.fechamento_id join minerio_viagens v on v.id=fv.viagem_id
   where fv.viagem_id = any(p_viagens);
  if v_dup is not null then raise exception 'Viagem já fechada em: %', v_dup; end if;
  perform pg_advisory_xact_lock(hashtext('frete_fechamentos_numero'));
  select coalesce(max((regexp_match(numero,'(\d+)$'))[1]::int),0)+1 into v_n from frete_fechamentos where numero like 'FG-'||v_ano||'-%';
  v_num := 'FG-'||v_ano||'-'||lpad(v_n::text,4,'0');
  insert into frete_fechamentos (numero,motorista,placas,periodo_ini,periodo_fim,precos,resumo,viagens,abastecimentos,preco_litro,
      qtd_viagens,total_toneladas,total_frete,total_abastecimento,total_nota,obs,criado_por)
  values (v_num, p->>'motorista', coalesce(array(select jsonb_array_elements_text(p->'placas')),'{}'),
      (p->>'periodo_ini')::date, (p->>'periodo_fim')::date, coalesce(p->'precos','{}'), coalesce(p->'resumo','[]'),
      coalesce(p->'viagens','[]'), coalesce(p->'abastecimentos','[]'), nullif(p->>'preco_litro','')::numeric,
      coalesce((p->>'qtd_viagens')::int,0), coalesce((p->>'total_toneladas')::numeric,0), coalesce((p->>'total_frete')::numeric,0),
      coalesce((p->>'total_abastecimento')::numeric,0), coalesce((p->>'total_nota')::numeric,0), nullif(p->>'obs',''), p->>'criado_por')
  returning id into v_id;
  insert into frete_fechamento_viagens (viagem_id, fechamento_id) select unnest(p_viagens), v_id;
  return jsonb_build_object('id',v_id,'numero',v_num);
end $$;

-- Cancelar: o documento fica (com o motivo) e as viagens voltam a ficar em aberto.
create or replace function public.frete_cancelar(p_id uuid, p_motivo text, p_usuario text) returns void
language plpgsql set search_path = public as $$
begin
  if coalesce(trim(p_motivo),'')='' then raise exception 'Informe o motivo do cancelamento.'; end if;
  update frete_fechamentos set status='cancelado', cancelado_em=now(), cancelado_por=p_usuario, motivo_cancelamento=p_motivo
   where id=p_id and status='fechado';
  if not found then raise exception 'Fechamento não encontrado ou já cancelado.'; end if;
  delete from frete_fechamento_viagens where fechamento_id=p_id;
end $$;

revoke all on function public.frete_fechar(jsonb,uuid[]), public.frete_cancelar(uuid,text,text) from public, anon;
grant execute on function public.frete_fechar(jsonb,uuid[]), public.frete_cancelar(uuid,text,text) to authenticated;
