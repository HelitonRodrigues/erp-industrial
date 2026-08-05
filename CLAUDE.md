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
[~] 1    Auth Supabase✓ + RLS baseline✓ + login live✓ — falta anon key (Passo D)
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

## Item 1 — Auth + RLS (em andamento, sessão 2026-08-05)

**No ar e testado:**
- **A** — 5 users provisionados no Supabase Auth; `usuarios.auth_id` linkado.
- **B** — RLS ligado nas **124 tabelas** + policy `baseline_authenticated_all`
  (`authenticated` pode tudo, anon nada). As 6 policies `{public}` antigas removidas.
- **C** — `doLogin()` → `signInWithPassword`; backdoor `sadm@fabrica.com` e
  `senha_hash` no cliente **removidos**; `doLogout()` faz `signOut`. Contrato do
  `sessionStorage.erp_user` mantido (40 módulos intactos). Commit `d8c5b9c`, login ok.

**Falta — Passo D (troca `service_role` → anon key; é o que fecha o buraco):**
`service_role` ainda em `js/supabase.js:7` (+ 2º client em `epi-qr.html`).
Bloqueio: 2 páginas **públicas** (sem login) leem o banco e quebram como anon.
Decisão do dono: mantê-las públicas mas **seguras via RPC** (não expor tabela inteira).
- **D1** RPCs SECURITY DEFINER p/ anon (retornam só o item): `branding_publico()`,
  `rastreio_por_codigo(cod)`, `rastreio_por_data_numero(dt,num)`,
  `rastreio_por_ordem(ordem)`, `carregamento_por_ordem(ordem)`, `epi_qr(func_id)`
- **D2** reescrever `rastreio.html` e `epi-qr.html` p/ chamar as RPCs
- **D4** trocar `service_role` → anon key (`js/supabase.js` + `epi-qr.html`)
- Depois: **1c** = apertar policies por perfil (piloto `producao`); limpezas
  (dropar `senha_hash`, onboarding `criarSADM` p/ Auth, rehidratar sessão em nova aba).
Ponto de retorno: tag `antes-item-1`.

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
