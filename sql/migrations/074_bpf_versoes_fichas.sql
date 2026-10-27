-- 074 — BPF: versões dos registros (fichas) e conteúdo das instruções
-- Cada mudança nos campos de uma ficha vira uma revisão "aguardando aprovação"; aprovada, passa a valer,
-- gera o PDF novo e a anterior vai para o histórico. Cada registro lançado guarda a revisão em que foi feito.
alter table public.bpf_documentos_mestre add column if not exists conteudo jsonb;   -- texto das ITs (vem dos POPs)
create table if not exists public.bpf_formulario_versoes (
  id uuid primary key default gen_random_uuid(),
  formulario_cod text not null,
  revisao text not null,
  titulo text, periodicidade text,
  campos jsonb not null default '[]'::jsonb,
  assinaturas jsonb not null default '[]'::jsonb,
  status text not null default 'aguardando',          -- aguardando | vigente | obsoleta | descartada
  alteracoes text,
  criado_por text, criado_em timestamptz not null default now(),
  aprovado_por text, aprovado_em timestamptz,
  unique (formulario_cod, revisao));
alter table public.bpf_formulario_versoes enable row level security;
drop policy if exists baseline_authenticated_all on public.bpf_formulario_versoes;
create policy baseline_authenticated_all on public.bpf_formulario_versoes for all to authenticated using (true) with check (true);
alter table public.bpf_registros add column if not exists form_revisao text;

-- a revisão atual de cada ficha vira a versão "vigente" de partida
insert into public.bpf_formulario_versoes (formulario_cod, revisao, titulo, periodicidade, campos, assinaturas, status, alteracoes, criado_por, aprovado_em)
select f.codigo, coalesce(m.revisao,'00'), f.titulo, f.periodicidade, coalesce(f.campos,'[]'), coalesce(f.assinaturas,'[]'), 'vigente',
       'Versão de partida (campos vigentes no sistema)', 'Sistema', now()
  from public.bpf_formularios f left join public.bpf_documentos_mestre m on m.codigo=f.codigo
 where not exists (select 1 from public.bpf_formulario_versoes v where v.formulario_cod=f.codigo);

-- todo registro novo guarda a revisão da ficha em que foi feito
create or replace function public.bpf_reg_form_revisao() returns trigger language plpgsql set search_path=public as $$
begin
  if new.form_revisao is null then
    select revisao into new.form_revisao from bpf_formulario_versoes where formulario_cod=new.formulario_cod and status='vigente' order by criado_em desc limit 1;
  end if;
  return new;
end $$;
drop trigger if exists bpf_reg_form_revisao on public.bpf_registros;
create trigger bpf_reg_form_revisao before insert on public.bpf_registros for each row execute function public.bpf_reg_form_revisao();
update public.bpf_registros r set form_revisao = v.revisao
  from public.bpf_formulario_versoes v where v.formulario_cod=r.formulario_cod and v.status='vigente' and r.form_revisao is null;
