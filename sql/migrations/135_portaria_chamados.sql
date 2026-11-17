-- (16/11/2026) 📣 Chamado do pátio: encarregado/operador chama o caminhão da fila; a portaria vê (som) e confirma "vou chamar"
create table if not exists public.portaria_chamados (
  id uuid primary key default gen_random_uuid(),
  portaria_id uuid,
  placa text,
  motorista text,
  ordem_numero text,
  chamado_por text,
  chamado_em timestamptz not null default now(),
  visto_por text,
  visto_em timestamptz,
  cancelado_em timestamptz
);
create index if not exists portaria_chamados_em_idx on public.portaria_chamados (chamado_em desc);
alter table public.portaria_chamados enable row level security;
drop policy if exists baseline_authenticated_all on public.portaria_chamados;
create policy baseline_authenticated_all on public.portaria_chamados for all to authenticated using (true) with check (true);
