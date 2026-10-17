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
[x] 4    limit/filtro queries abertas — relatorios page-load 100% (compras/qualidade/epi/carreg/gerencial/bpf/RH)✓; RPC de agregado deferida (baixo valor em pré-prod, justificado)
[~] 4.5  Fotos base64 → Storage (+ incluir Storage no backup) — EM ANDAMENTO (investigando código)
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
- ⚠️ `custo-precificacao.html` era mantido **pelo DONO** (regra antiga: não editar, passar
  snippet). **MUDOU na sessão 2026-08-07:** o dono pediu pra eu **editar direto no GitHub**
  (ele baixa de volta como base). Editei muito a aba **planejado x realizado** — ver memória
  `custo-precificacao-aba-planejado-realizado` (o que foi feito + o que falta) e
  `testar-custo-precificacao-local` (como testar contornando login, com os dados reais dele).
  Funcional pronto e testado; **falta:** preenchimento do realizado da planilha (só o dono
  salva — sem meu acesso ao Supabase; dados espalhados em log diário + CUSTO REAL de MAIO
  desatualizada) e o layout ⑤ (agrupar aditivo/pallet). Sempre `git pull` no início.
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

**Bug GRANEL no custos.html — CORRIGIDO (sessão 2026-10-06).** `renderCustoTon` e
`renderCustoProduto` pesavam o apontamento da OP direto (`toneladas(qtd, 1000)`), mas o
granel é apontado em **kg** → 1000× a mais (set/2026: 1.563.899 t na tela; real 7.256,9 t,
sendo 1.558,2 t de granel). Agora convertem antes por `Regras.qtdNaUnidadeDoProduto` pela
unidade do cadastro (mesma regra do `producao.html`); coluna "Sacos" mostra "t" e Custo/Saco
fica "—" para produto em massa. `carregamento.html` não tem o bug (granel fora do estoque
físico). ⚠️ Mesmo bug em `almoxarifado.html:montarFichaTecnica` (tela legada de saída por
produção; também usa aditivo `sacos/9` para todo produto) — não corrigido, confirmar se ainda é usada.

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

**Feito 2 (sessão 2026-08-10) — exceções do relatorios + helper `safeCount`:**
Novo `safeCount` (traz `r.count` sem baixar linhas) ao lado do `safe`.
- `abaCompras` (`bba20ac`): total→count; em-aberto/atrasado/valor→`.in('status',abertos)`
  (estado atual, qualquer idade); tabela+export→`.order(created_at desc).limit(500)`;
  solicitações por status→`.select('status')`. KPIs idênticos (atrasados ⊂ abertos).
  Export passou a cobrir 500 recentes (era "tudo") — teto `REC_MAX` documentado.
- `abaQualidade` (`573ff4c`): `caulim_analises_externas`→`.eq('status','vigente')`
  (vencida = vigente c/ validade passada; demais status não usados). Mesmos números.
- `abaEpi` (`b67b27f`): total/vencidos/a-vencer→count (`.lt/.gte/.lte` batem com o
  compare do cliente em date E timestamp — sem risco de borda); tabela (mostrava TODAS,
  sem slice) + export→`.limit(500)`.
Smoke test de cada aba local (login fake, RLS bloqueia anon → renderiza 0 sem quebrar,
0 erro JS). **Números reais o dono confere autenticado na produção** (RLS me bloqueia).

**Feito 3 (sessão 2026-08-10) — família "logs":** `abaPortaria` e `abaAbastecimento`
já eram por período (nada a fazer); `abaExpedicao` idem (KPIs somam o período, NÃO
podem levar `.limit` sem quebrar o total — total só via RPC/sum, subprojeto). Único
furo real: `abaCarregamento` `romaneios` (`e81bb32`) — "pendentes" é estado atual mas
vinha por recência (`limit 500`), escondendo romaneio antigo pendente → trocado por
`.or('status.in.(recebido,em_carregamento),status.is.null')` (URL PostgREST conferida).

**Feito 4 (sessão 2026-08-10) — últimas queries abertas de page-load (`ced9b92`):**
`abaGerencial` — `epi_entregas` (pull de tudo p/ contadores vencidos/a-vencer) → count
no Promise.all; `epiEntregas` removido do `_dadosGerencial` (não era lido). `abaBpf` —
`bpf_ncs` era `select('*')` sem janela → total→contagem, abertas (estado atual)→
`.or('status.neq.encerrado,status.is.null')`, tabela+export→limit(500). URLs conferidas,
smoke limpo. **Varredura final:** todas as demais `select('*')` de page-load do relatorios
já têm janela (período/status/limit) ou são catálogo pequeno (frota, bombas, naturezas/
centros, equipamentos, prestadores). **Passada de CORREÇÃO de page-load do relatorios: COMPLETA.**

**Resta (otimização, não correção — NÃO bloqueia; precisa de mim escrevendo SQL + o dono rodando):**
1. **Subprojeto RPC/view** (0 RPCs hoje): agregados que hoje baixam linhas p/ somar no
   cliente — almoxarifado (alertas de estoque: `estoque_atual < estoque_minimo`, comparação
   coluna×coluna que PostgREST não faz sem view/RPC), ABC, e os totais de período do
   `abaGerencial`/expedição/carregamento (count/sum server-side). Precisa backup fresco.
2. **Exports sob demanda** (`pdfEpi`/`pdfGerencial`/`csvEpi`/`csvExpedicao`/…): puxam
   `select('*')` completo — mas rodam SÓ no clique e export quer dado completo; deixar
   como está (janelar perderia dado). Só virar paginado se algum dia um export estourar.
