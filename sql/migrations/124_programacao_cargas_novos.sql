-- 124 — Programação de Cargas: pedido NOVO (entrou no Salescode depois que o dono programou)
-- visto_em null = novo (cartão cinza-escuro na tela). Fica "visto" ao arrastar, ao clicar em "✓ Visto" no cartão
-- ou em "Marcar todos como vistos". Pedido que já existia quando esta migração rodou = visto.
alter table programacao_cargas add column if not exists visto_em timestamptz;
update programacao_cargas set visto_em = now() where visto_em is null;
