-- 114 — Fechamento diário igual ao PDF "FECHAMENTO DIÁRIO DA FÁBRICA" (nov/2026)
-- Só DADOS (nenhuma tabela nova). Pode rodar de novo: apaga e regrava o que é dela.
--
-- pa_ajustes (usada só pelo fechamento.html) passa a guardar, por produto e dia:
--   motivo 'estoque_inicial' → contagem que vale a partir daquele dia (o último ≤ dia manda)
--   motivo 'carregamento'    → sacos/bags/kg carregados no dia
--   motivo 'diferenca'       → diferença de estoque do dia (positivo = faltou)
--   motivo 'contagem'        → número contado à mão (pallet PBR, invertido, aditivo em estoque,
--                               bag de areia, PU40/adesivo vencido). Vale o último ≤ dia.

-- 1) Estoque de outubro + carregamentos e diferenças de 01 a 09/11
delete from pa_ajustes where data between '2026-10-31' and '2026-11-09' and motivo in ('estoque_inicial','carregamento','diferenca','contagem');
insert into pa_ajustes(data,produto,sacos,motivo,responsavel,obs)
select d::date, p, s, m, 'Heliton José de Almeida Rodrigues',
       case when m='estoque_inicial' then 'Estoque de fechamento de outubro/2026' end
