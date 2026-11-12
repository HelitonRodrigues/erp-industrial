-- 123 — Programação de Cargas: coluna do quadro do Salescode (prioridade) + financeiro programado conta capacidade
-- • colunas_salescode: em quais colunas o pedido está (Programados · não faturados / Financeiro / A CONTRATAR /
--   Ordem de Carga / Ordem Cancelada). A extensão v1.3 manda "coluna" em cada cartão. Extensão antiga (sem coluna) não apaga.
-- • prog_publico: carga leva 'man' (tem data da fábrica) e 'col' — pedido no financeiro que o dono programou conta capacidade.
alter table programacao_cargas add column if not exists colunas_salescode text[];

create or replace function sync_salescode(p_token text, p_itens jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare n_up int := 0; n_saiu int := 0;
begin
  if auth.uid() is null and not _prog_token_ok(p_token) then raise exception 'token inválido'; end if;
  if p_itens is null or jsonb_array_length(p_itens) < 5 then
    return jsonb_build_object('ok', false, 'motivo', 'lista vazia ou muito curta — nada alterado');
  end if;
  create temp table _sc on commit drop as
    select distinct on (pedido, produto) pedido, produto, x from (
      select upper(substring(btrim(x->>'pedido') from '^[A-Za-z0-9]+')) pedido, btrim(x->>'produto') produto, x
      from jsonb_array_elements(p_itens) x) s
    where coalesce(pedido,'') <> ''
    order by pedido, produto, (nullif(btrim(x->>'status'),'') is null);
  -- colunas do quadro do Salescode em que o pedido aparece (um pedido pode estar em mais de uma)
  create temp table _col on commit drop as
    select upper(substring(btrim(x->>'pedido') from '^[A-Za-z0-9]+')) pedido,
           array_agg(distinct btrim(x->>'coluna')) filter (where coalesce(btrim(x->>'coluna'),'') <> '') colunas
    from jsonb_array_elements(p_itens) x group by 1;
  with agg as (
    select pedido,
      jsonb_agg(jsonb_build_object(
        'produto', produto,
        'qtd', nullif(replace(replace(regexp_replace(coalesce(x->>'qtd',''), '[^0-9,\.]', '', 'g'), '.', ''), ',', '.'), '')::numeric,
        'unidade', upper(btrim(regexp_replace(coalesce(x->>'qtd',''), '[0-9,\.\s]', '', 'g')))
      )) itens,
      max(x->>'cliente') cliente, max(x->>'cidade') cidade, max(x->>'frete') frete,
      min(_prog_data(x->>'data')) data_sc,
      max(nullif(btrim(x->>'status'),'')) status, max(x->>'view') view
    from _sc group by pedido
  ), up as (
    insert into programacao_cargas as p (pedido, em_salescode, data_salescode, status_salescode, cliente_salescode, cidade, frete, salescode_view, itens, colunas_salescode, atualizado_salescode)
    select agg.pedido, true, data_sc, status, cliente, cidade, frete, view, itens, _col.colunas, now() from agg left join _col on _col.pedido = agg.pedido
    on conflict (pedido) do update set
      em_salescode = true, data_salescode = excluded.data_salescode,
      status_salescode = coalesce(excluded.status_salescode, p.status_salescode),
      cliente_salescode = excluded.cliente_salescode, cidade = excluded.cidade, frete = excluded.frete,
      salescode_view = excluded.salescode_view, itens = excluded.itens,
      colunas_salescode = coalesce(excluded.colunas_salescode, p.colunas_salescode),
      atualizado_salescode = now(), updated_at = now()
    returning 1
  ) select count(*) into n_up from up;
  with saiu as (
    update programacao_cargas p set
      em_salescode = false,
      carregado = case when p.carregado_manual then p.carregado else true end,
      carregado_em = case when p.carregado_manual or p.carregado then p.carregado_em else now() end,
      carregado_origem = case when p.carregado_manual or p.carregado then p.carregado_origem else 'salescode' end,
      updated_at = now()
    where p.em_salescode and p.pedido not in (select pedido from _sc)
    returning 1
  ) select count(*) into n_saiu from saiu;
  return jsonb_build_object('ok', true, 'pedidos', n_up, 'sairam', n_saiu, 'em', now(),
    'precisa_detalhe', coalesce((select jsonb_agg(jsonb_build_object('pedido', p.pedido, 'view', p.salescode_view))
      from programacao_cargas p
      where p.em_salescode and not p.carregado and p.salescode_view is not null
        and (p.detalhes_em is null or p.detalhes_em < now() - interval '20 hours'
             or p.status_salescode is distinct from p.detalhes->>'_status')), '[]'::jsonb));
end $$;



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
        'status_salescode', p.status_salescode, 'linha_manual', p.linha_manual, 'colunas_salescode', p.colunas_salescode,
        'representante', case when geral then p.representante end))
      from programacao_cargas p
      where not p.carregado and (geral or p.representante = lk.representante)), '[]'::jsonb),
    -- todos os pedidos em aberto, sem nada que identifique cliente/representante: só para a conta de capacidade
    'carga', coalesce((select jsonb_agg(jsonb_build_object(
        'd', coalesce(p.data_manual, p.data_salescode, p.data_planilha), 'itens', p.itens, 'lm', p.linha_manual, 'st', p.status_salescode, 'man', p.data_manual is not null, 'col', p.colunas_salescode,
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
