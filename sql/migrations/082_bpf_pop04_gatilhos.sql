-- 082 — BPF POP-04 (aplicado direto no banco em 27/10/2026)
-- REG-POP04-01: um por dia de produção de alimentação animal (escopo), desde a vigência (08/09/2026) — gatilho g_uniforme.
-- REG-POP04-02: um por acesso registrado na Portaria (motoristas), desde a vigência — gatilho g_visita (religado);
--   traz nome, CPF, transportadora, placa, horários e se o vídeo de integração foi visto (confirmação no celular).
update bpf_gatilhos set ativo=true, evento='Acesso de motorista/visitante registrado na Portaria', obs='POP-04, item 7: a cada acesso' where codigo='g_visita';
update bpf_gatilhos set evento='Dia de produção de alimentação animal', obs='POP-04, item 7: nos dias de produção' where codigo='g_uniforme';
