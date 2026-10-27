-- 071 — Central da Qualidade: avisos por pessoa, ficha na hora e aviso de atraso
-- (1) aviso com destinatário (nome do usuário, igual ao das designações do BPF)
alter table public.notificacoes add column if not exists destinatarios text[] not null default '{}';
create index if not exists notificacoes_dest_idx on public.notificacoes using gin (destinatarios);

-- (2) módulo novo "qualidade" liberado para quem já abre BPF ou Laboratório
update public.perfis set permissoes = coalesce(permissoes,'{}'::jsonb) ||
  jsonb_build_object('qualidade', jsonb_build_object('view',true,'create',true,'edit',true,'delete',false,'export',true))
 where coalesce((permissoes->'bpf'->>'view')::boolean,false) or coalesce((permissoes->'laboratorio'->>'view')::boolean,false);

-- quem do POP deve ser avisado (pelos papéis marcados em ⚙️ Configurar)
create or replace function public.bpf_pessoas_pop(p_pop text, p_papeis text[])
returns text[] language sql stable security definer set search_path=public as $$
  select coalesce(array_agg(distinct funcionario_nome),'{}') from bpf_designacoes
   where ativo and pop_cod=p_pop and papeis && p_papeis and funcionario_nome is not null;
$$;

-- (3) POP-01: a ficha do recebimento de embalagem nasce NA HORA da entrada no Insumos
create or replace function public.bpf_trg_emb_recebimento()
returns trigger language plpgsql security definer set search_path=public as $$
declare g record; i record; v_tar uuid; v_reg uuid; v_nf text; v_forn text; v_pre jsonb;
begin
  if new.tipo <> 'entrada' then return new; end if;
  select * into g from bpf_gatilhos where codigo='g_emb_insumo' and ativo;
  if not found then return new; end if;
  select codigo, nome, unidade_estoque into i from insumos where id = new.insumo_id;
  if i.codigo is null or not (coalesce(g.filtro->'itens','[]'::jsonb) ? i.codigo) then return new; end if;
  v_nf := substring(coalesce(new.obs,'') from 'NF\s*([A-Za-z0-9.\-/]+)');
  if new.origem='RECEB_SOL' and new.origem_id is not null then
    select fornecedor into v_forn from compras_pedidos where id::text = new.origem_id;
  end if;
  v_forn := coalesce(nullif(new.fornecedor_destino,''), v_forn, '');
  v_pre := jsonb_build_object('embalagem', i.nome||' ('||i.codigo||')', 'quantidade', new.quantidade,
             'fornecedor', v_forn, 'nota_fiscal', coalesce(v_nf,''),
             'lote', 'EMB-'||to_char(coalesce(new.data,current_date),'YYMMDD')||'-'||upper(left(new.id::text,4)));
  insert into bpf_tarefas (gatilho_cod, formulario_cod, pop_cod, origem_tabela, origem_id, origem_ref, origem_det, pre, prazo, status)
  values ('g_emb_insumo', g.formulario_cod, g.pop_cod, 'insumos_movimentos', new.id::text, 'INS/'||new.id,
          'Entrada de '||coalesce(new.quantidade::text,'?')||' '||coalesce(i.unidade_estoque,'')||' de '||i.nome||' ('||i.codigo||')'
            ||case when v_forn<>'' then ' — '||v_forn else '' end,
          v_pre, now() + make_interval(hours => coalesce(g.prazo_horas,24)), 'aberta')
  on conflict (gatilho_cod, origem_ref) do nothing
  returning id into v_tar;
  if v_tar is null then return new; end if;
  insert into bpf_registros (formulario_cod, pop_cod, data, campos, status, conforme, anexos, assinaturas, assinaturas_papel,
                             origem_modulo, origem_id, tarefa_id, criado_por)
  values (g.formulario_cod, g.pop_cod, coalesce(new.data,current_date), v_pre, 'a_preencher', true, '[]', '[]', '{}',
          'insumos_movimentos', new.id::text, v_tar, 'Gatilho g_emb_insumo (na hora)')
  returning id into v_reg;
  update bpf_tarefas set registro_id = v_reg where id = v_tar;
  insert into notificacoes (tipo, modulo, titulo, descricao, chave, fonte, destinatarios)
  values ('aviso', 'bpf', 'BPF '||g.pop_cod||': conferir recebimento de embalagem',
          i.nome||' · '||coalesce(new.quantidade::text,'')||' '||coalesce(i.unidade_estoque,'')
            ||case when v_forn<>'' then ' · '||v_forn else '' end||case when v_nf is not null then ' · NF '||v_nf else '' end,
          'bpf_ficha_'||v_reg, 'bpf', bpf_pessoas_pop(g.pop_cod, array['lanca','responsavel','aviso']));
  return new;
exception when others then
  return new;   -- o BPF nunca trava a entrada de estoque
end $$;
drop trigger if exists bpf_emb_recebimento on public.insumos_movimentos;
create trigger bpf_emb_recebimento after insert on public.insumos_movimentos
  for each row execute function public.bpf_trg_emb_recebimento();

-- (4) ficha atrasada → aviso para quem lança e para o responsável; parada há +24 h do prazo → também quem recebe aviso
create or replace function public.bpf_notificar_atrasos()
returns integer language plpgsql security definer set search_path=public as $$
declare t record; n integer := 0;
begin
  for t in select * from bpf_tarefas where status='aberta' and prazo < now() and criado_em >= '2026-10-26' limit 200 loop
    if not exists (select 1 from notificacoes where chave = 'bpf_atraso_'||t.id) then
      insert into notificacoes (tipo, modulo, titulo, descricao, chave, fonte, destinatarios)
      values ('urgente','bpf','BPF '||t.pop_cod||': ficha ATRASADA', coalesce(t.origem_det,t.formulario_cod)||' · prazo era '||to_char(t.prazo at time zone 'America/Sao_Paulo','DD/MM HH24:MI'),
              'bpf_atraso_'||t.id,'bpf', bpf_pessoas_pop(t.pop_cod, array['lanca','responsavel']));
      n := n + 1;
    elsif t.prazo < now() - interval '24 hours' and not exists (select 1 from notificacoes where chave = 'bpf_atraso2_'||t.id) then
      insert into notificacoes (tipo, modulo, titulo, descricao, chave, fonte, destinatarios)
      values ('urgente','bpf','BPF '||t.pop_cod||': ficha parada há mais de 24 h do prazo', coalesce(t.origem_det,t.formulario_cod),
              'bpf_atraso2_'||t.id,'bpf', bpf_pessoas_pop(t.pop_cod, array['aviso','responsavel']));
      n := n + 1;
    end if;
  end loop;
  return n;
end $$;
grant execute on function public.bpf_notificar_atrasos() to authenticated;
grant execute on function public.bpf_pessoas_pop(text,text[]) to authenticated;
