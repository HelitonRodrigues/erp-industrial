-- 083 — Portaria: controle de visitantes (aba própria, separada do carregamento) — POP-04, 6.f
create table if not exists public.portaria_visitantes (
  id uuid primary key default gen_random_uuid(),
  entrada timestamptz not null default now(), saida timestamptz,
  nome text not null, documento text, empresa text, tipo text not null default 'Visitante', telefone text,
  motivo text, areas text, acompanhante text, cracha text,
  integrado boolean not null default false, video_versao text, paramentacao boolean not null default false,
  obs text, registrado_por text, saida_por text, created_at timestamptz not null default now());
create index if not exists portaria_visitantes_entrada on public.portaria_visitantes (entrada desc);
alter table public.portaria_visitantes enable row level security;
drop policy if exists baseline_authenticated_all on public.portaria_visitantes;
create policy baseline_authenticated_all on public.portaria_visitantes for all to authenticated using (true) with check (true);
-- cada entrada vira REG-POP04-02 no BPF pelo gatilho g_visita (bpf.html)
