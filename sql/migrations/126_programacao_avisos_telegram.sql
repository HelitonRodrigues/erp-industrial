-- 126 — Aviso "lancei pedido novo" também pelo TELEGRAM (grátis, robô oficial).
-- O robô do WhatsApp (CallMeBot) ficou lotado em 12/11/2026; os dois canais convivem.
-- Token do robô (criado pelo dono no @BotFather) fica em prog_aviso_config, SEM policy: nunca volta para a tela.
-- Cada pessoa abre o robô e manda /start; a tela lista quem mandou (getUpdates) e o dono escolhe quem recebe.

create table if not exists prog_aviso_config (
  id int primary key default 1 check (id = 1),
  telegram_token text,
  atualizado_em timestamptz not null default now(),
  atualizado_por text
);
alter table prog_aviso_config enable row level security;
revoke all on prog_aviso_config from anon, authenticated;

alter table prog_aviso_destinos add column if not exists canal text not null default 'whatsapp';
alter table prog_aviso_destinos add column if not exists chat_id text;
alter table prog_aviso_destinos alter column telefone drop not null;
alter table prog_aviso_destinos alter column apikey drop not null;

-- envia para todos os destinos ativos (WhatsApp via CallMeBot, Telegram via Bot API)
create or replace function prog_whats_enviar(p_texto text) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare d record; r jsonb := '[]'; rid bigint; tk text;
begin
  select telegram_token into tk from prog_aviso_config where id = 1;
  for d in select * from prog_aviso_destinos where ativo loop
    begin
      if d.canal = 'telegram' then
        if tk is null or d.chat_id is null then
          r := r || jsonb_build_object('nome', d.nome, 'canal', 'telegram', 'erro', 'robô do Telegram não configurado');
          continue;
        end if;
        rid := net.http_post('https://api.telegram.org/bot' || tk || '/sendMessage',
          jsonb_build_object('chat_id', d.chat_id, 'text', p_texto), '{}'::jsonb, '{"Content-Type":"application/json"}'::jsonb, 15000);
      else
        rid := net.http_get('https://api.callmebot.com/whatsapp.php',
          jsonb_build_object('phone', regexp_replace(d.telefone, '\D', '', 'g'), 'text', p_texto, 'apikey', d.apikey), '{}'::jsonb, 15000);
      end if;
      r := r || jsonb_build_object('nome', d.nome, 'canal', d.canal, 'req', rid);
    exception when others then
      r := r || jsonb_build_object('nome', d.nome, 'canal', d.canal, 'erro', sqlerrm);
    end;
  end loop;
  return r;
end $$;

-- admin: grava o token do robô (não devolve o token, só diz que está configurado)
create or replace function prog_tg_salvar_token(p_token text) returns boolean
language plpgsql security definer set search_path = public, extensions as $$
declare quem text;
begin
  if not backup_eh_admin() then raise exception 'só administrador'; end if;
  if coalesce(btrim(p_token), '') !~ '^\d{5,15}:[A-Za-z0-9_-]{30,60}$' then raise exception 'token inválido (formato 123456789:ABC...)'; end if;
  select nome into quem from usuarios where auth_id = auth.uid() limit 1;
  insert into prog_aviso_config(id, telegram_token, atualizado_em, atualizado_por) values (1, btrim(p_token), now(), quem)
  on conflict (id) do update set telegram_token = excluded.telegram_token, atualizado_em = now(), atualizado_por = quem;
  return true;
end $$;

create or replace function prog_tg_status() returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
begin
  if not backup_eh_admin() then raise exception 'só administrador'; end if;
  return coalesce((select jsonb_build_object('configurado', telegram_token is not null, 'em', atualizado_em, 'por', atualizado_por) from prog_aviso_config where id = 1),
                  jsonb_build_object('configurado', false));
end $$;

-- admin: chama getMe / getUpdates (resposta lida depois com prog_http_resposta)
create or replace function prog_tg_chamar(p_metodo text) returns bigint
language plpgsql security definer set search_path = public, extensions as $$
declare tk text;
begin
  if not backup_eh_admin() then raise exception 'só administrador'; end if;
  if p_metodo not in ('getMe', 'getUpdates') then raise exception 'método não permitido'; end if;
  select telegram_token into tk from prog_aviso_config where id = 1;
  if tk is null then raise exception 'cadastre o token do robô primeiro'; end if;
  return net.http_get('https://api.telegram.org/bot' || tk || '/' || p_metodo, '{}'::jsonb, '{}'::jsonb, 15000);
end $$;

create or replace function prog_http_resposta(p_ids bigint[]) returns jsonb
language sql security definer set search_path = public, extensions as $$
  select coalesce(jsonb_agg(jsonb_build_object('req', id, 'status', status_code, 'corpo', left(content, 20000), 'erro', error_msg)), '[]'::jsonb)
    from net._http_response where id = any(p_ids) and backup_eh_admin();
$$;

revoke all on function prog_whats_enviar(text) from public, anon, authenticated;
grant execute on function prog_whats_enviar(text) to service_role;
revoke all on function prog_tg_salvar_token(text), prog_tg_status(), prog_tg_chamar(text), prog_http_resposta(bigint[]) from public, anon;
grant execute on function prog_tg_salvar_token(text), prog_tg_status(), prog_tg_chamar(text), prog_http_resposta(bigint[]) to authenticated;
