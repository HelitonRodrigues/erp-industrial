-- 068 — BPF POP-04: integração pelo celular do motorista/visitante (página pública integracao.html)
-- Sem login. O que fica aberto ao público é SÓ: (1) o arquivo do vídeo IT-POP04-03,
-- (2) a logo/nome da empresa e (3) gravar "assisti ao vídeo" (REG-POP04-02).

-- (1) só o vídeo de integração pode ser lido sem login (todas as versões dele)
drop policy if exists bpf_video_integracao_publico on storage.objects;
create policy bpf_video_integracao_publico on storage.objects for select to anon, authenticated
  using (bucket_id = 'documentos' and name like 'bpf/mestre/IT-POP04-03\_%');

-- (2) dados para a página
create or replace function public.bpf_integracao_info()
returns jsonb language sql security definer stable set search_path = public as $$
  select jsonb_build_object(
    'revisao',      (select revisao from bpf_documentos_mestre where codigo = 'IT-POP04-03'),
    'arquivo_path', (select arquivo_path from bpf_documentos_mestre where codigo = 'IT-POP04-03'),
    'empresa',      (select coalesce(razao_social, nome_fantasia) from empresa_config limit 1),
    'logo',         (select logo from empresa_config limit 1));
$$;
revoke all on function public.bpf_integracao_info() from public;
grant execute on function public.bpf_integracao_info() to anon, authenticated;

-- (3) confirmação "vi o vídeo" (autodeclarada) — não duplica mesma pessoa/dia/versão
create or replace function public.bpf_integracao_confirmar(p_nome text, p_cpf text, p_placa text, p_empresa text, p_tipo text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_nome text := upper(regexp_replace(trim(coalesce(p_nome,'')), '\s+', ' ', 'g'));
  v_cpf  text := left(regexp_replace(coalesce(p_cpf,''), '\D', '', 'g'), 11);
  v_pl   text := left(regexp_replace(upper(coalesce(p_placa,'')), '[^A-Z0-9]', '', 'g'), 7);
  v_tipo text := case when p_tipo in ('Motorista','Visitante','Prestador') then p_tipo else 'Motorista' end;
  v_doc  record; v_versao text; v_hoje date; v_hora text; v_num text; v_id uuid;
begin
  if length(v_nome) < 5 or position(' ' in v_nome) = 0 then return jsonb_build_object('erro','Informe o nome completo.'); end if;
  if v_cpf = '' and v_pl = '' then return jsonb_build_object('erro','Informe o CPF ou a placa.'); end if;
  if v_cpf <> '' and length(v_cpf) <> 11 then return jsonb_build_object('erro','CPF incompleto.'); end if;
  select revisao, arquivo_path into v_doc from bpf_documentos_mestre where codigo = 'IT-POP04-03';
  if v_doc.arquivo_path is null then return jsonb_build_object('erro','O vídeo ainda não foi publicado pela empresa.'); end if;
  v_versao := 'rev. ' || coalesce(v_doc.revisao, '—');
  v_hoje := (now() at time zone 'America/Sao_Paulo')::date;
  v_hora := to_char(now() at time zone 'America/Sao_Paulo', 'HH24:MI');
  select numero into v_num from bpf_registros
   where formulario_cod = 'REG-POP04-02' and data = v_hoje and origem_modulo = 'celular'
     and campos->>'video_versao' = v_versao
     and ((v_cpf <> '' and campos->>'documento' = v_cpf) or (v_cpf = '' and campos->>'placa' = v_pl))
   limit 1;
  if v_num is not null then return jsonb_build_object('ok',true,'numero',v_num,'revisao',v_doc.revisao,'repetido',true); end if;
  insert into bpf_registros (formulario_cod,pop_cod,data,hora,campos,status,conforme,anexos,assinaturas,assinaturas_papel,
      origem_modulo,preenchido_por,lancado_por,lancado_em,concluido_em,foto_ficha,criado_por)
  values ('REG-POP04-02','POP-04',v_hoje,v_hora::time,
      jsonb_build_object('nome',v_nome,'documento',v_cpf,'empresa',left(coalesce(p_empresa,''),80),'tipo',v_tipo,'placa',v_pl,
                         'video_assistido','sim','video_versao',v_versao),
      'concluido',true,'[]','[]','{}','celular',v_nome,'Celular (autodeclarado)',now(),now(),
      jsonb_build_object('digital',true,'nome','Confirmado pelo próprio '||lower(v_tipo)||' no celular','em',now(),'por',v_nome),
      'Celular (integração BPF)')
  returning id, numero into v_id, v_num;
  insert into bpf_registro_trilha (registro_id, numero, acao, motivo, autor)
  values (v_id, v_num, 'lançado', 'Integração confirmada no celular (vídeo '||v_versao||')', v_nome);
  return jsonb_build_object('ok',true,'numero',v_num,'revisao',v_doc.revisao);
end $$;
revoke all on function public.bpf_integracao_confirmar(text,text,text,text,text) from public;
grant execute on function public.bpf_integracao_confirmar(text,text,text,text,text) to anon, authenticated;
