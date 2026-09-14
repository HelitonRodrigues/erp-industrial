-- 035 — Férias: ocultar funcionário do quadro
--
-- Nem todo mundo cadastrado em `funcionarios` é da fábrica: há logins de
-- sistema e pessoas de fora que nunca entram na escala de férias. Elas saem do
-- quadro, dos KPIs, do calendário, dos conflitos e das impressões — mas NÃO do
-- cadastro: `funcionarios.status` não é tocado, porque essa coluna é lida por
-- escala, EPI e produção. A marca vive só aqui, no módulo de férias.
--
-- Risco: nenhum — uma coluna com default false.

alter table public.rh_ferias_ciclo add column if not exists oculto boolean default false;

comment on column public.rh_ferias_ciclo.oculto is
  'true = fora do controle de férias (usuário de sistema, pessoa de fora da fábrica). Não afeta o cadastro do funcionário.';

-- Ocultar alguém que ainda não tem ciclo cria a linha só com a marca;
-- vencimento nulo continua sendo sugerido pela admissão quando ele reaparecer.
create index if not exists rh_ferias_ciclo_oculto_idx on public.rh_ferias_ciclo (oculto);

-- Para voltar atrás:
-- alter table public.rh_ferias_ciclo drop column if exists oculto;
