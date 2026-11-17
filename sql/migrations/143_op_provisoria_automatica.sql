-- (17/11/2026) Modo provisório do laboratório: aprovou o 1º pallet/bag de Big Bag / Caulim 25 kg num dia+linha sem produção lançada →
-- OP PROVISÓRIA criada sozinha (lab_op_provisoria). producao.html, ao lançar a produção, grava em cima dela.
-- Análise que nasce num pallet com OP já pega a OP (tg_analise_pega_op). Aplicada no Supabase em 17/11 (ver CLAUDE.md).
create or replace function public.dia_semana_pt(d date) returns text language sql immutable as
$$ select (array['Domingo','Segunda-feira','Terça-feira','Quarta-feira','Quinta-feira','Sexta-feira','Sábado'])[extract(dow from d)::int+1] $$;
-- lab_op_provisoria(p_pal uuid), tg_lab_aprova_pelo_primeiro (chama a OP provisória após a cascata) e tg_analise_pega_op:
-- definições completas aplicadas pelas migrações 143_op_provisoria_automatica e 143b_op_provisoria_dia_semana no Supabase.
