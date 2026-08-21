-- ============================================================================
-- 025 — CUSTO GERAL DO SISTEMA: view v_custos_consolidado
--
-- O módulo de Custos só conhecia o que era digitado nele (mais as OS de
-- manutenção). Na prática: 21 lançamentos, R$ 5.361 — enquanto o sistema já
-- registrava ~R$ 449 mil de gasto espalhado em folha, insumos consumidos,
-- diesel, almoxarifado, terceiros e manutenção. O DRE mostrava a fábrica
-- gastando cinco mil reais.
--
-- Esta view é a fonte única do REALIZADO: junta todas as fontes já existentes,
-- normaliza (data, valor, descrição) e resolve o GRUPO do DRE de cada linha.
-- Não duplica dado nem exige que cada módulo aprenda a lançar custo: o custo
-- continua morando onde nasce, e aqui é lido.
--
-- Regras de NÃO CONTAR EM DOBRO:
--   • o que já virou lançamento (lancamentos_custo.referencia_id) sai da fonte;
--   • saída de almoxarifado marcada com [MANUT|…] já está dentro do custo da OS
--     (recalcCustoOS soma as peças), então não entra de novo;
--   • insumo com custo unitário zerado não entra (valor desconhecido não é R$ 0).
--
-- security_invoker: a view respeita as policies de quem consulta.
-- ============================================================================

create or replace view public.v_custos_consolidado
with (security_invoker = true) as

-- 1. LANÇAMENTOS do próprio módulo (manuais + os que os módulos postam)
select 'lancamento'::text            as fonte,
       l.id                          as origem_id,
       l.data,
       l.descricao,
       l.valor,
       coalesce(n.grupo,'classificar')::text as grupo,
       l.linha,
       l.produto,
       coalesce(l.natureza_nome, n.nome)     as natureza_nome,
       l.centro_custo_nome,
       coalesce(l.referencia_numero, l.numero_nf) as referencia,
       true                          as editavel
  from public.lancamentos_custo l
  left join public.naturezas_custo n on n.id = l.natureza_id
 where coalesce(l.valor,0) <> 0

union all

-- 2. INSUMOS consumidos (ledger valorizado) — embalagem/pallet/plástico vão para
--    embalagem; matéria-prima e lenha para produção (CMV).
select 'insumos',
       m.id,
       m.data,
       'Consumo de '||coalesce(i.nome,'insumo')||coalesce(' — '||m.produto,'')||
         case when m.tipo='perda' then ' (perda)' else '' end,
       round(m.quantidade * m.custo_unitario, 2),
       case upper(coalesce(i.tipo,''))
         when 'EMBALAGEM' then 'embalagem'
         when 'PLASTICO'  then 'embalagem'
         when 'PALLET'    then 'embalagem'
         else 'producao'
       end,
       null, m.produto,
       'Insumo · '||coalesce(i.tipo,'—'),
       null,
       coalesce(m.origem||' '||coalesce(m.origem_id,''), m.origem),
       false
  from public.insumos_movimentos m
  join public.insumos i on i.id = m.insumo_id
 where m.tipo in ('consumo','perda')
   and coalesce(m.custo_unitario,0) > 0
   and coalesce(m.quantidade,0) > 0
   and not exists (select 1 from public.lancamentos_custo l where l.referencia_id = m.id)

union all

-- 3. DIESEL comprado (nota de abastecimento)
select 'abastecimento',
       e.id,
       e.data,
       'Diesel — NF '||coalesce(e.nf,'s/nº')||coalesce(' · '||e.fornecedor,''),
       round(coalesce(e.valor_danfe, e.litros * coalesce(e.valor_litro,0)), 2),
       'logistica',
       null, null,
       'Combustível',
       null,
       e.nf,
       false
  from public.abastecimento_entradas e
 where coalesce(e.valor_danfe, e.litros * coalesce(e.valor_litro,0)) > 0
   and not exists (select 1 from public.lancamentos_custo l where l.referencia_id = e.id)

union all

