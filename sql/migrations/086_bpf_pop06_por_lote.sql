-- 086 — BPF POP-06 (aplicado direto no banco em 27/10/2026)
-- REG-POP06-01 passa a ser 1 por LOTE (antes da moagem de cada lote), desde a vigência (05/08/2026), gatilho g_linha.
-- As 6 fichas antigas (1 por OP, ainda em branco) foram removidas para não duplicar.
update bpf_gatilhos set ativo=true, evento='Início da moagem de cada lote (alimentação animal)', obs='POP-06, item 7: antes de cada moagem de lote', filtro='{}' where codigo='g_linha';
