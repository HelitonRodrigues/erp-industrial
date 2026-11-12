-- 125 — Login do representante (programação de cargas)
-- Representante NÃO é usuário do ERP: não recebe JWT do Supabase Auth, então
-- nenhuma tabela/módulo do ERP abre para ele (RLS: anon não lê nada).
-- Ele entra com login/senha próprios (bcrypt) e recebe um token de sessão.
-- Os dados chegam pela Edge Function `prog-rep`, que filtra no SERVIDOR pelo
-- representante da conta e faz a conta dos dias livres lá (o celular não recebe
-- pedido de mais ninguém, nem anônimo).
-- Avisos "lancei pedido novo": notificação no ERP + WhatsApp grátis (CallMeBot) via pg_net.
-- Sessão nunca é apagada: sair/trocar senha só EXPIRA (expira_em = now()).
-- Atraso da fábrica (quebrou a linha): empurra os pedidos programados N dias úteis, com desfazer.

create table if not exists prog_rep_contas (
  id uuid primary key default gen_random_uuid(),
  login text not null unique,
  senha_hash text not null,
  representante text not null,          -- igual ao programacao_cargas.representante (ex.: "308 — BALDUINO ...")
  nome text,
  telefone text,
  ativo boolean not null default true,
  tentativas int not null default 0,
  bloqueado_ate timestamptz,
  ultimo_login timestamptz,
  criado_por text,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
create table if not exists prog_rep_sessoes (
  token_hash text primary key,
  conta_id uuid not null references prog_rep_contas(id) on delete cascade,
  criado_em timestamptz not null default now(),
  expira_em timestamptz not null,
  ultimo_uso timestamptz
);
create index if not exists prog_rep_sessoes_conta on prog_rep_sessoes(conta_id);
create table if not exists prog_rep_avisos (
  id uuid primary key default gen_random_uuid(),
  conta_id uuid references prog_rep_contas(id) on delete set null,
  representante text,
  tipo text not null default 'pedido_novo',
  pedido text,
  mensagem text,
  whatsapp jsonb,
  criado_em timestamptz not null default now(),
  lido_em timestamptz,
  lido_por text
);
create table if not exists prog_aviso_destinos (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  telefone text not null,               -- só números, com 55 + DDD
  apikey text not null,                 -- chave do CallMeBot daquele número
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);
create table if not exists prog_atrasos (
  id uuid primary key default gen_random_uuid(),
  linha text not null,
  inicio date not null,
  dias int not null,
  motivo text not null,
  itens jsonb not null default '[]',    -- [{id, pedido, de, para, antes}] (antes = data_manual anterior)
  criado_por text,
  criado_em timestamptz not null default now(),
  desfeito_em timestamptz,
  desfeito_por text
);

alter table prog_rep_contas enable row level security;
alter table prog_rep_sessoes enable row level security;
alter table prog_rep_avisos enable row level security;
alter table prog_aviso_destinos enable row level security;
alter table prog_atrasos enable row level security;
-- contas/sessões: NENHUMA policy (só as funções abaixo mexem). Senha nunca sai do banco.
drop policy if exists prog_rep_avisos_int on prog_rep_avisos;
create policy prog_rep_avisos_int on prog_rep_avisos for all to authenticated using (true) with check (true);
drop policy if exists prog_atrasos_int on prog_atrasos;
create policy prog_atrasos_int on prog_atrasos for select to authenticated using (true);
drop policy if exists prog_aviso_destinos_adm on prog_aviso_destinos;
create policy prog_aviso_destinos_adm on prog_aviso_destinos for all to authenticated using (backup_eh_admin()) with check (backup_eh_admin());

-- ── sessão ──
create or replace function rep_sessao(p_token text)
returns table(conta_id uuid, representante text, nome text, login text)
language plpgsql security definer set search_path = public, extensions as $$
declare h text := encode(digest(coalesce(p_token,''), 'sha256'), 'hex');
begin
  if coalesce(length(p_token),0) < 40 then return; end if;
  update prog_rep_sessoes s set ultimo_uso = now(), expira_em = greatest(s.expira_em, now() + interval '7 days')
   where s.token_hash = h and s.expira_em > now();
  return query
    select c.id, c.representante, c.nome, c.login
      from prog_rep_sessoes s join prog_rep_contas c on c.id = s.conta_id
     where s.token_hash = h and s.expira_em > now() and c.ativo;
end $$;

create or replace function rep_entrar(p_login text, p_senha text)
returns jsonb language plpgsql security definer set search_path = public, extensions as $$
declare c prog_rep_contas; tk text;
begin
  select * into c from prog_rep_contas where login = lower(btrim(p_login));
  if c.id is null or not c.ativo then
    perform pg_sleep(0.6);
    return jsonb_build_object('ok', false, 'motivo', 'Usuário ou senha incorretos.');
  end if;
  if c.bloqueado_ate is not null and c.bloqueado_ate > now() then
    return jsonb_build_object('ok', false, 'motivo', 'Muitas tentativas erradas. Tente de novo às ' ||
      to_char(c.bloqueado_ate at time zone 'America/Sao_Paulo', 'HH24:MI') || '.');
  end if;
  if c.senha_hash <> crypt(coalesce(p_senha,''), c.senha_hash) then
    update prog_rep_contas set
      bloqueado_ate = case when tentativas + 1 >= 5 then now() + interval '15 minutes' else null end,
      tentativas = case when tentativas + 1 >= 5 then 0 else tentativas + 1 end
     where id = c.id;
    perform pg_sleep(0.6);
    return jsonb_build_object('ok', false, 'motivo', 'Usuário ou senha incorretos.');
  end if;
  tk := encode(gen_random_bytes(32), 'hex');
  insert into prog_rep_sessoes(token_hash, conta_id, expira_em) values (encode(digest(tk, 'sha256'), 'hex'), c.id, now() + interval '7 days');
  update prog_rep_contas set tentativas = 0, bloqueado_ate = null, ultimo_login = now() where id = c.id;
  return jsonb_build_object('ok', true, 'token', tk, 'nome', c.nome);
end $$;

create or replace function rep_sair(p_token text) returns void
language sql security definer set search_path = public, extensions as $$
  update prog_rep_sessoes set expira_em = now() where token_hash = encode(digest(coalesce(p_token,''), 'sha256'), 'hex');
$$;

create or replace function rep_trocar_senha(p_token text, p_atual text, p_nova text) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare s record; c prog_rep_contas;
begin
  select * into s from rep_sessao(p_token);
  if s.conta_id is null then return jsonb_build_object('ok', false, 'motivo', 'Sessão expirada. Entre de novo.'); end if;
  select * into c from prog_rep_contas where id = s.conta_id;
  if c.senha_hash <> crypt(coalesce(p_atual,''), c.senha_hash) then return jsonb_build_object('ok', false, 'motivo', 'Senha atual incorreta.'); end if;
  if length(coalesce(p_nova,'')) < 6 then return jsonb_build_object('ok', false, 'motivo', 'A nova senha precisa de pelo menos 6 caracteres.'); end if;
  update prog_rep_contas set senha_hash = crypt(p_nova, gen_salt('bf', 10)), atualizado_em = now() where id = c.id;
  update prog_rep_sessoes set expira_em = now() where conta_id = c.id and token_hash <> encode(digest(p_token, 'sha256'), 'hex') and expira_em > now();
  return jsonb_build_object('ok', true);
end $$;

-- ── WhatsApp (CallMeBot, grátis) ──
create or replace function prog_whats_enviar(p_texto text) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare d record; r jsonb := '[]'; rid bigint;
begin
  for d in select * from prog_aviso_destinos where ativo loop
    begin
      rid := net.http_get('https://api.callmebot.com/whatsapp.php',
        jsonb_build_object('phone', regexp_replace(d.telefone, '\D', '', 'g'), 'text', p_texto, 'apikey', d.apikey), '{}'::jsonb, 15000);
      r := r || jsonb_build_object('nome', d.nome, 'req', rid);
    exception when others then
      r := r || jsonb_build_object('nome', d.nome, 'erro', sqlerrm);
    end;
  end loop;
  return r;
end $$;

create or replace function rep_avisar(p_token text, p_pedido text, p_obs text) returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
declare s record; txt text; w jsonb; nm text;
begin
  select * into s from rep_sessao(p_token);
  if s.conta_id is null then return jsonb_build_object('ok', false, 'motivo', 'Sessão expirada. Entre de novo.'); end if;
  if exists (select 1 from prog_rep_avisos where conta_id = s.conta_id and criado_em > now() - interval '60 seconds') then
    return jsonb_build_object('ok', false, 'motivo', 'Aviso já enviado agora há pouco. Espere 1 minuto.');
  end if;
  nm := coalesce(nullif(s.nome,''), s.representante);
  txt := '🆕 Pedido novo no Salescode' || chr(10) || 'Representante: ' || nm ||
         case when coalesce(btrim(p_pedido),'') <> '' then chr(10) || 'Pedido: ' || left(btrim(p_pedido), 40) else '' end ||
         case when coalesce(btrim(p_obs),'') <> '' then chr(10) || 'Obs: ' || left(btrim(p_obs), 300) else '' end ||
         chr(10) || to_char(now() at time zone 'America/Sao_Paulo', 'DD/MM HH24:MI') || ' · Programação de Cargas';
  w := prog_whats_enviar(txt);
  insert into prog_rep_avisos(conta_id, representante, pedido, mensagem, whatsapp)
  values (s.conta_id, s.representante, nullif(left(btrim(coalesce(p_pedido,'')), 40), ''), nullif(left(btrim(coalesce(p_obs,'')), 300), ''), w);
  insert into notificacoes(tipo, modulo, titulo, descricao, fonte, chave)
  values ('aviso', 'programacao_cargas', '🆕 ' || nm || ' lançou pedido novo no Salescode',
          coalesce('Pedido ' || nullif(btrim(p_pedido),''), 'Sem número informado') || coalesce(' · ' || nullif(btrim(p_obs),''), ''),
          'representante', 'rep_aviso_' || s.conta_id || '_' || extract(epoch from now())::bigint);
  return jsonb_build_object('ok', true, 'whatsapp', jsonb_array_length(w));
end $$;

-- ── admin (só SADM/ADM) ──
create or replace function rep_contas_listar() returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
begin
  if not backup_eh_admin() then raise exception 'só administrador'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', c.id, 'login', c.login, 'nome', c.nome, 'representante', c.representante,
     'telefone', c.telefone, 'ativo', c.ativo, 'ultimo_login', c.ultimo_login, 'bloqueado_ate', c.bloqueado_ate,
     'sessoes', (select count(*) from prog_rep_sessoes s where s.conta_id = c.id and s.expira_em > now())) order by c.nome)
   from prog_rep_contas c), '[]'::jsonb);
