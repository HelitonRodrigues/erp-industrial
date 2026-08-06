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
[x] 0    BACKUP  Pro✓ + dump noturno✓ + restore validado (load ao vivo)✓
[ ] 0.5  Projeto Supabase de staging permanente (opcional, custa compute)
[x] 1    Auth Supabase✓ + anon key✓ + RLS baseline✓ + 1c por perfil nas sensíveis✓
[~] 2    fallbacks apagados✓ (5 silenciosos removidos + detectores inertes) — falta 001_baseline.sql
[~] 2.5  Helper db() pronto (utils.js) + piloto producao✓ — espalhar gradual
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

## Item 1 — Auth + RLS ✅ núcleo fechado (sessão 2026-08-05)

**No ar e testado:**
- **A** — 5 users no Supabase Auth; `usuarios.auth_id` linkado.
- **B** — RLS nas **124 tabelas** + policy `baseline_authenticated_all`
  (`authenticated` pode tudo, anon nada). As 6 policies `{public}` antigas removidas.
- **C** — `doLogin()` → `signInWithPassword`; backdoor `sadm@fabrica.com` e
  `senha_hash` no cliente removidos; `doLogout()` faz `signOut`. Contrato
  `erp_user` mantido (40 módulos intactos). Commit `d8c5b9c`.
- **D** — `service_role` → **anon key** nos 3 clients (`js/supabase.js`,
  `epi-qr.html`, `importar-romaneio.js`). Páginas públicas + import de romaneio
  via RPC SECURITY DEFINER: `branding_publico`, `rastreio_por_codigo`,
  `rastreio_por_data_numero`, `rastreio_por_ordem`, `carregamento_por_ordem`,
  `epi_qr`, `turnos_publico`, `importar_romaneio`. Commits `bac031c`+`f4c2cf6`.
  **Provado:** deslogado, `funcionarios.select('*')` → `[]` (RLS bloqueia anon).
  Login + dashboard + módulos OK como `authenticated`.

**Falta (refino, não bloqueia):**
- ✅ **1c FEITO (escopo sensível):** helper `auth_perfil()` + `usuarios` self-read
  (protege `senha_hash`; testado ALM vê 1, SADM vê 5). Helper dinâmico
  `auth_pode_modulo(mod)` que lê `perfis.permissoes` → `planejamentos_custo` e
  `folhas_pagamento` travados ao módulo `custo_precificacao` (segue o `perfis.html`:
  muda lá, o banco acompanha). Testado: ALM bloqueado (`data:[]`), SADM/SGR acessam.
  Resto operacional fica na baseline (ok p/ 5 users de confiança); espalhar quando quiser.
  ⚠️ Dívida: `perfis` tem 2 formatos (novo por-id nos 5 users reais; antigo
  capitalizado nos perfis sem user). Normalizar no item 2.
- Limpezas: dropar `senha_hash` (morto), onboarding `criarSADM` p/ Auth, rehidratar sessão nova aba.
- ✅ Bug frota **400 RESOLVIDO**: `frota_veiculos` estava sem colunas (drift) —
  `ADD COLUMN IF NOT EXISTS` alinhado ao schema do `frota.html`.
- ✅ Landmines **RESOLVIDAS**: os 3 setup scripts com `DISABLE ROW LEVEL SECURITY`
  (frota_veiculos, planejamentos_custo, folhas_pagamento) → `ENABLE` + policy base (`376b113`).
- ⚠️ `custo-precificacao.html` é mantido **pelo DONO** (edita/sobe pela web do GitHub).
  NÃO editar aqui — passar snippet p/ ele colar. Sempre `git pull` no início (`pull.rebase=true`).
Ponto de retorno: tag `antes-item-1`.

## Item 2 — fallbacks silenciosos (feito, sessão 2026-08-06)

- **5 fallbacks silenciosos removidos** → trocados por `db()` (surge o erro):
  `producao.html` ×2 + `aferidor.html` ×2 (`producao_pallets`, tiravam codigo/equipe),
  `compras.html` ×1 (`_saveResiliente`, tirava historico/obs).
- **Detectores inertes** (`carregamento.html`, `desgaste.html`): mostram banner de
  migração, não corrompem; ficam como rede de segurança.
- **Schema alinhado (ADD COLUMN IF NOT EXISTS)** p/ os fallbacks virarem código morto:
  `producao_pallets.equipe`; `frota_veiculos` (17 colunas do setup); `compras_cotacoes/
  pedidos/recebimentos` → `historico jsonb`, `obs text`; `barracoes.layout jsonb`.
- Helper **`db(promise, ctx)`** em `utils.js` — retorna o mesmo `{data,error}`, só loga+toasta erro.
- **Falta:** `001_baseline.sql` (dump do schema como fonte única) + disciplina de migrations.

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
4. [x] **Restore validado — incl. load ao vivo.** Dump de 32.79 MB (run #3).
   `pg_restore --list` + restore a seco OK, e **load ao vivo** num cluster PG18
   descartável (`initdb` trust, porta 5433). Só funciona com o dump **COMPLETO**
   (não `--schema=public`), pra trazer os schemas `auth`/`extensions`/`storage`
   de que as tabelas do app dependem. Resultado: 124 tabelas public criadas e
   populadas, **0 erro em tabela do app**; `producao_pallets=292` (bate com o
   snapshot pré-backfill das 11:44). Únicos erros: extensão `supabase_vault` e
   role `authenticated` — ruído interno do Supabase. **Backup provado restaurável.**
   - Um projeto Supabase de staging *permanente* (0.5) fica opcional (custa
     compute); só vale quando for testar migrations/RLS de verdade (item 2).
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
