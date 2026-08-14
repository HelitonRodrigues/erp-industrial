# Migrations — como funciona a partir de agora

**Regra única:** nenhuma mudança de schema entra no Supabase pelo SQL Editor "solto".
Toda mudança vira um arquivo numerado nesta pasta, aplicado em ordem, primeiro no
staging, depois na produção. O arquivo é o histórico.

## 001 — Baseline (gerar uma vez, no seu computador)

O baseline é a foto do schema atual. Gere com o Supabase CLI:

```bash
npx supabase login
npx supabase link --project-ref zodgbitbflkepbszshmu
npx supabase db dump --schema public -f sql/migrations/001_baseline.sql
```

Commite o arquivo gerado. Ele nunca é "aplicado" na produção (a produção JÁ é o
baseline) — serve para reconstruir staging e para o dia em que precisar de um
banco do zero.

## Ordem de aplicação das seguintes

| Arquivo | O que faz | Risco |
|---|---|---|
| 002_producao_pallets_status_check.sql | corrige o CHECK para aceitar `aguardando_decisao` (o código já usa; o banco rejeitava) | baixo — dados atuais já conformes (452 pallets, todos `pendente`) |
| 003_pallet_guardas_estado.sql | CHECK em `estoque_status` + trigger que só permite transições válidas e impede carregar o mesmo pallet em duas ordens | baixo — permite todos os caminhos que o código usa hoje |
| 004_config_carregamento.sql | política "pendentes podem carregar" sai do localStorage e vira configuração central em `app_preferencias` | nenhum — só INSERT |

## Antes de aplicar em produção

1. `git tag antes-etapa-1` no repositório.
2. Dump fresco: `npx supabase db dump -f backup_$(date +%Y%m%d).sql` (guardar fora do Supabase).
3. Aplicar no staging e abrir carregamento.html apontando para ele: criar carga,
   reabrir carga, salvar layout do piso, marcar pallet como carregado 2× (deve
   bloquear a 2ª com a mensagem de "já está carregado na ordem …").
4. Só então aplicar na produção.
