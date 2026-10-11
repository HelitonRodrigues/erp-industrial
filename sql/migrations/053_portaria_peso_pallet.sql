-- 053 — Pesagem de saída: desconta o peso dos pallets do líquido
-- Líquido da balança (bruto − tara) inclui a madeira dos pallets de sacaria.
-- Peso padrão do pallet fica em empresa_config.peso_pallet_kg (28 kg), editável na saída.
-- portaria grava: qtd_pallets, peso_pallet_kg, peso_produto (t, líquido − pallets),
-- peso_esperado (t, sacos × peso do produto + granel) para comparar com a balança.
alter table public.portaria add column if not exists qtd_pallets    integer;
alter table public.portaria add column if not exists peso_pallet_kg numeric;
alter table public.portaria add column if not exists peso_produto   numeric;
alter table public.portaria add column if not exists peso_esperado  numeric;
alter table public.empresa_config add column if not exists peso_pallet_kg numeric default 28;
update public.empresa_config set peso_pallet_kg = 28 where peso_pallet_kg is null;
