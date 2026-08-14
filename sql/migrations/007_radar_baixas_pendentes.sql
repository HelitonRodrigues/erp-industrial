-- 007 — Radar de produção sem baixa de insumos
--
-- Pergunta que esta migration responde de forma PERMANENTE (não só no toast
-- da hora de salvar a OP): "existe produto produzido cujo consumo de insumos
-- não entrou no estoque?"
--
-- A view compara produtos_op (o que foi produzido) com insumos_movimentos
-- (o que baixou). Qualquer produto com sacos > 0 e sem movimento aparece —
-- seja por falta de ficha técnica, por alerta de dado faltando na ficha, ou
-- por falha na chamada. A coluna sem_ficha diz qual é o caso.
--
-- Consumida por: banner na tela de Insumos (aba Resumo) e conferências.
-- security_invoker: a view respeita as policies de quem consulta.

create or replace view public.v_baixas_pendentes
with (security_invoker = true) as
select pr.id            as producao_id,
       pr.data,
       pr.linha,
       pr.turno,
       pr.op_numero,
       item->>'produto' as produto,
       coalesce(nullif(item->>'total_sacos','')::numeric,
                nullif(item->>'sacos_pallets','')::numeric, 0) as sacos,
       not exists (
         select 1 from insumos_ficha f
          where norm_nome(f.produto) = norm_nome(item->>'produto')
       ) as sem_ficha
from producao pr
cross join lateral jsonb_array_elements(coalesce(pr.produtos_op,'[]'::jsonb)) item
where coalesce(nullif(item->>'total_sacos','')::numeric,
               nullif(item->>'sacos_pallets','')::numeric, 0) > 0
  and not exists (
    select 1 from insumos_movimentos m
     where m.origem = 'OP'
       and m.origem_id = coalesce(nullif(pr.op_numero,''), pr.id::text)
       and norm_nome(m.produto) = norm_nome(item->>'produto'));

-- ── Correção de bug encontrado no caminho ────────────────────────────────────
-- lab_notificar gravava na coluna "mensagem", que NÃO EXISTE em notificacoes
-- (a coluna é "descricao"). Como a function engole exceções de propósito
-- ("notificação nunca pode derrubar o salvamento"), as notificações do
-- laboratório falhavam em silêncio desde a criação. Corrigido.
create or replace function public.lab_notificar(p_titulo text, p_mensagem text, p_tipo text default 'alerta'::text)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  insert into notificacoes (titulo, descricao, tipo, modulo, lida)
  values (p_titulo, p_mensagem,
          case when coalesce(p_tipo,'alerta') in ('urgente','aviso','info') then p_tipo
               when p_tipo = 'erro' then 'urgente'
               else 'aviso' end,
          'laboratorio', false);
exception when others then
  raise notice 'lab_notificar falhou: %', sqlerrm;
end $$;