end $$;

create or replace function rep_conta_salvar(p_id uuid, p_login text, p_nome text, p_representante text, p_senha text, p_ativo boolean, p_telefone text default null)
returns uuid language plpgsql security definer set search_path = public, extensions as $$
declare v uuid; lg text := lower(btrim(coalesce(p_login,''))); quem text;
begin
  if not backup_eh_admin() then raise exception 'só administrador'; end if;
  if lg !~ '^[a-z0-9._-]{3,30}$' then raise exception 'login: 3 a 30 letras/números, sem espaço'; end if;
  if coalesce(btrim(p_representante),'') = '' then raise exception 'escolha o representante'; end if;
  if p_senha is not null and length(p_senha) < 6 then raise exception 'senha: pelo menos 6 caracteres'; end if;
  select nome into quem from usuarios where auth_id = auth.uid() limit 1;
  if p_id is null then
    if p_senha is null then raise exception 'informe a senha'; end if;
    insert into prog_rep_contas(login, senha_hash, representante, nome, telefone, ativo, criado_por)
    values (lg, crypt(p_senha, gen_salt('bf', 10)), btrim(p_representante), nullif(btrim(coalesce(p_nome,'')),''), nullif(btrim(coalesce(p_telefone,'')),''), coalesce(p_ativo, true), quem)
    returning id into v;
  else
    update prog_rep_contas set login = lg, representante = btrim(p_representante), nome = nullif(btrim(coalesce(p_nome,'')),''),
      telefone = nullif(btrim(coalesce(p_telefone,'')),''), ativo = coalesce(p_ativo, ativo),
      senha_hash = case when p_senha is null then senha_hash else crypt(p_senha, gen_salt('bf', 10)) end,
      tentativas = case when p_senha is null then tentativas else 0 end,
      bloqueado_ate = case when p_senha is null then bloqueado_ate else null end,
      atualizado_em = now()
     where id = p_id returning id into v;
    if v is null then raise exception 'conta não encontrada'; end if;
    -- trocou senha, representante ou desativou: derruba as sessões abertas
    if p_senha is not null or not coalesce(p_ativo, true) then
      update prog_rep_sessoes set expira_em = now() where conta_id = v and expira_em > now();
    end if;
  end if;
  -- com login, o link público (sem senha) desse representante deixa de funcionar
  if coalesce(p_ativo, true) then update prog_links set ativo = false where representante = btrim(p_representante); end if;
  return v;
