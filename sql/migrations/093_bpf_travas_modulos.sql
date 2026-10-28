-- 093 — BPF: travas dos outros módulos funcionando (aplicado direto no banco em 28/10/2026)
-- A trava de fornecedor não homologado age em Compras e Solicitações (não no almoxarifado).
update bpf_travas set modulo_alvo='compras' where codigo='fornecedor_nao_homologado';
-- Código: bpfTravaGenerica (js/utils.js) usado em carregamento.html (unidade_nao_liberada, veiculo_reprovado),
-- laboratorio.html (cor_delta_e, mp_quimica_vencida, laudo_externo_vencido, lote_nao_liberado) e
-- producao.html (rotulo_sem_rt, peso_fora_tolerancia). Respeita modo (bloquear / só avisar) e liberadores.
