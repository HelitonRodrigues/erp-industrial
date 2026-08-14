-- 004 — Política "pallets pendentes podem carregar?" sai do localStorage
--
-- Isso é uma decisão de QUALIDADE da fábrica, não uma preferência de tela.
-- Guardada por navegador (localStorage), a regra mudava de tablet para tablet.
-- Passa a viver em app_preferencias (chave/valor central que já existe),
-- com registro de quem mudou e quando dentro do próprio valor.
--
-- O carregamento.html lê esta chave no recarregarTudo() e grava no toggle.
-- O localStorage continua apenas como cache offline (última política conhecida).

insert into public.app_preferencias (chave, dados, atualizado_em)
values (
  'carregamento_liberar_pendentes',
  jsonb_build_object('valor', false, 'por', 'migration 004', 'em', now()),
  now()
)
on conflict (chave) do nothing;
