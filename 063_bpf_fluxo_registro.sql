-- 063 — BPF: fluxo do registro em papel → ERP
-- gerado → ficha impressa → preenchido no papel → digitado no ERP → foto da ficha → assinaturas → concluído
alter table public.bpf_registros
  add column if not exists preenchido_por     text,         -- quem preencheu a ficha no papel
  add column if not exists lancado_por        text,         -- quem digitou no ERP
  add column if not exists lancado_em         timestamptz,
  add column if not exists ficha_impressa_em  timestamptz,
  add column if not exists foto_ficha         jsonb,        -- {nome,path,tipo,tamanho,em,por}
  add column if not exists assinaturas_papel  jsonb not null default '{}'::jsonb;  -- {id_assinatura: "nome que assinou no papel"}

-- Registro gerado e ainda não digitado pode ser excluído (como o rascunho).
create or replace function public.bpf_bloqueia_delete()
returns trigger language plpgsql set search_path to 'public' as $function$
begin
  if old.status in ('rascunho','a_preencher','a_digitar')
     and coalesce(jsonb_array_length(old.assinaturas), 0) = 0
     and old.concluido_em is null
     and old.lancado_em is null then
    return old;
  end if;
  raise exception 'SYS-003: % já é registro do SGQ e não pode ser excluído (retenção de % anos). Use o cancelamento com motivo.',
    coalesce(old.numero, 'o registro'),
    coalesce((select retencao_anos from bpf_formularios where codigo = old.formulario_cod), 4);
end $function$;
