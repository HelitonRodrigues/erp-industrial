-- 037 — Laboratório: pallets por análise dentro de Limites por Produto +
--       pedidos de correção da Análise de Pallets (aba Correções).
-- Aditiva: só cria coluna/tabela nova.

-- Quantos pallets podem ser aprovados/reprovados de uma vez para o produto.
-- Substitui a tela "Regras de Intervalo de Aprovação em Lote" (lab_config_lote_pallets,
-- que fica no banco sem uso, sem nenhuma regra cadastrada).
alter table public.lab_produto_qualidade add column if not exists max_pallets_analise integer;
comment on column public.lab_produto_qualidade.max_pallets_analise is
  'Máximo de pallets por aprovação/reprovação em lote na Análise de Pallets. Nulo = sem limite.';

create table if not exists public.lab_pallet_correcoes (
  id uuid primary key default gen_random_uuid(),
  lancamento_id uuid,
  op_numero text,
  produto text,
  linha text,
  turno text,
  data_producao date,
  pallets_ids jsonb not null default '[]'::jsonb,
  pallets_numeros jsonb not null default '[]'::jsonb,
  itens jsonb not null default '[]'::jsonb,          -- o que está errado / precisa editar
  observacao text,                                   -- o que o solicitante pede
  solicitante text,
  solicitado_em timestamptz not null default now(),
  status text not null default 'pendente',           -- pendente | concluida | recusada
  responsavel text,                                  -- quem atendeu
  data date,
  hora time,
  descricao_correcao text,
  assinatura_path text,                              -- PNG no bucket lab-fotos
  assinatura_hash text,
  concluida_em timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists ix_lab_pallet_corr_status on public.lab_pallet_correcoes(status, solicitado_em desc);
create index if not exists ix_lab_pallet_corr_lanc on public.lab_pallet_correcoes(lancamento_id);

alter table public.lab_pallet_correcoes enable row level security;
drop policy if exists baseline_authenticated_all on public.lab_pallet_correcoes;
create policy baseline_authenticated_all on public.lab_pallet_correcoes
  for all to authenticated using (true) with check (true);

notify pgrst, 'reload schema';
