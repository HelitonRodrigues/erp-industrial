-- 196 — Fila de impressão: apaga o desenho (html) dos trabalhos já impressos.
-- Cada trabalho guarda a página inteira do rótulo (~150 KB, com imagens dentro).
-- 580 trabalhos impressos somavam ~89 MB — mais de um terço do banco.
-- Depois de impresso o html não é usado (a estação só mostra título e hora).
-- (a coluna html é obrigatória: fica vazia '' em vez de nula)
-- Mantém os últimos 2 dias por segurança; título, quantidade, quem e quando ficam.
-- Daqui em diante a limpeza é automática a cada trabalho novo.

create index if not exists impressao_fila_limpeza_idx
  on public.impressao_fila (impresso_em) where status = 'impresso' and html <> '';

create or replace function public._impressao_fila_limpar() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update impressao_fila set html = ''
   where status = 'impresso' and html <> ''
     and impresso_em < now() - interval '2 days';
  return null;
end $$;

drop trigger if exists trg_impressao_fila_limpar on public.impressao_fila;
create trigger trg_impressao_fila_limpar after insert on public.impressao_fila
  for each statement execute function public._impressao_fila_limpar();

update public.impressao_fila set html = ''
 where status = 'impresso' and html <> ''
   and impresso_em < now() - interval '2 days';
