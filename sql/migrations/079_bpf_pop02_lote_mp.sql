-- 079 — BPF POP-02: o REG-POP02-01 nasce e se atualiza sozinho a partir do Lote de MP (Laboratório → Caulim → Lotes de MP)
-- Padrão para os próximos POPs: o registro BPF puxa o que o módulo de origem já tem.
update public.bpf_formularios set sem_papel=true where codigo='REG-POP02-01';   -- lançado no Laboratório, sem ficha em papel

create or replace function public.bpf_reg_pop02(p_lote uuid)
returns uuid language plpgsql security definer set search_path=public as $$
declare l record; v_reg uuid; v_st text; v_quim boolean; v_sig text; v_c jsonb; v_ops jsonb;
begin
  select * into l from caulim_lotes_mp where id=p_lote;
  if l.id is null then return null; end if;
  select coalesce(c->'opcoes','[]'::jsonb) into v_ops from bpf_formularios f, jsonb_array_elements(f.campos) c
   where f.codigo='REG-POP02-01' and c->>'id'='variacao_declarada';
  v_sig := l.especificacao->>'sigla';
  -- análise química externa da variação, assinada e dentro da validade na data do lote (POP-17)
  select exists(select 1 from caulim_analises_externas e where e.tipo='quimica' and e.variacao_principal_id=l.variacao_declarada_id
      and coalesce(e.status,'') not in ('pendente_assinatura','devolvida') and (e.validade is null or e.validade>=l.data)) into v_quim;
  v_c := jsonb_strip_nulls(jsonb_build_object(
    'lote_mp', l.numero,
    'mina_frente', coalesce((select string_agg(x->>'nome'||case when (x->>'mistura_pct') is not null and jsonb_array_length(l.frentes)>1 then ' ('||(x->>'mistura_pct')||'%)' else '' end,' + ' order by (x->>'ordem')::int)
                             from jsonb_array_elements(coalesce(l.frentes,'[]'::jsonb)) x), l.frente_nome),
    'mistura_pct', l.mistura_pct,
    'montante_t', l.montante_t,
    'variacao_declarada', case when v_ops ? v_sig then v_sig end,
    'delta_e', round(l.delta_e::numeric,2),
    'granulometria_ok', case when l.retido_200 is not null then 'sim' else 'nao' end,
    'umidade', l.umidade_pct,
    'quimica_vigente', case when v_quim then 'sim' else 'nao' end,
    'decisao', case when l.cor_aprovada is true and v_quim then 'Liberado' when l.cor_aprovada is false then 'Reprovado' end,
    'obs', case when l.delta_e is null then 'Cor não medida no laboratório (ΔE em branco).' end));
  select id, status into v_reg, v_st from bpf_registros where formulario_cod='REG-POP02-01' and origem_id=l.id::text and cancelado_em is null limit 1;
  if v_reg is null then
    insert into bpf_registros (formulario_cod,pop_cod,data,hora,campos,status,conforme,anexos,assinaturas,assinaturas_papel,
                               origem_modulo,origem_id,preenchido_por,lancado_por,lancado_em,foto_ficha,criado_por)
    values ('REG-POP02-01','POP-02',coalesce(l.data,current_date),(coalesce(l.criado_em,now()) at time zone 'America/Sao_Paulo')::time,
            v_c,'aguardando_assinatura',(l.cor_aprovada is not false and v_quim),'[]','[]','{}',
            'laboratorio',l.id::text,l.analista_mp,'Laboratório',now(),
            jsonb_build_object('digital',true,'nome','Lançado no Laboratório (sem ficha em papel)','em',now(),'por',coalesce(l.analista_mp,'Laboratório')),
            'Laboratório — Lote de MP '||coalesce(l.numero,''))
    returning id into v_reg;
  elsif v_st not in ('concluido','cancelado') then
    update bpf_registros set campos = campos || v_c, data=coalesce(l.data,data), conforme=(l.cor_aprovada is not false and v_quim),
           preenchido_por=coalesce(l.analista_mp,preenchido_por), atualizado_em=now()
     where id=v_reg;
  end if;
  return v_reg;
end $$;

create or replace function public.bpf_trg_lote_mp() returns trigger language plpgsql security definer set search_path=public as $$
begin perform bpf_reg_pop02(new.id); return new;
exception when others then return new;   -- o BPF nunca trava o Laboratório
end $$;
drop trigger if exists bpf_lote_mp on public.caulim_lotes_mp;
create trigger bpf_lote_mp after insert or update on public.caulim_lotes_mp for each row execute function public.bpf_trg_lote_mp();

-- a química vigente muda quando uma análise externa é assinada/vence: reavalia os registros abertos
create or replace function public.bpf_trg_ext_pop02() returns trigger language plpgsql security definer set search_path=public as $$
begin
  perform bpf_reg_pop02(l.id) from caulim_lotes_mp l where l.variacao_declarada_id=new.variacao_principal_id;
  return new;
exception when others then return new;
end $$;
drop trigger if exists bpf_ext_pop02 on public.caulim_analises_externas;
create trigger bpf_ext_pop02 after insert or update on public.caulim_analises_externas for each row execute function public.bpf_trg_ext_pop02();

-- lotes de MP que já existiam
select public.bpf_reg_pop02(id) from public.caulim_lotes_mp;