3. Fora do relatorios: revisar "queries abertas" reais dos outros módulos (scanner tinha
   falso-positivo — ver mapa acima).

## Item 4.5 — Fotos base64 → Storage (em andamento, sessão 2026-08-10)

**Mapa (agente Explore) — onde há base64 no banco:**
| tabela.coluna | módulo | tipo | comprimido? |
|---|---|---|---|
| `linhas_producao.foto` | linhas.html | 1 img | ❌ RAW → era a anomalia de 17MB |
| `frota_veiculos.foto` | frota.html | 1 img | ✅ maxD1000 jpeg0.82 |
| `frota_veiculos.componentes[].foto_componente` | frota.html | array | ✅ maxD800 jpeg0.75 |
| `frota_veiculos.documentos[].data` | frota.html | array | ❌ RAW (aceita PDF/office cru!) |
| `manutencao.fotos_servico` / `assinaturas_servico` / `assinatura` | manutencao+frota | array+png | ✅ fotos jpeg0.75; assinatura png canvas |
| `manutencao_docs.url` | manutencao.html | base64 OU link | ❌ (opcional) |
| `terceiros_remessas.assinatura(_autorizador)` + `.itens[].fotos[]` | terceiros.html | png + array | assinatura png; fotos jpeg0.78 |
| `terceiros_servicos.anexos[]` | terceiros.html | array | ✅ jpeg0.80 |

Anomalia 17MB **resolvida**: era `linhas_producao.foto` cru (NÃO `barracoes.layout`, que
é só `{ordem,rotulos}` pequeno). `_supabase.storage` só é usado no **`bpf.html:9160-9214`**
(bucket **`documentos`**, modelo híbrido `url`/`path_storage`/`conteudo_base64`) — TEMPLATE
a seguir. **`backup.yml` só faz `pg_dump`, NÃO cobre Storage** (o "+Storage no backup" do 4.5 é step novo).

**Fase 1 FEITA (`50222a1`, no ar):** compressão canvas no `linhas.html:previewFotoLinha`
(maxD 1000, jpeg 0.82, = frota). Teste e2e: PNG 5.6MB → JPEG 109KB (−98,1%). Fotos
existentes encolhem quando o dono reenviar. Code-only, sem tocar no banco.

**Fase 2 — frota.documentos: FEITA no branch `feat/frota-docs-storage` (`0592e4a`, NÃO na main/prod).**
`uploadDocVeiculo` virou híbrido (≤4MB base64, >4MB → bucket `documentos`, fallback base64
se o Storage falhar); `renderDocsVeiculo` lê `data||url` (retrocompatível). Testado local:
≤4MB→base64, 5MB sob anon→fallback (sem crash), render dos dois formatos, 0 erro. **PENDENTE
p/ mergear:** o DONO testar o upload REAL autenticado (subir doc >4MB num veículo e ver ir
pro Storage), confirmar RLS/visibilidade do bucket `documentos`. Só então merge→main.