from (values
('2026-11-03','Liga Concentrado 10kg',20000,'carregamento'),('2026-11-03','Liga Concentrado 10kg',20,'diferenca'),('2026-11-04','Liga Concentrado 10kg',6840,'carregamento'),('2026-11-05','Liga Concentrado 10kg',7420,'carregamento'),('2026-11-06','Liga Concentrado 10kg',4240,'carregamento'),('2026-11-07','Liga Concentrado 10kg',6400,'carregamento'),('2026-11-09','Liga Concentrado 10kg',5800,'carregamento'),('2026-11-09','Liga Concentrado 10kg',132,'diferenca'),('2026-10-31','Liga Concentrado 10kg',25720,'estoque_inicial'),
('2026-11-03','Sikal Concentrado 10kg',8170,'carregamento'),('2026-11-03','Sikal Concentrado 10kg',2,'diferenca'),('2026-11-06','Sikal Concentrado 10kg',8360,'carregamento'),('2026-11-06','Sikal Concentrado 10kg',50,'diferenca'),('2026-11-07','Sikal Concentrado 10kg',8360,'carregamento'),('2026-11-09','Sikal Concentrado 10kg',29,'diferenca'),('2026-10-31','Sikal Concentrado 10kg',18620,'estoque_inicial'),
('2026-11-05','Geoplus Concentrado 10kg',1080,'carregamento'),('2026-10-31','Geoplus Concentrado 10kg',3420,'estoque_inicial'),
('2026-11-03','LigaPro 10kg',10,'carregamento'),('2026-10-31','LigaPro 10kg',0,'estoque_inicial'),
('2026-11-03','LigaNex 10kg',10,'carregamento'),('2026-10-31','LigaNex 10kg',0,'estoque_inicial'),
('2026-11-04','Liga Concentrado c/ Impermeabilizante 10kg',180,'carregamento'),('2026-11-05','Liga Concentrado c/ Impermeabilizante 10kg',180,'carregamento'),('2026-10-31','Liga Concentrado c/ Impermeabilizante 10kg',1461,'estoque_inicial'),
('2026-11-05','Liga Original c/ Impermeabilizante 50',180,'carregamento'),('2026-11-05','Liga Original c/ Impermeabilizante 50',4,'diferenca'),('2026-10-31','Liga Original c/ Impermeabilizante 50',195,'estoque_inicial'),
('2026-10-31','Sikal Concentrado c/ Impemeabilizante 10kg',2106,'estoque_inicial'),('2026-10-31','LigaPro c/ Impermeabilizante 10kg',0,'estoque_inicial'),('2026-10-31','LigaNex c/ Impermeabilizante 10kg',0,'estoque_inicial'),('2026-10-31','Liga Original 20kg',305,'estoque_inicial'),
('2026-11-05','GeoPlus 20Kg',546,'carregamento'),('2026-11-05','GeoPlus 20Kg',25,'diferenca'),('2026-10-31','GeoPlus 20Kg',4550,'estoque_inicial'),
('2026-11-03','Caulim 25kg - Branco 01',1600,'carregamento'),('2026-11-04','Caulim 25kg - Branco 01',280,'carregamento'),('2026-11-05','Caulim 25kg - Branco 01',804,'carregamento'),('2026-11-05','Caulim 25kg - Branco 01',26,'diferenca'),('2026-11-06','Caulim 25kg - Branco 01',1540,'carregamento'),('2026-11-07','Caulim 25kg - Branco 01',1400,'carregamento'),('2026-11-07','Caulim 25kg - Branco 01',10,'diferenca'),('2026-10-31','Caulim 25kg - Branco 01',3976,'estoque_inicial'),
('2026-11-06','Caulim 25kg - Branco 02',600,'carregamento'),('2026-10-31','Caulim 25kg - Branco 02',633,'estoque_inicial'),('2026-10-31','Caulim 25kg - Creme 02',190,'estoque_inicial'),
('2026-10-31','Caulim 20kg - Creme 02',0,'estoque_inicial'),('2026-10-31','Caulim 20kg - Branco 01',502,'estoque_inicial'),('2026-10-31','Caulim 20kg - Branco 02',0,'estoque_inicial'),('2026-10-31','Caulim 20kg - Cinza',0,'estoque_inicial'),('2026-10-31','Caulim 25kg - Marguerita',430,'estoque_inicial'),
('2026-11-04','Big Bag Caulim Cinza',39,'carregamento'),('2026-10-31','Big Bag Caulim Cinza',3,'estoque_inicial'),('2026-10-31','Big Bag Caulim Cinza c/ Impermeabilizante',0,'estoque_inicial'),
('2026-11-03','Big Bag Caulim Branco 01',80,'carregamento'),('2026-11-04','Big Bag Caulim Branco 01',40,'carregamento'),('2026-11-04','Big Bag Caulim Branco 01',1,'diferenca'),('2026-11-06','Big Bag Caulim Branco 01',40,'carregamento'),('2026-11-09','Big Bag Caulim Branco 01',91,'carregamento'),('2026-10-31','Big Bag Caulim Branco 01',112,'estoque_inicial'),
('2026-11-05','Big Bag Caulim Branco 02',4,'diferenca'),('2026-11-06','Big Bag Caulim Branco 02',130,'carregamento'),('2026-11-07','Big Bag Caulim Branco 02',40,'carregamento'),('2026-10-31','Big Bag Caulim Branco 02',3,'estoque_inicial'),
('2026-10-31','Big Bag Caulim Creme 02',1,'estoque_inicial'),('2026-11-04','Big Bag Caulim Brasil Minas',40,'carregamento'),('2026-10-31','Big Bag Caulim Brasil Minas',43,'estoque_inicial'),
('2026-11-03','Caulim Granel - Cinza',37660,'carregamento'),('2026-11-04','Caulim Granel - Cinza',78450,'carregamento'),('2026-11-06','Caulim Granel - Cinza',76950,'carregamento'),('2026-11-07','Caulim Granel - Cinza',75940,'carregamento'),('2026-11-09','Caulim Granel - Cinza',77840,'carregamento'),('2026-10-31','Caulim Granel - Cinza',117840,'estoque_inicial'),
('2026-10-31','Caulim Granel - Branco 02',0,'estoque_inicial'),('2026-11-03','Topdry',40,'diferenca'),('2026-10-31','Topdry',40,'estoque_inicial'),
-- contagens à mão (valem até a próxima contagem)
('2026-10-31','PALLET PBR',51,'contagem'),('2026-10-31','PALLET INVERTIDO',41,'contagem'),
('2026-10-31','ADITIVO 1 PARDO',230,'contagem'),('2026-10-31','ADITIVO 2 LIGA',0,'contagem'),('2026-10-31','ADITIVO 2 SIKAL',0,'contagem'),
('2026-10-31','BAG AREIA TOPDRY',0,'contagem'),('2026-10-31','BAG AREIA FINA',10,'contagem'),
('2026-10-31','PU40 BRANCO VENCIDO',401,'contagem'),('2026-10-31','ADESIVO 20G VENCIDO',0,'contagem')
) v(d,p,s,m);

