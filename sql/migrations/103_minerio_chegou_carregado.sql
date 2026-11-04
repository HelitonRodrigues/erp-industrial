-- 103 · Minério (caulim/grafitoso): terceiro que CHEGA CARREGADO (nov/2026)
-- Pesa o bruto na entrada e a tara na saída, já vazio. A viagem fecha na hora.
-- status 'aguardando_bruto' continua = "viagem aberta na balança" (nas duas formas).
-- chegou_carregado=true: bruto_kg/criado_por/entrada_em = entrada carregado;
--                        tara_kg/bruto_por/bruto_em = pesagem final (saída vazio).
alter table minerio_viagens add column if not exists chegou_carregado boolean not null default false;
alter table minerio_viagens alter column tara_kg drop not null;
alter table minerio_viagens add constraint minerio_viagens_pesado_tara_chk check (status <> 'pesado' or tara_kg is not null);
alter table minerio_viagens add constraint minerio_viagens_aberta_chk check (status <> 'aguardando_bruto'
  or (chegou_carregado and bruto_kg is not null) or (not chegou_carregado and tara_kg is not null));
