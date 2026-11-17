-- (17/11/2026) foto do realizado do plano de custo para o dashboard (aplicada no Supabase: 148_custo_salvar_real)
create or replace function public.custo_salvar_real(p_id uuid, p_real jsonb) returns void language sql security definer set search_path=public as $$
  update planejamentos_custo set totais = coalesce(totais,'{}'::jsonb) || jsonb_build_object('real', p_real) where id = p_id;
$$;
grant execute on function public.custo_salvar_real(uuid,jsonb) to authenticated;
