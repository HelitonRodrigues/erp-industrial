-- 002 — producao_pallets.status: aceitar 'aguardando_decisao'
--
-- O código (carregamento.html, laboratorio.html) trabalha com 4 estados de
-- qualidade do pallet: pendente | aprovado | reprovado | aguardando_decisao.
-- O CHECK antigo só conhecia 3 — qualquer gravação de 'aguardando_decisao'
-- estourava erro 23514 no update do laboratório.
--
-- Verificado antes de escrever: os 452 pallets atuais são todos 'pendente',
-- então a troca do constraint não falha em dado existente.

alter table public.producao_pallets
  drop constraint if exists producao_pallets_status_check;

alter table public.producao_pallets
  add constraint producao_pallets_status_check
  check (status = any (array[
    'pendente'::text,
    'aprovado'::text,
    'reprovado'::text,
    'aguardando_decisao'::text
  ]));
