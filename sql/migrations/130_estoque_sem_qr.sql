-- 130 — Estoque acabado SEM QR (implantação 14/11/2026).
-- estoque do produto = pallets com QR em estoque + estoque_sem_qr_saldo.saldo
-- saldo = Σ estoque_sem_qr.sacos (saldo inicial/acertos) − Σ itens 'rotulo_antigo' das cargas.
-- Granel: o saldo (em kg) entra como "acerto" no saldo de granel (produzido − carregado + acerto).
create table if not exists estoque_sem_qr (
  id uuid primary key default gen_random_uuid(),
  produto text not null, data date not null default current_date,
  sacos numeric not null, tipo text not null default 'ajuste', obs text,
  criado_por text, criado_em timestamptz not null default now());
alter table estoque_sem_qr enable row level security;
do $$ begin
  if not exists (select 1 from pg_policies where tablename='estoque_sem_qr' and policyname='baseline_authenticated_all') then
    create policy baseline_authenticated_all on estoque_sem_qr for all to authenticated using (true) with check (true);
  end if; end $$;
create or replace view estoque_sem_qr_saldo with (security_invoker=true) as
  select produto, sum(sacos) saldo, sum(entrou) entrou, sum(saiu) saiu from (
    select produto, sacos, sacos entrou, 0::numeric saiu from estoque_sem_qr
    union all
    select i->>'produto', -coalesce(nullif(i->>'sacos','')::numeric,0), 0, coalesce(nullif(i->>'sacos','')::numeric,0)
      from carregamentos c, jsonb_array_elements(c.itens) i where i->>'motivo_avulso'='rotulo_antigo'
  ) x group by produto;
grant select on estoque_sem_qr_saldo to authenticated;

-- Dados aplicados em 14/11/2026 (registro):
--  * 8.289 pallets produzidos antes de 03/11 (não granel) → estoque_status 'expedido', ordem_numero 'IMPLANTACAO-20261114',
--    fora_estoque_motivo 'Implantação 14/11/2026: produzido antes de 03/11, saiu sem QR (estoque igualado à planilha)'.
--  * Cargas PLANILHA-20261103..20261113 (planilha CARREGAMENTO DIÁRIO, itens sem QR / granel em t).
--  * estoque_sem_qr tipo 'inicial' (14/11) = alvo − QR(≥03/11) + saídas sem QR, alvo = EM ESTOQUE 14/11 + em análise 13 e 14.

-- Granel que sai pela Portaria DSM baixa o saldo de granel sozinho (dia = início/recepção, igual à planilha).
create or replace view granel_saidas_dsm with (security_invoker=true) as
  select case when coalesce(nf_produto,'') ilike '%granel%branco%02%' then 'Caulim Granel - Branco 02' else 'Caulim Granel - Cinza' end produto,
         (coalesce(inicio_em,recepcao_em) at time zone 'America/Sao_Paulo')::date data,
         (peso_saida-peso_entrada) kg, placa, nf_numero, id
    from dsm_caminhoes
   where status='saiu' and cancelado_em is null and peso_saida is not null and peso_entrada is not null;
grant select on granel_saidas_dsm to authenticated;
-- As cargas PLANILHA-* ficaram sem os itens de granel (a DSM já registra: 739.380 kg de 03 a 13/11, igual à planilha dia a dia).
