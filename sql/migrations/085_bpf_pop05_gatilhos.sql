-- 085 — BPF POP-05 (aplicado direto no banco em 27/10/2026) — desde a vigência (05/08/2026)
-- REG-POP05-02: laudo mensal da SABESP (g_agua) · análise interna anual (g_agua_int) ·
--   nova análise após intervenção na rede/reservatório, pela OS da Manutenção (g_agua_extra)
-- REG-POP05-01: higienização anual do reservatório (g_reserv)
update bpf_gatilhos set ativo=true, evento='Laudo mensal da SABESP', obs='POP-05, item 7: mensal' where codigo='g_agua';
update bpf_gatilhos set ativo=true, evento='Higienização anual do reservatório / caixa d''água', obs='POP-05, item 7: anual' where codigo='g_reserv';
insert into bpf_gatilhos (codigo,pop_cod,formulario_cod,evento,fonte_tipo,fonte_tabela,periodicidade,prazo_horas,ativo,filtro,obs) values
 ('g_agua_int','POP-05','REG-POP05-02','Análise interna anual de potabilidade no ponto de uso','calendario','calendario','anual',720,true,'{}','POP-05, item 7: anual'),
 ('g_agua_extra','POP-05','REG-POP05-02','Intervenção na rede/reservatório (OS da Manutenção)','erp','manutencao','evento',24,true,'{}','POP-05, item 7: nova análise antes de liberar o consumo')
on conflict (codigo) do update set ativo=true, evento=excluded.evento, obs=excluded.obs;