**Fase 2 (resto — sub-projeto, precisa BACKUP FRESCO + dono):** demais módulos reusando
o helper do bpf. Ordem por ganho: linhas.foto → frota.documentos (PDF/office crus) →
frota.foto/componentes → manutencao.fotos_servico → terceiros fotos/anexos. Assinaturas
(png canvas pequenas) por último/nem migra. Backfill dos base64 existentes (script único).
Migração ADITIVA em 3 deploys por módulo (protocolo #3). Adicionar step de backup do bucket
no `backup.yml`. Sites de escrita a mudar: `linhas.html:231/234/235`, `frota.html:2813-2827/
2250` e `:2154/2167/2248/2229/2257/2259`, `manutencao.html:3553/3544`, `terceiros.html:534-540/
548/544` e `:711-714/718/717`.

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

## Módulo Ensacadeiras (sessão 2026-10-08)

Pesagem saco a saco da **Linha 3** (2 bicos). Sem Node-RED.
- **Coletor** (`coletor-ensacadeira/`, fica FORA do repo — o `config.json` tem o token):
  Node.js puro (sem npm), tarefa do Windows "Silicate - Coletor Ensacadeira" que liga
  com o PC (SYSTEM, AtStartup, reinicia se cair). Lê Modbus TCP 192.168.0.7, unit 1/2,
  HR 80–85 a cada 100 ms. Captura no **SP1** (borda): 1º peso estável após 150 ms, ou
  mediana das 5 últimas em 1 s; rearme < 1 kg. Fila persistente `fila.json` + CSV mensal.
- **Banco** (migração 047): `ensacadeira_sacos` (1 linha/saco, `evento_id` único →
  reenvio não duplica), `ensacadeira_status` (upsert por linha+bico), `ensacadeira_tolerancias`,
  `ensacadeira_coletores` (só hash do token, sem policy). Coletor grava SÓ pela RPC
  `ensacadeira_enviar(p_token,…)` SECURITY DEFINER; anon não lê nem grava tabela nenhuma.
- **Tela** `ensacadeiras.html` (grupo Produção, abas aovivo/historico/config). Peso ao vivo
  por **Realtime broadcast** (canal `ens-<linha_id>`, coletor manda via REST
  `/realtime/v1/api/broadcast` ~5x/s; saco também vai pelo canal na hora). Cliente separado
  só para isso — o `_supabase` do ERP tem realtime desligado. Banco a cada 2 s como reserva.
- **v1.1 (mesmo dia)** — 1º teste real: unit 2 sem resposta travava o laço único → bico 1 lido
  ~1x/s → SP1 (pulso curto) perdido, 30 sacos e só 1 gravado. Corrigido: um laço e uma conexão
  por bico, bico mudo cai para 1 leitura/s, TID não exigido (casar pelo unit), e rede de
  segurança `sem_sp1` (grava na retirada o último peso estável). Tolerância padrão 10 kg −150/+200 g,
  20 kg −200/+300 g, 25 kg −250/+350 g — chute inicial, o dono ajusta na aba Configuração.
- **v1.2.0 — regra de captura do dono (09/10):** SP1 é o peso programado que fecha o pistão (ex.: 10,30).
  Grava a **1ª leitura com SP1=1** (`metodo='sp1'`), sem esperar estável — o estável do indicador sobe
  depois (10,80) e não é o peso real (balança de chão dá 10,10–10,20). Só conta saco que **começou do zero**
  (armou abaixo de `rearme_kg`) e chegou no SP1; pistão fechado antes do SP1 (entupimento) **não grava**.
  Rede de segurança `sem_sp1` e captura por estável/mediana **removidas**. `tempo_ms` = tempo de enchimento
  (saiu do zero → SP1). Tolerância acima do 10 kg subiu p/ 0,50 (leitura no SP1 ≈ 10,30–10,40).
- **Acompanhamento (048)** — topo da aba Ao vivo: turno **automático** (hora atual × `turnos.calendario`,
  só turnos da escala ativa; sobreposição → vale o que começou por último), encarregado e equipe da
  linha **automáticos** (blocos turno/turno2/turno3 da `escalas` ativa), produto escolhido e **fixado**
  (`ensacadeira_acompanhamento`, 1 aberto por linha), "Limpar tudo" fecha e abre outro. Tabela por bico
  (sacos, t, pallets = sacos ÷ `capacidades` do produto, médio, leves, sobrepeso, ritmo, eficiência vs
  `linhas_producao.produtos[].capHora` casado pela família `produtos.linhas`) + produção por hora.
  A RPC grava `produto` e `acompanhamento_id` em cada saco novo.
  **Toda a aba Ao vivo** (cards dos bicos, KPIs, gráficos, últimos sacos) conta a partir de `inicioVivo()`
  (início do acompanhamento → senão do turno → senão do dia): "Limpar tudo" zera a tela inteira.
  Histórico continua por data, sem relação com o acompanhamento.
  Modal do Limpar tudo tem 2 modos: "só zerar a tela" (padrão) ou "zerar e APAGAR o Histórico" — DELETE de
  `ensacadeira_sacos` da linha com `capturado_em < agora`; exige `ensacadeiras.historico:delete` + digitar APAGAR; vai pro addLog.
- **v1.3.0 + migração 049 (10/10):** coletor numa conexão só (fila serializada, timeout 300 ms, leitura
  prioritária do bico perto do SP1). **Nada abaixo de 10 kg vira saco** (coletor `captura.min_valido_kg` e
  a RPC também barra: só 10–100 kg). **Amostra:** subida do zero ao pico em < 1 s = amostra do bico →
  `ensacadeira_amostras` (não conta saco; canal `amostra`). **Níveis:** coletor lê os níveis programados
  (registrador em `config.json > niveis`, descoberto com `procurar-nivel.bat`) → `ensacadeira_status.sp1_prog..sp3_prog`;
  mudança vira linha em `ensacadeira_niveis_hist`. Tela: abas novas **Turnos** (cada turno do dia montado pelos
  sacos: 1º/último saco, sem movimento no início/fim, paradas > 5 min, status "pendente de ajuste" — só
  visualização, ajuste/fechamento a definir; **não grava nada em producao.html**), **Amostras**, **Níveis**.
  Ao vivo: bicos no topo; "Ritmo agora" = sacos dos últimos 10 min × 6; "Ritmo médio" = só tempo produzindo
  (intervalo > 5 min = parada); produção por hora só dentro do horário do turno. Histórico com coluna/filtro turno.
- ⚠️ Policies provisórias `ens_*` (da 1ª versão) ficaram restritas a `authenticated`;
  podem ser apagadas (a baseline cobre).

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

## Portaria × Carregamento (sessão 2026-10-10, migração 050)

- **portaria.html** reescrita, abas: Fila · Ordens de carregamento · Motoristas · Histórico.
- **Ordem em PDF**: arrasta/escolhe o PDF ou cola print (Ctrl+V). PDF com texto → pdf.js 3.11.174
  (cdnjs, carregado só quando usa); imagem ou PDF escaneado → Tesseract.js 5.1.1 ('por', jsdelivr).
  `lerOrdemDeTexto(pecas)` lê pela POSIÇÃO do texto (rótulo → valor abaixo; colunas pela linha de
  cabeçalho #/CLIENTE/PRODUTO/QTD./FRETE/UNIDADES; "Cidade/UF · PEDIDO"; mapa do baú "6º"+pedido).
  Testado com o modelo "ORDEM DE EMBARQUE E CARREGAMENTO RC-xxxxxx". Sempre abre **conferência
  editável** antes de salvar. PDF vai para Storage `documentos/portaria/ordens/`.
- **Banco (050)**: tabela `motoristas` (cadastro de carga; ≠ `lenha_motoristas`); `romaneios` + caminhao,
  paletes, bags, sacos, mapa (jsonb), arquivo_path, portaria_id, liberado_em/por; `romaneio_itens` + frete,
  unidades, ordem_entrega; `portaria` + romaneio_id, motorista_id, placa2, cpf, observacao, registrado_por,
  inicio_carregamento, iniciado_por, fura_fila_motivo, finalizado_por.
- **Fila**: ordem de chegada. Próximo da vez = 1º com ordem vinculada. Iniciar outro antes pede motivo
  (`fura_fila_motivo`, vai pro histórico/log). Sem ordem não perde a posição.
- **Status**: portaria `sem_ordem → aguardando → carregando → finalizado`; romaneio
  `recebido → em_carregamento (portaria liberou) → carregado (carregamento.html salvou) → finalizado (pesou saída)`.
- **carregamento.html**: lista padrão = "Liberadas pela portaria" (em_carregamento/carregado); modo pátio
  só mostra em_carregamento (ou carga já começada). `vigiarOrdensPortaria()` confere `romaneios` a cada 20 s
  (não roda com carga aberta) e avisa "Portaria liberou a ordem X".

## Certificado de análise na carga (sessão 2026-10-10, migração 051)

- Laudo continua por **OP** (laboratorio.html → aba Laudo; caulim saco, bag e granel — `_lauUnidade`: bag/granel = t).
- Ao **finalizar**, `_lauGravarArquivo()` grava a folha (`docCertificado`) em Storage `documentos/laudos/<numero>.html`
  → `lab_laudos.arquivo_path`. Laudo finalizado antes disso grava ao ser aberto. Link direto:
  `laboratorio.html?laudo=<id>&imprimir=1`.
- **js/certificados.js** (Carregamento e Portaria): `certVincularCarga()` ao salvar a carga — pallet → `producao_pallets.lancamento_id`
  (OP) → laudo finalizado → `lab_laudo_carregamentos` (origem 'carregamento', qtd/unidade/kg/cliente/ordem/placa). Granel (sem pallet)
  usa o laudo finalizado mais recente do produto, `sugerido=true`. OP sem laudo/rascunho → aviso "avise o Laboratório".
  `certDaCarga/certDaOrdem/certImprimir/certHtml` para listar e imprimir.
- Carregamento abre a carga salva com o bloco "📜 Certificado de análise" (botão "Buscar de novo"). Portaria mostra na pesagem de
  saída ("entregar ao motorista") e cita os números no romaneio de saída.
- Portaria: lixeira em ordens (qualquer situação sem pallet carregado; caminhão vinculado volta a "sem ordem"), fila,
  carregando (sem pallet) e histórico.
- **Iniciar carregamento (052)**: modal em 3 passos — confere caminhão/ordem (clientes e produtos), **tara obrigatória**
  (dica: última tara da placa) e **unidade de carregamento** (barracões: Unidade 01/02/03, multi). Botão só libera com tudo
  preenchido. Grava `portaria.peso_tara/tara_em/tara_por/unidade_carregamento` e `romaneios.unidade_carregamento`;
  carregamento.html mostra "🏭 Carregar na Unidade X" no card da ordem e no modo pátio.
- **Certificado POR LOTE (certificados.js)**: cada item da carga vai para o laudo do SEU lote (OP do pallet → lote bipado →
  granel sem lote = mais recente do produto). 13 bags 261002B + 13 bags 261003B = 2 linhas em `lab_laudo_carregamentos`
  (unidade 'bag'/'sc'/'t'). `certImprimir(laudoId, linkId)` injeta o quadro "Fornecimento (esta remessa)" (cliente,
  quantidade do lote, data, ordem, placa) na folha do Storage antes de "Identificação do produto".
- **Saída sem pallet (053)**: líquido da balança − nº pallets × `empresa_config.peso_pallet_kg` (28 kg; editar na saída
  vira padrão) = `peso_produto`. Nº de pallets = itens com pallet de produto em saco (bag e granel não contam), contado
  de `carregamentos.itens`. `peso_esperado` = sacos × `produtos.peso_unidade_kg` + bags + granel; tela mostra a diferença.
- **Fila (v5)**: uma lista só em grade — carregando (verde; verde-escuro = carregado, pesar) em cima, depois a fila por chegada.
  Quadro "Unidades" no topo (barracões) com a placa e o tempo de quem está carregando em cada uma. Sem coluna lateral.
- **Fechamento do dia (054)**: aba com KPIs do dia (caminhões, t de produto, sacos, bags, granel, pallets, tempos), tabela por
  caminhão (produtos do Carregamento; sem carga salva, da ordem) e resumo por grupo (`produtos.linhas[0]`) e por unidade
  (SC/UN/T). "Fechar o dia" grava `portaria_fechamentos` (1 por data, snapshot) e imprime A4 paisagem.
- **Produto da ordem × produtos.html (054)**: `casarProduto()` — apelido conferido (`produto_aliases`) → nome igual → parecido
  por palavras com peso/medida/tipo batendo (seguro só com folga; senão "⚠ confira"). Conferência da ordem tem a coluna
  "Produto no ERP"; salvar grava `romaneio_itens.produto_id/produto_erp` e o apelido. carregamento.html usa `produto_erp`.

### Portaria v6 (fila compacta, carga bipada, documentos da saída)
- Fila em linhas compactas (`.frow`): carregando no topo (verde), depois fila por `hora_chegada` com desempate `created_at`/`id` (`ordemChegada`). Editar chegada sem mexer na hora mantém a hora exata. "↩ Voltar para a fila" mantém a posição.
- Produto: ordem sem número de variação ("CAULIM BIG BAG – BRANCO") casa com a variação 01; com "02" no texto vale a 02.
- Motoristas: 👁️ visualizar (somente leitura, botão Editar), ✏️ editar, 🗑️ excluir.
- `cargaDaOrdem(numero)` lê `carregamentos.itens` (QR bipados) → grupos produto+lote. Aparece na pesagem de saída e em "Ver ordem". Na saída re-liga os lotes ao laudo (`certVincularCarga`).
- Ao confirmar saída abre `#m-docs`: romaneio de saída (bruto da portaria, pallets, carga conferida com certificado por lote, entregas, termo, 4 assinaturas) + 1 certificado por lote. Reimpressão pelo Histórico (🖨️).
- Certificado só existe se o Laboratório finalizou o laudo do lote; granel sem lote usa o último laudo finalizado do produto.

### Carregamento × Portaria (abas para encarregados)
- **📄 Ordens da portaria**: romaneios `recebido` (portaria ainda não clicou "Iniciar"). Mostra se o caminhão já está na fila (posição), pallets a separar, estoque liberado e onde está (barracão). Estoque é dividido na ordem da fila (`ordensEsperando` → `analisarItemOrdem(l,usado)`): a ordem do 1º caminhão usa primeiro.
- **🚪 Fila da portaria**: só leitura, lê `portaria` (sem_ordem/aguardando/carregando) com a mesma ordem da portaria.html (`_ordemChegada`). Atualiza a cada 20 s junto com `vigiarOrdensPortaria`.
- **Modo pátio**: 3 abas grandes (CARREGAR / ORDENS / FILA) — `_patioAba`, `patioOrdensHtml`, `patioFilaHtml`. Só CARREGAR abre câmera/carga.
  Tocar no card abre a ordem em tela cheia (`patioVerOrdem` → `#pt-ordem`, produtos + entregas + PDF), FECHAR volta para a mesma aba.
  ORDENS/FILA mostram só o que está na ordem (texto da ordem, sem conta de estoque, sem toneladas). Total = itens em pallet
  Visual por cor (público com pouca leitura): VERDE = pode carregar · AZUL = só ver (⛔ ainda não carrega) · AMARELO = esperando na portaria.
  Botões separados: ▶ CARREGAR (verde) e 👁️ VER ORDEM (contorno azul); a ordem aberta tem ⬅ VOLTAR e só mostra ▶ CARREGAR AGORA se liberada.
  (`romaneio_itens.unidades` com "N plt"; sem essa coluna → item com produto do ERP que não é bag/granel). Outros itens aparecem, mas fora do total (`resumoOrdemPatio`).
- Abas novas não estão em `MODULO_FUNCIONALIDADES` (utils.js) → aba sem registro = liberada.

### Aferidor — etiqueta de pallet em MEIA FOLHA A4 (econômica)
- Linhas que não são 25kg/bag/granel: `rotuloLabelHTMLSimples` agora é a metade de BAIXO da folha A4 (210 × 148 mm, laser); a metade de cima sai em branco (`paginaMeiaA4`).
- Economia de toner: sem faixa preta no produto, nº do pallet vazado (só contorno, `-webkit-text-stroke`), rótulos em cinza, linhas de 0,25 mm, logo pequeno em cinza (empresa_config.logo). Rodapé QUALIDADE sai SEMPRE com [X] APROVADO marcado (impressão é antes da análise; reprovado risca à mão / QR mostra a situação real). Sem campo "Visto".
- QR: correção Q, 44 mm máx./36 mín., tamanho exato para laser (`qrSvgLocal(..., pontosPorMm=23.6)`; a térmica continua com 8 pontos/mm). Testado: lê a 300 e a 100 dpi com borrão.
- Rótulo completo (25kg/bag/granel) mantém o layout; só tirou fundos cinza, bordas grossas e o quadrado cheio do logo.
- Big bag não é pallet: `_ehBag(pp)` / `_unid(pp)` trocam "Pallet" por "Bag" nas duas etiquetas, no seletor do modal e no aviso; rastreio.html mostra "Código do Bag" quando o produto é big bag.

### Portaria v7 (QR bipados, tolerância, fechamento)
- "🔎 Ver os N bipados" (saída e Ver ordem) abre `#m-qr` (`abrirBipados`): por produto+lote, um cartão por pallet/bag em ordem do nº do código (`-P001` → 1). Bag aparece como BAG.
- Líquido do produto × produto carregado: tolerância `TOL_KG=200` (±). Dentro = verde, fora = vermelho (saída, fechamento e romaneio impresso).
- Fechamento do dia: por caminhão 👁️ visualizar romaneio (sem imprimir, `imprimirSaida(id,true)`), 🖨️ reimprimir, ↩ `voltarParaCarregamento` (portaria → carregando, limpa saída/bruto; romaneio → em_carregamento para corrigir no Carregamento; depois pesa de novo). `acharPassagem()` acha o registro também no dia carregado do Fechamento.
- ↩ **Devolver ao carregamento (antes da saída, 055)**: na Fila (caminhão "carregado") e no modal de saída, `devolverAoCarregamento` → romaneio `em_carregamento` + `devolvido_em/devolvido_por`; a carga salva continua. Carregamento mostra "A PORTARIA DEVOLVEU"; o encarregado abre (CONTINUAR), tira pelo código (pátio: **🗑️ TIRAR PALLET/BAG DO CAMINHÃO** → lista por nº → `patioTirarConfirma`; computador: ✕), bipa outro e salva — o RPC devolve ao estoque o que saiu (`p_devolver`) e a ordem volta a `carregado`.

### Login (index.html) — foto na tela toda + logo gigante atrás do cartão (056)
- Fundo: img/hero.avif em tela cheia com véu navy; símbolo da Silicate em SVG (verde-limão) gigante atrás do cartão; nome da empresa vazado embaixo; hora/turno no canto. Sem avatar, sem logo pequena.
- Entra com **e-mail OU nome de usuário** (`usuarios.login`). Sem @ → `rpc('email_do_login')` → e-mail → `signInWithPassword`.
- "Lembrar de mim": guarda {ident, nome} em localStorage (`erp_login_email`) → cartão "Entrando como Luciano Brito [Trocar]", só pede a senha.
- Senha só de números: no celular (`html.movel`) o campo abre teclado numérico (`inputmode=numeric`); botão "Minha senha tem letras" troca e fica guardado (`erp_login_senha_letras`) — para quem ainda tem senha antiga.
- usuarios.html: campo "Nome de usuário" (sugere pelo 1º nome, sem repetir), mostrado na tabela; senhas novas/redefinidas só números, 6 a 12 (`SENHA_OK`).
- carregamento.html abre direto no MODO PÁTIO em celular/tablet (`ehCelularOuTablet`), salvo se a pessoa tocou em SAIR.

### Aviso de mudança no Status das Linhas (sessão 2026-10-13, migração 057 + função `push-linhas`)
- **Fonte**: gatilho `lab_status_linha` em `laboratorio` (insert/update de status/linha/data/hora). Mantém `linhas_status_atual`
  (status da análise mais nova de cada linha; análise atrasada mais velha não muda nada) e, quando o status MUDA, grava
  `linhas_status_eventos` + `realtime.send` no canal público `linhas-status` (evento `mudou`, payload só linha/status/produto/turno)
  + `net.http_post` (pg_net) na função `push-linhas`. Falha do aviso não trava o laboratório: fica em `push_resultado.erro_gatilho`.
- **Telas (opção 5)**: `js/alerta-linhas.js` (`AlertaLinhas.iniciar({aoMudar, faixa})`) no dashboard e no aferidor. Som gerado no
  navegador por status (OK ding-dong · Ajuste bipe · Manutenção 3 toques · Parada sirene, repete a cada 10 s até "OK, VI", máx. 5 min),
  aviso grande na cor do status no topo. Canal ao vivo + banco a cada 15 s (`id > último`); evento > 15 min não toca. Botão 🔔
  fixo: navegador exige 1 toque para liberar som (botão vermelho pisca até isso); menu testar/desligar nesta tela (localStorage
  `erp_alerta_som`)/celular. Aferidor ganhou a faixa "Status das Linhas" (`#al-faixa`, lê `linhas_status_atual`). Dashboard recarrega
  (`init({silencioso:true})`) quando muda. TV/PC fixo: Chrome com `--autoplay-policy=no-user-gesture-required` dispensa o toque.
- **Celular (opção 1, Web Push)**: menu 🔔 → "Receber avisos neste aparelho" → escolhe status → permissão → `pushManager.subscribe`
  → `push_inscricoes` (upsert por endpoint) → teste. Funciona com o ERP fechado e sem login (login só para cadastrar). iPhone só
  com o ERP na Tela de Início. Som = padrão do aparelho; Parada/Manutenção vibram mais e ficam na tela (`requireInteraction`).
  `sw.js` ganhou `push` + `notificationclick` (abre o dashboard).
- **Função `push-linhas`** (verify_jwt=false, auth própria): `chave` (gera o par VAPID na 1ª vez em `push_config` — sem policy,
  só service_role; a privada nunca sai do servidor), `enviar` (pega eventos pendentes de forma atômica, últimos 30 min, filtra
  por `status_filtro`/`linhas_filtro`, 404/410 desliga a inscrição), `teste` (exige JWT do usuário). `npm:web-push@3.6.7`
  (criptografia conferida no Deno: payload decifrado com http_ece, JWT VAPID válido). Código em `supabase/functions/push-linhas/`.

### App Android "Avisos Silicate" (sessão 2026-10-13, migração 058)
- Por quê: Web Push com o ERP fechado só toca o som padrão do celular (1 por site). O app toca o som de CADA status no volume de
  ALARME (sobe ao máximo enquanto toca e volta), mesmo no silencioso. Parada repete a cada 10 s até "OK, VI" (máx. 5 min).
- Código em `app-android/` (Java puro, sem AndroidX; OkHttp 4.12; minSdk 26, target 34; tela feita em código, sem XML de layout).
  **No GitHub vai zipado em `.github/app-android.zip`** (subir 1 arquivo pelo celular); `.github/workflows/apk-avisos.yml`
  descompacta, monta com Gradle 8.7/AGP 8.5.2 e publica `AvisosSilicate.apk` em Releases (tag `avisos-vN`, versionCode = run number,
  então instala por cima). Chave fixa `app-android/app/silicate-avisos.jks` (senha no build.gradle) — sem ela cada build teria
  assinatura diferente. `.vercelignore` tira `.github`/`app-android`/`*.jks` do site.
- Serviço em primeiro plano `specialUse` + wake lock parcial + pedido de "não otimizar bateria"; liga no boot e após atualizar.
  Escuta o canal Realtime `linhas-status` (WebSocket Phoenix, anon, canal público): qualquer `broadcast` = "vá conferir";
  confere via RPC `linhas_status_publico(p_desde_id)` (SECURITY DEFINER, anon; só últimos 30 min) a cada 30 s de reserva.
  Ao ligar não toca o passado; evento > 15 min não toca. Tela: estado, linhas agora (`linhas_status_atual_publico()`), abrir ERP
  (Chrome — WebView não imprime), escolher status (SharedPreferences), testar sons. Sons em `res/raw` (mesmos do js/alerta-linhas.js).
- Sem SDK Android no ambiente do Claude: compilado só contra stubs da API (javac) — 1º build real é no Actions.
- **📺 Painel de Metas por DLNA (TvDlna.java, sessão 2026-10-14):** para TVs sem Chromecast (Samsung/LG…). Código da TV digitado
  no app (prefs `tv_codigo`) → WebView invisível 1920×1080 abre `painel-metas.html?tv=COD&largura=1600&captura=1` (página fixa a
  viewport em 1600 CSS px, esconde botões e marca `window.__painelPronto` / `__painelErro`) → foto JPEG → servidorzinho HTTP no
  celular (porta 8077, headers DLNA JPEG_LRG) → SSDP M-SEARCH (MediaRenderer/AVTransport, MulticastLock) acha as TVs, lê a descrição
  (friendlyName + controlURL do AVTransport) → SOAP Stop + SetAVTransportURI (DIDL imageItem.photo) + Play. Repete a cada 5 min,
  "Mandar de novo agora", "Parar"; roda no AvisoService (WifiLock), volta sozinho após reiniciar (`tv_ativa`).
  `usesCleartextTraffic=true` (TV é http) + ACCESS_WIFI_STATE/CHANGE_WIFI_MULTICAST_STATE. Fluxo SOAP+foto testado contra TV falsa
  (Python): Stop → SetAVTransportURI → TV buscou a foto (image/jpeg) → Play. Captura da WebView fora da tela: não testável aqui.

### Painel de Metas para TV (`painel-metas.html`, sessões 2026-10-13/14, migração 059)
- Módulo `painel_metas` (grupo Produção, "Painel de Metas (TV)"). **v2 (pedido do dono): tela CLARA e linguagem simples**
  (público com fundamental incompleto): "Fizemos X sacos · A meta era Y · Faltaram Z" / "Passou Z da meta 👏"; "Máquina rodando:
  Rodou 13 horas e 16 min · A meta era … · Faltou …". Cabeçalho do cartão = 👍 BATEU / 👎 NÃO BATEU (meta de PRODUÇÃO).
  Frase do dia ("1 de 4 linhas bateu a meta…"), turnos 👍/👎, últimos 6 dias ✓/✗ e 🔥 sequência. Sem %, sem jargão, sem nomes.
  Meta mostrada em número inteiro arredondado para CIMA (não existe 0,2 saco); toneladas com 1 casa.
- Dia: ONTEM (Brasília); sem OP ontem → último dia com OP. `?data=` força. Atualiza a cada 5 min e na virada do dia; Wake Lock.
- Cálculo em `Regras.metaDaOP` (js/regras.js) — mesmas metas da OP (conferido em node contra efic_disp/efic_prod gravados).
  Turno PARADO conta meta cheia com 0; produto sem média/h fica fora (aviso); fontes de média/h deduplicadas por nome.
- **TV sem espelhar (059):** `painel_tv` (1 linha, código de 8 letras/números sem 0/O/1/I/L, sem policy) +
  `painel_tv_codigo(p_novo)` (logado; gera/troca) + `painel_tv_dados(p_codigo,p_ini,p_fim)` (anon; ≤62 dias; só OP sem
  encarregado/equipe, seções do planejamento, média/h das linhas, unidade dos produtos). Página: logado → tabelas; senão com
  `?tv=CODIGO` (guardado em localStorage `painel_tv_codigo`) → RPC; senão tela "digite o código". `vercel.json` rewrite `/tv`.
  Botão **📺 Passar para a TV** (logado): `PresentationRequest([painel-metas.html?tv=COD]).start()` → lista de Chromecast/Google TV
  do Chrome (a TV recebe a página; não é espelhamento) + plano B: navegador da TV em `<host>/tv` + código. "Trocar código"
  desliga TVs antigas. Bluetooth/DLNA/Miracast não são possíveis a partir de página web (sem API) — por isso Cast + código.
- **⚙️ Dia e linhas (060):** `painel_tv.config` jsonb `{dia, dia_ate, linhas}` — vale para TODAS as TVs (e a foto DLNA).
  `painel_tv_config_ler(p_codigo)` (logado sem código; TV com código) e `painel_tv_config_salvar(p_config)` (logado). Dia fixo
  vale até o fim de `dia_ate` (checkbox "Amanhã volta sozinho para o automático", padrão marcado) e depois volta para ontem.
  `linhas` null = todas (linha nova entra sozinha). `?data=` da URL ainda tem prioridade.

### Laboratório — Status das Linhas (correção 2026-10-14)
- Bug: o cartão só aceitava análise da MESMA data+turno da OP mais nova da linha; como a OP é lançada depois do turno, durante o
  turno a OP mais nova é a de ontem e o cartão ficava "Sem análise" com teste lançado (dashboard funcionava porque usa a última
  análise). Agora `renderDashLinhas` usa a **análise mais nova da linha** (data+hora) + selo de idade ("há 2 h" / "⚠️ há 3 dias");
  `carregarOpsDash` (🔄) só recarrega as análises. Clicar no cartão **abre a última análise** (`verAnalise`); "📋 todas" filtra a lista.
- `laboratorio.html?analise=<id>` abre a análise direto. Dashboard: cartão "Como a linha está agora" abre a última análise num
  modal (`verAnaliseLinha`, reaproveita `#modal-dia`) com botão "Ver análise completa no Laboratório →" (antes ia direto para o lab).

### Produção — MODO PÁTIO (sessão 2026-10-15)
- `producao.html` ganhou o **modo pátio** (`#pz`, funções `pz*`): abre sozinho em celular/tablet (`pzMovel`), `?patio=1` força,
  botão "📱 MODO PÁTIO" no topo; "🖥️ SAIR" volta para a tela normal e fica guardado (localStorage `erp_prod_modo_patio`).
- Público com pouca leitura: **uma pergunta por tela**, botão grande, sem sigla (horímetro = "relógio da máquina").
  Início: botão LANÇAR PRODUÇÃO + "O que já foi lançado" hoje/ontem (✅ por linha × turno; cinza "falta" já abre o lançamento
  com linha/dia/turno; linha que a escala não põe no turno não aparece; turno de hoje que não começou = "depois").
  Passos: linha → dia (hoje/ontem/anteontem/outro) → turno (aviso grande se já lançado = duplicaria) → quem trabalhou (vem da
  **escala** da semana: encarregado + membros da linha naquele turno) → produto (os da família da linha, ⭐ mais feitos primeiro;
  "ver todos") → relógio: começou em (maior H.F da linha, igual `lBuscarHorimetro`; corrigível) e quanto marcava no fim (valida
  menor/ >24 h; "76.743" = milhar) → quantidade: − N + por capacidade de pallet (bag = "bags", granel = "cargas de 14.000 kg"),
  sobra (num pallet / solta) e saco vazio estragado → outro produto? (o H.I encadeia no H.F) → paradas (turno tem / rodou /
  ficou parada, "falta explicar X"; motivo em botões + hora parou/voltou) → conferir (com "mudar" em cada item, 👍/👎 meta pelo
  `Regras.metaDaOP`, "mais informações": lenha, lote MP, lote aditivo, recado) → SALVAR.
- **Sem conta própria:** `pzSalvar()` abre o `#modal-lanc` escondido, preenche (data, linha, turno, encarregado, equipe,
  `addProdutoOP(dados)`, `addParadaOP(dados)`, extras) e chama o MESMO `salvarLanc()` — que agora **retorna true/false**
  (`_salvou` logo após o insert). Lote, pallets do estoque, horímetro da linha, baixa de insumos e efic_disp/efic_prod iguais
  ao computador. Recado vai em `obs` com prefixo "[pátio]". Testado com Playwright (mock): concentrado 19×180+60 = 3.480,
  bag, granel 4×14.000+2.800, parada, troca de dia/turno pela conferência (escala recarrega), desktop não abre sozinho.
- Vários produtos no turno (sem limite; o mesmo produto pode repetir): H.I de cada um = H.F do anterior (0→10, 10→20…);
  "Teve outro produto?" lista numerada + TOTAL DO TURNO (`pzSomaTxt`, soma por unidade). Conferência: com 1 produto mostra
  "Fizemos/meta/faltaram"; com vários, UM veredito do turno (`metaDaOP.producao.bateu`) + uma linha por produto.
  Nº da OP é gerado sozinho no salvar (`gerarNumOP`, OP-LLL-AAAAMMDD-NNNN) e aparece na tela "PRODUÇÃO SALVA".
  Testado: 4 produtos na Emitec (2 h cada, Liga repetido) → produtos_op com HI/HF encadeados, 5.580 sacos, ht 8.

## Felisbina — Grade do mês e Resumos (10/2026)
- Aba **Grade do mês** (`tab-grade`, permissão `felisbina.grade`): dias × itens do setor, igual às abas da planilha (SILICATE/TOPDRY/PREPARADOR/TINTAS). A célula é o TOTAL do dia daquele tipo; grava via RPC `felis_ajustar_dia` (migração 061), que substitui os lançamentos não-ficha do dia/tipo e, na produção, refaz a baixa pela ficha. Consumo de insumo: a célula manda no total, a parte da ficha fica.
- Aba **Resumos**: visões por setor (Overview produção/carregamento) e **Compilado de insumos**. Liberado = final + carregado. Estoque de segurança = `felis_itens.estoque_minimo`.

## Escala 5x2 — 42h (sessão 2026-10-17, base: "Plano_Escala_5x2_Silicate_V4")
- **Turnos novos** (os antigos ficaram intactos): `1º - Manhã 5x2 (42h)` 07:20–16:44 (almoço 11–12), `2º - Tarde 5x2 (42h)`
  16:24–01:19:30 (janta 19–20), `3º - Madrugada 5x2 (42h) L2` 00:59:30–07:40 na máquina (lanche 03–04; jornada até 09:20:30 em apoio).
  Máquina roda Seg–Sáb; cada pessoa faz 5 jornadas (folga rotativa). Passagem de 20 min nas trocas.
- **calendario._regime** = escala da PESSOA `{escala, jornadas, noturna:'nao'|'22-5'|'turno', fim_jornada}`. O calendário continua
  sendo o horário da MÁQUINA (Produção/Custo leem só os dias). turnos.html: `jornadaComputadaSeg` (hora noturna 52min30s; '22-5' CLT,
  'turno' = acordo no turno inteiro) → 8h24 × 5 = 42h nos três (conferido com o PDF; etapa 40h também fecha 8h00).
  Horários com segundos: `calcMinutos` ignora os segundos (máquina T = 7h55, N = 5h41).
- **custo-precificacao**: CP-0012 "Novembro/2026 — Escala 5x2 (42h)" = cópia do CP-0011 (out) com os turnos trocados
  (Manhã→M 5x2, Noite→T 5x2, Madrugada→N 5x2), calendário de nov (feriados 2, 15, 20; domingos folga) e 2 produtos novos no mapa.
  Equipes iguais às de outubro (as 13 contratações do plano ainda não existem no cadastro).
