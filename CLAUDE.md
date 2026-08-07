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
[~] 2    TODOS os fallbacks apagados✓ (silenciosos + schema-strip) — só falta 001_baseline (opcional)
[x] 2.5  Helper db() + espalhado em ~20 módulos (todos os fluxos de dado)✓
[~] 3    js/regras.js✓ — TONELAGEM✓ + PALLET✓ + EFICIÊNCIA✓ (núcleo fechado); falta snippet 95 (dono) + aposentar colunas de peso antigas
[~] 4    limit/filtro nas queries abertas — relatorios/RH feito; método+armadilhas mapeados
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

- **7 fallbacks silenciosos removidos** → trocados por `db()` (surge o erro):
  `producao.html` ×2 + `aferidor.html` ×2 (`producao_pallets`, tiravam codigo/equipe),
  `compras.html` ×1 (`_saveResiliente`, tirava historico/obs),
  `almoxarifado.html` ×2 (save de produto, tirava estoque_maximo/codigo_especificacao).
  Bônus: writes de estoque (`estoque_atual`) e de OP blindados com `db()`.
- **Detectores inertes** (`carregamento.html`, `desgaste.html`): mostram banner de
  migração, não corrompem; ficam como rede de segurança.
- **Schema alinhado (ADD COLUMN IF NOT EXISTS)** p/ os fallbacks virarem código morto:
  `producao_pallets.equipe`; `frota_veiculos` (17 colunas do setup); `compras_cotacoes/
  pedidos/recebimentos` → `historico jsonb`, `obs text`; `barracoes.layout jsonb`;
  `almoxarifado` → `estoque_maximo numeric`, `codigo_especificacao text`.
- Helper **`db(promise, ctx)`** em `utils.js` — retorna o mesmo `{data,error}`, só loga+toasta erro.
- **db() espalhado em ~20 módulos** (saves/deletes/writes silenciosos → visíveis):
  producao, almoxarifado, expedicao, carregamento, laboratorio, manutencao, portaria,
  solicitacoes, epi, aferidor, produtos, funcionarios, linhas, turnos, rh, escala,
  equip-gerais, equip-linhas, motivos, planejamento. Tail menor (abastecimento níveis
  de bomba, terceiros status, bpf, custos) fica gradual.
- **Fallbacks de schema REMOVIDOS** ✅ — colunas confirmadas/adicionadas no banco,
  depois trocados por `db()`: funcionarios(certificacoes/custos), abastecimento_entradas
  (valor_danfe/valor_litro), terceiros_remessas(itens/autorizado_por_id/assinatura_autorizador)
  + terceiros_servicos(anexos), frota_veiculos(dadosExtras), manutencao(extrasNovos:
  +tempo_previsto), escala(turno2). **Zero fallback de schema silencioso no sistema.**
  Órfão inofensivo: `_strip` (def sem uso) em terceiros.html:541 — limpar algum dia.
- **Falta:** `001_baseline.sql` (dump do schema como fonte única) + disciplina de migrations.

## Item 3 — js/regras.js (em andamento, sessão 2026-08-06)

Fonte única de cálculo. Estratégia acordada com o dono: **um cálculo de cada vez,
com piloto, ele confere o número, só então espalha.** Primeiro cálculo: **TONELAGEM.**

- **Passo 1 — modelo do peso (commit `2b56eb5`).** Faltava peso do produto como
  campo: estava embutido no nome ("...10kg"), então ninguém convertia certo.
  Novo campo **`produtos.peso_unidade_kg`** (numeric, opcional) + input no
  `produtos.html` (salvar/editar/limpar/detalhe). SQL rodado pelo dono:
  `alter table produtos add column if not exists peso_unidade_kg numeric;`
  Dono preencheu todos: saco 10/20/25 → 10/20/25; Concentrado → 10; Big Bag → 1000;
  Granel (contado por tonelada) → 1000. Modelo universal:
  **`toneladas = quantidade × peso_unidade_kg ÷ 1000`** (granel c/ peso 1000 se auto-corrige).