-- 2) Peças do moinho no controle de insumos (martelo, gaveta, grelha, eixos)
insert into insumos(codigo,nome,grupo,tipo,unidade_estoque,unidade_consumo,fator_conversao,estoque_minimo,status)
select c,n,'INSUMOS COMPARTILHADOS','MOINHO','pç','pç',1,0,'ativo' from (values
  ('ALM-0481','Martelo'),('ALM-0482','Gaveta'),('ALM-0483','Grelha'),('ALM-0484','Eixos')) v(c,n)
where not exists (select 1 from insumos i where i.codigo=v.c);

delete from insumos_movimentos where insumo_id in (select id from insumos where codigo in ('ALM-0481','ALM-0482','ALM-0483','ALM-0484'))
  and data between '2026-10-31' and '2026-11-09';
insert into insumos_movimentos(insumo_id,data,tipo,quantidade,origem,motivo,obs)
select i.id, v.d::date, v.t, v.q, v.o, v.m, v.obs from (values
  ('ALM-0481','2026-10-31','ajuste',20,'ABERTURA','Saldo de abertura de novembro/2026',null),
  ('ALM-0481','2026-11-03','consumo',6,'MANUAL',null,'Consumo da Longa Vida'),
  ('ALM-0481','2026-11-04','consumo',6,'MANUAL',null,'Consumo da Emitec'),
  ('ALM-0481','2026-11-05','entrada',30,'MANUAL',null,null),
  ('ALM-0481','2026-11-07','consumo',6,'MANUAL',null,'Consumo da Linha 2'),
  ('ALM-0482','2026-10-31','ajuste',1,'ABERTURA','Saldo de abertura de novembro/2026',null),
  ('ALM-0483','2026-10-31','ajuste',23,'ABERTURA','Saldo de abertura de novembro/2026',null),
  ('ALM-0484','2026-10-31','ajuste',44,'ABERTURA','Saldo de abertura de novembro/2026',null),
  ('ALM-0484','2026-11-03','consumo',2,'MANUAL',null,'Consumo da Longa Vida'),
  ('ALM-0484','2026-11-04','consumo',2,'MANUAL',null,'Consumo da Emitec')
) v(c,d,t,q,o,m,obs) join insumos i on i.codigo=v.c;

-- 3) Ajuste de fração de pallet da madrugada de 10/11 pertence à OP da madrugada (entra no fechamento de 09/11)
update insumos_movimentos set origem_id='OP-LIN-20261110-9759'
 where id='264af04f-2d35-414e-bd41-e6ae706b0617' and origem='AJUSTE' and origem_id is null;

-- 4) Estoque mínimo dos insumos da Felisbina (status Comprar = estoque abaixo do mínimo)
update felis_itens f set estoque_minimo=v.m, atualizado_em=now() from (values
  ('EMBALAGEM STAND POUNCH 10 DOSES',5000),('EMBALAGEM LIGA ORIGINAL 50g',10000),('EMBALAGEM KILIGA 50g',5000),('EMBALAGEM SIKALMAX 50g',1000),
  ('EMBALAGEM 1L',2000),('EMBALAGEM 5L',500),('EMBALAGEM LIGA AD 3,6L',500),('EMBALAGEM LIGA AD 18L',500),('EMBALAGEM CHAPISTEC 3,6L',100),('EMBALAGEM CHAPISTEC 18L',100),
  ('LATA IMPER PRO 3,6L',250),('LATA IMPER PRO 18L',250),('LATA BETUMEX 3,6L',500),('LATA BETUMEX 18L',500),
  ('CAIXAS LIGA ORIGINAL 50g',80),('CAIXAS KILIGA 50g',20),('CAIXAS SIKALMAX 50g',150),('CAIXAS PADRÃO SILICATE 001',300),('CAIXAS PADRÃO SILICATE 002',300),
  ('RÓTULO LIGA AD 1L',5000),('RÓTULO SIKAL 1L',1500),('RÓTULO SIKAL 5L',500),
  ('TAMPA LIGA AD 1L',1000),('TAMPA SIKAL 1L',1000),('TAMPA SIKAL 5L',500),('TAMPA BETUMEX 3,6L',500),('TAMPA BETUMEX 18L',500)
) v(n,m) where f.nome=v.n;

-- conferência
select motivo, count(*) linhas, sum(sacos) total from pa_ajustes group by 1 order by 1;
