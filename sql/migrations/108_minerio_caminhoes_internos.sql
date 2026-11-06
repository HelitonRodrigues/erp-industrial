-- 108 · Minério: caminhões internos com tara fixa (nov/2026)
-- Placa cadastrada: na entrada o porteiro pesa só o BRUTO (balança), a tara vem daqui e a viagem fecha na hora.
create table if not exists public.minerio_caminhoes_internos(
  placa text primary key,
  tara_kg numeric not null check (tara_kg > 0),
  motorista text,
  ativo boolean not null default true,
  atualizado_em timestamptz not null default now(),
  atualizado_por text
);
alter table public.minerio_caminhoes_internos enable row level security;
drop policy if exists baseline_authenticated_all on public.minerio_caminhoes_internos;
create policy baseline_authenticated_all on public.minerio_caminhoes_internos for all to authenticated using (true) with check (true);

insert into public.minerio_caminhoes_internos (placa, tara_kg, atualizado_por) values
 ('FRM5821',12700,'Heliton'),('FPE4788',12640,'Heliton'),('ETJ7231',11340,'Heliton'),('ETJ7483',11700,'Heliton')
on conflict (placa) do update set tara_kg = excluded.tara_kg, ativo = true, atualizado_em = now();

-- Viagens de 06/11/2026 (caminhões internos, Caulim · Fábrica · frente BRANCO 2) — fecham com ticket
insert into public.minerio_viagens (data, material, placa, motorista, unidade, frente, tara_kg, bruto_kg, status, chegou_carregado, origem, criado_por, bruto_por)
select v.* from (values
  ('2026-11-06'::date,'CAULIM','FPE4788','REINALDO','FABRICA','BRANCO 2',12640::numeric,37150::numeric,'pesado',true,'portaria','Heliton José de Almeida Rodrigues','Heliton José de Almeida Rodrigues'),
  ('2026-11-06'::date,'CAULIM','ETJ7483','JOSUÉ',   'FABRICA','BRANCO 2',11700,32920,'pesado',true,'portaria','Heliton José de Almeida Rodrigues','Heliton José de Almeida Rodrigues'),
  ('2026-11-06'::date,'CAULIM','FPE4788','REINALDO','FABRICA','BRANCO 2',12640,38120,'pesado',true,'portaria','Heliton José de Almeida Rodrigues','Heliton José de Almeida Rodrigues'),
  ('2026-11-06'::date,'CAULIM','ETJ7483','JOSUÉ',   'FABRICA','BRANCO 2',11700,31520,'pesado',true,'portaria','Heliton José de Almeida Rodrigues','Heliton José de Almeida Rodrigues')
) v(data,material,placa,motorista,unidade,frente,tara_kg,bruto_kg,status,chegou_carregado,origem,criado_por,bruto_por)
where not exists (select 1 from public.minerio_viagens m where m.data = v.data and m.placa = v.placa and m.bruto_kg = v.bruto_kg);

select ticket, placa, motorista, tara_kg, bruto_kg, liquido_kg from public.minerio_viagens where data = '2026-11-06' and unidade = 'FABRICA' order by ticket;
