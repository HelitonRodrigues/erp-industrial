-- 039 — Análises externas: anexos, preenchimento por qualquer usuário (fica
--       pendente) e validação SÓ por quem tem a permissão "Assinar"
--       (perfis.html → Laboratório → aba Caulim → ✍️ Assinar).
-- Aditiva: colunas novas + função de permissão + trigger de proteção.

alter table public.caulim_analises_externas add column if not exists anexos jsonb not null default '[]'::jsonb;
alter table public.caulim_analises_externas add column if not exists observacoes text;
alter table public.caulim_analises_externas add column if not exists laboratorio_externo text;
alter table public.caulim_analises_externas add column if not exists preenchido_por text;
alter table public.caulim_analises_externas add column if not exists preenchido_em timestamptz;
alter table public.caulim_analises_externas add column if not exists assinado_por text;
alter table public.caulim_analises_externas add column if not exists assinado_em timestamptz;
alter table public.caulim_analises_externas add column if not exists assinatura_path text;
alter table public.caulim_analises_externas add column if not exists assinatura_hash text;
alter table public.caulim_analises_externas add column if not exists parecer text;
alter table public.caulim_analises_externas add column if not exists devolucao_motivo text;

-- Permissão de uma ação numa aba, lida de perfis.permissoes (a mesma que o
-- perfis.html grava). SADM/ADM podem tudo.
create or replace function public.auth_pode_acao(modulo text, aba text, acao text)
returns boolean language sql stable security definer set search_path to 'public' as $$
  select public.auth_perfil() in ('SADM','ADM')
      or coalesce((select (permissoes -> modulo -> 'abas' -> aba ->> acao) = 'true'
                   from perfis where codigo = public.auth_perfil()), false);
$$;

-- Só quem pode assinar tira a análise de "pendente": vigente, candidata ou
-- devolvida exigem a permissão. Lançar/editar pendente continua livre.
create or replace function public.tg_externa_so_responsavel_assina()
returns trigger language plpgsql security definer set search_path to 'public' as $$
begin
  -- sair de pendente/devolvida (ou nascer já valendo) é validar: exige permissão.
  -- Troca automática entre estados já assinados (vigente → substituído,
  -- candidata → vigente) continua livre.
  if coalesce(new.status,'') <> 'pendente_assinatura'
     and (tg_op = 'INSERT'
          or coalesce(old.status,'') in ('pendente_assinatura','devolvida')
          or old.assinado_em is distinct from new.assinado_em)
     and auth.uid() is not null
     and not public.auth_pode_acao('laboratorio','caulim','assinar') then
    raise exception 'Só o responsável (permissão Assinar em Laboratório → Caulim) valida análise externa.';
  end if;
  return new;
end $$;
drop trigger if exists tg_externa_so_responsavel_assina on public.caulim_analises_externas;
create trigger tg_externa_so_responsavel_assina before insert or update on public.caulim_analises_externas
  for each row execute function public.tg_externa_so_responsavel_assina();

notify pgrst, 'reload schema';
