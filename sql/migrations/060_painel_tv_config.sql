-- 060 — Painel de Metas: escolher o DIA e as LINHAS que aparecem (vale para todas as TVs).
alter table public.painel_tv add column if not exists config jsonb not null default '{}'::jsonb;

-- Lê a configuração do painel (dia escolhido e linhas). Logado: direto. TV: precisa do código.
create or replace function public.painel_tv_config_ler(p_codigo text default null)
returns jsonb language plpgsql security definer stable set search_path = public as $$
declare v jsonb;
begin
  if auth.uid() is null and (p_codigo is null or not exists (select 1 from public.painel_tv where id = 1 and codigo = upper(trim(p_codigo)))) then
    raise exception 'código da TV inválido' using errcode = '28000';
  end if;
  select config into v from public.painel_tv where id = 1;
  return coalesce(v, '{}'::jsonb);
end $$;
revoke all on function public.painel_tv_config_ler(text) from public;
grant execute on function public.painel_tv_config_ler(text) to anon, authenticated;

-- Salva (só logado). Formato: {"dia":"AAAA-MM-DD"|null, "dia_ate":"AAAA-MM-DD"|null, "linhas":[...]|null}
create or replace function public.painel_tv_config_salvar(p_config jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'faça login' using errcode = '28000'; end if;
  if not exists (select 1 from public.painel_tv where id = 1) then perform public.painel_tv_codigo(false); end if;
  update public.painel_tv set config = jsonb_build_object(
      'dia', p_config->'dia', 'dia_ate', p_config->'dia_ate', 'linhas', p_config->'linhas',
      'salvo_em', now(), 'salvo_por', auth.uid())
   where id = 1;
  return (select config from public.painel_tv where id = 1);
end $$;
revoke all on function public.painel_tv_config_salvar(jsonb) from public;
grant execute on function public.painel_tv_config_salvar(jsonb) to authenticated;
