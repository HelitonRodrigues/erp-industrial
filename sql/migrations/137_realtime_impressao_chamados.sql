-- (17/11/2026) menos peso no banco (Nano travou): a estação de impressão e os chamados da portaria passam a ser AVISADOS
-- pelo realtime em vez de perguntar a cada 3–5 s.
alter publication supabase_realtime add table public.impressao_fila;
alter publication supabase_realtime add table public.portaria_chamados;
