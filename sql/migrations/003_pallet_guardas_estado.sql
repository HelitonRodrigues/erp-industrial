-- 003 — Guardas de estado do pallet (a fundação do estoque que nunca fura)
--
-- Dois problemas que o front-end sozinho não resolve:
--   1. Nada impedia estoque_status de receber qualquer texto, nem de "voltar"
--      de expedido para estoque por um update errado.
--   2. CORRIDA: dois tablets carregando ao mesmo tempo podiam marcar o MESMO
--      pallet como 'carregado' em duas ordens diferentes — cada carga gravava
--      seu snapshot e o estoque saía furado sem ninguém perceber.
--
-- O trigger abaixo é o guarda-costas. Transições permitidas:
--
--        estoque ──► carregado ──► expedido
--                ◄──           (reabrir/editar carga devolve ao estoque)
--
-- Regras extras:
--   • update que NÃO muda estoque_status passa livre (salvar posição no piso,
--     trocar barracão, análise do laboratório etc.);
--   • re-gravar 'carregado' na MESMA ordem passa (edição de carga);
--   • re-gravar 'carregado' com ordem DIFERENTE bloqueia — é a trava da corrida;
--   • expedido não volta para estoque por update direto (se um dia precisar,
--     será por RPC específica com trilha).

alter table public.producao_pallets
  drop constraint if exists producao_pallets_estoque_status_check;

alter table public.producao_pallets
  add constraint producao_pallets_estoque_status_check
  check (estoque_status = any (array['estoque'::text,'carregado'::text,'expedido'::text]));

create or replace function public.pallet_guarda_estado()
returns trigger
language plpgsql
set search_path = public
as $$
declare
  de   text := coalesce(old.estoque_status, 'estoque');
  para text := coalesce(new.estoque_status, 'estoque');
begin
  -- não mudou de estado
  if de = para then
    -- trava da corrida: já está carregado e alguém tenta "carregar de novo"
    -- em outra ordem
    if para = 'carregado'
       and new.ordem_numero is distinct from old.ordem_numero
       and old.ordem_numero is not null then
      raise exception 'Pallet % já está carregado na ordem % — não pode entrar na ordem %.',
        coalesce(old.codigo, old.id::text), old.ordem_numero, new.ordem_numero
        using errcode = 'P0001',
              hint = 'Reabra a carga original para liberar o pallet antes de usá-lo em outra ordem.';
    end if;
    return new;
  end if;

  if de = 'estoque'   and para = 'carregado' then return new; end if;  -- carregar
  if de = 'carregado' and para = 'expedido'  then return new; end if;  -- portaria
  if de = 'carregado' and para = 'estoque'   then return new; end if;  -- reabrir carga

  raise exception 'Transição de estoque inválida no pallet %: % → %.',
    coalesce(old.codigo, old.id::text), de, para
    using errcode = 'P0001',
          hint = 'Permitido: estoque→carregado, carregado→expedido, carregado→estoque (reabertura).';
end;
$$;

drop trigger if exists tg_pallet_guarda_estado on public.producao_pallets;
create trigger tg_pallet_guarda_estado
  before update of estoque_status, ordem_numero on public.producao_pallets
  for each row
  execute function public.pallet_guarda_estado();
