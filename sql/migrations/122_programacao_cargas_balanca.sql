-- 122 — Programação de Cargas: baixa pelo TICKET DE PESAGEM da balança (Portal de Relatórios)
-- A extensão do Chrome abre o Portal (http://45.184.42.85:8007/relatorio/ticket/consulta#erp), lista os tickets
-- dos últimos dias, lê a impressão de cada ticket NOVO (pedidos, pesagem final, líquido, anotação) e manda para cá.
-- Pedido com pesagem final = CARREGADO, com a data/hora da pesagem final. A balança é a prova:
--   • não carregado (e ninguém mexeu na mão)        → carregado, data = pesagem final, origem 'balanca'
--   • carregado automático (saiu do Salescode)      → corrige a data para a pesagem final, origem 'balanca'
--   • mexido na mão (carregado_manual)              → não muda nada (só guarda o ticket no pedido)

create table if not exists prog_balanca_tickets (
  ticket         text primary key,
  placa          text,
  motorista      text,
  status         text,
  pesagem_final  timestamptz,
  liquido_kg     numeric,
  anotacao       text,
  pedidos        jsonb not null default '[]'::jsonb,   -- [{pedido, cliente, qtd, kg, produto}]
  lido_em        timestamptz not null default now()
);
alter table prog_balanca_tickets enable row level security;
drop policy if exists baseline_authenticated_all on prog_balanca_tickets;
create policy baseline_authenticated_all on prog_balanca_tickets for all to authenticated using (true) with check (true);

alter table programacao_cargas add column if not exists balanca jsonb;   -- [{ticket, em, placa, liq, anot}]

-- quais destes tickets o ERP ainda não tem (a extensão só abre a impressão dos novos)
create or replace function balanca_novos(p_token text, p_tickets text[])
returns text[] language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null and not _prog_token_ok(p_token) then raise exception 'token inválido'; end if;
  return coalesce((select array_agg(t) from unnest(p_tickets) t
                   where not exists (select 1 from prog_balanca_tickets b where b.ticket = t)), '{}');
end $$;

-- p_tickets: [{ticket, placa, motorista, status, fim:"dd/mm/aaaa hh:mi", liq:"40130,00 kg", anot, itens:[{pedido, cliente, qtd, kg, produto}]}]
create or replace function sync_balanca(p_token text, p_tickets jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare x jsonb; it jsonb; fim timestamptz; liq numeric; ped text; n_t int := 0; n_marc int := 0; n_corr int := 0; n_fora int := 0;
  marcados text[] := '{}'; r programacao_cargas;
begin
  if auth.uid() is null and not _prog_token_ok(p_token) then raise exception 'token inválido'; end if;
  for x in select * from jsonb_array_elements(coalesce(p_tickets, '[]'::jsonb)) loop
    -- só ticket com pesagem final e não cancelado
    if coalesce(x->>'fim', '') !~ '^\d{2}/\d{2}/\d{4}' or upper(coalesce(x->>'status', '')) like 'CANCEL%' then continue; end if;
    fim := to_timestamp(substring(x->>'fim' from '^\d{2}/\d{2}/\d{4}(?: \d{2}:\d{2})?'), 'DD/MM/YYYY HH24:MI')::timestamp at time zone 'America/Sao_Paulo';
    liq := nullif(replace(replace(regexp_replace(coalesce(x->>'liq', ''), '[^0-9,\.]', '', 'g'), '.', ''), ',', '.'), '')::numeric;
    insert into prog_balanca_tickets (ticket, placa, motorista, status, pesagem_final, liquido_kg, anotacao, pedidos)
    values (x->>'ticket', x->>'placa', x->>'motorista', x->>'status', fim, liq, x->>'anot', coalesce(x->'itens', '[]'::jsonb))
    on conflict (ticket) do update set placa = excluded.placa, motorista = excluded.motorista, status = excluded.status,
      pesagem_final = excluded.pesagem_final, liquido_kg = excluded.liquido_kg, anotacao = excluded.anotacao,
      pedidos = excluded.pedidos, lido_em = now();
    n_t := n_t + 1;
    for ped in select distinct upper(substring(btrim(i->>'pedido') from '^[A-Za-z0-9]+'))
               from jsonb_array_elements(coalesce(x->'itens', '[]'::jsonb)) i where coalesce(btrim(i->>'pedido'), '') <> '' loop
      select * into r from programacao_cargas where pedido = ped;
      if r.id is null then n_fora := n_fora + 1; continue; end if;
      update programacao_cargas p set
        balanca = (select coalesce(jsonb_agg(e), '[]'::jsonb) from jsonb_array_elements(coalesce(p.balanca, '[]'::jsonb)) e where e->>'ticket' <> x->>'ticket')
                  || jsonb_build_array(jsonb_build_object('ticket', x->>'ticket', 'em', fim, 'placa', x->>'placa', 'liq', liq, 'anot', left(x->>'anot', 300))),
        carregado        = case when p.carregado_manual then p.carregado else true end,
        carregado_em     = case when p.carregado_manual then p.carregado_em
                                when not p.carregado or p.carregado_origem in ('salescode', 'planilha', 'balanca') then fim else p.carregado_em end,
        carregado_origem = case when p.carregado_manual then p.carregado_origem
                                when not p.carregado or p.carregado_origem in ('salescode', 'planilha', 'balanca') then 'balanca' else p.carregado_origem end,
        carregado_por    = case when not p.carregado_manual and not p.carregado then 'Balança · ticket ' || ltrim(x->>'ticket', '0') else p.carregado_por end
      where p.id = r.id;
      if not r.carregado_manual and not r.carregado then n_marc := n_marc + 1; marcados := marcados || ped;
      elsif not r.carregado_manual and r.carregado_origem is distinct from 'balanca' then n_corr := n_corr + 1; end if;
    end loop;
  end loop;
  return jsonb_build_object('ok', true, 'tickets', n_t, 'marcados', n_marc, 'corrigidos', n_corr, 'fora_do_erp', n_fora, 'pedidos', to_jsonb(marcados));
end $$;

revoke all on function balanca_novos(text, text[]) from public;
revoke all on function sync_balanca(text, jsonb) from public;
grant execute on function balanca_novos(text, text[]) to anon, authenticated;
grant execute on function sync_balanca(text, jsonb) to anon, authenticated;