end $$;

create or replace function rep_conta_desconectar(p_id uuid) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  if not backup_eh_admin() then raise exception 'só administrador'; end if;
  update prog_rep_sessoes set expira_em = now() where conta_id = p_id and expira_em > now();
  update prog_rep_contas set bloqueado_ate = null, tentativas = 0 where id = p_id;
end $$;

create or replace function prog_whats_testar() returns jsonb
language plpgsql security definer set search_path = public, extensions as $$
begin
  if not backup_eh_admin() then raise exception 'só administrador'; end if;
  return prog_whats_enviar('✅ Teste da Programação de Cargas — se chegou, o aviso de pedido novo está funcionando. ' ||
    to_char(now() at time zone 'America/Sao_Paulo', 'DD/MM HH24:MI'));
end $$;

-- resposta do CallMeBot (para mostrar se chegou)
create or replace function prog_whats_resposta(p_ids bigint[]) returns jsonb
language sql security definer set search_path = public, extensions as $$
  select coalesce(jsonb_agg(jsonb_build_object('req', id, 'status', status_code, 'corpo', left(content, 300), 'erro', error_msg)), '[]'::jsonb)
    from net._http_response where id = any(p_ids) and backup_eh_admin();
$$;

-- ── atraso da fábrica ──
-- A tela calcula as novas datas (dias úteis do planejamento) e manda a lista; aqui grava tudo de uma vez.
create or replace function prog_aplicar_atraso(p_linha text, p_inicio date, p_dias int, p_motivo text, p_itens jsonb)
returns uuid language plpgsql security definer set search_path = public, extensions as $$
declare v uuid; quem text; it jsonb; ant jsonb := '[]';
begin
  select nome into quem from usuarios where auth_id = auth.uid() and status = 'ativo' limit 1;
  if quem is null then raise exception 'precisa estar logado no ERP'; end if;
  if coalesce(btrim(p_motivo),'') = '' then raise exception 'informe o motivo'; end if;
  if p_dias is null or p_dias < 1 or p_dias > 30 then raise exception 'dias: de 1 a 30'; end if;
  for it in select * from jsonb_array_elements(coalesce(p_itens,'[]')) loop
    ant := ant || jsonb_build_object('id', it->>'id', 'pedido', it->>'pedido', 'de', it->>'de', 'para', it->>'para',
      'antes', (select to_jsonb(data_manual) from programacao_cargas where id = (it->>'id')::uuid));
    update programacao_cargas set data_manual = (it->>'para')::date, updated_at = now()
     where id = (it->>'id')::uuid and not carregado;
  end loop;
  insert into prog_atrasos(linha, inicio, dias, motivo, itens, criado_por)
  values (p_linha, p_inicio, p_dias, btrim(p_motivo), ant, quem) returning id into v;
  return v;
