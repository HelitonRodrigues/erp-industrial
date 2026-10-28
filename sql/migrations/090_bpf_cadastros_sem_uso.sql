-- 090 — BPF: saem os cadastros que viraram registro ou outro módulo (aplicado direto no banco em 28/10/2026; todos vazios)
-- visitantes → Portaria › Visitantes (REG-POP04-02) · inspeção de veículo → REG-POP21-01 · reprocessamento → REG-POP16-01
-- rótulos → REG-POP15-03 · transição de cor → REG-POP06-01 · cronograma → REG-POP20-02 · saída de equipamento → REG-POP07-01/02
delete from bpf_travas where codigo='equip_sem_certificado';
drop table if exists public.bpf_visitantes cascade;
drop table if exists public.bpf_inspecao_veiculo cascade;
drop table if exists public.bpf_reprocessos cascade;
drop table if exists public.bpf_rotulos cascade;
drop table if exists public.bpf_transicoes_cor cascade;
drop table if exists public.bpf_cronograma cascade;
drop table if exists public.bpf_equip_saidas cascade;
