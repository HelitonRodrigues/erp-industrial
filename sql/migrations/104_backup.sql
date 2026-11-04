-- 104 · Módulo BACKUP (backup.html) — nov/2026
-- Exportar: dados de todas as tabelas (public) + arquivos do Storage + a ESTRUTURA do banco
--           (tabelas, regras, funções, gatilhos, permissões) num .zip.
-- Importar: só num ERP NOVO (banco praticamente vazio). Recoloca os dados com os gatilhos desligados.
-- Tudo só para Super Admin (SADM/ADM). Sessão direta no banco (SQL Editor) também pode.
-- Fora do arquivo: push_config (chave privada dos avisos) e usuarios.senha_hash (credencial).
-- Logins (Supabase Auth) não vão: no ERP novo cada um ganha senha nova pelo 🔑 em Usuários.

create table if not exists public.backup_importacoes(
  id uuid primary key default gen_random_uuid(),
  iniciado_em timestamptz not null default now(),
  iniciado_por text,
  arquivo text,
  finalizado_em timestamptz,
  resumo jsonb
);
alter table public.backup_importacoes enable row level security;   -- sem policy: só pelas funções

create or replace function public.backup_eh_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select perfil from usuarios where auth_id = auth.uid() limit 1) in ('SADM','ADM'), false)
$$;

create or replace function public.backup__checa() returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null and session_user <> 'authenticator' then return; end if;   -- SQL Editor / conexão direta
  if not backup_eh_admin() then raise exception 'Só o Super Admin pode usar o Backup.' using errcode = '42501'; end if;
end $$;

create or replace function public.backup__fora() returns text[]
language sql immutable as $$ select array['push_config','backup_importacoes'] $$;

create or replace function public.backup__tabela(p text) returns regclass
language plpgsql stable security definer set search_path = public as $$
begin
  if p = any(backup__fora()) or not exists(select 1 from pg_tables where schemaname = 'public' and tablename = p) then
    raise exception 'Tabela "%" não faz parte do backup.', p;
  end if;
  return ('public.' || quote_ident(p))::regclass;
end $$;

/* lista de tabelas (linhas, tamanho, dependências) + sequências */
create or replace function public.backup_info() returns jsonb
language plpgsql security definer set search_path = public as $$
declare r record; n bigint; tabs jsonb := '[]'; seqs jsonb := '[]'; v bigint; ch boolean;
begin
  perform backup__checa();
  for r in select c.oid, c.relname from pg_class c
           where c.relnamespace = 'public'::regnamespace and c.relkind = 'r'
             and not exists(select 1 from pg_depend d where d.objid = c.oid and d.deptype = 'e')
           order by c.relname loop
    if r.relname = any(backup__fora()) then continue; end if;
    execute format('select count(*) from public.%I', r.relname) into n;
    tabs := tabs || jsonb_build_object('nome', r.relname, 'linhas', n, 'bytes', pg_total_relation_size(r.oid),
      'deps', (select coalesce(jsonb_agg(distinct cf.relname), '[]') from pg_constraint k join pg_class cf on cf.oid = k.confrelid
               where k.conrelid = r.oid and k.contype = 'f' and k.confrelid <> r.oid and cf.relnamespace = 'public'::regnamespace));
  end loop;
  for r in select sequencename from pg_sequences where schemaname = 'public' order by 1 loop
    execute format('select last_value, is_called from public.%I', r.sequencename) into v, ch;
    seqs := seqs || jsonb_build_object('nome', r.sequencename, 'valor', v, 'chamado', ch);
  end loop;
  return jsonb_build_object('versao', 1, 'gerado_em', now(), 'tabelas', tabs, 'sequencias', seqs,
    'fora', to_jsonb(backup__fora()), 'colunas_fora', jsonb_build_object('usuarios', jsonb_build_array('senha_hash')));
end $$;

