-- 070 — BPF: configuração por POP (quem participa por NOME, gatilhos e travas configuráveis)
-- Designação passa a ligar o USUÁRIO do ERP ao POP, com os papéis dele naquele POP.
alter table public.bpf_designacoes
  add column if not exists usuario_id uuid,
  add column if not exists papeis text[] not null default '{}';   -- responsavel | ve | lanca | assina | aviso | libera
-- Trava configurável: modo (bloquear/avisar), onde age e quem libera exceção
alter table public.bpf_travas add column if not exists config jsonb not null default '{}'::jsonb;
-- Configuração geral do POP (canais de aviso etc.)
create table if not exists public.bpf_pop_config (
  pop_cod text primary key, config jsonb not null default '{}'::jsonb,
  atualizado_em timestamptz not null default now(), atualizado_por text);
alter table public.bpf_pop_config enable row level security;
drop policy if exists baseline_authenticated_all on public.bpf_pop_config;
create policy baseline_authenticated_all on public.bpf_pop_config for all to authenticated using (true) with check (true);
-- Fornecedor do Compras marcado como BPF (embalagem / matéria-prima)
alter table public.almoxarifado_fornecedores add column if not exists bpf_categoria text;

-- POP-01: padrões pedidos
update public.bpf_travas set config='{"modo":"bloquear","onde":["pedido","recebimento","checklist"],"liberadores":[]}'::jsonb
 where codigo='fornecedor_nao_homologado' and config='{}'::jsonb;
update public.bpf_gatilhos set filtro = coalesce(filtro,'{}'::jsonb) || '{"itens":["ALM-0456","ALM-0476","ALM-0448"]}'::jsonb
 where codigo='g_emb_insumo';
update public.bpf_gatilhos set ativo=false, evento='NÃO USADO — as embalagens ficam no catálogo de Insumos (ligar duplicaria as fichas)'
 where codigo='g_emb_almox';
update public.bpf_gatilhos set ativo=true, fonte_tabela='almoxarifado_fornecedores',
  filtro = coalesce(filtro,'{}'::jsonb) || '{"meses":12,"avisar_dias":30,"desde":"2026-10-26"}'::jsonb,
  evento='Fornecedor BPF sem homologação ou com reavaliação vencendo'
 where codigo='g_forn';
update public.almoxarifado_fornecedores set bpf_categoria='embalagem'
 where bpf_categoria is null and (nome_fantasia ilike '%logpel%' or razao_social ilike '%logpel%');
