-- 028 — Políticas do bucket insumos-docs.
-- O ERP hoje acessa o Supabase com a chave anon e sem login, então a política
-- precisa liberar o papel anon — mesmo nível de acesso do resto do sistema.
-- Quando o item 1 do plano (chave anon + RLS) entrar, isto vira acesso por perfil.
drop policy if exists insumos_docs_anon_select on storage.objects;
drop policy if exists insumos_docs_anon_insert on storage.objects;
drop policy if exists insumos_docs_anon_update on storage.objects;
drop policy if exists insumos_docs_anon_delete on storage.objects;

create policy insumos_docs_anon_select on storage.objects for select
  to anon, authenticated using (bucket_id = 'insumos-docs');
create policy insumos_docs_anon_insert on storage.objects for insert
  to anon, authenticated with check (bucket_id = 'insumos-docs');
create policy insumos_docs_anon_update on storage.objects for update
  to anon, authenticated using (bucket_id = 'insumos-docs') with check (bucket_id = 'insumos-docs');
create policy insumos_docs_anon_delete on storage.objects for delete
  to anon, authenticated using (bucket_id = 'insumos-docs');
