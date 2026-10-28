-- 089 — BPF POPs 11 a 21 + módulo mais leve (aplicado direto no banco em 28/10/2026) — tudo desde a vigência, em "A preencher"
-- Novos gatilhos: g_mockrecall (11-01 anual) · g_listamestra (12-01 anual) · g_distrib (12-02 por documento vigente)
--   · g_rotulo_rt (15-03 por produto, anual) · g_lab17 (17-01 anual) · g_treinam (20-01) · g_audit (20-03) · g_veiculo_port (21-01 pela Portaria)
-- Religados/ajustados: g_naoconf (16-01 pelos pallets reprovados/bloqueados) · g_laudo (17-02) · g_bigbag (18-02 dias de Big Bag) · g_manifest (19-02)
-- Estendidos até a vigência: g_lote_prod (13) · g_amostra (14) · g_boletim/g_cert (15) · g_ensaque (18) · g_reclama (19) · g_veiculo (21)
-- bpf_vincular_tarefas(): liga tarefa→ficha numa só chamada.
create or replace function public.bpf_vincular_tarefas() returns integer language sql security definer set search_path=public as $$
  with u as (update bpf_tarefas t set registro_id=r.id from bpf_registros r where r.tarefa_id=t.id and t.registro_id is null returning 1)
  select count(*)::int from u;
$$;
grant execute on function public.bpf_vincular_tarefas() to authenticated;