-- 4. SERVIÇOS DE TERCEIROS (tornearia, rebobinamento, fabricação)
select 'terceiros',
       s.id,
       s.data,
       'Serviço de terceiro'||coalesce(' — '||p.nome,'')||coalesce(' · NF '||s.nota_fiscal,''),
       s.valor_total,
       'manutencao',
       null, null,
       'Serviço de terceiros',
       null,
       coalesce(s.nota_fiscal, s.requisicao),
       false
  from public.terceiros_servicos s
  left join public.terceiros_prestadores p on p.id = s.prestador_id
 where coalesce(s.valor_total,0) > 0
   and not exists (select 1 from public.lancamentos_custo l where l.referencia_id = s.id)

union all

-- 5. ORDENS DE SERVIÇO de manutenção que ainda não viraram lançamento
select 'manutencao',
       o.id,
       coalesce(o.data_conclusao, o.data_abertura),
       'OS '||coalesce(o.numero::text,'')||' — '||coalesce(o.equipamento,'equipamento')||
         coalesce(' ('||o.tipo||')',''),
       o.custo_manutencao,
       'manutencao',
       nullif(o.linha,'Frota'), null,
       'Manutenção · '||coalesce(o.tipo,'—'),
       null,
       o.numero::text,
       false
  from public.manutencao o
 where coalesce(o.custo_manutencao,0) > 0
   and not exists (select 1 from public.lancamentos_custo l where l.referencia_id = o.id)

union all

-- 6. SAÍDAS DE ALMOXARIFADO que não são peça de OS (essas já estão na OS)
select 'almoxarifado',
       a.id,
       a.data,
       'Saída de almoxarifado — '||coalesce(x.nome,'item')||coalesce(' · '||a.numero_doc,''),
       round(a.quantidade * a.valor_unitario, 2),
       case coalesce(x.categoria,'')
         when 'Embalagem'     then 'embalagem'
         when 'Pallets'       then 'embalagem'
         when 'Matéria-Prima' then 'producao'
         when 'Combustível'   then 'logistica'
         else 'manutencao'
       end,
       a.linha, null,
       'Almoxarifado · '||coalesce(x.categoria,'—'),
       null,
       a.numero_doc,
       false
  from public.almoxarifado_movimentos a
  left join public.almoxarifado x on x.id = a.insumo_id
 where a.tipo = 'saida'
   and coalesce(a.quantidade,0) > 0
   and coalesce(a.valor_unitario,0) > 0
   and coalesce(a.obs,'') not like '%[MANUT%'
   and not exists (select 1 from public.lancamentos_custo l where l.referencia_id = a.id)

union all

-- 7. FOLHA DE PAGAMENTO (total bruto da competência, no último dia do mês)
select 'folha',
       f.id,
       (make_date(f.ano, f.mes, 1) + interval '1 month - 1 day')::date,
       'Folha de pagamento '||lpad(f.mes::text,2,'0')||'/'||f.ano||
         coalesce(' — '||(f.totais->>'funcionarios')||' funcionário(s)',''),
       (f.totais->>'totalBruto')::numeric,
       'rh',
       null, null,
       'Folha de pagamento',
       null,
       f.codigo,
       false
  from public.folhas_pagamento f
 where f.status <> 'excluido'
   and coalesce((f.totais->>'totalBruto')::numeric,0) > 0
   and f.mes is not null and f.ano is not null

union all

-- 8. LENHA fechada (combustível de processo → CMV)
select 'lenha',
       fe.id,
       fe.periodo_fim,
       'Lenha — '||coalesce(fe.numero,'')||coalesce(' · '||fe.fornecedor_nome,'')||
         ' ('||round(coalesce(fe.total_m3,0),2)||' m³)',
       fe.valor_total,
       'producao',
       null, null,
       'Lenha',
       null,
       fe.numero,
       false
  from public.lenha_fechamentos fe
 where fe.status = 'fechado'
   and coalesce(fe.valor_total,0) > 0;

-- ── Atalho por mês e grupo (é o que o DRE consome) ──────────────────────────
create or replace view public.v_custos_por_grupo
with (security_invoker = true) as
select to_char(data,'YYYY-MM') as mes,
       grupo,
       sum(valor)  as valor,
       count(*)    as lancamentos
  from public.v_custos_consolidado
 group by 1,2;
