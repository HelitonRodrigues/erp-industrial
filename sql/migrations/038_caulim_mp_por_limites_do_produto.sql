-- 038 — Lote de MP do caulim passa a buscar tudo de Limites por Produto.
-- Aditiva: só colunas novas + variacao_declarada_id deixa de ser obrigatória.

-- Limites por Produto: cor (STD), vínculo com a variação de cor e caracterização.
alter table public.lab_produto_qualidade add column if not exists variacao_id uuid references public.caulim_variacoes(id) on delete set null;
alter table public.lab_produto_qualidade add column if not exists std_l numeric;
alter table public.lab_produto_qualidade add column if not exists std_a numeric;
alter table public.lab_produto_qualidade add column if not exists std_b numeric;
alter table public.lab_produto_qualidade add column if not exists delta_e_max numeric;
alter table public.lab_produto_qualidade add column if not exists dureza_min numeric;
alter table public.lab_produto_qualidade add column if not exists dureza_max numeric;
alter table public.lab_produto_qualidade add column if not exists retido200_min numeric;
alter table public.lab_produto_qualidade add column if not exists retido200_max numeric;
comment on column public.lab_produto_qualidade.variacao_id is
  'Variação de cor (caulim_variacoes) ligada ao produto — sigla do nº do lote, homologações e análises externas.';

-- Lote de MP: produto (variação declarada) + caracterização nova + foto dos limites usados.
alter table public.caulim_lotes_mp add column if not exists produto_id uuid references public.produtos(id) on delete set null;
alter table public.caulim_lotes_mp add column if not exists dureza numeric;
alter table public.caulim_lotes_mp add column if not exists retido_200 numeric;
alter table public.caulim_lotes_mp add column if not exists especificacao jsonb;
alter table public.caulim_lotes_mp alter column variacao_declarada_id drop not null;
comment on column public.caulim_lotes_mp.especificacao is
  'Limites de Limites por Produto no momento do lote (STD, ΔE máx., umidade, dureza, retido #200) e o resultado de cada um.';

notify pgrst, 'reload schema';
