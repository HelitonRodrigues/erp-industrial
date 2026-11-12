-- 121 — Programação de Cargas v3: linha escolhida por pedido + link público por representante
-- O representante abre programacao-rep.html?c=CODIGO (sem login) e vê:
--   • os pedidos DELE com a data da fábrica (e se mudou);
--   • os dias livres (conta feita com os pedidos de TODOS, mas sem cliente/pedido dos outros).
-- representante = '*' é o link geral do dono (vê tudo).

alter table programacao_cargas add column if not exists linha_manual text;

create table if not exists prog_links (
  id            uuid primary key default gen_random_uuid(),
  representante text not null unique,
  codigo        text not null unique,
  ativo         boolean not null default true,
  criado_em     timestamptz not null default now(),
  trocado_em    timestamptz,
  ultimo_acesso timestamptz
);
alter table prog_links enable row level security;
drop policy if exists baseline_authenticated_all on prog_links;
create policy baseline_authenticated_all on prog_links for all to authenticated using (true) with check (true);

-- gera (ou troca) o código do representante. Só logado.
create or replace function prog_link_gerar(p_rep text, p_trocar boolean default false)
returns text language plpgsql security definer set search_path = public as $$
declare cod text; alfa text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
begin
  if auth.uid() is null then raise exception 'precisa estar logado'; end if;
  if coalesce(btrim(p_rep),'') = '' then raise exception 'representante vazio'; end if;
  select codigo into cod from prog_links where representante = p_rep;
  if cod is not null and not p_trocar then
    update prog_links set ativo = true where representante = p_rep;
    return cod;
  end if;
  loop
    cod := (select string_agg(substr(alfa, 1 + floor(random() * length(alfa))::int, 1), '') from generate_series(1, 10));
    exit when not exists (select 1 from prog_links where codigo = cod);
  end loop;
  insert into prog_links (representante, codigo) values (p_rep, cod)
  on conflict (representante) do update set codigo = excluded.codigo, ativo = true, trocado_em = now();
  return cod;
end $$;
revoke all on function prog_link_gerar(text, boolean) from public, anon;
grant execute on function prog_link_gerar(text, boolean) to authenticated;

-- dados do link público (anon). Nunca devolve cliente/pedido de outro representante.
create or replace function prog_publico(p_codigo text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare lk prog_links; geral boolean; fim date := current_date + 42;
begin
  select * into lk from prog_links where codigo = upper(btrim(p_codigo)) and ativo;
  if lk.id is null then return jsonb_build_object('ok', false, 'motivo', 'link inválido ou desativado'); end if;
  geral := lk.representante = '*';
  update prog_links set ultimo_acesso = now() where id = lk.id;
  return jsonb_build_object(
    'ok', true,
    'representante', case when geral then null else lk.representante end,
    'geral', geral,
    'empresa', (select coalesce(nome_fantasia, razao_social) from empresa_config limit 1),
    'atualizado', (select max(atualizado_salescode) from programacao_cargas),
    'meus', coalesce((select jsonb_agg(jsonb_build_object(
        'pedido', p.pedido, 'cliente', coalesce(p.planilha->>'cliente', p.cliente_salescode), 'cidade', coalesce(p.detalhes->>'entrega_cidade', p.cidade),
        'itens', p.itens, 'planilha', case when p.planilha is null then null else jsonb_build_object('embalagem', p.planilha->'embalagem', 'material', p.planilha->'material', 'peso_t', p.planilha->'peso_t') end,
        'data_manual', p.data_manual, 'data_salescode', p.data_salescode, 'data_planilha', p.data_planilha,
        'status_salescode', p.status_salescode, 'linha_manual', p.linha_manual,
        'representante', case when geral then p.representante end))
      from programacao_cargas p
      where not p.carregado and (geral or p.representante = lk.representante)), '[]'::jsonb),
    -- todos os pedidos em aberto, sem nada que identifique cliente/representante: só para a conta de capacidade
    'carga', coalesce((select jsonb_agg(jsonb_build_object(
        'd', coalesce(p.data_manual, p.data_salescode, p.data_planilha), 'itens', p.itens, 'lm', p.linha_manual, 'st', p.status_salescode,
        'planilha', case when p.planilha is null then null else jsonb_build_object('embalagem', p.planilha->'embalagem', 'material', p.planilha->'material', 'peso_t', p.planilha->'peso_t') end))
      from programacao_cargas p
      where not p.carregado and coalesce(p.data_manual, p.data_salescode, p.data_planilha) between current_date and fim), '[]'::jsonb),
    'planos', coalesce((select jsonb_agg(jsonb_build_object('nome', pc.nome, 'mes', pc.mes, 'ano', pc.ano, 'atualizado_em', pc.atualizado_em,
        'estado', jsonb_build_object('calendario', pc.estado->'calendario', 'horasDomingoEspecial', pc.estado->'horasDomingoEspecial',
          'blocos', (select jsonb_agg(jsonb_build_object('linhaNome', b->>'linhaNome',
             'secoes', (select jsonb_agg(jsonb_build_object('turnoNome', s->>'turnoNome', 'eficiencia', s->'eficiencia', 'simuladoDesligado', s->'simuladoDesligado',
                'produtos', (select jsonb_agg(jsonb_build_object('nome', pr->>'nome', 'capHora', pr->'capHora', 'ativo', pr->'ativo')) from jsonb_array_elements(s->'produtos') pr)))
               from jsonb_array_elements(b->'secoes') s)))
            from jsonb_array_elements(pc.estado->'blocos') b))))
      from planejamentos_custo pc
      where pc.status = 'ativo' and make_date(pc.ano, pc.mes, 1) between date_trunc('month', current_date)::date and fim), '[]'::jsonb),
    'turnos', coalesce((select jsonb_agg(jsonb_build_object('nome', t.nome, 'refeicao_min', t.refeicao_min, 'calendario', t.calendario)) from turnos t), '[]'::jsonb),
    'produtos', coalesce((select jsonb_agg(jsonb_build_object('id', pr.id, 'nome', pr.nome, 'linhas', pr.linhas, 'peso_unidade_kg', pr.peso_unidade_kg)) from produtos pr where pr.status = 'ativo'), '[]'::jsonb),
    'aliases', coalesce((select jsonb_agg(jsonb_build_object('alias_norm', a.alias_norm, 'produto_id', a.produto_id)) from produto_aliases a), '[]'::jsonb)
  );
end $$;
revoke all on function prog_publico(text) from public;
grant execute on function prog_publico(text) to anon, authenticated;