end $$;

create or replace function prog_desfazer_atraso(p_id uuid) returns int
language plpgsql security definer set search_path = public, extensions as $$
declare a prog_atrasos; quem text; it jsonb; n int := 0;
begin
  select nome into quem from usuarios where auth_id = auth.uid() and status = 'ativo' limit 1;
  if quem is null then raise exception 'precisa estar logado no ERP'; end if;
  select * into a from prog_atrasos where id = p_id and desfeito_em is null;
  if a.id is null then raise exception 'atraso não encontrado ou já desfeito'; end if;
  for it in select * from jsonb_array_elements(a.itens) loop
    -- só volta quem continua na data que o atraso colocou (se alguém mexeu depois, respeita)
    update programacao_cargas set data_manual = nullif(it->>'antes','null')::date, updated_at = now()
     where id = (it->>'id')::uuid and not carregado and data_manual = (it->>'para')::date;
    if found then n := n + 1; end if;
  end loop;
  update prog_atrasos set desfeito_em = now(), desfeito_por = quem where id = p_id;
  return n;
end $$;

-- ── permissões: tudo fechado; só abre o necessário ──
revoke all on function rep_sessao(text) from public, anon, authenticated;
revoke all on function prog_whats_enviar(text) from public, anon, authenticated;
grant execute on function rep_sessao(text) to service_role;
grant execute on function prog_whats_enviar(text) to service_role;
revoke all on function rep_entrar(text, text), rep_sair(text), rep_trocar_senha(text, text, text), rep_avisar(text, text, text) from public;
grant execute on function rep_entrar(text, text), rep_sair(text), rep_trocar_senha(text, text, text), rep_avisar(text, text, text) to anon, authenticated, service_role;
revoke all on function rep_contas_listar(), rep_conta_salvar(uuid, text, text, text, text, boolean, text), rep_conta_desconectar(uuid),
  prog_whats_testar(), prog_whats_resposta(bigint[]), prog_aplicar_atraso(text, date, int, text, jsonb), prog_desfazer_atraso(uuid) from public, anon;
grant execute on function rep_contas_listar(), rep_conta_salvar(uuid, text, text, text, text, boolean, text), rep_conta_desconectar(uuid),
  prog_whats_testar(), prog_whats_resposta(bigint[]), prog_aplicar_atraso(text, date, int, text, jsonb), prog_desfazer_atraso(uuid) to authenticated;
revoke all on prog_rep_contas, prog_rep_sessoes from anon, authenticated;
revoke all on prog_aviso_destinos, prog_rep_avisos, prog_atrasos from anon;
