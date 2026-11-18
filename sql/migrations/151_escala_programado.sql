-- (18/11/2026) escala PROGRAMADO → ATIVA quando o período começa. Aplicada no Supabase (151_escala_programado).
create or replace function public.escalas_promover() returns int language plpgsql security definer set search_path=public as $$
declare n int; begin update escalas set status='ativa' where status='programado' and periodo_inicio <= (now() at time zone 'America/Sao_Paulo')::date; get diagnostics n = row_count; return n; end $$;
grant execute on function public.escalas_promover() to authenticated;
