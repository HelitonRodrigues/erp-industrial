-- 059 — Painel de Metas na TV sem login: código da TV + leitura só do necessário.
-- A TV (Chromecast, navegador da Smart TV) abre painel-metas.html?tv=CODIGO.
-- O código fica numa tabela sem policy (ninguém do app lê direto); gerar/trocar só logado.
create table if not exists public.painel_tv (
  id int primary key default 1 check (id = 1),
  codigo text not null,
  criado_em timestamptz not null default now(),
  criado_por uuid
);
alter table public.painel_tv enable row level security;

create or replace function public.painel_tv_codigo(p_novo boolean default false)
returns text language plpgsql security definer set search_path = public, extensions as $$
declare v text;
begin
  if auth.uid() is null then raise exception 'faça login' using errcode = '28000'; end if;
  select codigo into v from public.painel_tv where id = 1;
  if v is null or p_novo then
    -- 8 letras/números sem os que confundem (0/O, 1/I/L)
    select string_agg(substr('ABCDEFGHJKMNPQRSTUVWXYZ23456789', 1 + (get_byte(b, i) % 31), 1), '')
      into v from (select gen_random_bytes(8) b) x, generate_series(0, 7) i;
    insert into public.painel_tv(id, codigo, criado_por) values (1, v, auth.uid())
    on conflict (id) do update set codigo = excluded.codigo, criado_em = now(), criado_por = excluded.criado_por;
  end if;
  return v;
end $$;
revoke all on function public.painel_tv_codigo(boolean) from public;
grant execute on function public.painel_tv_codigo(boolean) to authenticated;

-- Só o que o painel usa: OP (linha, turno, horas, quantidades por produto — sem encarregado/equipe),
-- seções do planejamento (horas e média/h), média/h do cadastro das linhas e a unidade dos produtos.
create or replace function public.painel_tv_dados(p_codigo text, p_ini date, p_fim date)
returns jsonb language plpgsql security definer stable set search_path = public as $$
begin
  if p_codigo is null or not exists (select 1 from public.painel_tv where id = 1 and codigo = upper(trim(p_codigo))) then
    raise exception 'código da TV inválido' using errcode = '28000';
  end if;
  if p_fim < p_ini or p_fim - p_ini > 62 then raise exception 'período inválido'; end if;
  return jsonb_build_object(
    'producao', coalesce((
      select jsonb_agg(jsonb_build_object('id', o.id, 'data', o.data, 'linha', o.linha, 'turno', o.turno, 'ht', o.ht,
               'produto', o.produto, 'total_sacos', o.total_sacos,
               'produtos_op', (select jsonb_agg(jsonb_build_object('produto', p->>'produto', 'linha_produto', p->>'linha_produto',
                                                                   'ht', p->'ht', 'total_sacos', p->'total_sacos'))
                                 from jsonb_array_elements(coalesce(o.produtos_op, '[]'::jsonb)) p)) order by o.data)
        from public.producao o where o.data between p_ini and p_fim), '[]'::jsonb),
    'planejamentos', coalesce((
      select jsonb_agg(jsonb_build_object('mes', pl.mes, 'secoes', (
               select jsonb_agg(jsonb_build_object('linha', s->>'linha', 'turno', s->>'turno', 'eficiencia', s->'eficiencia',
                        'dispH', s->'dispH', 'horasBrutas', s->'horasBrutas', 'diasTrabalho', s->'diasTrabalho',
                        'produtos', (select jsonb_agg(jsonb_build_object('nome', pp->>'nome', 'capHora', pp->'capHora'))
                                       from jsonb_array_elements(coalesce(s->'produtos', '[]'::jsonb)) pp)))
                 from jsonb_array_elements(coalesce(pl.secoes, '[]'::jsonb)) s)))
        from public.planejamentos pl where pl.mes between to_char(p_ini, 'YYYY-MM') and to_char(p_fim, 'YYYY-MM')), '[]'::jsonb),
    'linhas', coalesce((
      select jsonb_agg(jsonb_build_object('nome', l.nome, 'status', l.status, 'produtos', (
               select jsonb_agg(jsonb_build_object('nome', pp->>'nome', 'capHora', pp->'capHora'))
                 from jsonb_array_elements(coalesce(l.produtos, '[]'::jsonb)) pp)) order by l.nome)
        from public.linhas_producao l), '[]'::jsonb),
    'produtos', coalesce((select jsonb_agg(jsonb_build_object('nome', pr.nome, 'unidade', pr.unidade)) from public.produtos pr), '[]'::jsonb)
  );
end $$;
revoke all on function public.painel_tv_dados(text, date, date) from public;
grant execute on function public.painel_tv_dados(text, date, date) to anon, authenticated;
