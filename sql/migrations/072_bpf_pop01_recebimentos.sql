-- 072 — BPF POP-01: check list do recebimento (REG-POP01-01) completo e automático
-- campo "Código" separado da embalagem
update public.bpf_formularios set campos = (
  select jsonb_agg(x order by ord) from (
    select c x, o::numeric ord from jsonb_array_elements(campos) with ordinality e(c,o)
    union all select jsonb_build_object('id','codigo_item','tipo','texto','label','Código'),
      (select o from jsonb_array_elements(campos) with ordinality e(c,o) where c->>'id'='embalagem')+0.5) z)
 where codigo='REG-POP01-01' and not exists (select 1 from jsonb_array_elements(campos) c where c->>'id'='codigo_item');

-- gera a ficha de UMA entrada de embalagem (usada pelo gatilho na hora e pela carga dos recebimentos antigos)
create or replace function public.bpf_emb_gerar(p_mov uuid, p_avisar boolean default true)
returns uuid language plpgsql security definer set search_path=public as $$
declare m record; g record; i record; v_tar uuid; v_reg uuid; v_nf text; v_forn text; v_ped text; v_hora text; v_pre jsonb;
begin
  select * into m from insumos_movimentos where id=p_mov;
  if m.id is null or m.tipo<>'entrada' then return null; end if;
  select * into g from bpf_gatilhos where codigo='g_emb_insumo' and ativo;
  if not found then return null; end if;
  select codigo, nome, unidade_estoque into i from insumos where id=m.insumo_id;
  if i.codigo is null or not (coalesce(g.filtro->'itens','[]'::jsonb) ? i.codigo) then return null; end if;
  v_nf := substring(coalesce(m.obs,'') from 'NF\s*([A-Za-z0-9.\-/]+)');
  if m.origem='RECEB_SOL' and m.origem_id is not null then
    select fornecedor, lpad(numero::text,4,'0') into v_forn, v_ped from compras_pedidos where id::text=m.origem_id;
  end if;
  v_forn := coalesce(nullif(m.fornecedor_destino,''), v_forn, '');
  v_hora := to_char(coalesce(m.criado_em,now()) at time zone 'America/Sao_Paulo','HH24:MI');
  v_pre := jsonb_build_object('hora',v_hora,'embalagem',i.nome,'codigo_item',i.codigo,'quantidade',m.quantidade,
             'fornecedor',v_forn,'fornecedor_homologado','sim','nota_fiscal',coalesce(v_nf,''),
             'lote','EMB-'||to_char(coalesce(m.data,current_date),'YYMMDD')||'-'||upper(left(m.id::text,4)));
  insert into bpf_tarefas (gatilho_cod, formulario_cod, pop_cod, origem_tabela, origem_id, origem_ref, origem_det, pre, prazo, status, criado_em)
  values ('g_emb_insumo', g.formulario_cod, g.pop_cod, 'insumos_movimentos', m.id::text, 'INS/'||m.id,
          case when v_ped is not null then 'Recebimento do pedido #'||v_ped||' — ' else 'Entrada — ' end
            ||coalesce(m.quantidade::text,'?')||' '||coalesce(i.unidade_estoque,'')||' de '||i.nome
            ||case when v_forn<>'' then ' · '||v_forn else '' end||case when v_nf is not null then ' · NF '||v_nf else '' end,
          v_pre, coalesce(m.criado_em,now()) + make_interval(hours => coalesce(g.prazo_horas,24)), 'aberta', coalesce(m.criado_em,now()))
  on conflict (gatilho_cod, origem_ref) do nothing
  returning id into v_tar;
  if v_tar is null then return null; end if;
  insert into bpf_registros (formulario_cod, pop_cod, data, hora, campos, status, conforme, anexos, assinaturas, assinaturas_papel,
                             origem_modulo, origem_id, tarefa_id, criado_por)
  values (g.formulario_cod, g.pop_cod, coalesce(m.data,current_date), v_hora::time, v_pre, 'a_preencher', true, '[]', '[]', '{}',
          'insumos_movimentos', m.id::text, v_tar, 'Gatilho g_emb_insumo')
  returning id into v_reg;
  update bpf_tarefas set registro_id=v_reg where id=v_tar;
  if p_avisar then
    insert into notificacoes (tipo, modulo, titulo, descricao, chave, fonte, destinatarios)
    values ('aviso','bpf','BPF '||g.pop_cod||': conferir recebimento de embalagem',
            i.nome||' · '||coalesce(m.quantidade::text,'')||' '||coalesce(i.unidade_estoque,'')
              ||case when v_forn<>'' then ' · '||v_forn else '' end||case when v_nf is not null then ' · NF '||v_nf else '' end,
            'bpf_ficha_'||v_reg,'bpf', bpf_pessoas_pop(g.pop_cod, array['lanca','responsavel','aviso']));
  end if;
  return v_reg;
