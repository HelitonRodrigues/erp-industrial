# ERP Industrial Silicate — estado e plano de trabalho

> Contexto de domínio (regras de pallet, aditivo, sobra, dívidas técnicas):
> ver `.claude/skills/erp-silicate/SKILL.md`. Leia antes de calcular qualquer coisa.

## Situação atual

**Pré-produção.** O dono (Heliton — CEO e gerente de produção) está alimentando
cadastros e testando módulo a módulo. Ninguém da fábrica usa ainda.

Isso define a prioridade: **fazer primeiro o que fica mais caro depois.**
Enquanto não há usuários, errar RLS ou schema custa quase nada. Depois do
go-live, custa parada de linha.

## Estado do plano

```
[x] C    Sidebar colapsa a 0px + persiste em localStorage        CONCLUÍDO
[x] 0    BACKUP  Pro✓ + dump noturno✓ + integridade do dump validada✓
[ ] 0.5  Projeto Supabase de staging (load ao vivo do dump)      ← PRÓXIMO
[ ] 1    Chave anon + RLS nas 118 tabelas
[ ] 2    001_baseline.sql + migrations + apagar os 12 fallbacks
[ ] 2.5  Helper db() — erro nunca mais silencioso
[ ] 3    js/regras.js — fonte única: pallet, tonelagem, eficiência, custo
[ ] 4    limit/filtro nas 118 queries abertas
[ ] 4.5  Fotos base64 → Storage (+ incluir Storage no backup)
[ ] 5    Deep-links entre módulos (?equip=&aba=)
[ ] 6    Tokens de design + Lucide + varrer os 10.431 style=
[ ] 7    Quebrar bpf/manutencao/laboratorio/compras (opcional)
[ ] 8    Offline-first (IndexedDB) nos 4 fluxos de campo
```

**Ao concluir um item, marque `[x]` aqui e faça commit.** Este arquivo é a
memória do projeto entre sessões.

## Item 0 — Backup (estado)

1. [x] Supabase **Pro** (backups diários, 7 dias)
2. [~] Dump manual offsite — coberto pelo Actions; cópia local é extra opcional
3. [x] **GitHub Actions com dump noturno** — `.github/workflows/backup.yml`,
   03:00 BRT, artifact `erp-backup` (retenção 14 dias). Testado verde (run #3).
   - Region: `sa-east-1`. Host real do pooler: **`aws-1`**-sa-east-1 (não aws-0).
   - Secret `SUPABASE_DB_URL` = URI do **Session Pooler** (IPv4). Só o dono edita.
   - Pegadinha resolvida: o runner resolve `pg_dump` pro 16 → version mismatch
     com o servidor 17.6. Fixado chamando `/usr/lib/postgresql/17/bin/pg_dump`.
   - Senha do banco foi resetada p/ alfanumérica (evita URL-encode). NÃO quebra
     o app: ele autentica via API key (JWT), não via senha do Postgres.
4. [x] **Integridade do restore validada** — dump de 32.79 MB (artifact run #3).
   `pg_restore --list` + restore a seco (`--schema=public -f`) rodaram sem erro
   (exit 0, 46 MB de SQL, 124 tabelas com dados; todas as tabelas-chave do ERP
   presentes). Prova que o dump descomprime e é restaurável.
   - Falta o **load ao vivo** num banco real (testa FKs/constraints) → item 0.5.
   - PG local (18.4) existe mas senha do `postgres` foi esquecida; o load ao
     vivo vai num projeto Supabase de staging OU após reset da senha local.
5. PITR só no go-live — em pré-produção, backup diário basta.

## Diagnóstico — RESOLVIDO (sessão 2026-08-05)

1. **Rastreabilidade — corrigido.** `producao_pallets` tinha `codigo` mas **não
   tinha `equipe`**. O fallback disparava em todo insert e, ao remover `equipe`,
   levava o `codigo` junto → **292/292 pallets sem código** (mas 0 expedidos —
   tudo pré-produção, nenhum dano de campo). Fix aplicado:
   `alter table producao_pallets add column equipe text` + backfill
   determinístico do `codigo` (`LINHA-DATA-OP-Pnnn`). Validado com pallet novo;
   `sem_codigo = 0`.
   ⚠️ Os fallbacks em `producao.html:1600-1607` **continuam no código** — agora
   inertes, mas mascarariam drift futuro. Remover no item 2.
2. **Base64 — baixa urgência.** `frota_veiculos` 2.4 MB + `terceiros_remessas`
   824 kB + `manutencao` 744 kB ≈ 4 MB. Item 4.5 pode esperar.
   Anomalia p/ investigar: `linhas_producao` com **17 MB** (config não deveria
   pesar isso — provável JSON/base64 escondido).
3. **Aditivo — sem vazamento.** Aplicado só em `L20` (20 kg) e `CONC` (=10 kg);
   **zero** em 25 kg / Big Bag / Granel. `CONC` no custo **É o 10 kg** (rótulo
   "Concentrado" é só cosmético — renomear algum dia). A checagem 3:1 ainda não
   foi fechada: a dosagem g/saco não está no modelo (reforça o item 3 —
   `js/regras.js` como fonte única da dosagem).
4. **`sacosPorPallet` do 25 kg — corrigido.** 95 → **77** (commit `b066971`).

## Protocolo de trabalho

1. **Nunca duas camadas no mesmo commit.** Cálculo e layout separados — se o
   número sair errado, tem que dar para saber qual dos dois causou.
2. **Módulo piloto antes de espalhar.** Padrão: `producao.html`.
3. **Migração sempre aditiva, em 3 deploys:** adiciona coluna → código escreve
   nas duas e lê da nova → remove a antiga semanas depois. Nunca `DROP` ou
   `RENAME` numa passada.
4. **`git tag antes-item-N` + dump fresco** antes de cada item.
5. Itens que mexem em dado (1, 2, 3, 4.5) exigem **backup testado antes**.
6. `css/style.css` e `js/utils.js` afetam os 37 módulos de uma vez. Mais
   cuidado que em qualquer `.html` isolado.
7. **Não esconder falha.** Nada de `.filter(Boolean)` ou `try/catch` vazio para
   silenciar elemento ausente ou erro de query. Se falhou, tem que aparecer.
8. Nunca digitar ou manipular senha e credencial do dono — pedir a ele.

## Escopo — o que NÃO construir

Nada fiscal ou contábil: NF-e, CT-e, SPED, EFD-Reinf, eSocial, apuração de
ICMS/ST, folha. Trabalho infinito, sem valor competitivo, e errar dá multa.
O ERP é o **sistema de operação**; integra com emissor fiscal ou exporta para
o contador.

A vantagem real deste sistema sobre Protheus/SAP é ser feito para **uma**
fábrica específica. Não generalizar.
