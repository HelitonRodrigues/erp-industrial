-- 191 — Fecha as tabelas que estavam abertas para a internet.
-- 8 tabelas estavam SEM RLS: qualquer pessoa com a chave pública do site
-- conseguia ler e gravar nelas sem login. carregamento_ao_vivo tinha
-- policy liberada para "public" (inclui quem não está logado).
-- Depois desta migration: só usuário logado acessa — igual às outras tabelas.
-- Não muda nada para quem usa o sistema.

do $$
declare t text;
begin
  foreach t in array array[
    'bpf_gatilhos','bpf_tarefas','insumos_entradas_mp',
    'lab_cimentos','lab_cimentos_movimentos','lab_entradas_cai',
    'lab_entradas_movimentos','lab_mp_limites'
  ] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists baseline_authenticated_all on public.%I', t);
    execute format('create policy baseline_authenticated_all on public.%I for all to authenticated using (true) with check (true)', t);
  end loop;
end $$;

drop policy if exists cav_all on public.carregamento_ao_vivo;
drop policy if exists baseline_authenticated_all on public.carregamento_ao_vivo;
create policy baseline_authenticated_all on public.carregamento_ao_vivo
  for all to authenticated using (true) with check (true);