- **Passo 2 — `js/regras.js` + piloto (commit `bb36989`).** Criado `js/regras.js`
  (funções PURAS, sem DOM/banco, sem valor chutado): `Regras.toneladas(qtd,pesoKg)`,
  `Regras.normalizarNome(s)`, `Regras.pesoUnidadeKg(nome,produtos)` (match por nome
  normalizado; **retorna null se falta peso — nunca chuta**). Testado no node (10/20/25,
  Big Bag, granel, entrada inválida, lookup). Piloto no **`custos.html`**: as 2 contas de
  custo/ton (`renderCustoTon` + `renderCustoProduto`) **deixaram de assumir 10 kg/saco**
  (bug `pesoSaco=0.01`) e usam `peso_unidade_kg`. Produto sem peso ou nome divergente
  **não entra na tonelagem** → banner amarelo + "⚠️ sem peso" por linha (protocolo #7,
  nada de número errado silencioso). Dono validou o número ("no meu ponto de vista está ok").
- **Passo 3 — espalhar (commit `29db10b`).** Descoberto: peso estava **fragmentado em 4
  nomes** — `peso_unidade_kg` (já era convenção no `insumos.html`), `peso_saco`
  (só `expedicao`), `peso`/`peso_embalagem` (só `almoxarifado`, com extração-do-nome).
  Nenhum código **escreve** os 3 últimos → estavam vazios. Unificado tudo em
  **`peso_unidade_kg`**: `expedicao.html` (peso por item + rótulo) e `almoxarifado.html`
  (ficha técnica MP = peso × sacos) passam a lê-lo, com nomes antigos + extração só como
  retrocompatibilidade. `dashboard.html` fora (tonelada vem de custo/custo-por-ton).

- **Passo 4 — PALLET (commit `482ae91`).** Segundo cálculo. `regras.js` ganhou
  `sacosDePallets(itens)`, `totalSacos(itens,sobra)`, `palletsCheios(itens)`,
  `palletsFisicos(itens,sobra,sobraOcupa)` (puras, testadas no node — inclui 3300 sacos
  = 18 cheios + 60 sobra → 19 pallets). No `producao.html`: helper `_lerItensPallet(div)`
  (única leitura de DOM) + os **5 sites** duplicados (calcProdOP, calcTotaisOP,
  calcEficienciaOP, validação, SAVE) passam a chamar `regras.js`. Estrutura do array
  `pallets` persistido preservada byte a byte. Dono validou ("está ok").
- **Passo 5 — EFICIÊNCIA DE PRODUÇÃO (commit `e2d1fef`).** Terceiro cálculo.
  `regras.js`: `metaSacos(capHora,horas)` + `eficienciaProducao(sacos,meta)`. Comentário
  fixo de que **NÃO** é o fator de planejamento do `planejamento.html` (`perda = brutos ×
  (100−efic)/100` — entrada de planejamento, não medição; não unificar — alerta da skill).
  No `producao.html`: os 3 pontos que faziam `capHora×h` e `sacos/meta×100` (save,
  calcEficienciaOP, performance do OEE) passam a chamar `regras.js`. Número idêntico.
- **Bug de lógica achado pelo dono no piloto (commit `331b2fd`, validado).** A meta
  de produção usava horas **TRABALHADAS** (`capHora × htProduto`) → trabalhar mais
  inflava a meta e nunca batia. Correto: meta fixa = `capHora × horas DISPONÍVEIS
  planejadas` (`getHorasDispDia`, ex: 6,23h). Ex.: 500 sc/h × 6,23h = **3.115** (antes
  7,10h × 500 = 3.550). Corrigido na tela (`calcEficienciaOP`, rateando as horas
  disponíveis por produto pelo tempo gasto) e no valor salvo (`eficiencia`, fallback p/
  horas trabalhadas se sem planejamento). **OEE performance NÃO muda** de propósito:
  usa tempo de máquina rodando (definição correta de OEE; a disponibilidade do OEE já
  cobre planejado×real — mudar as duas contaria em dobro).

