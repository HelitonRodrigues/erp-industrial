-- 190 (23/11/2026) — BPF conforme item 7/12 de cada POP (aplicado direto no Supabase)
-- POP-10/15: registros eletrônicos (SGQ/sistema) → sem ficha de papel
update bpf_formularios set sem_papel=true where codigo in ('REG-POP10-01','REG-POP15-01','REG-POP15-02');
-- periodicidade igual ao POP
update bpf_formularios set periodicidade='por_lote' where codigo in ('REG-POP06-01','REG-POP13-01','REG-POP18-01');

-- Duplicadas canceladas (nunca juntadas), com motivo — tarefa e ficha
with c(ref,motivo) as (values
('LOTE06/4263ec74-3497-4572-9f5f-eeccbdc132e7/20261119B02','POP-06 item 7/12: uma inspeção por moagem de LOTE — lote 20261119B02 já tem a ficha da 1ª OP (OP-LIN-20261119-5759)'),
('LOTE06/74c15add-b6b7-493a-88bd-f4ff41395f68/20261119B02','POP-06 item 7/12: uma inspeção por moagem de LOTE — lote 20261119B02 já tem a ficha da 1ª OP (OP-LIN-20261119-5759)'),
('RASTRO/4263ec74-3497-4572-9f5f-eeccbdc132e7/20261119B02','POP-10 item 7/12: um registro por LOTE — lote 20261119B02 já tem o registro da 1ª OP'),
('RASTRO/74c15add-b6b7-493a-88bd-f4ff41395f68/20261119B02','POP-10 item 7/12: um registro por LOTE — lote 20261119B02 já tem o registro da 1ª OP'),
('OP14/4263ec74-3497-4572-9f5f-eeccbdc132e7/20261119B02','POP-14 item 7/12: uma amostragem por LOTE — lote 20261119B02 já tem a ficha da 1ª OP'),
('OP14/74c15add-b6b7-493a-88bd-f4ff41395f68/20261119B02','POP-14 item 7/12: uma amostragem por LOTE — lote 20261119B02 já tem a ficha da 1ª OP'),
('OP18/4263ec74-3497-4572-9f5f-eeccbdc132e7/20261119B02','POP-18 item 12: aferição por LOTE — lote 20261119B02 já tem a ficha da 1ª OP'),
('OP18/74c15add-b6b7-493a-88bd-f4ff41395f68/20261119B02','POP-18 item 12: aferição por LOTE — lote 20261119B02 já tem a ficha da 1ª OP'),
('OP13/ac922efb-a82a-4644-87cf-16239abbee59','POP-13 item 12 (por lote/turno): lote 20261120B01 no 1º turno já tem a ficha da OP-LIN-20261120-1962'),
('OP13/285a3db1-f272-406a-abf8-6835c72545b6','POP-13 item 12 (por lote/turno): lote 20261121B01 no 1º turno já tem a ficha da OP-LIN-20261121-8081'),
('OP13/df7b8925-89ce-4cf2-931a-21f09502f45d','POP-13 item 12 (por lote/turno): lote 20261121B01 no 2º turno já tem a ficha da OP-LIN-20261121-6196'),
('CARR/73c74c19-2968-40dd-ba3f-9986cb32ce3c','POP-21 item 7: uma inspeção por carregamento — ordem 028548 já tem a ficha da Portaria (mesmo caminhão)'),
('CARR/811389bc-9a6d-476f-ac80-1ea51051f5ab','POP-21 item 7: uma inspeção por carregamento — ordem 028555 já tem a ficha da Portaria (mesmo caminhão)'),
('CARR/5e6884b5-7209-4b32-bbf8-4f5903e2b993','POP-21 item 7: uma inspeção por carregamento — ordem 028563 já tem a ficha da Portaria (mesmo caminhão)'),
('CARR/62e59831-3dc5-43b2-945d-9d32be46524a','POP-21 item 7: uma inspeção por carregamento — ordem 028554 já tem a ficha da Portaria (mesmo caminhão)'),
('PORT21/f1e479bb-b53e-4b3d-bed3-e1b43666d9ec','POP-21 item 2: fora do escopo — ordem 028534 só Sikal/Felisbina (sem caulim 25 kg/Big Bag/granel)'),
('PORT21/3a46ceef-45eb-46a5-bb4c-f791ac425a72','POP-21 item 2: fora do escopo — ordem 028551 só Liga/Felisbina'),
('PORT21/eeeca0dd-852b-46e0-8a8c-268c48042bb2','POP-21 item 2: fora do escopo — ordem 028553 só Liga/Felisbina'),
('PORT21/f7d1cdbe-555c-4107-990d-d63ea4b5014d','POP-21 item 2: fora do escopo — ordem 028562 só Liga'),
('PORT21/5b8e54c3-957f-49bb-9452-eae1974d9120','POP-21 item 2: fora do escopo — ordem 028561 só Sikal'),
('PORT21/b802ad9b-3423-4df5-90fd-ee1e5a04742b','POP-21 item 2: fora do escopo — ordem 028560 só Sikal'),
('PORT21/7febe807-7482-4ee6-85f6-63c111ca018c','POP-21 item 2: fora do escopo — ordem 028564 só Liga'),
('PORT21/41216033-5e0a-4921-ab2c-2a33aa946d32','POP-21 item 7: sem ordem de carregamento na Portaria — se receber ordem com caulim, nasce ficha nova'),
('PORT21/6df2dd25-043e-443c-9036-8674968afab1','POP-21 item 7: sem ordem de carregamento na Portaria — se receber ordem com caulim, nasce ficha nova'),
('PORT21/2ccd35a6-6d10-4df7-a0b2-c9b48f55272c','POP-21 item 7: sem ordem de carregamento na Portaria — se receber ordem com caulim, nasce ficha nova')),
t as (update bpf_tarefas x set status='cancelada', cancelada_por='Heliton José de Almeida Rodrigues', cancelada_motivo=c.motivo, concluida_em=now()
      from c where x.origem_ref=c.ref and x.status<>'cancelada' returning x.registro_id, c.motivo)
update bpf_registros r set cancelado_em=now(), cancelado_por='Heliton José de Almeida Rodrigues', cancelado_motivo=t.motivo
from t where r.id=t.registro_id and r.cancelado_em is null and r.lancado_em is null;

-- 2ª parte (23/11): Dossiê do lote (dos_lote) — aplicado via replace no corpo da função:
--   dias do lote passam a incluir REG-POP07-02 (peso-padrão por turno) e REG-POP18-02 (Big Bags do dia);
--   REG-POP21-01 entra pela ORDEM de cada carga que levou o lote: (r.formulario_cod='REG-POP21-01' and r.campos->>'ordem' in (select ordem_numero from car))
-- Fichas POP-21 da Portaria estavam sem a ordem (lia portaria.ordem_numero; o campo é numero_ordem) → preenchido:
update bpf_registros r set campos = r.campos || jsonb_build_object('ordem', p.numero_ordem,'placa', concat_ws(' / ', p.placa, nullif(nullif(p.placa2,''),p.placa)))
 from bpf_tarefas t, portaria p
 where t.id=r.tarefa_id and r.formulario_cod='REG-POP21-01' and r.cancelado_em is null and r.lancado_em is null
   and t.origem_ref like 'PORT21/%' and p.id::text=split_part(t.origem_ref,'/',2) and p.numero_ordem is not null and coalesce(r.campos->>'ordem','')='';
