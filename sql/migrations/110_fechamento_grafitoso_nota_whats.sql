-- 110 · Fechamento Grafitoso — nota fiscal do motorista + envio pelo WhatsApp (nov/2026)
-- Situação do fechamento: fechado (= AGUARDANDO NOTA) → nota_lancada (usuário digitou a NF) | cancelado.
-- Só cancela quem ainda está aguardando nota (frete_cancelar já filtra status='fechado').

alter table public.frete_fechamentos
  add column if not exists nota_numero text,
  add column if not exists nota_data date,
  add column if not exists nota_valor numeric,
  add column if not exists nota_arquivo_path text,     -- Storage documentos/fretes/notas/...
  add column if not exists nota_obs text,
  add column if not exists nota_lancada_em timestamptz,
  add column if not exists nota_lancada_por text,
  add column if not exists whatsapp text,              -- último número usado para mandar o relatório
  add column if not exists pdf_path text,              -- Storage documentos/fretes/<numero>.pdf
  add column if not exists enviado_em timestamptz,
  add column if not exists enviado_por text;

alter table public.frete_fechamentos drop constraint if exists frete_fechamentos_status_check;
alter table public.frete_fechamentos add constraint frete_fechamentos_status_check
  check (status in ('fechado','nota_lancada','cancelado'));

-- Viagens EM ABERTO (pesadas, de 03/11/2026 em diante, ainda sem fechamento) — lista da aba Novo fechamento.
create or replace view public.frete_viagens_abertas with (security_invoker = on) as
select v.id, v.data, v.ticket, v.ref_planilha, v.placa, v.material, v.frente, v.motorista,
       upper(trim(v.motorista)) as motorista_norm, v.tara_kg, v.bruto_kg, v.liquido_kg, v.entrada_em
  from public.minerio_viagens v
 where v.data >= date '2026-11-03'
   and v.status = 'pesado' and v.liquido_kg is not null
   and not exists (select 1 from public.frete_fechamento_viagens fv where fv.viagem_id = v.id);
grant select on public.frete_viagens_abertas to authenticated;