end $$;

create or replace function public.bpf_trg_emb_recebimento()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  perform bpf_emb_gerar(new.id, true);
  return new;
exception when others then return new;   -- o BPF nunca trava a entrada de estoque
end $$;

-- recebimentos já confirmados nas Solicitações (antes do gatilho) → viram registro também
select public.bpf_emb_gerar(m.id, false)
  from insumos_movimentos m join insumos i on i.id=m.insumo_id
 where m.tipo='entrada' and m.origem='RECEB_SOL'
   and i.codigo in (select jsonb_array_elements_text(filtro->'itens') from bpf_gatilhos where codigo='g_emb_insumo');

-- fichas que já existiam: separa código, completa fornecedor, NF, hora e "homologado"
update public.bpf_registros r set
  campos = r.campos
    || jsonb_build_object('embalagem', i.nome, 'codigo_item', i.codigo,
         'fornecedor', coalesce(nullif(r.campos->>'fornecedor',''), nullif(m.fornecedor_destino,''), p.fornecedor, ''),
         'nota_fiscal', coalesce(nullif(r.campos->>'nota_fiscal',''), substring(coalesce(m.obs,'') from 'NF\s*([A-Za-z0-9.\-/]+)'), ''),
         'fornecedor_homologado', coalesce(r.campos->>'fornecedor_homologado','sim'),
         'hora', to_char(m.criado_em at time zone 'America/Sao_Paulo','HH24:MI')),
  hora = coalesce(r.hora, (to_char(m.criado_em at time zone 'America/Sao_Paulo','HH24:MI'))::time)
  from insumos_movimentos m join insumos i on i.id=m.insumo_id
  left join compras_pedidos p on p.id::text = m.origem_id
 where r.formulario_cod='REG-POP01-01' and r.origem_id = m.id::text and r.lancado_em is null;

-- ── correção aplicada em seguida: aproveita tarefa antiga sem ficha, inclui recebimentos de COMPRA,
--    número no formato brasileiro (5.000) e fornecedor/pedido também pelo texto da entrada
create or replace function public._fmt_qtd(q numeric) returns text language sql immutable as $$ select replace(trim(to_char(q,'FM999G999G990')),',','.') $$;
-- (bpf_emb_gerar recriada com: on conflict → reaproveita a tarefa existente sem registro; v_ped/v_forn também lidos de m.obs;
--  v_det usa _fmt_qtd) — ver definição atual no banco: select pg_get_functiondef('public.bpf_emb_gerar(uuid,boolean)'::regprocedure);
select public.bpf_emb_gerar(m.id, false)
  from insumos_movimentos m join insumos i on i.id=m.insumo_id
 where m.tipo='entrada' and m.origem in ('RECEB_SOL','COMPRA')
   and i.codigo in (select jsonb_array_elements_text(filtro->'itens') from bpf_gatilhos where codigo='g_emb_insumo');