- **Passo 6 — DISPONIBILIDADE (commit `58ad629`).** `Regras.disponibilidade(ht,hp)` =
  `(HT−HP)/HT×100`, consolidando 3 cópias no `producao.html` (KPI do dia, resumo do dia,
  tabela por linha). Número idêntico (refactor puro). NÃO é a disponibilidade do OEE
  (base horas brutas do planejamento) — essa fica separada de propósito.

**Bug `sacosPorPallet:95` — RESOLVIDO (verificado 2026-08-07).** Conferido o
`custo-precificacao.html`: CAULIM25 já está `sacosPorPallet: 77` (linha 287), L20=91,
CONC=180. Não há mais nenhum `95` de pallet (os `95` restantes são largura CSS, preset
de eficiência 95% e valor de folha — não relacionados). O dono corrigiu numa edição
manual anterior. Nada a fazer. (Obs.: a SKILL ainda cita o `95` como bug aberto —
desatualizada nesse ponto.)

**Falta no item 3 (único, não bloqueia):** **aposentar** `peso_saco`/`peso`/`peso_embalagem`
(migração aditiva: dropar as colunas mortas semanas depois, já sem uso real).

## Item 4 — limit/filtro nas queries abertas (em andamento, sessão 2026-08-07)

Escolha do dono: **passe completo e caprichado** (janela server-side por tela),
não trava de segurança genérica. Disciplina de piloto (dono confere cada tela).

**Mapa (agente Explore):** ~140 "queries abertas" reportadas, MAS o scanner tem
**falsos positivos** — queries "builder" (`let q=…; if(x) q=q.eq(…)`) que filtram
nas linhas seguintes (ex.: `insumos.html:2069` já filtra por data/OP). Escopo real
menor. `relatorios.html` **já filtra a maioria por período** (`.gte/.lte data`,
recarrega no botão "🔍 Filtrar" via `carregarAba()`); só as exceções precisam.

**REGRA CENTRAL — cada tela tem uma janela diferente; errar esconde dado (protocolo #7):**
- **Período** (relatórios) → filtrar por `data` do seletor `f-ini/f-fim`. Maioria já faz.
- **Estado atual** (férias, pedidos em aberto) → filtrar por status/vigência, NÃO por data.
- **Contagem** (KPI "total de X") → usar `select('*',{count:'exact',head:true})`, sem trazer linhas.
- **Recente-N** (tabela que mostra `.slice(0,60)`) → `.order(data desc).limit(N)` com N>exibido.
- **Histórico por entidade** (ficha de EPI do funcionário) → paginar por entidade.
- **Saldo/agregado** (estoque, ABC) → NÃO dá filtro simples; precisa **RPC/view** (0 hoje) — sub-projeto.

**Feito:** `relatorios.html` aba RH (commits `089abaa`+`6939d94`) — `rh_ferias`
→ `.order(data_inicio desc).limit(200)` (tabela mostra 60, KPIs pegam atuais/futuras
do topo; não some nada); `rh_escala` → query de **contagem** (era só `escalas.length`).
⚠️ Lição: o 1º piloto filtrou férias por status e escondia as "concluídas" da tabela/
export — corrigido. **Ler TODOS os usos de uma query antes de limitar.**

**Próximo (exceções do relatorios, todas com armadilha — refatoração cuidadosa, não `.limit()` seco):**
- `abaCompras` (2144): `pedidos.length` é total (→ count) + em-aberto qualquer idade (→ or status) + tabela 60 recentes.
- `abaQualidade` caulim (892): `caulim_analises_externas` agrupa por status (contagem sobre todas).
- `epi_entregas` (1670, 2332, 3136, 3376, 3554): histórico por funcionário (ficha precisa de tudo da pessoa).
Depois: portaria/abastecimento/carregamento (logs: recentes + em aberto); por fim os
`init` pesados (`laboratorio` caulim_*, `compras`) — e o que for agregado vira RPC (parar e planejar).

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