/* um pedaço de uma tabela, em ordem da chave primária */
create or replace function public.backup_ler(p_tabela text, p_offset int, p_limit int) returns jsonb
language plpgsql security definer set search_path = public as $$
declare t regclass; pk text; res jsonb;
begin
  perform backup__checa();
  t := backup__tabela(p_tabela);
  select string_agg(format('%I', a.attname), ',' order by array_position(i.indkey::int2[], a.attnum)) into pk
    from pg_index i join pg_attribute a on a.attrelid = i.indrelid and a.attnum = any(i.indkey)
   where i.indrelid = t and i.indisprimary;
  execute format('select coalesce(jsonb_agg(to_jsonb(x)%s), ''[]'') from (select * from %s order by %s offset %s limit %s) x',
    case when p_tabela = 'usuarios' then ' - ''senha_hash''' else '' end, t, coalesce(pk, 'ctid'),
    greatest(coalesce(p_offset, 0), 0), least(greatest(coalesce(p_limit, 500), 1), 5000)) into res;
  return res;
end $$;

/* arquivos do Storage */
create or replace function public.backup_arquivos() returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  perform backup__checa();
  return (select coalesce(jsonb_agg(jsonb_build_object('b', bucket_id, 'n', name, 's', coalesce((metadata->>'size')::bigint, 0),
                 'm', metadata->>'mimetype') order by bucket_id, name), '[]') from storage.objects);
end $$;

