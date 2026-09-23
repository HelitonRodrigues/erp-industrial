-- 040 — (a) lab_laudos ganha atualizado_em, que o laudo da OP sempre gravou
--       e não existia (o laudo da OP não salvava); responsavel deixa de ser
--       obrigatório no RASCUNHO (o finalizado continua exigindo na tela).
--       (b) análise externa JÁ ASSINADA fica travada: sem a permissão Assinar,
--       só as trocas automáticas de validade (vigente→substituído,
--       candidata aprovada→vigente) passam.
alter table public.lab_laudos add column if not exists atualizado_em timestamptz default now();
alter table public.lab_laudos alter column responsavel drop not null;

create or replace function public.tg_externa_so_responsavel_assina()
returns trigger language plpgsql security definer set search_path to 'public' as $$
declare pode boolean := auth.uid() is null or public.auth_pode_acao('laboratorio','caulim','assinar');
begin
  if pode then return new; end if;
  -- sair de pendente/devolvida (ou nascer já valendo) é validar
  if coalesce(new.status,'') <> 'pendente_assinatura'
     and (tg_op = 'INSERT' or coalesce(old.status,'') in ('pendente_assinatura','devolvida')) then
    raise exception 'Só o responsável (permissão Assinar em Laboratório → Caulim) valida análise externa.';
  end if;
  -- já assinada: nada muda, exceto a virada automática de validade
  if tg_op = 'UPDATE' and old.assinado_em is not null then
    if (to_jsonb(new) - 'status') is distinct from (to_jsonb(old) - 'status')
       or not ((old.status = 'vigente' and new.status in ('vigente','substituido'))
            or (old.status = 'candidato_aprovado' and new.status in ('candidato_aprovado','vigente'))
            or old.status = new.status) then
      raise exception 'Análise externa assinada não pode ser alterada (só o responsável).';
    end if;
  end if;
  return new;
end $$;

notify pgrst, 'reload schema';
