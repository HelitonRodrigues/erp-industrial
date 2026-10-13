-- 056 — Entrar com o NOME DE USUÁRIO ou com o e-mail
-- usuarios.login: nome curto (ex.: luciano), único, minúsculo. Preenchido com a parte do e-mail antes do @.
-- email_do_login(p_login): função pública (anon) que devolve SÓ o e-mail do usuário ativo com aquele login,
-- para o index.html chamar o Supabase Auth (que só entende e-mail). Se vier com @, devolve o próprio e-mail.
alter table public.usuarios add column if not exists login text;
update public.usuarios set login = lower(split_part(email,'@',1)) where login is null and email like '%@%';
create unique index if not exists usuarios_login_uk on public.usuarios (lower(login)) where login is not null;
create or replace function public.email_do_login(p_login text)
returns text language sql stable security definer set search_path = public as $$
  select case
    when position('@' in coalesce(p_login,'')) > 0 then lower(trim(p_login))
    else (select u.email from public.usuarios u where u.status = 'ativo' and lower(u.login) = lower(trim(p_login)) limit 1)
  end;
$$;
revoke all on function public.email_do_login(text) from public;
grant execute on function public.email_do_login(text) to anon, authenticated;