/* ESTRUTURA do banco em SQL — rodar no SQL Editor do projeto novo antes de importar */
create or replace function public.backup_estrutura() returns text
language plpgsql security definer set search_path = public as $fn$
declare o text; r record; cols text; g record; nl constant text := E'\n';
begin
  perform backup__checa();
  o := '-- ERP Silicate — ESTRUTURA do banco (módulo Backup, ' || to_char(now() at time zone 'America/Sao_Paulo', 'DD/MM/YYYY HH24:MI') || ')' || nl ||
       '-- Rodar UMA vez no SQL Editor de um projeto Supabase NOVO, antes de importar os dados.' || nl ||
       '-- Não leva: logins (Auth), Edge Functions (criar-usuario, push-linhas), chaves/segredos.' || nl ||
       'set check_function_bodies = off;' || nl || 'set client_min_messages = warning;' || nl || nl ||
       'create extension if not exists pgcrypto with schema extensions;' || nl ||
       'create extension if not exists "uuid-ossp" with schema extensions;' || nl ||
       'create extension if not exists pg_net;' || nl || nl || '-- ── sequências' || nl;

  for r in select s.*, c.oid from pg_sequences s join pg_class c on c.relname = s.sequencename and c.relnamespace = 'public'::regnamespace
           where s.schemaname = 'public' and not exists(select 1 from pg_depend d where d.objid = c.oid and d.deptype = 'i') order by 1, 2 loop
    o := o || format('create sequence if not exists public.%I as %s increment %s minvalue %s maxvalue %s start %s cache %s%s;',
      r.sequencename, r.data_type, r.increment_by, r.min_value, r.max_value, r.start_value, r.cache_size, case when r.cycle then ' cycle' else '' end) || nl;
  end loop;

  o := o || nl || '-- ── tabelas' || nl;
  for r in select c.oid, c.relname from pg_class c where c.relnamespace = 'public'::regnamespace and c.relkind = 'r'
           and not exists(select 1 from pg_depend d where d.objid = c.oid and d.deptype = 'e') order by c.relname loop
    select string_agg('  ' || format('%I', a.attname) || ' ' || format_type(a.atttypid, a.atttypmod) ||
             case when a.attgenerated = 's' then ' generated always as (' || pg_get_expr(ad.adbin, ad.adrelid) || ') stored' else '' end ||
             case a.attidentity when 'a' then ' generated always as identity' when 'd' then ' generated by default as identity' else '' end ||
             case when a.attnotnull then ' not null' else '' end, ',' || nl order by a.attnum)
      into cols from pg_attribute a left join pg_attrdef ad on ad.adrelid = a.attrelid and ad.adnum = a.attnum
     where a.attrelid = r.oid and a.attnum > 0 and not a.attisdropped;
    o := o || format('create table if not exists public.%I (', r.relname) || nl || coalesce(cols, '') || nl || ');' || nl;
  end loop;

  o := o || nl || '-- ── chaves primárias e únicas' || nl;
  for r in select k.conname, c.relname, pg_get_constraintdef(k.oid) def from pg_constraint k join pg_class c on c.oid = k.conrelid
           where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and k.contype in ('p','u')
             and not exists(select 1 from pg_depend d where d.objid = c.oid and d.deptype = 'e') order by c.relname, k.contype, k.conname loop
    o := o || format('do $b$ begin alter table public.%I add constraint %I %s; exception when duplicate_object or duplicate_table or invalid_table_definition then null; end $b$;',
      r.relname, r.conname, r.def) || nl;
  end loop;

  o := o || nl || '-- ── funções' || nl;
  for r in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.prokind in ('f','p')
           and not exists(select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e') order by p.proname, p.oid loop
    o := o || pg_get_functiondef(r.oid) || ';' || nl;
  end loop;

  o := o || nl || '-- ── valores padrão das colunas' || nl;
  for r in select c.relname, a.attname, pg_get_expr(ad.adbin, ad.adrelid) d from pg_attrdef ad
           join pg_attribute a on a.attrelid = ad.adrelid and a.attnum = ad.adnum join pg_class c on c.oid = ad.adrelid
           where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and a.attgenerated = '' and not a.attisdropped
             and not exists(select 1 from pg_depend d where d.objid = c.oid and d.deptype = 'e') order by c.relname, a.attnum loop
    o := o || format('alter table public.%I alter column %I set default %s;', r.relname, r.attname, r.d) || nl;
  end loop;
  for r in select s.relname seq, t.relname tab, a.attname col from pg_depend d
           join pg_class s on s.oid = d.objid and s.relkind = 'S' join pg_class t on t.oid = d.refobjid
           join pg_attribute a on a.attrelid = t.oid and a.attnum = d.refobjsubid
           where d.deptype = 'a' and s.relnamespace = 'public'::regnamespace loop
    o := o || format('alter sequence public.%I owned by public.%I.%I;', r.seq, r.tab, r.col) || nl;
  end loop;

  o := o || nl || '-- ── regras (check) e ligações (chaves estrangeiras)' || nl;
  for r in select k.conname, c.relname, pg_get_constraintdef(k.oid) def from pg_constraint k join pg_class c on c.oid = k.conrelid
           where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and k.contype in ('c','x','f')
             and not exists(select 1 from pg_depend d where d.objid = c.oid and d.deptype = 'e')
           order by case k.contype when 'f' then 2 else 1 end, c.relname, k.conname loop
    o := o || format('do $b$ begin alter table public.%I add constraint %I %s; exception when duplicate_object or duplicate_table then null; end $b$;',
      r.relname, r.conname, r.def) || nl;
  end loop;

  o := o || nl || '-- ── índices' || nl;
  for r in select pg_get_indexdef(i.indexrelid) def from pg_index i join pg_class ic on ic.oid = i.indexrelid join pg_class t on t.oid = i.indrelid
           where t.relnamespace = 'public'::regnamespace and t.relkind = 'r'
             and not exists(select 1 from pg_constraint k where k.conindid = i.indexrelid and k.contype in ('p','u','x'))
             and not exists(select 1 from pg_depend d where d.objid = t.oid and d.deptype = 'e') order by ic.relname loop
    o := o || regexp_replace(r.def, '^CREATE (UNIQUE )?INDEX ', 'CREATE \1INDEX IF NOT EXISTS ') || ';' || nl;
  end loop;

  o := o || nl || '-- ── visões' || nl;
  for r in select c.oid, c.relname, c.reloptions from pg_class c where c.relnamespace = 'public'::regnamespace and c.relkind = 'v'
           and not exists(select 1 from pg_depend d where d.objid = c.oid and d.deptype = 'e') order by c.oid loop
    o := o || format('create or replace view public.%I%s as', r.relname,
      case when r.reloptions is not null then ' with (' || array_to_string(r.reloptions, ', ') || ')' else '' end) || nl || pg_get_viewdef(r.oid, true) || nl;
  end loop;

  o := o || nl || '-- ── gatilhos' || nl;
  for r in select t.tgname, c.relname, pg_get_triggerdef(t.oid) def from pg_trigger t join pg_class c on c.oid = t.tgrelid
           where c.relnamespace = 'public'::regnamespace and not t.tgisinternal order by c.relname, t.tgname loop
    o := o || format('drop trigger if exists %I on public.%I;', r.tgname, r.relname) || nl || r.def || ';' || nl;
  end loop;

  o := o || nl || '-- ── segurança (RLS) e políticas' || nl;
  for r in select c.relname, c.relforcerowsecurity f from pg_class c where c.relnamespace = 'public'::regnamespace and c.relkind = 'r' and c.relrowsecurity
           and not exists(select 1 from pg_depend d where d.objid = c.oid and d.deptype = 'e') order by 1 loop
    o := o || format('alter table public.%I enable row level security;', r.relname) || nl;
    if r.f then o := o || format('alter table public.%I force row level security;', r.relname) || nl; end if;
  end loop;
  for r in select * from pg_policies where schemaname in ('public','storage') and (schemaname = 'public' or tablename = 'objects') order by schemaname, tablename, policyname loop
    o := o || format('drop policy if exists %I on %I.%I;', r.policyname, r.schemaname, r.tablename) || nl ||
      format('create policy %I on %I.%I as %s for %s to %s%s%s;', r.policyname, r.schemaname, r.tablename, lower(r.permissive), lower(r.cmd),
        (select string_agg(case when x = 'public' then 'public' else quote_ident(x) end, ', ') from unnest(r.roles) x),
        case when r.qual is not null then ' using (' || r.qual || ')' else '' end,
        case when r.with_check is not null then ' with check (' || r.with_check || ')' else '' end) || nl;
  end loop;

  o := o || nl || '-- ── quem pode chamar cada função' || nl;
  for r in select p.oid, p.proacl from pg_proc p where p.pronamespace = 'public'::regnamespace and p.prokind in ('f','p') and p.proacl is not null
           and not exists(select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e') order by p.proname loop
    o := o || format('revoke all on function public.%s from public;', r.oid::regprocedure) || nl;
    for g in select distinct case when e.grantee = 0 then 'public' else quote_ident(pg_get_userbyid(e.grantee)) end gr
             from aclexplode(r.proacl) e where e.privilege_type = 'EXECUTE' loop
      o := o || format('grant execute on function public.%s to %s;', r.oid::regprocedure, g.gr) || nl;
    end loop;
  end loop;

  o := o || nl || '-- ── tempo real' || nl;
  for r in select tablename from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' order by 1 loop
    o := o || format('do $b$ begin alter publication supabase_realtime add table public.%I; exception when duplicate_object then null; end $b$;', r.tablename) || nl;
  end loop;

  o := o || nl || '-- ── pastas de arquivos (Storage)' || nl;
  for r in select * from storage.buckets order by id loop
    o := o || format('insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values (%L, %L, %L, %s, %s) on conflict (id) do nothing;',
      r.id, r.name, r.public, coalesce(r.file_size_limit::text, 'null'),
      case when r.allowed_mime_types is null then 'null' else quote_literal(r.allowed_mime_types::text) || '::text[]' end) || nl;
  end loop;

  o := o || nl || '-- ── PRIMEIRO ACESSO (depois de criar o seu login em Authentication > Users):' || nl ||
       '-- insert into public.usuarios (nome, email, perfil, auth_id)' || nl ||
       '--   select ''SEU NOME'', email, ''SADM'', id from auth.users where email = ''seu@email.com.br'';' || nl;
  return o;
end $fn$;

/* trava: só importa num banco (quase) vazio */
create or replace function public.backup_banco_vazio() returns jsonb
language plpgsql security definer set search_path = public as $$
declare r record; n bigint; tot bigint := 0; lst jsonb := '[]';
begin
  perform backup__checa();
  for r in select c.relname from pg_class c where c.relnamespace = 'public'::regnamespace and c.relkind = 'r'
           and not exists(select 1 from pg_depend d where d.objid = c.oid and d.deptype = 'e')
           and c.relname not in ('usuarios','perfis','empresa_config','auditoria','backup_importacoes','push_config') loop
    execute format('select count(*) from public.%I', r.relname) into n;
    if n > 0 then tot := tot + n; lst := lst || jsonb_build_object('nome', r.relname, 'linhas', n); end if;
  end loop;
  return jsonb_build_object('vazio', tot <= 50, 'linhas', tot, 'tabelas', lst);
end $$;

create or replace function public.backup_iniciar_importacao(p_arquivo text) returns uuid
language plpgsql security definer set search_path = public as $$
declare v jsonb; v_id uuid;
begin
  perform backup__checa();
  v := backup_banco_vazio();
  if not (v->>'vazio')::boolean then
    raise exception 'Este banco já tem dados (% registros). A importação só roda num ERP novo, vazio.', v->>'linhas';
  end if;
  update backup_importacoes set finalizado_em = now(), resumo = coalesce(resumo, '{}') || '{"abandonada":true}' where finalizado_em is null;
  insert into backup_importacoes (iniciado_por, arquivo)
    values ((select nome from usuarios where auth_id = auth.uid() limit 1), p_arquivo) returning backup_importacoes.id into v_id;
  return v_id;
end $$;

/* recoloca um pedaço de uma tabela (gatilhos da tabela desligados durante o insert) */
create or replace function public.backup_importar(p_sessao uuid, p_tabela text, p_linhas jsonb, p_substituir boolean default false) returns int
language plpgsql security definer set search_path = public as $$
declare t regclass; cols text; n int := 0;
begin
  perform backup__checa();
  if not exists(select 1 from backup_importacoes where id = p_sessao and finalizado_em is null and iniciado_em > now() - interval '12 hours') then
    raise exception 'Importação não iniciada ou já encerrada. Comece de novo.';
  end if;
  t := backup__tabela(p_tabela);
  select string_agg(format('%I', attname), ',' order by attnum) into cols
    from pg_attribute where attrelid = t and attnum > 0 and not attisdropped and attgenerated = '';
  execute format('alter table %s disable trigger user', t);
  if p_tabela = 'usuarios' then
    -- login: quem não existe no Auth deste projeto fica sem login (cria no 🔑 de Usuários);
    -- o cadastro de quem está importando assume o id do backup e mantém o login dele.
    drop table if exists _bk_u;
    create temp table _bk_u on commit drop as select * from jsonb_populate_recordset(null::public.usuarios, p_linhas);
    update _bk_u b set auth_id = null where b.auth_id is not null and not exists(select 1 from auth.users a where a.id = b.auth_id);
    update _bk_u b set auth_id = u.auth_id from public.usuarios u where lower(u.email) = lower(b.email) and u.auth_id is not null;
    delete from public.usuarios u using _bk_u b where lower(u.email) = lower(b.email) and u.id <> b.id;
    execute format('insert into public.usuarios (%s) overriding system value select %s from _bk_u on conflict do nothing', cols, cols);
    get diagnostics n = row_count;
  else
    if p_substituir and p_tabela in ('perfis','empresa_config') then execute format('delete from %s', t); end if;
    execute format('insert into %s (%s) overriding system value select %s from jsonb_populate_recordset(null::%s, $1) on conflict do nothing',
      t, cols, cols, t) using p_linhas;
    get diagnostics n = row_count;
  end if;
  execute format('alter table %s enable trigger user', t);
  return n;
end $$;

create or replace function public.backup_finalizar_importacao(p_sessao uuid, p_sequencias jsonb, p_resumo jsonb) returns void
language plpgsql security definer set search_path = public as $$
declare s jsonb;
begin
  perform backup__checa();
  for s in select * from jsonb_array_elements(coalesce(p_sequencias, '[]')) loop
    if exists(select 1 from pg_sequences where schemaname = 'public' and sequencename = s->>'nome') and (s->>'valor') is not null then
      perform setval(format('public.%I', s->>'nome')::regclass, (s->>'valor')::bigint, coalesce((s->>'chamado')::boolean, true));
    end if;
  end loop;
  update backup_importacoes set finalizado_em = now(), resumo = p_resumo where id = p_sessao;
end $$;

revoke all on function public.backup_info(), public.backup_ler(text,int,int), public.backup_arquivos(), public.backup_estrutura(),
  public.backup_banco_vazio(), public.backup_iniciar_importacao(text), public.backup_importar(uuid,text,jsonb,boolean),
  public.backup_finalizar_importacao(uuid,jsonb,jsonb), public.backup__checa(), public.backup__tabela(text) from public, anon;
grant execute on function public.backup_info(), public.backup_ler(text,int,int), public.backup_arquivos(), public.backup_estrutura(),
  public.backup_banco_vazio(), public.backup_iniciar_importacao(text), public.backup_importar(uuid,text,jsonb,boolean),
  public.backup_finalizar_importacao(uuid,jsonb,jsonb), public.backup__checa(), public.backup__tabela(text) to authenticated;

-- Storage: no ERP novo o admin precisa subir os arquivos em todas as pastas (publico-anexos só aceita anon com regra)
drop policy if exists backup_admin_arquivos on storage.objects;
create policy backup_admin_arquivos on storage.objects for all to authenticated using (public.backup_eh_admin()) with check (public.backup_eh_admin());
