-- 033 — Lote de matéria-prima do caulim: frentes em texto, cor do espectro (RGB)
--       e fotos da amostra.
--
-- Por quê:
--  * A frente deixou de ser um cadastro fechado. Na prática a lavra muda de
--    frente sem passar por cadastro nenhum, e o lote chegava sem onde registrar.
--    Agora o campo é texto (frente_nome) e frente_id só é preenchido quando o
--    texto casa com uma frente já cadastrada — os relatórios antigos que leem
--    pelo id continuam funcionando.
--  * Um lote pode nascer da mistura de mais de uma frente. `frentes` guarda a
--    lista inteira (nome, mistura %, montante t); a tela só salva quando a soma
--    das misturas fecha 100%.
--  * O espectrofotômetro da fábrica entrega RGB, não L*a*b*. Guardamos o RGB
--    medido e a tela converte para CIELAB, que é onde o ΔE faz sentido.
--  * Fotos da amostra ficam no bucket lab-fotos; a coluna guarda só o caminho.
--
-- Já aplicada no projeto zodgbitbflkepbszshmu. Este arquivo é o registro.

alter table public.caulim_lotes_mp alter column frente_id drop not null;

alter table public.caulim_lotes_mp
  add column if not exists frente_nome text,
  add column if not exists frentes     jsonb not null default '[]'::jsonb,
  add column if not exists cor_r       numeric,
  add column if not exists cor_g       numeric,
  add column if not exists cor_b_rgb   numeric,
  add column if not exists fotos       jsonb not null default '[]'::jsonb;

comment on column public.caulim_lotes_mp.frente_nome is
  'Frente principal em texto livre. frente_id fica nulo quando não há cadastro correspondente.';
comment on column public.caulim_lotes_mp.frentes is
  'Lista das frentes do lote: [{ordem, nome, mistura_pct, montante_t}]. Com duas ou mais, mistura_pct soma 100.';
comment on column public.caulim_lotes_mp.cor_b_rgb is
  'B do RGB do espectro — não confundir com cor_b, que é o b* do CIELAB.';
comment on column public.caulim_lotes_mp.fotos is
  'Fotos da amostra: [{nome, path, mime, tamanho, enviado_em}] — path dentro do bucket lab-fotos.';

-- bucket das fotos do laboratório (privado; a tela abre por URL assinada)
insert into storage.buckets (id, name, public)
values ('lab-fotos','lab-fotos',false)
on conflict (id) do nothing;

-- O front usa a chave anon; sem estas políticas o upload volta "new row
-- violates row-level security policy" e a foto some sem erro visível.
drop policy if exists lab_fotos_anon_select on storage.objects;
drop policy if exists lab_fotos_anon_insert on storage.objects;
drop policy if exists lab_fotos_anon_delete on storage.objects;

create policy lab_fotos_anon_select on storage.objects
  for select to anon, authenticated using (bucket_id = 'lab-fotos');
create policy lab_fotos_anon_insert on storage.objects
  for insert to anon, authenticated with check (bucket_id = 'lab-fotos');
create policy lab_fotos_anon_delete on storage.objects
  for delete to anon, authenticated using (bucket_id = 'lab-fotos');
