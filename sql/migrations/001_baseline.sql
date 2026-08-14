-- ============================================================================
-- 001_baseline.sql — FOTO DO SCHEMA public em 14/08/2026
-- Projeto: erp-industrial (zodgbitbflkepbszshmu) · Postgres 17
-- Gerada a partir dos catálogos do banco (pg_catalog) já COM as migrations
-- 002/003/004 aplicadas. Uso: reconstruir um projeto de staging do zero.
-- A produção nunca "roda" este arquivo — ela já é o baseline.
-- ============================================================================

-- ── EXTENSÕES ───────────────────────────────────────────────────────────────
create extension if not exists "pgcrypto";
create extension if not exists "uuid-ossp";
create extension if not exists "pg_stat_statements";

-- ── TABELAS ─────────────────────────────────────────────────────────────────
create table public.abastecimento_bombas (
  id uuid default gen_random_uuid() not null,
  nome text not null,
  capacidade_litros numeric not null,
  litros_atual numeric default 0,
  combustivel text default 'diesel'::text,
  ativo boolean default true,
  created_at timestamp with time zone default now(),
  alerta_pct integer default 20,
  valor_litro numeric
);
create table public.abastecimento_entradas (
  id uuid default gen_random_uuid() not null,
  bomba_id uuid,
  data date not null,
  litros numeric not null,
  nf text,
  fornecedor text,
  almox_movimento_id uuid,
  responsavel text,
  obs text,
  created_at timestamp with time zone default now(),
  valor_danfe numeric,
  valor_litro numeric
);
create table public.abastecimento_registros (
  id uuid default gen_random_uuid() not null,
  bomba_id uuid,
  data timestamp with time zone default now(),
  veiculo_id uuid,
  veiculo_nome text,
  veiculo_placa text,
  horimetro_anterior numeric,
  horimetro_atual numeric,
  litros numeric not null,
  responsavel text,
  obs text,
  tipo_veiculo text default 'frota'::text,
  terceiro_nome text,
  created_at timestamp with time zone default now(),
  assinatura_responsavel text,
  assinatura_motorista text,
  operador text
);
create table public.aferidor_aditivacao (
  id uuid default gen_random_uuid() not null,
  numero text,
  data date,
  hora text,
  linha text,
  encarregado_turno text,
  responsavel_coleta text,
  lote_aditivo text,
  lancamento_id uuid,
  op_numero text,
  itens jsonb default '[]'::jsonb,
  criado_em timestamp with time zone default now(),
  atualizado_em timestamp with time zone default now()
);
create table public.almoxarifado (
  id uuid default uuid_generate_v4() not null,
  nome text not null,
  codigo text,
  categoria text,
  unidade text default 'kg'::text,
  estoque_atual numeric default 0,
  estoque_minimo numeric default 0,
  localizacao text,
  custo_unitario numeric,
  fornecedor text,
  created_at timestamp with time zone default now(),
  atualizado_em timestamp with time zone default now(),
  foto text,
  marca text,
  obs text,
  fornecedor_id uuid,
  is_insumo boolean default false,
  estoque_reservado numeric default 0,
  peso numeric,
  aditivo_g numeric,
  validade_dias integer,
  estoque_ideal numeric,
  estoque_maximo numeric,
  estoque_seguranca numeric,
  estoque_bloqueado numeric default 0,
  criticidade text,
  codigo_especificacao text,
  status text default 'ativo'::text,
  is_limpeza boolean default false,
  prazo_entrega_dias integer
);
create table public.almoxarifado_fornecedores (
  id uuid default gen_random_uuid() not null,
  razao_social text not null,
  nome_fantasia text,
  cnpj text,
  ie text,
  fone text,
  email text,
  contato text,
  categoria text,
  endereco text,
  prazo_pagamento text,
  obs text,
  created_at timestamp with time zone default now(),
  atualizado_em timestamp with time zone default now(),
  prazo_entrega integer,
  certificacoes text,
  status_homologacao text default 'em_analise'::text,
  documentacao text
);
create table public.almoxarifado_movimentos (
  id uuid default uuid_generate_v4() not null,
  insumo_id uuid,
  tipo text not null,
  quantidade numeric not null,
  data date,
  motivo text,
  solicitante text,
  nota_fiscal text,
  created_at timestamp with time zone default now(),
  perda numeric,
  fornecedor_destino text,
  valor_unitario numeric,
  linha text,
  obs text,
  centro_custo_id text,
  natureza text,
  natureza_id text,
  natureza_nome text,
  chave_acesso text,
  dt_emissao date,
  cfop text,
  natureza_operacao text,
  fornecedor_id uuid,
  responsavel text,
  numero_doc text,
  op_referencia text,
  lote text,
  validade date,
  tipo_mov text,
  peca_validada boolean default false,
  observacao text
);
create table public.almoxarifado_saida_assinaturas (
  numero_doc text not null,
  assin_solic text,
  assin_resp text,
  solicitante text,
  responsavel text,
  created_at timestamp with time zone default now()
);
create table public.almoxarifado_solicitacoes (
  id uuid default gen_random_uuid() not null,
  data date not null,
  solicitante text not null,
  prioridade text default 'normal'::text,
  status text default 'pendente'::text,
  centro_custo_id text,
  natureza text,
  fornecedor_sugerido text,
  obs text,
  produtos jsonb default '[]'::jsonb,
  created_at timestamp with time zone default now(),
  atualizado_em timestamp with time zone default now(),
  natureza_id text,
  natureza_nome text,
  assinatura text,
  assin_nome text,
  assin_cargo text,
  cotacao_itens jsonb default '[]'::jsonb,
  cotacao_comprador text,
  obs_cotacao text,
  aprovador_nome text,
  aprovador_cargo text,
  aprovador_assinatura text,
  comprado_por text,
  comprado_data date,
  numero text,
  obs_aprovacao text,
  cotacao_fornecedores jsonb default '[]'::jsonb,
  fornecedor_sugerido_id uuid,
  assinatura_comprador text,
  responsavel_solic text,
  programado text,
  programado_data date,
  programado_dias integer,
  compras_sol_id text,
  snapshot jsonb,
  aprovado_por text,
  aprovado_em timestamp with time zone
);
create table public.almoxarifado_solicitacoes_cadastro (
  id text not null,
  nome text,
  nome_base text,
  identificacao text,
  codigo_especificacao text,
  codigo_sugerido text,
  unidade text,
  custo_unitario numeric,
  origem text,
  equipamento text,
  data timestamp with time zone,
  status text default 'pendente'::text,
  motivo text,
  created_at timestamp with time zone default now()
);
create table public.app_preferencias (
  chave text not null,
  dados jsonb,
  atualizado_em timestamp with time zone default now()
);
create table public.auditoria (
  id uuid default uuid_generate_v4() not null,
  acao text not null,
  modulo text not null,
  registro_id text,
  descricao text,
  usuario_email text,
  criado_em timestamp with time zone default now()
);
create table public.barracoes (
  id uuid default gen_random_uuid() not null,
  nome text not null,
  linhas jsonb default '[]'::jsonb,
  ordem integer default 0,
  created_at timestamp with time zone default now(),
  layout jsonb default '{}'::jsonb
);
-- ── SEQUÊNCIAS ──────────────────────────────────────────────────────────────
create sequence if not exists public.lab_auditoria_campos_id_seq;
create sequence if not exists public.caulim_lote_transicoes_id_seq;
create sequence if not exists public.bpf_registro_trilha_id_seq;

create table public.bpf_sil004_registros (
  id uuid default gen_random_uuid() not null,
  producao_op_id text,
  data_registro date,
  hora_registro text,
  linha text,
  turno text,
  produto text,
  linha_produto text,
  encarregado_ref text,
  op_numero_ref text,
  c1 text, c2 text, c3 text, c4 text, c5 text, c6 text,
  obs text,
  assinatura_encarregado text,
  encarregado_nome text,
  assinatura_qualidade text,
  qualidade_nome text,
  status text default 'pendente'::text,
  created_at timestamp with time zone default now()
);
create table public.bpf_sil005_registros (
  id uuid default gen_random_uuid() not null,
  data date,
  hora_inicio text,
  hora_fim text,
  local_empresa text,
  terceirizada boolean default false,
  empresa_terceirizada text,
  certificado_url text,
  local_atividade text,
  executante_id text,
  executante_nome text,
  executante_funcao text,
  assinatura_executante text,
  assinatura_encarregado text,
  encarregado_nome text,
  assinatura_qualidade text,
  qualidade_nome text,
  obs text,
  status text default 'pendente'::text,
  created_at timestamp with time zone default now()
);
create table public.bpf_sil006_registros (
  id uuid default gen_random_uuid() not null,
  data date,
  hora_inicio text,
  hora_fim text,
  local_empresa text,
  terceirizada boolean default false,
  empresa_terceirizada text,
  certificado_url text,
  local_atividade text,
  executante_id text,
  executante_nome text,
  executante_funcao text,
  assinatura_executante text,
  assinatura_encarregado text,
  encarregado_nome text,
  assinatura_qualidade text,
  qualidade_nome text,
  obs text,
  status text default 'pendente'::text,
  created_at timestamp with time zone default now()
);
create table public.bpf_sil007_registros (
  id uuid default gen_random_uuid() not null,
  producao_op_id text,
  data_registro date,
  hora_registro text,
  linha text,
  turno text,
  produto text,
  linha_produto text,
  encarregado_ref text,
  op_numero_ref text,
  unidade text,
  lote text,
  c1 text, c2 text, c3 text, c4 text, c5 text, c6 text,
  obs text,
  executante_id text,
  executante_nome text,
  assinatura_executante text,
  assinatura_encarregado text,
  encarregado_nome text,
  assinatura_qualidade text,
  qualidade_nome text,
  status text default 'pendente'::text,
  created_at timestamp with time zone default now()
);
create table public.bpf_sil008_registros (
  id uuid default gen_random_uuid() not null,
  data date,
  rato_p1_data text, rato_p1_troca text, rato_p1_coment text,
  rato_p2_data text, rato_p2_troca text, rato_p2_coment text,
  rato_p3_data text, rato_p3_troca text, rato_p3_coment text,
  rato_p4_data text, rato_p4_troca text, rato_p4_coment text,
  rato_p5_data text, rato_p5_troca text, rato_p5_coment text,
  rato_p6_data text, rato_p6_troca text, rato_p6_coment text,
  pombo_local text,
  pombo_presenca text,
  pombo_fezes text,
  pombo_bloqueios text,
  pombo_coment text,
  executante_id text,
  executante_nome text,
  assinatura_executante text,
  assinatura_encarregado text,
  encarregado_nome text,
  assinatura_qualidade text,
  qualidade_nome text,
  status text default 'pendente'::text,
  obs text,
  created_at timestamp with time zone default now()
);
create table public.bpf_sil009_registros (
  id uuid default gen_random_uuid() not null,
  data date,
  hora_retirada text,
  executante_id text,
  executante_nome text,
  assinatura_executante text,
  assinatura_encarregado text,
  encarregado_nome text,
  assinatura_qualidade text,
  qualidade_nome text,
  obs text,
  status text default 'pendente'::text,
  created_at timestamp with time zone default now()
);
create table public.bpf_sil012_registros (
  id uuid default gen_random_uuid() not null,
  producao_op_id text,
  data_registro date,
  hora_registro text,
  linha text,
  turno text,
  produto text,
  linha_produto text,
  encarregado_ref text,
  op_numero_ref text,
  lote text,
  executante_id text,
  executante_nome text,
  assinatura_executante text,
  assinatura_encarregado text,
  encarregado_nome text,
  assinatura_qualidade text,
  qualidade_nome text,
  obs text,
  status text default 'pendente'::text,
  created_at timestamp with time zone default now()
);
create table public.bpf_sil015_registros (
  id uuid default gen_random_uuid() not null,
  producao_op_id text,
  data_registro date,
  hora_registro text,
  linha text,
  turno text,
  produto text,
  linha_produto text,
  encarregado_ref text,
  op_numero_ref text,
  lote text,
  equipamento text,
  peso_verificado text,
  conforme text,
  executante_id text,
  executante_nome text,
  assinatura_executante text,
  assinatura_encarregado text,
  encarregado_nome text,
  assinatura_qualidade text,
  qualidade_nome text,
  obs text,
  status text default 'pendente'::text,
  created_at timestamp with time zone default now()
);
create table public.bpf_sil018_registros (
  id uuid default gen_random_uuid() not null,
  op_id text,
  data date,
  linha text,
  turno text,
  op_numero text,
  executante_id text,
  executante_nome text,
  q1 text, q2 text, q3 text, q4 text, q5 text,
  q6 text, q7 text, q8 text, q9 text, q10 text,
  obs018 text,
  assinatura_executante text,
  assinatura_qualidade text,
  qualidade_nome text,
  status text default 'pendente'::text,
  created_at timestamp with time zone default now()
);
create table public.bpf_sil_acesso (
  perfil_cod text not null,
  sils jsonb
);
create table public.bpf_sil_objetivos (
  id uuid default gen_random_uuid() not null,
  sil_cod text not null,
  descricao text,
  freq_exec_dias integer,
  freq_encar_dias integer,
  freq_qual_dias integer,
  tempo_ref text,
  atualizado_em timestamp with time zone default now(),
  atualizado_por text
);
create table public.bpf_transicoes_cor (
  id uuid default gen_random_uuid() not null,
  data date default CURRENT_DATE not null,
  hora time without time zone,
  linha text,
  lote_origem text not null,
  variacao_origem text,
  lote_seguinte text,
  variacao_seguinte text,
  quantidade_descartada numeric,
  unidade text default 'kg'::text,
  destino text not null,
  responsavel text,
  registro_id uuid,
  obs text,
  created_at timestamp with time zone default now()
);
create table public.bpf_travas (
  codigo text not null,
  sys_ref text not null,
  nome text not null,
  descricao text,
  pop_cod text,
  modulo_alvo text,
  severidade text default 'bloqueio'::text,
  ativa boolean default false,
  ativada_em timestamp with time zone,
  ativada_por text,
  obs text
);
create table public.bpf_treinamentos (
  id uuid default gen_random_uuid() not null,
  procedimento_cod text,
  data date,
  instrutor_id uuid,
  instrutor_nome text,
  carga_horaria integer,
  participantes_ids uuid[],
  num_participantes integer default 0,
  conteudo text,
  created_at timestamp with time zone default now()
);
create table public.bpf_visitante_acessos (
  id uuid default gen_random_uuid() not null,
  visitante_id uuid not null,
  data date default CURRENT_DATE not null,
  hora_entrada time without time zone,
  hora_saida time without time zone,
  areas jsonb default '[]'::jsonb,
  acompanhante text,
  placa text,
  motivo text,
  autorizado_por text,
  registro_id uuid,
  created_at timestamp with time zone default now()
);
create table public.bpf_visitantes (
  id uuid default gen_random_uuid() not null,
  nome text not null,
  documento text,
  empresa text,
  tipo text default 'visitante'::text,
  telefone text,
  video_assistido_em timestamp with time zone,
  integracao_validade date,
  integracao_path text,
  status text default 'pendente'::text,
  created_at timestamp with time zone default now()
);
create table public.carregamentos (
  id uuid default gen_random_uuid() not null,
  ordem_numero text,
  data date,
  hora text,
  motorista text,
  placa text,
  transportadora text,
  total_pallets integer default 0,
  itens jsonb default '[]'::jsonb,
  created_at timestamp with time zone default now()
);
create table public.caulim_analises_externas (
  id uuid default gen_random_uuid() not null,
  tipo text not null,
  variacao_principal_id uuid not null,
  numero_relatorio text,
  data_liberacao date not null,
  validade date not null,
  valores jsonb not null,
  valor_dentro_limite_legal boolean default true not null,
  pdf_anexo text,
  status text default 'vigente'::text not null,
  substitui_id uuid,
  criado_em timestamp with time zone default now() not null
);
create table public.caulim_certificados (
  id uuid default gen_random_uuid() not null,
  lote_producao_id uuid not null,
  numero text,
  dados_snapshot jsonb not null,
  emitido_por text not null,
  emitido_em timestamp with time zone default now() not null
);
create table public.caulim_clientes (
  id uuid default gen_random_uuid() not null,
  nome text not null,
  ativo boolean default true not null
);
create table public.caulim_homologacoes (
  id uuid default gen_random_uuid() not null,
  variacao_id uuid not null,
  cliente_id uuid not null,
  nome_interno text not null,
  status text default 'em_homologacao'::text not null,
  ficha_tecnica_pdf text,
  padrao_qc jsonb,
  config_linha jsonb,
  criado_em timestamp with time zone default now() not null
);
create table public.caulim_lote_transicoes (
  id bigint default nextval('caulim_lote_transicoes_id_seq'::regclass) not null,
  lote_producao_id uuid not null,
  de_status text,
  para_status text not null,
  autor text not null,
  motivo text,
  data timestamp with time zone default now() not null
);
create table public.caulim_lotes_mp (
  id uuid default gen_random_uuid() not null,
  numero text not null,
  frente_id uuid not null,
  mistura_pct numeric,
  montante_t numeric,
  data date not null,
  variacao_declarada_id uuid not null,
  cor_l numeric,
  cor_a numeric,
  cor_b numeric,
  delta_e numeric,
  cor_aprovada boolean,
  granulometria jsonb,
  umidade_pct numeric,
  analista_mp text not null,
  criado_em timestamp with time zone default now() not null
);
create table public.caulim_lotes_producao (
  id uuid default gen_random_uuid() not null,
  numero text not null,
  lote_mp_id uuid not null,
  homologacao_id uuid,
  estrategia text default 'B'::text not null,
  status text default 'aberto'::text not null,
  autorizacao_estrategia_a jsonb,
  granulometria_consolidada jsonb,
  umidade_final_pct numeric,
  ponto_corte_amostra_id uuid,
  motivo_bloqueio text,
  data_abertura timestamp with time zone default now() not null,
  data_fechamento timestamp with time zone,
  mm_result numeric,
  peso_esp_result numeric
);
create table public.caulim_minas_frentes (
  id uuid default gen_random_uuid() not null,
  nome text not null,
  ativo boolean default true not null,
  criado_em timestamp with time zone default now() not null
);
create table public.caulim_unidades (
  id uuid default gen_random_uuid() not null,
  lote_producao_id uuid not null,
  tipo text not null,
  qr_codigo text not null,
  sequencial integer not null,
  status text default 'disponivel'::text not null,
  criado_em timestamp with time zone default now() not null
);
create table public.caulim_variacoes (
  id uuid default gen_random_uuid() not null,
  codigo text not null,
  nome text not null,
  std_l numeric not null,
  std_a numeric not null,
  std_b numeric not null,
  delta_e_max numeric default 2.0 not null,
  ativo boolean default true not null
);
create table public.centros_custo (
  id uuid default uuid_generate_v4() not null,
  codigo text not null,
  nome text not null,
  tipo text not null,
  referencia_id uuid,
  referencia_nome text,
  meta_custo_mensal numeric default 0,
  status text default 'ativo'::text,
  criado_em timestamp with time zone default now()
);
create table public.compras_contratos (
  id uuid default gen_random_uuid() not null,
  fornecedor_id uuid,
  fornecedor text,
  descricao text,
  inicio date,
  fim date,
  valor numeric,
  status text default 'ativo'::text,
  obs text,
  created_at timestamp with time zone default now()
);
create table public.compras_cotacoes (
  id uuid default gen_random_uuid() not null,
  numero integer,
  solicitacao_id uuid,
  data date default CURRENT_DATE,
  comprador text,
  status text default 'aberta'::text,
  propostas jsonb default '[]'::jsonb,
  fornecedor_escolhido_id uuid,
  fornecedor_escolhido text,
  justificativa_escolha text,
  created_at timestamp with time zone default now(),
  atualizado_em timestamp with time zone default now(),
  historico jsonb,
  obs text
);
create table public.compras_nc (
  id uuid default gen_random_uuid() not null,
  pedido_id uuid,
  fornecedor_id uuid,
  fornecedor text,
  data date default CURRENT_DATE,
  descricao text,
  gravidade text default 'media'::text,
  status text default 'aberta'::text,
  resolucao text,
  created_at timestamp with time zone default now()
);
create table public.compras_pedidos (
  id uuid default gen_random_uuid() not null,
  numero integer,
  solicitacao_id uuid,
  cotacao_id uuid,
  data date default CURRENT_DATE,
  comprador text,
  fornecedor_id uuid,
  fornecedor text,
  condicao_pagamento text,
  prazo_entrega date,
  status text default 'emitido'::text,
  valor_total numeric default 0,
  itens jsonb default '[]'::jsonb,
  historico jsonb default '[]'::jsonb,
  created_at timestamp with time zone default now(),
  atualizado_em timestamp with time zone default now(),
  obs text
);
create table public.compras_recebimentos (
  id uuid default gen_random_uuid() not null,
  pedido_id uuid,
  numero integer,
  data date default CURRENT_DATE,
  recebido_por text,
  itens jsonb default '[]'::jsonb,
  nota_fiscal text,
  obs text,
  nao_conforme boolean default false,
  created_at timestamp with time zone default now(),
  valor_total_geral numeric,
  desconto numeric,
  frete numeric,
  valor_final numeric,
  historico jsonb
);
create table public.compras_solicitacoes (
  id uuid default gen_random_uuid() not null,
  numero integer,
  data date default CURRENT_DATE,
  solicitante text,
  solicitante_perfil text,
  centro_custo text,
  prioridade text default 'normal'::text,
  justificativa text,
  excesso_justificativa text,
  status text default 'pendente'::text,
  origem text,
  origem_ref text,
  equipamento text,
  itens jsonb default '[]'::jsonb,
  aprovador text,
  aprovado_em timestamp with time zone,
  obs_aprovacao text,
  historico jsonb default '[]'::jsonb,
  created_at timestamp with time zone default now(),
  atualizado_em timestamp with time zone default now(),
  responsavel_solic text,
  programado text,
  programado_data date,
  programado_dias integer,
  codigo text,
  origem_id text,
  snapshot jsonb
);
create table public.desgaste_estoque (
  id uuid default gen_random_uuid() not null,
  peca text not null,
  condicao text not null,
  identificacao text,
  quantidade integer not null,
  peso_unitario numeric(12,3),
  fornecedor text,
  obs text,
  data_entrada date default CURRENT_DATE not null,
  status text default 'disponivel'::text not null,
  registro_id uuid,
  usado_em timestamp with time zone,
  criado_em timestamp with time zone default now() not null,
  criado_por text,
  peso_total numeric(12,3),
  foto text,
  foto_thumb text,
  tem_foto boolean generated always as (foto IS NOT NULL) stored
);
create table public.desgaste_padroes (
  peca text not null,
  peso_novo numeric(12,3),
  peso_descarte numeric(12,3),
  atualizado_em timestamp with time zone default now() not null,
  atualizado_por text
);
create table public.desgaste_registros (
  id uuid default gen_random_uuid() not null,
  peca text not null,
  linha text not null,
  tipo text,
  data_retirada date not null,
  data_devolucao date,
  peso_inicial numeric(12,2) not null,
  peso_final numeric(12,2),
  horimetro_inicial numeric(12,2),
  horimetro_final numeric(12,2),
  producao_sacos integer,
  fornecedor text,
  obs text,
  foto_entrada text,
  foto_saida text,
  tem_foto_entrada boolean generated always as (foto_entrada IS NOT NULL) stored,
  tem_foto_saida boolean generated always as (foto_saida IS NOT NULL) stored,
  criado_em timestamp with time zone default now() not null,
  criado_por text,
  foto_entrada_thumb text,
  foto_saida_thumb text,
  quantidade integer,
  peso_unitario numeric(12,3),
  quantidade_descarte integer,
  peso_unitario_descarte numeric(12,3)
);
create table public.eletrica_medicoes (
  id text not null,
  data date,
  equipamento text,
  linha text,
  componente text,
  responsavel text,
  cv text,
  kw text,
  rpm text,
  fabricante text,
  modelo text,
  tensao_nominal text,
  corrente_nominal text,
  corr_r text,
  corr_s text,
  corr_t text,
  tens_r text,
  tens_s text,
  tens_t text,
  temperatura text,
  temp_limite text,
  isolamento text,
  isol_min text,
  obs text,
  foto text,
  criado_em timestamp with time zone
);
create table public.empresa_config (
  id uuid default uuid_generate_v4() not null,
  razao_social text,
  nome_fantasia text,
  cnpj text,
  ie text,
  rua text,
  numero text,
  bairro text,
  cidade text,
  estado text,
  cep text,
  telefone text,
  email text,
  logo text,
  criado_em timestamp with time zone default now(),
  atualizado_em timestamp with time zone default now(),
  uf text,
  complemento text,
  dias_alerta_epi integer default 5,
  eficiencia_meta integer default 85,
  obs text
);
create table public.epi_cadastro (
  id uuid default uuid_generate_v4() not null,
  nome text not null,
  ca text,
  validade_ca date,
  periodicidade_dias integer,
  unidade text default 'unidade'::text,
  estoque_atual numeric default 0,
  estoque_minimo numeric default 0,
  custo_unitario numeric,
  created_at timestamp with time zone default now(),
  descricao text,
  categoria text,
  imagem_url text,
  pdf_url text,
  pdf_nome text
);
create table public.epi_entregas (
  id uuid default uuid_generate_v4() not null,
  funcionario_id uuid,
  epi_id uuid,
  data_entrega date,
  quantidade numeric default 1,
  validade date,
  data_prevista_troca date,
  status text default 'em_dia'::text,
  assinatura text,
  created_at timestamp with time zone default now()
);
create table public.epi_treinamentos (
  id uuid default gen_random_uuid() not null,
  funcionario_id uuid,
  nome text not null,
  carga_horaria integer,
  instrutor text,
  data_realizacao date not null,
  validade date,
  obs text,
  cert_url text,
  cert_nome text,
  cert_tipo text,
  created_at timestamp with time zone default now()
);
create table public.equipamentos_gerais (
  id uuid default uuid_generate_v4() not null,
  nome text not null,
  codigo text not null,
  centro_custo text,
  local text,
  fabricante text,
  modelo text,
  serie text,
  patrimonio text,
  horimetro numeric default 0,
  aquisicao date,
  status text default 'ativo'::text,
  obs text,
  componentes jsonb default '[]'::jsonb,
  ordem integer default 0,
  criado_em timestamp with time zone default now(),
  atualizado_em timestamp with time zone default now(),
  localizacao text,
  foto text,
  criticidade text
);
create table public.equipamentos_linhas (
  id uuid default uuid_generate_v4() not null,
  nome text not null,
  codigo text not null,
  centro_custo text,
  linha text,
  fabricante text,
  modelo text,
  serie text,
  patrimonio text,
  horimetro numeric default 0,
  aquisicao date,
  status text default 'ativo'::text,
  obs text,
  componentes jsonb default '[]'::jsonb,
  ordem integer default 0,
  criado_em timestamp with time zone default now(),
  atualizado_em timestamp with time zone default now(),
  foto text,
  criticidade text
);
create table public.escalas (
  id uuid default gen_random_uuid() not null,
  nome text not null,
  periodo_inicio date,
  periodo_fim date,
  turno_id text,
  turno_nome text,
  status text default 'rascunho'::text,
  encarregado jsonb,
  operador jsonb,
  linhas jsonb default '[]'::jsonb,
  limpeza jsonb default '[]'::jsonb,
  ferias jsonb default '[]'::jsonb,
  ausencias jsonb default '[]'::jsonb,
  observacoes text,
  assinatura_encarregado text,
  assinatura_responsavel text,
  historico jsonb default '[]'::jsonb,
  criado_em timestamp with time zone default now(),
  atualizado_em timestamp with time zone default now(),
  assinatura_resp_id text,
  assinatura_img text,
  turno2 jsonb
);
create table public.expedicao (
  id uuid default uuid_generate_v4() not null,
  numero_ordem text not null,
  cliente text not null,
  produto text not null,
  quantidade numeric,
  data_prevista date,
  status text default 'pendente'::text,
  motorista text,
  placa text,
  obs text,
  created_at timestamp with time zone default now(),
  atualizado_em timestamp with time zone default now()
);
create table public.expedicao_ordens (
  id uuid default gen_random_uuid() not null,
  numero_ordem text not null,
  status text default 'pendente'::text,
  data_emissao date,
  data_prevista date,
  cliente text not null,
  destino text,
  tipo_veiculo text default 'carreta'::text,
  motorista text,
  placa text,
  transportadora text,
  nf text,
  obs text,
  itens jsonb default '[]'::jsonb,
  sequencia_carga jsonb default '[]'::jsonb,
  total_sacos numeric default 0,
  total_kg numeric default 0,
  total_pallets integer default 0,
  atualizado_em timestamp with time zone default now(),
  created_at timestamp with time zone default now(),
  pedidos_ids text,
  cap_kg numeric
);
create table public.expedicao_pedidos (
  id uuid default gen_random_uuid() not null,
  numero text not null,
  cliente text not null,
  cidade text,
  data_pedido date,
  data_prevista date,
  palete text default 'FÁBRICA'::text,
  retira boolean default false,
  transportadora text,
  motorista text,
  placa text,
  itens jsonb default '[]'::jsonb,
  obs text,
  status text default 'pendente'::text,
  created_at timestamp with time zone default now()
);
create table public.fechamentos_custo (
  id uuid default gen_random_uuid() not null,
  mes text not null,
  fechado_em timestamp with time zone,
  fechado_por text,
  total_lancamentos integer default 0,
  created_at timestamp with time zone default now()
);
create table public.folha_dados_funcionario (
  id uuid default gen_random_uuid() not null,
  funcionario_id uuid not null,
  dados jsonb not null,
  atualizado_em timestamp with time zone default now()
);
create table public.folhas_pagamento (
  id uuid default gen_random_uuid() not null,
  codigo text not null,
  numero integer not null,
  nome text,
  mes integer not null,
  ano integer not null,
  dados jsonb not null,
  status text default 'ativo'::text,
  criado_por text,
  created_at timestamp with time zone default now(),
  atualizado_em timestamp with time zone default now(),
  totais jsonb
);
create table public.frota_empresas (
  id uuid default gen_random_uuid() not null,
  nome text not null,
  tipo text default 'empresa'::text,
  especialidade text,
  fone text,
  doc text,
  email text,
  contato text,
  obs text,
  created_at timestamp with time zone default now(),
  atualizado_em timestamp with time zone default now()
);
create table public.frota_veiculos (
  id uuid default uuid_generate_v4() not null,
  nome text not null,
  tipo text default 'empilhadeira'::text,
  placa text,
  marca text,
  modelo text,
  ano integer,
  tipo_revisao text default 'horas'::text,
  revisao_horas numeric,
  horimetro_atual numeric default 0,
  proxima_revisao date,
  obs text,
  status text default 'ativo'::text,
  atualizado_em timestamp with time zone default now(),
  created_at timestamp with time zone default now(),
  foto text,
  componentes jsonb default '[]'::jsonb,
  empresa_resp text,
  revisao_dias integer,
  documentos jsonb default '[]'::jsonb,
  tipo_controle text default 'horas'::text,
  sistemas_info jsonb default '{}'::jsonb,
  planos jsonb default '[]'::jsonb,
  inspecoes jsonb default '[]'::jsonb,
  proxima_revisao_data date
);
create table public.funcionarios (
  id uuid default uuid_generate_v4() not null,
  nome text not null,
  cpf text,
  rg text,
  nascimento date,
  telefone text,
  email text,
  funcao text,
  setor text,
  turno text,
  linha text,
  centro_custo text,
  admissao date,
  demissao date,
  status text default 'ativo'::text,
  foto text,
  obs text,
  criado_em timestamp with time zone default now(),
  atualizado_em timestamp with time zone default now(),
  certificacoes jsonb,
  custos jsonb
);
create table public.inspecoes (
  id text not null,
  data date,
  equipamento text,
  linha text,
  componente text,
  responsavel text,
  condicao text,
  checklist jsonb,
  obs text,
  foto text,
  assinatura text,
  criado_em timestamp with time zone
);
create table public.insumos (
  id uuid default gen_random_uuid() not null,
  codigo text,
  nome text not null,
  grupo text not null,
  subgrupo text,
  tipo text not null,
  unidade_estoque text not null,
  unidade_consumo text,
  fator_conversao numeric(14,4) default 1,
  estoque_minimo numeric(14,3) default 0,
  estoque_maximo numeric(14,3),
  cobertura_min_dias integer,
  custo_unitario numeric(14,4),
  cor_hex text default '#64748b'::text,
  ordem integer default 0,
  controla_lote boolean default false,
  controla_qualidade boolean default false,
  retornavel boolean default false,
  exibir_ficha boolean default true,
  produto_vinculado text,
  localizacao text,
  fornecedor text,
  fornecedor_id uuid,
  status text default 'ativo'::text,
  obs text,
  criado_em timestamp with time zone default now(),
  atualizado_em timestamp with time zone default now()
);
create table public.insumos_fechamentos (
  id uuid default gen_random_uuid() not null,
  data date not null,
  payload jsonb not null,
  versao integer default 1,
  gerado_por text,
  gerado_em timestamp with time zone default now(),
  enviado_em timestamp with time zone,
  obs text
);
create table public.insumos_ficha (
  id uuid default gen_random_uuid() not null,
  produto text not null,
  insumo_id uuid not null,
  qtd_por numeric(14,6) not null,
  base text default 'unidade'::text not null,
  perda_pct numeric(8,3) default 0,
  tolerancia_pct numeric(8,3),
  peso_unidade_kg numeric(14,3),
  sacos_por_pallet integer,
  unidades_por_caixa integer,
  criado_em timestamp with time zone default now(),
  atualizado_em timestamp with time zone default now(),
  modo text default 'multiplicar'::text,
  usar_pallets_reais boolean default false,
  usar_perda_op boolean default false,
  ordem integer default 0
);
create table public.insumos_grupos (
  id uuid default gen_random_uuid() not null,
  nome text not null,
  ordem integer default 0,
  cor_hex text default '#64748b'::text,
  ativo boolean default true,
  criado_em timestamp with time zone default now(),
  oculto boolean default false
);
create table public.insumos_inventarios (
  id uuid default gen_random_uuid() not null,
  data date default CURRENT_DATE not null,
  insumo_id uuid not null,
  contado numeric(14,3) not null,
  saldo_sistema numeric(14,3) not null,
  divergencia numeric(14,3) not null,
  responsavel text,
  obs text,
  criado_em timestamp with time zone default now()
);
create table public.insumos_lotes (
  id uuid default gen_random_uuid() not null,
  insumo_id uuid not null,
  lote text not null,
  validade date,
  qtd_inicial numeric(14,3) default 0 not null,
  saldo numeric(14,3) default 0 not null,
  custo_unitario numeric(14,4),
  resultados jsonb default '{}'::jsonb,
  status text default 'liberado'::text,
  nota_fiscal text,
  fornecedor text,
  criado_em timestamp with time zone default now()
);
create table public.insumos_movimentos (
  id uuid default gen_random_uuid() not null,
  insumo_id uuid not null,
  lote_id uuid,
  data date default CURRENT_DATE not null,
  tipo text not null,
  quantidade numeric(14,3) not null,
  qtd_teorica numeric(14,3),
  custo_unitario numeric(14,4),
  origem text,
  origem_id text,
  fornecedor_destino text,
  responsavel text,
  motivo text,
  obs text,
  criado_em timestamp with time zone default now(),
  produto text
);
create table public.insumos_preferencias (
  chave text not null,
  valor jsonb not null,
  atualizado_em timestamp with time zone default now()
);
create table public.lab_auditoria_campos (
  id bigint default nextval('lab_auditoria_campos_id_seq'::regclass) not null,
  tabela text not null,
  registro_id uuid not null,
  campo text not null,
  valor_anterior text,
  valor_novo text,
  usuario text,
  data timestamp with time zone default now() not null
);
create table public.lab_config_lote_pallets (
  id uuid default gen_random_uuid() not null,
  produto_id uuid,
  linha text,
  qtd_maxima_pallets integer default 1 not null,
  ativo boolean default true not null,
  criado_em timestamp with time zone default now() not null
);
create table public.lab_laudo_carregamentos (
  id uuid default gen_random_uuid() not null,
  laudo_id uuid not null,
  carregamento_id uuid,
  romaneio_id uuid,
  data date default CURRENT_DATE not null,
  cliente text,
  cliente_id uuid,
  pedido_numero text,
  quantidade numeric not null,
  unidade text,
  peso_kg numeric,
  created_at timestamp with time zone default now()
);
create table public.lab_laudo_sequencia (
  ano integer not null,
  ultimo integer default 0 not null
);
create table public.lab_laudos (
  id uuid default gen_random_uuid() not null,
  numero text,
  tipo text not null,
  referencia_id text not null,
  produto text,
  dados_snapshot jsonb not null,
  responsavel text not null,
  assinatura_hash text,
  emitido_em timestamp with time zone default now() not null,
  producao_id uuid,
  op_numero text,
  lote text,
  lote_mp text,
  data_fabricacao date,
  validade date,
  embalagem text,
  qtd_produzida numeric,
  unidade_qtd text,
  analise_quimica jsonb,
  granulometria jsonb,
  umidade_max numeric,
  umidade_result numeric,
  veredito text,
  observacao text,
  status text default 'rascunho'::text,
  aprovador_pallets text,
  aprovador_pallets_id uuid,
  responsavel_id uuid,
  responsavel_cargo text,
  assinado_em timestamp with time zone,
  variacao text,
  frente_extracao text,
  classificacao text default 'Veículo Mineral'::text,
  mm_result numeric,
  mm_min numeric,
  peso_esp_result numeric,
  peso_esp_min numeric,
  peso_esp_max numeric,
  total_retido_result numeric,
  total_retido_min numeric,
  total_retido_max numeric,
  analises_externas jsonb default '[]'::jsonb,
  rt_nome text,
  rt_crea text,
  validade_anos integer default 3,
  composicao_txt text,
  modo_usar text,
  precaucoes text,
  registro_txt text,
  total_retido_espec text,
  ensaios_fora jsonb
);
create table public.lab_limites_agua_traco (
  id uuid default gen_random_uuid() not null,
  traco_id uuid not null,
  limite_inf_ml numeric,
  limite_sup_ml numeric
);
create table public.lab_limites_quimicos (
  id uuid default gen_random_uuid() not null,
  produto text not null,
  cliente_id uuid,
  oxido text not null,
  ordem integer default 0,
  minimo numeric,
  maximo numeric,
  ativo boolean default true,
  criado_por text,
  created_at timestamp with time zone default now(),
  atualizado_em timestamp with time zone default now()
);
create table public.lab_pallet_analises (
  id uuid default gen_random_uuid() not null,
  pallet_id uuid,
  lancamento_id uuid,
  produto_id uuid,
  produto text,
  linha text,
  turno text,
  data date default CURRENT_DATE not null,
  hora time without time zone,
  pallet_numero integer,
  intervalo_ini integer,
  intervalo_fim integer,
  pallets_ids jsonb default '[]'::jsonb not null,
  responsavel text,
  responsavel_id uuid,
  traco_id uuid,
  traco_nome text,
  lote_areia text,
  qtd_produto_g numeric,
  densidade numeric,
  agua_ml numeric,
  umidade numeric,
  peso_amostra_g numeric,
  granulometria jsonb default '[]'::jsonb not null,
  total_retido numeric,
  passante numeric,
  alerta_balanco boolean default false,
  liga text,
  exsudacao text,
  cor text,
  resultado text default 'em_analise'::text not null,
  aprovado_auto boolean default false,
  ensaios_fora jsonb default '[]'::jsonb not null,
  motivo_reprovacao text,
  obs_laboratorio text,
  acao text,
  assinatura_nome text,
  assinatura_funcao text,
  assinatura_em timestamp with time zone,
  obs text,
  criado_por text,
  created_at timestamp with time zone default now(),
  atualizado_em timestamp with time zone default now(),
  mm_result numeric,
  peso_esp_result numeric,
  composicao jsonb
);
create table public.lab_peneiras (
  id uuid default gen_random_uuid() not null,
  codigo text not null,
  abertura_mm numeric,
  ordem integer default 0 not null,
  ativo boolean default true not null,
  criado_em timestamp with time zone default now() not null
);
create table public.lab_produto_limites_peneira (
  id uuid default gen_random_uuid() not null,
  produto_id uuid not null,
  peneira_id uuid not null,
  limite_inf numeric,
  limite_sup numeric,
  medido boolean default true not null,
  reportavel_laudo boolean default true not null,
  com_limite boolean default true not null
);
create table public.lab_produto_qualidade (
  id uuid default gen_random_uuid() not null,
  produto_id uuid not null,
  ensaios_obrigatorios jsonb default '[]'::jsonb not null,
  traco_padrao_id uuid,
  qtd_produto_por_traco numeric,
  limite_densidade_min numeric,
  limite_densidade_max numeric,
  limite_umidade_max numeric,
  atualizado_em timestamp with time zone default now() not null,
  limite_total_retido_min numeric,
  limite_total_retido_max numeric,
  limite_mm_min numeric,
  limite_peso_esp_min numeric,
  limite_peso_esp_max numeric
);
create table public.lab_solicitacoes_correcao (
  id uuid default gen_random_uuid() not null,
  amostra_id uuid not null,
  justificativa text not null,
  dados_propostos jsonb not null,
  dados_anteriores jsonb not null,
  solicitante text not null,
  status text default 'pendente'::text not null,
  aprovador text,
  data_solicitacao timestamp with time zone default now() not null,
  data_decisao timestamp with time zone,
  obs_decisao text
);
create table public.lab_tracos (
  id uuid default gen_random_uuid() not null,
  nome text not null,
  cimento_g numeric not null,
  areia_g numeric not null,
  ativo boolean default true not null,
  criado_em timestamp with time zone default now() not null
);
create table public.laboratorio (
  id uuid default uuid_generate_v4() not null,
  data date,
  hora time without time zone,
  linha text not null,
  produto text,
  turno text,
  encarregado text,
  status text default 'OK'::text,
  separador text,
  umidade numeric,
  massa text,
  laudo text,
  responsavel text,
  obs text,
  peneiramento jsonb default '{}'::jsonb,
  composicao jsonb default '{}'::jsonb,
  afericoes jsonb default '[]'::jsonb,
  created_at timestamp with time zone default now(),
  atualizado_em timestamp with time zone default now(),
  status_amostra text,
  amostra_pai_id uuid,
  responsavel_coleta text,
  responsavel_analise text,
  separador_canal text,
  separador_rpm numeric,
  traco_id uuid,
  peso_amostra_inicial numeric,
  peneiramento_raw jsonb,
  resultado_ensaios jsonb,
  cor_conformidade text,
  insumo_cimento_id uuid,
  insumo_cimento_lote text,
  insumo_areia_id uuid,
  insumo_areia_lote text,
  insumo_aditivo_id uuid,
  insumo_aditivo_lote text,
  bloqueada_edicao boolean default false not null,
  motivo_reprovacao text,
  ensaio_nao_conforme text,
  mm_result numeric,
  peso_esp_result numeric,
  finalizada_em timestamp with time zone,
  finalizada_por text,
  correcao_liberada boolean default false
);
create table public.lancamentos_custo (
  id uuid default uuid_generate_v4() not null,
  data date default CURRENT_DATE not null,
  descricao text not null,
  valor numeric default 0 not null,
  quantidade numeric default 1,
  unidade text default 'un'::text,
  centro_custo_id uuid,
  centro_custo_nome text,
  natureza_id uuid,
  natureza_nome text,
  modulo_origem text default 'manual'::text,
  referencia_id uuid,
  referencia_numero text,
  numero_nf text,
  fornecedor text,
  linha text,
  produto text,
  toneladas_referencia numeric default 0,
  obs text,
  criado_por text,
  criado_em timestamp with time zone default now(),
  atualizado_em timestamp with time zone default now(),
  recorrente boolean default false,
  aprovado boolean default false,
  aprovado_por text,
  aprovado_em timestamp with time zone
);
create table public.linhas_producao (
  id uuid default uuid_generate_v4() not null,
  nome text not null,
  horimetro numeric default 0,
  status text default 'ativo'::text,
  obs text,
  produtos jsonb default '[]'::jsonb,
  criado_em timestamp with time zone default now(),
  atualizado_em timestamp with time zone default now(),
  foto text
);
create table public.lubrificacao (
  id text not null,
  equipamento text,
  linha text,
  componente text,
  lubrificante text,
  tipo text,
  qtd numeric,
  unidade text,
  freq_val numeric,
  freq_unid text,
  ultima date,
  responsavel text,
  custo numeric,
  execucoes jsonb
);
create table public.manut_prev_execs (
  id text not null,
  plano_id text,
  tipo text,
  equipamento text,
  componente text,
  data date,
  responsavel text,
  obs text,
  foto text,
  assinatura text,
  checklist jsonb,
  condicao text,
  qtd numeric,
  custo numeric,
  corr_r text, corr_s text, corr_t text,
  tens_r text, tens_s text, tens_t text,
  temperatura text,
  isolamento text,
  alarmes jsonb,
  criado_em timestamp with time zone
);
create table public.manut_prev_planos (
  id text not null,
  tipo text,
  equipamento text,
  linha text,
  componente text,
  per_val numeric,
  per_unid text,
  responsavel text,
  ativo boolean,
  checklist jsonb,
  lubrificante text,
  subtipo text,
  qtd numeric,
  unidade text,
  custo numeric,
  corrente_nominal text,
  temp_limite text,
  isol_min text,
  cv text,
  kw text,
  rpm text,
  tensao_nominal text,
  fabricante text,
  modelo text,
  ultima date,
  criado_em timestamp with time zone
);
create table public.manutencao (
  id uuid default uuid_generate_v4() not null,
  numero integer,
  tipo text default 'corretiva'::text not null,
  prioridade text default 'normal'::text,
  equipamento text not null,
  linha text,
  data_abertura date,
  data_prevista date,
  descricao text default ''::text,
  tecnico text,
  especialidade text,
  horas_gastas numeric default 0,
  status text default 'aberta'::text,
  solucao text,
  pecas jsonb default '[]'::jsonb,
  created_at timestamp with time zone default now(),
  atualizado_em timestamp with time zone default now(),
  parte text,
  terceiro text,
  hora_ini time without time zone,
  hora_fin time without time zone,
  horimetro numeric,
  custo_manutencao numeric,
  pecas_trocadas text,
  servico_realizado text,
  assinatura text,
  resp_terceiro text,
  fotos_servico jsonb default '[]'::jsonb,
  assinaturas_tecnicos jsonb default '[]'::jsonb,
  assinaturas_servico jsonb default '[]'::jsonb,
  solicitante text,
  os_lote jsonb,
  data_conclusao date,
  data_prevista_fim date,
  tempo_previsto numeric,
  hora_inicio_prev text,
  hora_fim_prev text,
  checklist jsonb,
  analise_falha jsonb,
  encarregado text,
  gestor_aprov text,
  conclusao_gestor text,
  os_itens jsonb default '[]'::jsonb,
  os_requisicoes jsonb default '[]'::jsonb,
  requisicao_terceiro text,
  sistema text,
  tempo_parada numeric,
  sistemas jsonb default '[]'::jsonb,
  observacoes text,
  data_momento date
);
create table public.manutencao_componentes (
  id uuid default uuid_generate_v4() not null,
  linha text,
  equipamento text not null,
  componente text not null,
  tipo_manut text default 'preventiva'::text,
  especialidade text,
  data date,
  horimetro numeric,
  intervalo_horas numeric,
  proxima_revisao_horas numeric,
  responsavel text,
  obs text,
  created_at timestamp with time zone default now()
);
create table public.manutencao_cronograma (
  id uuid default uuid_generate_v4() not null,
  equipamento text not null,
  descricao text not null,
  equipe text,
  status text default 'PLAN'::text,
  data_ini date,
  data_fim date,
  created_at timestamp with time zone default now()
);
create table public.manutencao_cronogramas (
  id uuid default gen_random_uuid() not null,
  titulo text,
  data_ini date,
  data_fim date,
  num_dias integer,
  linhas_nomes text,
  total_tarefas integer,
  dados jsonb default '{}'::jsonb not null,
  created_at timestamp with time zone default now(),
  atualizado_em timestamp with time zone default now()
);
create table public.manutencao_docs (
  id uuid default uuid_generate_v4() not null,
  nome text not null,
  equipamento text not null,
  categoria text default 'linha'::text,
  tipo text default 'manual'::text,
  descricao text,
  url text,
  created_at timestamp with time zone default now(),
  atualizado_em timestamp with time zone default now(),
  componente text
);
create table public.manutencao_filtros (
  id uuid default uuid_generate_v4() not null,
  linha text not null,
  medida text not null,
  quantidade integer default 1,
  data_troca date,
  intervalo_horas numeric,
  horimetro numeric,
  responsavel text,
  teste_chamine text,
  obs text,
  created_at timestamp with time zone default now()
);
create table public.manutencao_frota (
  id uuid default uuid_generate_v4() not null,
  equipamento text not null,
  tipo_revisao text,
  material text,
  intervalo text,
  data date,
  responsavel text,
  obs text,
  created_at timestamp with time zone default now()
);
create table public.metas_custo (
  id uuid default uuid_generate_v4() not null,
  mes text not null,
  linha text,
  produto text,
  meta_custo_ton numeric default 0,
  meta_custo_total numeric default 0,
  criado_em timestamp with time zone default now()
);
create table public.motivos_parada (
  id uuid default uuid_generate_v4() not null,
  nome text not null,
  descricao text,
  status text default 'ativo'::text,
  criado_em timestamp with time zone default now(),
  atualizado_em timestamp with time zone default now(),
  conta_como_trabalhada boolean default false
);
create table public.naturezas_custo (
  id uuid default uuid_generate_v4() not null,
  codigo text not null,
  nome text not null,
  grupo text default 'geral'::text not null,
  conta_contabil text,
  status text default 'ativo'::text,
  criado_em timestamp with time zone default now()
);
create table public.notificacoes (
  id uuid default uuid_generate_v4() not null,
  tipo text default 'info'::text,
  modulo text,
  titulo text not null,
  descricao text,
  lida boolean default false,
  created_at timestamp with time zone default now()
);
create table public.orcamentos_custo (
  id uuid default gen_random_uuid() not null,
  mes text not null,
  centro_custo_id uuid,
  centro_custo_nome text,
  valor_orcado numeric default 0,
  alerta_pct integer default 80,
  obs text,
  created_at timestamp with time zone default now()
);
create table public.perfis (
  id uuid default uuid_generate_v4() not null,
  codigo text not null,
  nome text not null,
  descricao text,
  cor text default '#042D4D'::text,
  permissoes jsonb default '{}'::jsonb,
  criado_em timestamp with time zone default now()
);
create table public.planejamentos (
  id uuid default uuid_generate_v4() not null,
  mes text not null,
  calendario jsonb default '{}'::jsonb,
  feriados_locais jsonb default '[]'::jsonb,
  secoes jsonb default '[]'::jsonb,
  totais jsonb default '{}'::jsonb,
  criado_em timestamp with time zone default now(),
  atualizado_em timestamp with time zone default now()
);
create table public.planejamentos_custo (
  id uuid default gen_random_uuid() not null,
  codigo text not null,
  numero integer not null,
  nome text,
  mes integer,
  ano integer,
  estado jsonb not null,
  totais jsonb,
  status text default 'ativo'::text,
  criado_por text,
  created_at timestamp with time zone default now(),
  atualizado_em timestamp with time zone default now()
);
create table public.portaria (
  id uuid default uuid_generate_v4() not null,
  placa text,
  nome_motorista text,
  celular text,
  transportadora text,
  modelo_veiculo text,
  tipo_carga text,
  numero_ordem text,
  hora_chegada timestamp with time zone default now(),
  hora_saida timestamp with time zone,
  peso_tara numeric,
  peso_bruto numeric,
  peso_liquido numeric,
  status text default 'sem_ordem'::text,
  liberado boolean default false,
  created_at timestamp with time zone default now()
);
create table public.producao (
  id uuid default uuid_generate_v4() not null,
  data date not null,
  linha text not null,
  turno text not null,
  produto text not null,
  qtd_produzida numeric default 0 not null,
  qtd_planejada numeric,
  eficiencia integer default 0,
  paradas_horas numeric default 0,
  paradas jsonb default '[]'::jsonb,
  responsavel text,
  obs text,
  status text default 'normal'::text,
  created_at timestamp with time zone default now(),
  atualizado_em timestamp with time zone default now(),
  consumo_lenha numeric,
  temp_moinho numeric,
  perda_filtro numeric,
  lote_mp text,
  lote_aditivo text,
  equipe jsonb default '[]'::jsonb,
  produtos_op jsonb default '[]'::jsonb,
  paradas_op jsonb default '[]'::jsonb,
  obs_parada text,
  sacos_analise numeric default 0,
  sacos_reprovados numeric default 0,
  motivo_reprovacao text,
  op_numero text,
  dia_semana text,
  encarregado text,
  ht numeric default 0,
  hp numeric default 0,
  motivos_parada jsonb default '[]'::jsonb,
  total_sacos numeric default 0,
  efic_disp text,
  efic_prod text,
  resp_reprovacao text,
  hora_reprovacao text,
  almox_baixa_feita boolean default false,
  laudo_id uuid,
  laudo_numero text,
  lote_producao_id uuid
);
create table public.producao_martelos (
  id uuid default uuid_generate_v4() not null,
  linha text not null,
  tipo text,
  data_retirada date not null,
  data_devolucao date,
  peso_inicial numeric,
  peso_final numeric,
  horimetro_inicial numeric,
  horimetro_final numeric,
  producao_sacos integer,
  fornecedor text,
  obs text,
  created_at timestamp with time zone default now()
);
create table public.producao_pallets (
  id uuid default uuid_generate_v4() not null,
  lancamento_id uuid,
  data date,
  linha text,
  turno text,
  produto text,
  numero integer,
  status text default 'pendente'::text,
  analise jsonb default '{}'::jsonb,
  created_at timestamp with time zone default now(),
  responsavel_lab text,
  hora_lab text,
  obs_lab text,
  atualizado_em timestamp with time zone default now(),
  codigo text,
  barracao text,
  pos_fila integer,
  pos_nivel integer,
  estoque_status text default 'estoque'::text,
  carregado_em timestamp with time zone,
  romaneio_numero text,
  ordem_numero text,
  pedido_numero text,
  cliente_dest text,
  embalagem_tipo text default 'saco'::text,
  ensaio_nao_conforme text,
  responsavel_decisao text,
  aprovacao_automatica boolean default false not null,
  laudo_id uuid,
  equipe text,
  analise_id uuid,
  bloqueado_por uuid,
  motivo_bloqueio text,
  responsavel_lab_id uuid
);
create table public.produtos (
  id uuid default uuid_generate_v4() not null,
  nome text not null,
  centro_custo text,
  linhas text[],
  unidade text,
  unidade_custom text,
  emb_tipo text default 'unitario'::text,
  emb_qtd integer,
  capacidades integer[],
  status text default 'ativo'::text,
  criado_em timestamp with time zone default now(),
  atualizado_em timestamp with time zone default now(),
  foto text,
  peso_saco numeric,
  chilincado text default 'SIM'::text,
  peso_unidade_kg numeric,
  laudo_composicao text,
  laudo_modo_usar text,
  laudo_precaucoes text,
  laudo_registro text,
  laudo_classificacao text
);
create table public.rh_escala (
  id uuid default uuid_generate_v4() not null,
  funcionario_id uuid,
  mes text not null,
  turno text,
  dias_trabalho integer[] default '{}'::integer[],
  created_at timestamp with time zone default now()
);
create table public.rh_ferias (
  id uuid default uuid_generate_v4() not null,
  funcionario_id uuid,
  data_inicio date not null,
  data_fim date not null,
  status text default 'agendada'::text,
  obs text,
  created_at timestamp with time zone default now()
);
create table public.romaneio_itens (
  id uuid default gen_random_uuid() not null,
  romaneio_id uuid,
  numero text,
  pedido text,
  cidade text,
  cliente text,
  produto text,
  quantidade text,
  caixa text,
  lote text
);
create table public.romaneios (
  id uuid default gen_random_uuid() not null,
  numero text,
  data_emissao text,
  transportadora text,
  motorista text,
  placa text,
  status text default 'recebido'::text,
  data_hora_saida text,
  origem text default 'salescode'::text,
  importado_em timestamp with time zone default now(),
  atualizado_em timestamp with time zone default now()
);
create table public.terceiros_prestadores (
  id uuid default gen_random_uuid() not null,
  nome text not null,
  tipo text,
  especialidade text,
  documento text,
  telefone text,
  email text,
  endereco text,
  obs text,
  status text default 'ativo'::text,
  atualizado_em timestamp with time zone,
  created_at timestamp with time zone default now()
);
create table public.terceiros_remessas (
  id uuid default gen_random_uuid() not null,
  numero integer,
  prestador_id uuid,
  prestador_nome text,
  descricao text,
  quantidade numeric,
  origem text,
  referencia text,
  data_saida date,
  previsao_retorno date,
  data_retorno date,
  autorizado_por text,
  transportado_por text,
  status text default 'enviado'::text,
  obs text,
  fotos jsonb default '[]'::jsonb,
  assinatura text,
  atualizado_em timestamp with time zone,
  created_at timestamp with time zone default now(),
  ref_os text,
  ref_equipamento text,
  ref_peca text,
  assinatura_autorizador text,
  itens jsonb default '[]'::jsonb,
  autorizado_por_id uuid
);
create table public.terceiros_servicos (
  id uuid default gen_random_uuid() not null,
  numero integer,
  prestador_id uuid,
  prestador_nome text,
  remessa_id uuid,
  descricao text,
  itens jsonb default '[]'::jsonb,
  valor_total numeric,
  data date,
  competencia text,
  requisicao text,
  nota_fiscal text,
  status text default 'aberto'::text,
  anexos jsonb default '[]'::jsonb,
  obs text,
  atualizado_em timestamp with time zone,
  created_at timestamp with time zone default now()
);
create table public.turnos (
  id uuid default uuid_generate_v4() not null,
  nome text not null,
  calendario jsonb default '{}'::jsonb,
  refeicao_nome text,
  refeicao_min integer default 0,
  refeicao_inicio time without time zone,
  refeicao_fim time without time zone,
  status text default 'ativo'::text,
  criado_em timestamp with time zone default now(),
  atualizado_em timestamp with time zone default now()
);
create table public.usuarios (
  id uuid default uuid_generate_v4() not null,
  nome text not null,
  email text not null,
  senha_hash text,
  perfil text default 'OPR'::text not null,
  funcao text,
  setor text,
  turno text,
  cpf text,
  telefone text,
  admissao date,
  status text default 'ativo'::text,
  ultimo_acesso timestamp with time zone,
  criado_em timestamp with time zone default now(),
  atualizado_em timestamp with time zone default now(),
  foto text,
  auth_id uuid
);

-- ── TABELAS (bloco bpf_* do primeiro lote) ──────────────────────────────────
create table public.bpf_auditorias (
  id uuid default gen_random_uuid() not null,
  tipo text,
  data date,
  auditor text,
  linha text,
  escopo text,
  resultado text default 'agendada'::text,
  created_at timestamp with time zone default now(),
  registro_sil002_id uuid
);
create table public.bpf_calibracoes (
  id uuid default gen_random_uuid() not null,
  instrumento_id uuid not null,
  tipo text default 'calibracao'::text not null,
  data date not null,
  validade date not null,
  prestador_id uuid,
  prestador_nome text,
  certificado_numero text,
  certificado_path text,
  resultado text,
  erro_encontrado numeric,
  peso_padrao_id uuid,
  registro_id uuid,
  registrado_por text,
  obs text,
  created_at timestamp with time zone default now(),
  anexos jsonb default '[]'::jsonb not null
);
create table public.bpf_cronograma (
  id uuid default gen_random_uuid() not null,
  ano integer not null,
  tipo text not null,
  titulo text not null,
  mes_previsto integer,
  publico_alvo text,
  pop_cod text,
  responsavel text,
  status text default 'planejado'::text,
  realizado_em date,
  registro_id uuid,
  obs text,
  created_at timestamp with time zone default now()
);
create table public.bpf_designacoes (
  id uuid default gen_random_uuid() not null,
  funcionario_id uuid,
  funcionario_nome text not null,
  funcao_cod text not null,
  pop_cod text,
  cargo_carteira text,
  data_inicio date default CURRENT_DATE not null,
  data_fim date,
  evidencia_path text,
  evidencia_validade date,
  designado_por text,
  ativo boolean default true,
  obs text,
  created_at timestamp with time zone default now(),
  anexos jsonb default '[]'::jsonb not null
);
create table public.bpf_documento_revisoes (
  id uuid default gen_random_uuid() not null,
  documento_cod text not null,
  revisao text not null,
  data date default CURRENT_DATE not null,
  alteracao text,
  autor text,
  arquivo_path text,
  created_at timestamp with time zone default now()
);
create table public.bpf_documentos (
  id uuid default gen_random_uuid() not null,
  nome text not null,
  tipo text,
  tamanho bigint,
  url text,
  path_storage text,
  enviado_por text,
  created_at timestamp with time zone default now(),
  conteudo_base64 text
);
create table public.bpf_documentos_mestre (
  id uuid default gen_random_uuid() not null,
  codigo text not null,
  tipo text not null,
  titulo text not null,
  revisao text default '00'::text not null,
  data_emissao date,
  data_revisao date,
  proxima_revisao date,
  status text default 'vigente'::text not null,
  pop_cod text,
  grupo text,
  ordem integer default 0,
  ncs_resolve text,
  substitui text,
  arquivo_path text,
  observacao text,
  aprovado_por text,
  aprovado_em date,
  created_at timestamp with time zone default now(),
  atualizado_em timestamp with time zone default now()
);
create table public.bpf_equip_saidas (
  id uuid default gen_random_uuid() not null,
  instrumento_id uuid,
  descricao text not null,
  prestador_id uuid,
  prestador_nome text,
  motivo text not null,
  data_saida date not null,
  nf_saida text,
  previsao_retorno date,
  data_retorno date,
  certificado_path text,
  nf_retorno text,
  status text default 'fora'::text,
  liberado_por text,
  liberado_em timestamp with time zone,
  obs text,
  created_at timestamp with time zone default now(),
  anexos jsonb default '[]'::jsonb not null
);
create table public.bpf_excecoes (
  id uuid default gen_random_uuid() not null,
  tipo text not null,
  referencia text not null,
  motivo text not null,
  justificativa text,
  alcada text not null,
  autorizado_por text not null,
  autorizado_em timestamp with time zone default now(),
  registro_id uuid,
  created_at timestamp with time zone default now()
);
create table public.bpf_formularios (
  id uuid default gen_random_uuid() not null,
  codigo text not null,
  titulo text not null,
  pop_cod text not null,
  it_cod text,
  periodicidade text,
  campos jsonb default '[]'::jsonb not null,
  assinaturas jsonb default '[]'::jsonb not null,
  fonte_modulo text,
  exige_anexo boolean default false,
  gera_validade boolean default false,
  validade_meses integer,
  retencao_anos integer default 4,
  ordem integer default 0,
  ativo boolean default true,
  observacao text,
  created_at timestamp with time zone default now()
);
create table public.bpf_fornecedores_qualif (
  id uuid default gen_random_uuid() not null,
  fornecedor_id uuid,
  nome text not null,
  cnpj text,
  categoria_risco text not null,
  tipo_fornecimento text,
  status text default 'em_homologacao'::text not null,
  documentos jsonb default '[]'::jsonb,
  avaliado_em date,
  reavaliacao_em date,
  avaliado_por text,
  bloqueia_recebimento boolean default true,
  obs text,
  created_at timestamp with time zone default now(),
  anexos jsonb default '[]'::jsonb not null
);
create table public.bpf_funcoes (
  codigo text not null,
  nome text not null,
  ordem integer default 0,
  ativo boolean default true
);
create table public.bpf_inspecao_veiculo (
  id uuid default gen_random_uuid() not null,
  romaneio_id uuid,
  ordem_numero text,
  placa text not null,
  motorista text,
  transportadora text,
  data date default CURRENT_DATE not null,
  hora time without time zone,
  limpo boolean,
  coberto boolean,
  sem_vetores boolean,
  sem_carga_incompativel boolean,
  sem_odor boolean,
  sem_avarias boolean,
  resultado text not null,
  reinspecao_de uuid,
  fotos jsonb default '[]'::jsonb,
  obs text,
  inspetor text,
  registro_id uuid,
  created_at timestamp with time zone default now(),
  anexos jsonb default '[]'::jsonb not null
);
create table public.bpf_instrumentos (
  id uuid default gen_random_uuid() not null,
  tag text not null,
  nome text not null,
  tipo text,
  fabricante text,
  modelo text,
  numero_serie text,
  faixa_min numeric,
  faixa_max numeric,
  unidade text,
  resolucao numeric,
  classe text,
  emp numeric,
  localizacao text,
  equipamento_id uuid,
  periodicidade_meses integer default 12,
  status text default 'ativo'::text,
  critico boolean default true,
  obs text,
  created_at timestamp with time zone default now()
);
create table public.bpf_manifestacoes (
  id uuid default gen_random_uuid() not null,
  numero text not null,
  data date default CURRENT_DATE not null,
  anonimo boolean default false,
  autor_nome text,
  tema text not null,
  descricao text not null,
  tratamento text,
  responsavel text,
  retorno text,
  status text default 'aberta'::text,
  encerrado_em date,
  registro_id uuid,
  created_at timestamp with time zone default now()
);
create table public.bpf_ncs (
  id uuid default gen_random_uuid() not null,
  procedimento_cod text,
  data date,
  linha text,
  gravidade text,
  descricao text,
  acao_corretiva text,
  responsavel_id uuid,
  responsavel_nome text,
  prazo date,
  status text default 'aberta'::text,
  created_at timestamp with time zone default now()
);
create table public.bpf_pesos_padrao (
  id uuid default gen_random_uuid() not null,
  identificacao text not null,
  valor_nominal numeric not null,
  unidade text default 'kg'::text,
  classe text,
  certificado_numero text,
  certificado_path text,
  data_certificado date,
  validade date,
  status text default 'ativo'::text,
  obs text,
  created_at timestamp with time zone default now(),
  anexos jsonb default '[]'::jsonb not null
);
create table public.bpf_prestadores_qualif (
  id uuid default gen_random_uuid() not null,
  prestador_id uuid,
  nome text not null,
  cnpj text,
  categoria text not null,
  acreditacao text,
  numero_acreditacao text,
  escopo text,
  escopo_compativel boolean default false,
  documento_path text,
  validade date,
  reavaliacao_em date,
  status text default 'em_qualificacao'::text,
  bloqueia_envio boolean default true,
  obs text,
  created_at timestamp with time zone default now(),
  anexos jsonb default '[]'::jsonb not null
);
create table public.bpf_proc_status (
  proc_id text not null,
  status text,
  updated_at timestamp with time zone default now()
);
create table public.bpf_reclamacoes (
  id uuid default gen_random_uuid() not null,
  numero text not null,
  canal text,
  cliente text not null,
  contato text,
  produto text,
  lote_ref text,
  nota_fiscal text,
  data_recebimento date default CURRENT_DATE not null,
  prazo_ate date,
  descricao text not null,
  analise_causa text,
  plano_acao text,
  escalonado_para text default 'nenhum'::text,
  nc_id uuid,
  recall_id uuid,
  responsavel text,
  status text default 'aberta'::text,
  encerrado_em date,
  registro_id uuid,
  created_at timestamp with time zone default now(),
  anexos jsonb default '[]'::jsonb not null
);
create table public.bpf_registro_trilha (
  id bigint default nextval('bpf_registro_trilha_id_seq'::regclass) not null,
  registro_id uuid not null,
  numero text,
  acao text not null,
  campo text,
  valor_anterior text,
  valor_novo text,
  motivo text,
  autor text,
  autor_id uuid,
  em timestamp with time zone default now()
);
create table public.bpf_registros (
  id uuid default gen_random_uuid() not null,
  numero text,
  formulario_cod text not null,
  pop_cod text not null,
  data date default CURRENT_DATE not null,
  hora time without time zone,
  campos jsonb default '{}'::jsonb not null,
  assinaturas jsonb default '[]'::jsonb not null,
  anexos jsonb default '[]'::jsonb not null,
  status text default 'rascunho'::text not null,
  conforme boolean,
  validade date,
  origem_modulo text,
  origem_id text,
  nc_id uuid,
  criado_por text,
  criado_por_id uuid,
  concluido_em timestamp with time zone,
  cancelado_em timestamp with time zone,
  cancelado_por text,
  cancelado_motivo text,
  retencao_ate date,
  created_at timestamp with time zone default now(),
  atualizado_em timestamp with time zone default now()
);
create table public.bpf_reprocessos (
  id uuid default gen_random_uuid() not null,
  nc_id uuid,
  lote_origem text not null,
  lote_novo text,
  forma text not null,
  percentual_diluicao numeric,
  quantidade numeric,
  unidade text,
  proposta_qualidade text,
  autorizado_rt boolean default false,
  rt_nome text,
  rt_crea text,
  autorizado_em timestamp with time zone,
  status text default 'proposto'::text,
  bloqueado_ate_analise boolean default true,
  registro_id uuid,
  obs text,
  created_at timestamp with time zone default now()
);
create table public.bpf_rotulos (
  id uuid default gen_random_uuid() not null,
  produto_id uuid,
  produto_nome text not null,
  versao integer default 1 not null,
  croqui_path text,
  composicao jsonb default '{}'::jsonb,
  classificacao text default 'Veículo Mineral'::text,
  base_isencao text,
  aprovado_rt boolean default false,
  rt_nome text,
  rt_crea text,
  aprovado_em timestamp with time zone,
  status text default 'rascunho'::text,
  reimprimivel boolean default true,
  reavaliacao_em date,
  motivo_alteracao text,
  created_at timestamp with time zone default now(),
  anexos jsonb default '[]'::jsonb not null
);
create table public.bpf_sequencias (
  formulario_cod text not null,
  ultimo integer default 0 not null
);
create table public.bpf_sil002_registros (
  id uuid default gen_random_uuid() not null,
  data date,
  hora text,
  embalagem text,
  lote text,
  danfe text,
  quantidade numeric,
  executante_id uuid,
  executante_nome text,
  executante_funcao text,
  assinatura_executante text,
  assinatura_encarregado text,
  encarregado_nome text,
  assinatura_qualidade text,
  qualidade_nome text,
  c1 text, c2 text, c3 text, c4 text, c5 text, c6 text,
  observacoes text,
  status text default 'pendente'::text,
  created_at timestamp with time zone default now(),
  updated_at timestamp with time zone default now(),
  almoxarifado_movimento_id uuid,
  fornecedor text,
  responsavel_almox text
);
create table public.bpf_sil003_registros (
  id uuid default gen_random_uuid() not null,
  producao_op_id text,
  data_inicio date,
  hora_inicio text,
  hora_fim text,
  linha text,
  turno text,
  produto text,
  linha_produto text,
  encarregado_ref text,
  op_numero_ref text,
  destino_varredura text,
  executante_id text,
  executante_nome text,
  executante_funcao text,
  assinatura_executante text,
  assinatura_encarregado text,
  encarregado_nome text,
  assinatura_qualidade text,
  qualidade_nome text,
  status text default 'pendente'::text,
  obs text,
  created_at timestamp with time zone default now()
);

-- ── PRIMARY KEYS ────────────────────────────────────────────────────────────
-- Padrão do projeto: PK em (id). Exceções listadas explicitamente abaixo.
do $$
declare t text;
begin
  for t in
    select c.relname from pg_class c
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind='r'
      and c.relname not in (
        'almoxarifado_saida_assinaturas','app_preferencias','bpf_funcoes',
        'bpf_sil_acesso',  -- sem PK em produção (só UNIQUE perfil_cod)
        'bpf_proc_status','bpf_sequencias','bpf_travas','desgaste_padroes',
        'insumos_preferencias','lab_laudo_sequencia')
  loop
    execute format('alter table public.%I add constraint %I primary key (id)', t, t||'_pkey');
  end loop;
end $$;
alter table public.almoxarifado_saida_assinaturas add constraint almoxarifado_saida_assinaturas_pkey primary key (numero_doc);
alter table public.app_preferencias add constraint app_preferencias_pkey primary key (chave);
alter table public.bpf_funcoes add constraint bpf_funcoes_pkey primary key (codigo);
alter table public.bpf_proc_status add constraint bpf_proc_status_pkey primary key (proc_id);
alter table public.bpf_sequencias add constraint bpf_sequencias_pkey primary key (formulario_cod);
alter table public.bpf_travas add constraint bpf_travas_pkey primary key (codigo);
alter table public.desgaste_padroes add constraint desgaste_padroes_pkey primary key (peca);
alter table public.insumos_preferencias add constraint insumos_preferencias_pkey primary key (chave);
alter table public.lab_laudo_sequencia add constraint lab_laudo_sequencia_pkey primary key (ano);

-- ── UNIQUES E FOREIGN KEYS ──────────────────────────────────────────────────
alter table public.abastecimento_entradas add constraint abastecimento_entradas_bomba_id_fkey FOREIGN KEY (bomba_id) REFERENCES abastecimento_bombas(id);
alter table public.abastecimento_registros add constraint abastecimento_registros_bomba_id_fkey FOREIGN KEY (bomba_id) REFERENCES abastecimento_bombas(id);
alter table public.almoxarifado_movimentos add constraint almoxarifado_movimentos_insumo_id_fkey FOREIGN KEY (insumo_id) REFERENCES almoxarifado(id) ON DELETE CASCADE;
alter table public.bpf_auditorias add constraint bpf_auditorias_registro_sil002_id_fkey FOREIGN KEY (registro_sil002_id) REFERENCES bpf_sil002_registros(id) ON DELETE SET NULL;
alter table public.bpf_documentos_mestre add constraint bpf_documentos_mestre_codigo_key UNIQUE (codigo);
alter table public.bpf_formularios add constraint bpf_formularios_codigo_key UNIQUE (codigo);
alter table public.bpf_instrumentos add constraint bpf_instrumentos_tag_key UNIQUE (tag);
alter table public.bpf_manifestacoes add constraint bpf_manifestacoes_numero_key UNIQUE (numero);
alter table public.bpf_pesos_padrao add constraint bpf_pesos_padrao_identificacao_key UNIQUE (identificacao);
alter table public.bpf_reclamacoes add constraint bpf_reclamacoes_numero_key UNIQUE (numero);
alter table public.bpf_registros add constraint bpf_registros_numero_key UNIQUE (numero);
alter table public.bpf_sil_acesso add constraint bpf_sil_acesso_perfil_cod_key UNIQUE (perfil_cod);
alter table public.bpf_sil_objetivos add constraint bpf_sil_objetivos_sil_cod_key UNIQUE (sil_cod);
alter table public.caulim_analises_externas add constraint caulim_analises_externas_substitui_id_fkey FOREIGN KEY (substitui_id) REFERENCES caulim_analises_externas(id);
alter table public.caulim_analises_externas add constraint caulim_analises_externas_variacao_principal_id_fkey FOREIGN KEY (variacao_principal_id) REFERENCES caulim_variacoes(id);
alter table public.caulim_certificados add constraint caulim_certificados_lote_producao_id_fkey FOREIGN KEY (lote_producao_id) REFERENCES caulim_lotes_producao(id);
alter table public.caulim_certificados add constraint caulim_certificados_numero_key UNIQUE (numero);
alter table public.caulim_homologacoes add constraint caulim_homologacoes_cliente_id_fkey FOREIGN KEY (cliente_id) REFERENCES caulim_clientes(id);
alter table public.caulim_homologacoes add constraint caulim_homologacoes_variacao_id_cliente_id_key UNIQUE (variacao_id, cliente_id);
alter table public.caulim_homologacoes add constraint caulim_homologacoes_variacao_id_fkey FOREIGN KEY (variacao_id) REFERENCES caulim_variacoes(id);
alter table public.caulim_lote_transicoes add constraint caulim_lote_transicoes_lote_producao_id_fkey FOREIGN KEY (lote_producao_id) REFERENCES caulim_lotes_producao(id) ON DELETE CASCADE;
alter table public.caulim_lotes_mp add constraint caulim_lotes_mp_frente_id_fkey FOREIGN KEY (frente_id) REFERENCES caulim_minas_frentes(id);
alter table public.caulim_lotes_mp add constraint caulim_lotes_mp_numero_key UNIQUE (numero);
alter table public.caulim_lotes_mp add constraint caulim_lotes_mp_variacao_declarada_id_fkey FOREIGN KEY (variacao_declarada_id) REFERENCES caulim_variacoes(id);
alter table public.caulim_lotes_producao add constraint caulim_lotes_producao_homologacao_id_fkey FOREIGN KEY (homologacao_id) REFERENCES caulim_homologacoes(id);
alter table public.caulim_lotes_producao add constraint caulim_lotes_producao_lote_mp_id_fkey FOREIGN KEY (lote_mp_id) REFERENCES caulim_lotes_mp(id);
alter table public.caulim_lotes_producao add constraint caulim_lotes_producao_numero_key UNIQUE (numero);
alter table public.caulim_unidades add constraint caulim_unidades_lote_producao_id_fkey FOREIGN KEY (lote_producao_id) REFERENCES caulim_lotes_producao(id) ON DELETE CASCADE;
alter table public.caulim_unidades add constraint caulim_unidades_qr_codigo_key UNIQUE (qr_codigo);
alter table public.caulim_variacoes add constraint caulim_variacoes_codigo_key UNIQUE (codigo);
alter table public.centros_custo add constraint centros_custo_codigo_key UNIQUE (codigo);
alter table public.desgaste_estoque add constraint desgaste_estoque_registro_id_fkey FOREIGN KEY (registro_id) REFERENCES desgaste_registros(id) ON DELETE SET NULL;
alter table public.epi_entregas add constraint epi_entregas_epi_id_fkey FOREIGN KEY (epi_id) REFERENCES epi_cadastro(id) ON DELETE CASCADE;
alter table public.epi_entregas add constraint epi_entregas_funcionario_id_fkey FOREIGN KEY (funcionario_id) REFERENCES funcionarios(id) ON DELETE CASCADE;
alter table public.epi_treinamentos add constraint epi_treinamentos_funcionario_id_fkey FOREIGN KEY (funcionario_id) REFERENCES funcionarios(id) ON DELETE CASCADE;
alter table public.expedicao_ordens add constraint expedicao_ordens_numero_ordem_key UNIQUE (numero_ordem);
alter table public.fechamentos_custo add constraint fechamentos_custo_mes_key UNIQUE (mes);
alter table public.folha_dados_funcionario add constraint folha_dados_funcionario_funcionario_id_key UNIQUE (funcionario_id);
alter table public.insumos add constraint insumos_codigo_key UNIQUE (codigo);
alter table public.insumos_fechamentos add constraint insumos_fechamentos_data_key UNIQUE (data);
alter table public.insumos_ficha add constraint insumos_ficha_insumo_id_fkey FOREIGN KEY (insumo_id) REFERENCES insumos(id) ON DELETE CASCADE;
alter table public.insumos_ficha add constraint insumos_ficha_produto_insumo_id_base_key UNIQUE (produto, insumo_id, base);
alter table public.insumos_grupos add constraint insumos_grupos_nome_key UNIQUE (nome);
alter table public.insumos_inventarios add constraint insumos_inventarios_insumo_id_fkey FOREIGN KEY (insumo_id) REFERENCES insumos(id) ON DELETE CASCADE;
alter table public.insumos_lotes add constraint insumos_lotes_insumo_id_fkey FOREIGN KEY (insumo_id) REFERENCES insumos(id) ON DELETE CASCADE;
alter table public.insumos_lotes add constraint insumos_lotes_insumo_id_lote_key UNIQUE (insumo_id, lote);
alter table public.insumos_movimentos add constraint insumos_movimentos_insumo_id_fkey FOREIGN KEY (insumo_id) REFERENCES insumos(id) ON DELETE CASCADE;
alter table public.insumos_movimentos add constraint insumos_movimentos_lote_id_fkey FOREIGN KEY (lote_id) REFERENCES insumos_lotes(id) ON DELETE SET NULL;
alter table public.lab_config_lote_pallets add constraint lab_config_lote_pallets_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES produtos(id);
alter table public.lab_laudos add constraint lab_laudos_numero_key UNIQUE (numero);
alter table public.lab_limites_agua_traco add constraint lab_limites_agua_traco_traco_id_fkey FOREIGN KEY (traco_id) REFERENCES lab_tracos(id) ON DELETE CASCADE;
alter table public.lab_peneiras add constraint lab_peneiras_codigo_key UNIQUE (codigo);
alter table public.lab_produto_limites_peneira add constraint lab_produto_limites_peneira_peneira_id_fkey FOREIGN KEY (peneira_id) REFERENCES lab_peneiras(id) ON DELETE CASCADE;
alter table public.lab_produto_limites_peneira add constraint lab_produto_limites_peneira_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES produtos(id) ON DELETE CASCADE;
alter table public.lab_produto_limites_peneira add constraint lab_produto_limites_peneira_produto_id_peneira_id_key UNIQUE (produto_id, peneira_id);
alter table public.lab_produto_qualidade add constraint lab_produto_qualidade_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES produtos(id) ON DELETE CASCADE;
alter table public.lab_produto_qualidade add constraint lab_produto_qualidade_produto_id_key UNIQUE (produto_id);
alter table public.lab_produto_qualidade add constraint lab_produto_qualidade_traco_padrao_id_fkey FOREIGN KEY (traco_padrao_id) REFERENCES lab_tracos(id);
alter table public.lab_solicitacoes_correcao add constraint lab_solicitacoes_correcao_amostra_id_fkey FOREIGN KEY (amostra_id) REFERENCES laboratorio(id) ON DELETE CASCADE;
alter table public.laboratorio add constraint laboratorio_amostra_pai_id_fkey FOREIGN KEY (amostra_pai_id) REFERENCES laboratorio(id);
alter table public.laboratorio add constraint laboratorio_insumo_aditivo_id_fkey FOREIGN KEY (insumo_aditivo_id) REFERENCES almoxarifado(id);
alter table public.laboratorio add constraint laboratorio_insumo_areia_id_fkey FOREIGN KEY (insumo_areia_id) REFERENCES almoxarifado(id);
alter table public.laboratorio add constraint laboratorio_insumo_cimento_id_fkey FOREIGN KEY (insumo_cimento_id) REFERENCES almoxarifado(id);
alter table public.laboratorio add constraint laboratorio_traco_id_fkey FOREIGN KEY (traco_id) REFERENCES lab_tracos(id);
alter table public.lancamentos_custo add constraint lancamentos_custo_centro_custo_id_fkey FOREIGN KEY (centro_custo_id) REFERENCES centros_custo(id);
alter table public.lancamentos_custo add constraint lancamentos_custo_natureza_id_fkey FOREIGN KEY (natureza_id) REFERENCES naturezas_custo(id);
alter table public.naturezas_custo add constraint naturezas_custo_codigo_key UNIQUE (codigo);
alter table public.perfis add constraint perfis_codigo_key UNIQUE (codigo);
alter table public.producao add constraint producao_lote_producao_id_fkey FOREIGN KEY (lote_producao_id) REFERENCES caulim_lotes_producao(id);
alter table public.producao_pallets add constraint producao_pallets_lancamento_id_fkey FOREIGN KEY (lancamento_id) REFERENCES producao(id) ON DELETE CASCADE;
alter table public.rh_escala add constraint rh_escala_funcionario_id_fkey FOREIGN KEY (funcionario_id) REFERENCES funcionarios(id) ON DELETE CASCADE;
alter table public.rh_ferias add constraint rh_ferias_funcionario_id_fkey FOREIGN KEY (funcionario_id) REFERENCES funcionarios(id) ON DELETE CASCADE;
alter table public.romaneio_itens add constraint romaneio_itens_romaneio_id_fkey FOREIGN KEY (romaneio_id) REFERENCES romaneios(id) ON DELETE CASCADE;
alter table public.romaneios add constraint romaneios_numero_key UNIQUE (numero);
alter table public.terceiros_remessas add constraint terceiros_remessas_prestador_id_fkey FOREIGN KEY (prestador_id) REFERENCES terceiros_prestadores(id) ON DELETE SET NULL;
alter table public.terceiros_servicos add constraint terceiros_servicos_prestador_id_fkey FOREIGN KEY (prestador_id) REFERENCES terceiros_prestadores(id) ON DELETE SET NULL;
alter table public.terceiros_servicos add constraint terceiros_servicos_remessa_id_fkey FOREIGN KEY (remessa_id) REFERENCES terceiros_remessas(id) ON DELETE SET NULL;
alter table public.usuarios add constraint usuarios_email_key UNIQUE (email);

-- ── CHECK CONSTRAINTS ───────────────────────────────────────────────────────
-- (já inclui as guardas das migrations 002/003)
alter table public.almoxarifado_movimentos add constraint almoxarifado_movimentos_tipo_check CHECK ((tipo = ANY (ARRAY['entrada'::text, 'saida'::text])));
alter table public.desgaste_estoque add constraint desgaste_estoque_condicao_check CHECK ((condicao = ANY (ARRAY['novo'::text, 'usado'::text])));
alter table public.desgaste_estoque add constraint desgaste_estoque_peca_check CHECK ((peca = ANY (ARRAY['martelo'::text, 'eixo'::text, 'grelha'::text, 'gaveta'::text])));
alter table public.desgaste_estoque add constraint desgaste_estoque_peso_unitario_check CHECK ((peso_unitario > (0)::numeric));
alter table public.desgaste_estoque add constraint desgaste_estoque_quantidade_check CHECK ((quantidade > 0));
alter table public.desgaste_estoque add constraint desgaste_estoque_status_check CHECK ((status = ANY (ARRAY['disponivel'::text, 'usado'::text])));
alter table public.desgaste_padroes add constraint desgaste_padrao_coerente CHECK (((peso_descarte IS NULL) OR (peso_novo IS NULL) OR (peso_descarte <= peso_novo)));
alter table public.desgaste_padroes add constraint desgaste_padroes_peca_check CHECK ((peca = ANY (ARRAY['martelo'::text, 'eixo'::text, 'grelha'::text, 'gaveta'::text])));
alter table public.desgaste_padroes add constraint desgaste_padroes_peso_descarte_check CHECK ((peso_descarte >= (0)::numeric));
alter table public.desgaste_padroes add constraint desgaste_padroes_peso_novo_check CHECK ((peso_novo > (0)::numeric));
alter table public.desgaste_registros add constraint desgaste_datas_coerentes CHECK (((data_devolucao IS NULL) OR (data_devolucao >= data_retirada)));
alter table public.desgaste_registros add constraint desgaste_peso_coerente CHECK (((peso_final IS NULL) OR (peso_final <= peso_inicial)));
alter table public.desgaste_registros add constraint desgaste_registros_peca_check CHECK ((peca = ANY (ARRAY['martelo'::text, 'eixo'::text, 'grelha'::text, 'gaveta'::text])));
alter table public.desgaste_registros add constraint desgaste_registros_peso_final_check CHECK ((peso_final >= (0)::numeric));
alter table public.desgaste_registros add constraint desgaste_registros_peso_inicial_check CHECK ((peso_inicial > (0)::numeric));
alter table public.funcionarios add constraint funcionarios_status_check CHECK ((status = ANY (ARRAY['ativo'::text, 'ferias'::text, 'afastado'::text, 'inativo'::text])));
alter table public.lab_laudos add constraint chk_laudo_segregacao CHECK (((responsavel_id IS NULL) OR (aprovador_pallets_id IS NULL) OR (responsavel_id <> aprovador_pallets_id)));
alter table public.notificacoes add constraint notificacoes_tipo_check CHECK ((tipo = ANY (ARRAY['urgente'::text, 'aviso'::text, 'info'::text])));
alter table public.producao_pallets add constraint producao_pallets_estoque_status_check CHECK ((estoque_status = ANY (ARRAY['estoque'::text, 'carregado'::text, 'expedido'::text])));
alter table public.producao_pallets add constraint producao_pallets_status_check CHECK ((status = ANY (ARRAY['pendente'::text, 'aprovado'::text, 'reprovado'::text, 'aguardando_decisao'::text])));
alter table public.usuarios add constraint usuarios_status_check CHECK ((status = ANY (ARRAY['ativo'::text, 'inativo'::text])));

-- ── ÍNDICES ─────────────────────────────────────────────────────────────────
CREATE UNIQUE INDEX bpf_sil002_uniq_mov ON public.bpf_sil002_registros USING btree (almoxarifado_movimento_id) WHERE (almoxarifado_movimento_id IS NOT NULL);
CREATE INDEX idx_afer_adit_data ON public.aferidor_aditivacao USING btree (data);
CREATE INDEX idx_afer_adit_lanc ON public.aferidor_aditivacao USING btree (lancamento_id);
CREATE INDEX idx_alm_mov_data ON public.almoxarifado_movimentos USING btree (data);
CREATE INDEX idx_auditoria_criado_em ON public.auditoria USING btree (criado_em DESC);
CREATE INDEX idx_auditoria_modulo ON public.auditoria USING btree (modulo);
CREATE INDEX idx_carregamentos_data ON public.carregamentos USING btree (data);
CREATE INDEX idx_carregamentos_ordem ON public.carregamentos USING btree (ordem_numero);
CREATE INDEX idx_caulim_analises_ext_status ON public.caulim_analises_externas USING btree (status, tipo);
CREATE INDEX idx_caulim_lotes_prod_status ON public.caulim_lotes_producao USING btree (status);
CREATE INDEX idx_caulim_unidades_qr ON public.caulim_unidades USING btree (qr_codigo);
CREATE INDEX idx_cronograma_data ON public.manutencao_cronograma USING btree (data_ini DESC);
CREATE INDEX idx_desg_estoque_data ON public.desgaste_estoque USING btree (data_entrada DESC);
CREATE INDEX idx_desg_estoque_disp ON public.desgaste_estoque USING btree (peca, condicao) WHERE (status = 'disponivel'::text);
CREATE INDEX idx_desgaste_em_uso ON public.desgaste_registros USING btree (peca, linha) WHERE (data_devolucao IS NULL);
CREATE INDEX idx_desgaste_linha ON public.desgaste_registros USING btree (linha);
CREATE INDEX idx_desgaste_peca_data ON public.desgaste_registros USING btree (peca, data_retirada DESC);
CREATE INDEX idx_epi_entregas_func ON public.epi_entregas USING btree (funcionario_id);
CREATE INDEX idx_epi_func ON public.epi_entregas USING btree (funcionario_id);
CREATE INDEX idx_eq_gerais_status ON public.equipamentos_gerais USING btree (status);
CREATE INDEX idx_eq_linhas_linha ON public.equipamentos_linhas USING btree (linha);
CREATE INDEX idx_eq_linhas_status ON public.equipamentos_linhas USING btree (status);
CREATE INDEX idx_equipamentos_linhas_linha ON public.equipamentos_linhas USING btree (linha);
CREATE INDEX idx_equipamentos_linhas_status ON public.equipamentos_linhas USING btree (status);
CREATE INDEX idx_escalas_periodo ON public.escalas USING btree (periodo_inicio, periodo_fim);
CREATE INDEX idx_escalas_status ON public.escalas USING btree (status);
CREATE INDEX idx_expedicao_status ON public.expedicao USING btree (status);
CREATE INDEX idx_ficha_produto ON public.insumos_ficha USING btree (produto);
CREATE INDEX idx_frota_status ON public.frota_veiculos USING btree (status) WHERE (status IS NOT NULL);
CREATE INDEX idx_funcionarios_setor ON public.funcionarios USING btree (setor);
CREATE INDEX idx_funcionarios_status ON public.funcionarios USING btree (status);
CREATE INDEX idx_insumos_grupo ON public.insumos USING btree (grupo);
CREATE INDEX idx_insumos_grupos_ordem ON public.insumos_grupos USING btree (ordem);
CREATE INDEX idx_insumos_prod ON public.insumos USING btree (produto_vinculado);
CREATE INDEX idx_insumos_status ON public.insumos USING btree (status);
CREATE INDEX idx_insumos_tipo ON public.insumos USING btree (tipo);
CREATE INDEX idx_inv_data ON public.insumos_inventarios USING btree (data);
CREATE INDEX idx_lab_correcao_status ON public.lab_solicitacoes_correcao USING btree (status);
CREATE INDEX idx_lab_data ON public.laboratorio USING btree (data);
CREATE INDEX idx_lab_laudos_producao ON public.lab_laudos USING btree (producao_id);
CREATE INDEX idx_lab_linha ON public.laboratorio USING btree (linha);
CREATE INDEX idx_lab_pallet_analises_lancamento ON public.lab_pallet_analises USING btree (lancamento_id);
CREATE INDEX idx_lab_pallet_analises_pallet ON public.lab_pallet_analises USING btree (pallet_id);
CREATE INDEX idx_laboratorio_amostra_pai ON public.laboratorio USING btree (amostra_pai_id);
CREATE INDEX idx_laboratorio_data ON public.laboratorio USING btree (data);
CREATE INDEX idx_laboratorio_linha ON public.laboratorio USING btree (linha);
CREATE INDEX idx_laboratorio_status_amostra ON public.laboratorio USING btree (status_amostra);
CREATE INDEX idx_lancamentos_centro ON public.lancamentos_custo USING btree (centro_custo_id);
CREATE INDEX idx_lancamentos_data ON public.lancamentos_custo USING btree (data);
CREATE INDEX idx_lancamentos_linha ON public.lancamentos_custo USING btree (linha);
CREATE INDEX idx_lancamentos_modulo ON public.lancamentos_custo USING btree (modulo_origem);
CREATE INDEX idx_lancamentos_natureza ON public.lancamentos_custo USING btree (natureza_id);
CREATE INDEX idx_laudocarr_carr ON public.lab_laudo_carregamentos USING btree (carregamento_id);
CREATE INDEX idx_laudocarr_laudo ON public.lab_laudo_carregamentos USING btree (laudo_id);
CREATE INDEX idx_laudos_lote ON public.lab_laudos USING btree (lote);
CREATE INDEX idx_laudos_producao ON public.lab_laudos USING btree (producao_id);
CREATE INDEX idx_limq_produto ON public.lab_limites_quimicos USING btree (produto);
CREATE UNIQUE INDEX idx_limq_unico ON public.lab_limites_quimicos USING btree (produto, COALESCE(cliente_id, '00000000-0000-0000-0000-000000000000'::uuid), oxido);
CREATE INDEX idx_lotes_insumo ON public.insumos_lotes USING btree (insumo_id);
CREATE INDEX idx_lotes_validade ON public.insumos_lotes USING btree (validade);
CREATE INDEX idx_manut_cron_atualizado ON public.manutencao_cronogramas USING btree (atualizado_em DESC);
CREATE INDEX idx_manut_docs_created ON public.manutencao_docs USING btree (created_at DESC);
CREATE INDEX idx_manut_status ON public.manutencao USING btree (status);
CREATE INDEX idx_manutencao_abertas ON public.manutencao USING btree (data_abertura DESC) WHERE (status = ANY (ARRAY['aberta'::text, 'em_andamento'::text]));
CREATE INDEX idx_manutencao_data ON public.manutencao USING btree (data_abertura DESC);
CREATE INDEX idx_manutencao_equip_status ON public.manutencao USING btree (equipamento, status);
CREATE INDEX idx_manutencao_equipamento ON public.manutencao USING btree (equipamento);
CREATE INDEX idx_manutencao_numero ON public.manutencao USING btree (numero DESC);
CREATE INDEX idx_manutencao_status ON public.manutencao USING btree (status);
CREATE INDEX idx_martelos_linha ON public.producao_martelos USING btree (linha);
CREATE INDEX idx_motivos_status ON public.motivos_parada USING btree (status);
CREATE INDEX idx_mov_data ON public.insumos_movimentos USING btree (data);
CREATE INDEX idx_mov_insumo ON public.insumos_movimentos USING btree (insumo_id);
CREATE INDEX idx_mov_origem ON public.insumos_movimentos USING btree (origem, origem_id);
CREATE INDEX idx_notif_lida ON public.notificacoes USING btree (lida);
CREATE INDEX idx_notif_tipo ON public.notificacoes USING btree (tipo);
CREATE INDEX idx_pallets_barracao ON public.producao_pallets USING btree (barracao);
CREATE INDEX idx_pallets_data ON public.producao_pallets USING btree (data);
CREATE INDEX idx_pallets_estoque ON public.producao_pallets USING btree (estoque_status);
CREATE INDEX idx_pallets_linha ON public.producao_pallets USING btree (linha);
CREATE INDEX idx_pallets_ordem ON public.producao_pallets USING btree (ordem_numero);
CREATE INDEX idx_pallets_romaneio ON public.producao_pallets USING btree (romaneio_numero);
CREATE INDEX idx_pallets_status ON public.producao_pallets USING btree (status);
CREATE INDEX idx_planejamentos_mes ON public.planejamentos USING btree (mes);
CREATE INDEX idx_portaria_status ON public.portaria USING btree (status);
CREATE INDEX idx_producao_data ON public.producao USING btree (data);
CREATE INDEX idx_producao_linha ON public.producao USING btree (linha);
CREATE INDEX idx_producao_pallets_lancamento ON public.producao_pallets USING btree (lancamento_id);
CREATE INDEX idx_romaneio_itens_rom ON public.romaneio_itens USING btree (romaneio_id);
CREATE INDEX idx_romaneios_status ON public.romaneios USING btree (status);
CREATE INDEX idx_solcad_pendentes ON public.almoxarifado_solicitacoes_cadastro USING btree (status, origem, equipamento, codigo_especificacao);
CREATE INDEX idx_ter_rem_data ON public.terceiros_remessas USING btree (data_saida);
CREATE INDEX idx_ter_rem_prest ON public.terceiros_remessas USING btree (prestador_id);
CREATE INDEX idx_ter_rem_status ON public.terceiros_remessas USING btree (status);
CREATE INDEX idx_ter_sv_comp ON public.terceiros_servicos USING btree (competencia);
CREATE INDEX idx_ter_sv_prest ON public.terceiros_servicos USING btree (prestador_id);
CREATE INDEX idx_ter_sv_remessa ON public.terceiros_servicos USING btree (remessa_id);
CREATE INDEX idx_ter_sv_status ON public.terceiros_servicos USING btree (status);
CREATE INDEX idx_usuarios_email ON public.usuarios USING btree (email);
CREATE INDEX ix_bpf_calib ON public.bpf_calibracoes USING btree (instrumento_id, validade DESC);
CREATE INDEX ix_bpf_crono ON public.bpf_cronograma USING btree (ano, tipo);
CREATE INDEX ix_bpf_desig ON public.bpf_designacoes USING btree (funcao_cod, pop_cod, ativo);
CREATE INDEX ix_bpf_desig_func ON public.bpf_designacoes USING btree (funcionario_id, ativo);
CREATE INDEX ix_bpf_doc_rev ON public.bpf_documento_revisoes USING btree (documento_cod);
CREATE INDEX ix_bpf_docs_pop ON public.bpf_documentos_mestre USING btree (pop_cod);
CREATE INDEX ix_bpf_docs_tipo ON public.bpf_documentos_mestre USING btree (tipo, status);
CREATE INDEX ix_bpf_form_pop ON public.bpf_formularios USING btree (pop_cod, ativo);
CREATE INDEX ix_bpf_forn ON public.bpf_fornecedores_qualif USING btree (categoria_risco, status);
CREATE INDEX ix_bpf_insp_veic ON public.bpf_inspecao_veiculo USING btree (romaneio_id, data DESC);
CREATE INDEX ix_bpf_reg_form ON public.bpf_registros USING btree (formulario_cod, data DESC);
CREATE INDEX ix_bpf_reg_orig ON public.bpf_registros USING btree (origem_modulo, origem_id);
CREATE INDEX ix_bpf_reg_pop ON public.bpf_registros USING btree (pop_cod, data DESC);
CREATE INDEX ix_bpf_reg_st ON public.bpf_registros USING btree (status);
CREATE INDEX ix_bpf_reg_val ON public.bpf_registros USING btree (validade) WHERE (validade IS NOT NULL);
CREATE INDEX ix_bpf_rotulo ON public.bpf_rotulos USING btree (produto_id, status);
CREATE INDEX ix_bpf_trilha_reg ON public.bpf_registro_trilha USING btree (registro_id, em DESC);
CREATE INDEX ix_bpf_vis_ac ON public.bpf_visitante_acessos USING btree (visitante_id, data DESC);
CREATE INDEX ix_llc_laudo ON public.lab_laudo_carregamentos USING btree (laudo_id);
CREATE INDEX ix_lpa_data ON public.lab_pallet_analises USING btree (data DESC);
CREATE INDEX ix_lpa_lanc ON public.lab_pallet_analises USING btree (lancamento_id);
CREATE INDEX ix_lpa_pallet ON public.lab_pallet_analises USING btree (pallet_id);
CREATE INDEX ix_lpa_result ON public.lab_pallet_analises USING btree (resultado);
CREATE UNIQUE INDEX uq_mov_op ON public.insumos_movimentos USING btree (origem, origem_id, insumo_id, COALESCE(lote_id, '00000000-0000-0000-0000-000000000000'::uuid)) WHERE (origem = 'OP'::text);
CREATE UNIQUE INDEX ux_lab_laudos_numero ON public.lab_laudos USING btree (numero);
CREATE UNIQUE INDEX ux_lab_laudos_producao ON public.lab_laudos USING btree (producao_id);

-- ── VIEWS ───────────────────────────────────────────────────────────────────
create or replace view public.v_insumos_consumo_30d as
 SELECT i.id AS insumo_id,
    (COALESCE(sum(m.quantidade), (0)::numeric) / 30.0) AS consumo_dia
   FROM (insumos i
     LEFT JOIN insumos_movimentos m ON (((m.insumo_id = i.id) AND (m.tipo = ANY (ARRAY['consumo'::text, 'perda'::text])) AND (m.data >= (CURRENT_DATE - '30 days'::interval)))))
  GROUP BY i.id;

create or replace view public.v_insumos_saldo as
 SELECT i.id,
    i.codigo,
    i.nome,
    i.grupo,
    i.tipo,
    i.unidade_estoque,
    i.estoque_minimo,
    COALESCE(sum(
        CASE m.tipo
            WHEN 'entrada'::text THEN m.quantidade
            WHEN 'devolucao'::text THEN m.quantidade
            WHEN 'retorno'::text THEN m.quantidade
            WHEN 'ajuste'::text THEN m.quantidade
            WHEN 'consumo'::text THEN (- m.quantidade)
            WHEN 'perda'::text THEN (- m.quantidade)
            WHEN 'saida'::text THEN (- m.quantidade)
            ELSE (0)::numeric
        END), (0)::numeric) AS saldo
   FROM (insumos i
     LEFT JOIN insumos_movimentos m ON ((m.insumo_id = i.id)))
  GROUP BY i.id;

-- ── FUNCTIONS (parte 1: auth, bpf, branding, carregamento, epi, importar) ───
CREATE OR REPLACE FUNCTION public.auth_perfil()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select perfil from usuarios where auth_id = auth.uid() limit 1;
$function$;

CREATE OR REPLACE FUNCTION public.auth_pode_modulo(modulo text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select public.auth_perfil() = 'SADM'
      or coalesce((select permissoes -> modulo ->> 'view' = 'true'
                   from perfis where codigo = public.auth_perfil()), false);
$function$;

CREATE OR REPLACE FUNCTION public.bpf_bloqueia_delete()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  if old.status = 'rascunho'
     and coalesce(jsonb_array_length(old.assinaturas), 0) = 0
     and old.concluido_em is null then
    return old;
  end if;
  raise exception 'SYS-003: % já é registro do SGQ e não pode ser excluído (retenção de % anos). Use o cancelamento com motivo.',
    coalesce(old.numero, 'o registro'),
    coalesce((select retencao_anos from bpf_formularios where codigo = old.formulario_cod), 4);
end $function$;

CREATE OR REPLACE FUNCTION public.bpf_gerar_protocolo()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
declare
  v_alfabeto constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; -- sem O/0, I/1
  v_cod text;
  v_i int;
begin
  loop
    v_cod := '';
    for v_i in 1..6 loop
      v_cod := v_cod || substr(v_alfabeto, 1 + floor(random()*length(v_alfabeto))::int, 1);
    end loop;
    v_cod := 'MF-' || to_char(current_date,'YYYY') || '-' || v_cod;
    exit when not exists (select 1 from bpf_manifestacoes where numero = v_cod);
  end loop;
  return v_cod;
end $function$;

CREATE OR REPLACE FUNCTION public.bpf_gerar_protocolo_rc()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
declare
  v_alfabeto constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; -- sem O/0, I/1
  v_cod text; v_i int;
begin
  loop
    v_cod := '';
    for v_i in 1..6 loop
      v_cod := v_cod || substr(v_alfabeto, 1 + floor(random()*length(v_alfabeto))::int, 1);
    end loop;
    v_cod := 'RC-' || to_char(current_date,'YYYY') || '-' || v_cod;
    exit when not exists (select 1 from bpf_reclamacoes where numero = v_cod);
  end loop;
  return v_cod;
end $function$;

CREATE OR REPLACE FUNCTION public.bpf_proximo_numero(p_form text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
declare v_seq int;
begin
  insert into bpf_sequencias(formulario_cod, ultimo) values (p_form, 1)
    on conflict (formulario_cod) do update set ultimo = bpf_sequencias.ultimo + 1
    returning ultimo into v_seq;
  return p_form || '-' || lpad(v_seq::text, 6, '0');
end $function$;

CREATE OR REPLACE FUNCTION public.bpf_purgar_pre_producao(p_confirmacao text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_regs int; v_trilha int;
begin
  if p_confirmacao is distinct from 'APAGAR TUDO DE TESTE' then
    raise exception 'Confirmação incorreta. Para apagar, chame com a frase exata: APAGAR TUDO DE TESTE';
  end if;
  select count(*) into v_regs   from bpf_registros;
  select count(*) into v_trilha from bpf_registro_trilha;

  alter table bpf_registro_trilha disable trigger tg_bpf_trilha_imutavel;
  alter table bpf_registros       disable trigger tg_bpf_registros_no_delete;
  delete from bpf_registro_trilha;
  delete from bpf_registros;
  alter table bpf_registros       enable trigger tg_bpf_registros_no_delete;
  alter table bpf_registro_trilha enable trigger tg_bpf_trilha_imutavel;

  update bpf_sequencias set ultimo = 0;
  return format('Apagados %s registro(s) e %s linha(s) de trilha. Sequenciais zerados.', v_regs, v_trilha);
end $function$;

CREATE OR REPLACE FUNCTION public.bpf_reclamacao_aberta(p_num text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (
    select 1 from bpf_reclamacoes
     where numero = p_num
       and status <> 'encerrada'
       and created_at > now() - interval '30 days'
  );
$function$;

CREATE OR REPLACE FUNCTION public.bpf_set_numero()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  if new.numero is null or new.numero = '' then
    new.numero := bpf_proximo_numero(new.formulario_cod);
  end if;
  if new.retencao_ate is null then
    new.retencao_ate := new.data + make_interval(years =>
      coalesce((select retencao_anos from bpf_formularios where codigo = new.formulario_cod), 4));
  end if;
  return new;
end $function$;

CREATE OR REPLACE FUNCTION public.bpf_trilha_imutavel()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  raise exception 'SYS-002/SYS-043: a trilha de auditoria é imutável.';
end $function$;

CREATE OR REPLACE FUNCTION public.branding_publico()
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select jsonb_build_object('nome_fantasia',nome_fantasia,'razao_social',razao_social,'logo',logo)
  from empresa_config limit 1;
$function$;

CREATE OR REPLACE FUNCTION public.carregamento_por_ordem(ordem text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select jsonb_build_object('transportadora',transportadora,'placa',placa,
    'motorista',motorista,'hora',hora,'data',data)
  from carregamentos where ordem_numero = ordem order by created_at desc limit 1;
$function$;

CREATE OR REPLACE FUNCTION public.epi_qr(func_id text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select case when f.id is null then null else jsonb_build_object(
    'func',   jsonb_build_object('id',f.id,'nome',f.nome,'setor',f.setor,'funcao',f.funcao,'status',f.status),
    'epis',   coalesce((select jsonb_agg(to_jsonb(e)) from epi_cadastro e),'[]'::jsonb),
    'ents',   coalesce((select jsonb_agg(to_jsonb(en) order by en.data_entrega desc)
                        from epi_entregas en where en.funcionario_id::text = f.id::text),'[]'::jsonb),
    'treins', coalesce((select jsonb_agg(to_jsonb(t) order by t.data_realizacao desc)
                        from epi_treinamentos t where t.funcionario_id::text = f.id::text),'[]'::jsonb)
  ) end
  from (select * from funcionarios where id::text = func_id) f;
$function$;

CREATE OR REPLACE FUNCTION public.importar_romaneio(rom jsonb, itens jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare rid text;
begin
  insert into romaneios (numero, data_emissao, transportadora, motorista, placa, origem)
  values (rom->>'numero', rom->>'data_emissao', rom->>'transportadora',
          rom->>'motorista', rom->>'placa', rom->>'origem')
  on conflict (numero) do update set
    data_emissao=excluded.data_emissao, transportadora=excluded.transportadora,
    motorista=excluded.motorista, placa=excluded.placa, origem=excluded.origem
  returning id::text into rid;
  delete from romaneio_itens where numero = rom->>'numero';
  if coalesce(jsonb_array_length(itens),0) > 0 then
    insert into romaneio_itens (numero, pedido, cidade, cliente, produto, quantidade, caixa, lote, romaneio_id)
    select rom->>'numero', x->>'pedido', x->>'cidade', x->>'cliente', x->>'produto',
           x->>'quantidade', x->>'caixa', x->>'lote', rid
    from jsonb_array_elements(itens) x;
  end if;
  return jsonb_build_object('id', rid, 'itens', coalesce(jsonb_array_length(itens),0));
end $function$;

-- ── FUNCTIONS (parte 2: lab, manifestação, pallet, rastreio, reclamação) ────
CREATE OR REPLACE FUNCTION public.lab_bloqueia_edicao()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
declare
  v_campos constant text[] := array[
    'peneiramento_raw','umidade','mm_result','peso_esp_result',
    'status','status_amostra','resultado','aprovado','granulometria'];
  v_novo jsonb := to_jsonb(new);
  v_velho jsonb := to_jsonb(old);
  c text;
begin
  if (v_velho->>'finalizada_em') is null then return new; end if;      -- ainda aberta
  if coalesce((v_velho->>'correcao_liberada')::boolean,false) then     -- correção aprovada
    new.correcao_liberada := false;                                    -- vale uma vez só
    return new;
  end if;

  foreach c in array v_campos loop
    if (v_novo ? c) and ((v_novo->c) is distinct from (v_velho->c)) then
      raise exception 'Analise finalizada em % nao pode ser alterada (campo "%"). Abra uma Solicitacao de Correcao (Regra 2) — ela exige aprovacao de Engenharia ou Administrador e preserva o valor anterior.',
        to_char((v_velho->>'finalizada_em')::timestamptz,'DD/MM/YYYY HH24:MI'), c;
    end if;
  end loop;
  return new;
end $function$;

CREATE OR REPLACE FUNCTION public.lab_notifica_pallet_reprovado()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  if new.resultado = 'reprovado' then
    perform lab_notificar(
      '🔴 Pallet reprovado no laboratório',
      format('%s · pallet #%s (intervalo %s–%s) reprovado por %s. Motivo: %s',
             coalesce(new.produto,'—'), coalesce(new.pallet_numero::text,'—'),
             coalesce(new.intervalo_ini::text,'—'), coalesce(new.intervalo_fim::text,'—'),
             coalesce(new.responsavel,'—'), coalesce(new.motivo_reprovacao,'—')),
      'erro');
  elsif new.resultado = 'aguardando_decisao' then
    perform lab_notificar(
      '⚠️ Pallet aguardando decisão da diretoria',
      format('%s · pallet #%s precisa de decisão. Motivo: %s',
             coalesce(new.produto,'—'), coalesce(new.pallet_numero::text,'—'),
             coalesce(new.motivo_reprovacao,'—')),
      'alerta');
  end if;
  return new;
end $function$;

CREATE OR REPLACE FUNCTION public.lab_notificar(p_titulo text, p_mensagem text, p_tipo text DEFAULT 'alerta'::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  insert into notificacoes (titulo, mensagem, tipo, modulo, lida)
  values (p_titulo, p_mensagem, coalesce(p_tipo,'alerta'), 'laboratorio', false);
exception when others then
  -- Notificação nunca pode derrubar o salvamento do ensaio.
  raise notice 'lab_notificar falhou: %', sqlerrm;
end $function$;

CREATE OR REPLACE FUNCTION public.lab_proximo_numero_laudo()
 RETURNS text
 LANGUAGE plpgsql
AS $function$
declare v_ano int := extract(year from current_date)::int; v_seq int;
begin
  insert into lab_laudo_sequencia(ano, ultimo) values (v_ano, 1)
    on conflict (ano) do update set ultimo = lab_laudo_sequencia.ultimo + 1
    returning ultimo into v_seq;
  return 'LAU-' || v_ano || '-' || lpad(v_seq::text, 4, '0');
end $function$;

CREATE OR REPLACE FUNCTION public.lab_set_numero_laudo()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  if new.numero is null or new.numero = '' then
    new.numero := lab_proximo_numero_laudo();
  end if;
  return new;
end $function$;

CREATE OR REPLACE FUNCTION public.manifestacao_abrir(p_tema text, p_descricao text, p_anonimo boolean DEFAULT true, p_autor text DEFAULT NULL::text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_num text; v_autor text; v_recentes int;
begin
  if p_tema is null or p_tema not in ('reclamacao','sugestao','elogio') then
    raise exception 'Escolha o tema: reclamação, sugestão ou elogio.';
  end if;
  if p_descricao is null or length(btrim(p_descricao)) < 10 then
    raise exception 'Descreva a manifestação com pelo menos 10 caracteres.';
  end if;
  if length(p_descricao) > 5000 then
    raise exception 'Texto muito longo (máximo 5.000 caracteres).';
  end if;

  -- Freio simples de enxurrada. Não identifica ninguém: só conta o volume
  -- total do último minuto. Canal interno de fábrica, exposição baixa.
  select count(*) into v_recentes
    from bpf_manifestacoes
   where created_at > now() - interval '1 minute';
  if v_recentes >= 20 then
    raise exception 'Muitas manifestações neste momento. Tente novamente em um minuto.';
  end if;

  -- Anonimato decidido no BANCO, não no navegador: se marcou anônima, o nome
  -- é descartado aqui, mesmo que a tela tenha mandado alguma coisa.
  v_autor := case when coalesce(p_anonimo,true) then null
                  else nullif(btrim(coalesce(p_autor,'')),'') end;

  v_num := bpf_gerar_protocolo();

  insert into bpf_manifestacoes (numero, data, anonimo, autor_nome, tema, descricao, status)
  values (v_num, current_date, coalesce(p_anonimo,true), v_autor,
          p_tema, btrim(p_descricao), 'aberta');

  return json_build_object(
    'numero', v_num,
    'mensagem', 'Manifestação registrada. Guarde o protocolo para acompanhar a resposta.'
  );
end $function$;

CREATE OR REPLACE FUNCTION public.manifestacao_consultar(p_numero text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r record;
begin
  select numero, data, tema, status, tratamento, retorno, encerrado_em
    into r
    from bpf_manifestacoes
   where upper(btrim(numero)) = upper(btrim(p_numero));

  if not found then
    return json_build_object('encontrado', false);
  end if;

  return json_build_object(
    'encontrado',   true,
    'numero',       r.numero,
    'data',         r.data,
    'tema',         r.tema,
    'status',       r.status,
    'tratamento',   r.tratamento,
    'retorno',      r.retorno,
    'encerrado_em', r.encerrado_em
  );
end $function$;

CREATE OR REPLACE FUNCTION public.pallet_guarda_estado()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  de   text := coalesce(old.estoque_status, 'estoque');
  para text := coalesce(new.estoque_status, 'estoque');
begin
  if de = para then
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

  if de = 'estoque'   and para = 'carregado' then return new; end if;
  if de = 'carregado' and para = 'expedido'  then return new; end if;
  if de = 'carregado' and para = 'estoque'   then return new; end if;

  raise exception 'Transição de estoque inválida no pallet %: % → %.',
    coalesce(old.codigo, old.id::text), de, para
    using errcode = 'P0001',
          hint = 'Permitido: estoque→carregado, carregado→expedido, carregado→estoque (reabertura).';
end;
$function$;

CREATE OR REPLACE FUNCTION public.rastreio_por_codigo(cod text)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select to_jsonb(pp) || jsonb_build_object('producao',
    (select to_jsonb(pr) from (select op_numero,produtos_op,encarregado,equipe,turno,data,lote_mp
       from producao where id = pp.lancamento_id) pr))
  from producao_pallets pp where pp.codigo = cod limit 1;
$function$;

CREATE OR REPLACE FUNCTION public.rastreio_por_data_numero(dt date, num integer)
 RETURNS SETOF jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select to_jsonb(pp) || jsonb_build_object('producao',
    (select to_jsonb(pr) from (select op_numero,produtos_op,encarregado,equipe,turno,data,lote_mp
       from producao where id = pp.lancamento_id) pr))
  from producao_pallets pp where pp.data = dt and pp.numero = num;
$function$;

CREATE OR REPLACE FUNCTION public.rastreio_por_ordem(ordem text)
 RETURNS SETOF jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select to_jsonb(pp) || jsonb_build_object('producao',
    (select to_jsonb(pr) from (select op_numero,produtos_op,encarregado,equipe,turno,data,lote_mp
       from producao where id = pp.lancamento_id) pr))
  from producao_pallets pp where pp.ordem_numero = ordem and pp.estoque_status = 'carregado';
$function$;

CREATE OR REPLACE FUNCTION public.reclamacao_abrir(p_cliente text, p_contato text, p_descricao text, p_produto text DEFAULT NULL::text, p_lote text DEFAULT NULL::text, p_nota_fiscal text DEFAULT NULL::text, p_canal text DEFAULT 'formulario_web'::text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_num text; v_recentes int; v_prazo date;
begin
  if p_cliente is null or length(btrim(p_cliente)) < 2 then
    raise exception 'Informe o nome da empresa ou da pessoa que está reclamando.';
  end if;
  if p_contato is null or length(btrim(p_contato)) < 6 then
    raise exception 'Informe um contato (e-mail ou telefone) para recebermos o retorno.';
  end if;
  if p_descricao is null or length(btrim(p_descricao)) < 15 then
    raise exception 'Descreva o ocorrido com pelo menos 15 caracteres.';
  end if;
  if length(p_descricao) > 5000 then
    raise exception 'Texto muito longo (máximo 5.000 caracteres).';
  end if;

  -- Canal aberto na internet: freio de enxurrada um pouco mais firme que o
  -- do colaborador, que fica atrás de um QR dentro da fábrica.
  select count(*) into v_recentes
    from bpf_reclamacoes
   where created_at > now() - interval '1 minute';
  if v_recentes >= 10 then
    raise exception 'Muitas solicitações neste momento. Tente novamente em um minuto.';
  end if;

  v_num   := bpf_gerar_protocolo_rc();
  v_prazo := current_date + 15;   -- SYS-025

  insert into bpf_reclamacoes
    (numero, canal, cliente, contato, produto, lote_ref, nota_fiscal,
     data_recebimento, prazo_ate, descricao, status, escalonado_para)
  values
    (v_num,
     coalesce(nullif(btrim(p_canal),''),'formulario_web'),
     btrim(p_cliente), btrim(p_contato),
     nullif(btrim(coalesce(p_produto,'')),''),
     nullif(btrim(coalesce(p_lote,'')),''),
     nullif(btrim(coalesce(p_nota_fiscal,'')),''),
     current_date, v_prazo, btrim(p_descricao), 'aberta', 'nenhum');

  return json_build_object(
    'numero', v_num,
    'prazo',  v_prazo,
    'mensagem','Reclamação registrada. Responderemos em até 15 dias.'
  );
end $function$;

CREATE OR REPLACE FUNCTION public.reclamacao_anexar(p_numero text, p_path text, p_nome text, p_tamanho bigint DEFAULT NULL::bigint, p_tipo text DEFAULT NULL::text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r record; v_qtd int;
begin
  select id, numero, status, anexos into r
    from bpf_reclamacoes
   where upper(btrim(numero)) = upper(btrim(p_numero));

  if not found then
    raise exception 'Protocolo não encontrado.';
  end if;
  if r.status = 'encerrada' then
    raise exception 'Esta reclamação já foi encerrada e não aceita novos anexos.';
  end if;

  v_qtd := coalesce(jsonb_array_length(r.anexos), 0);
  if v_qtd >= 5 then
    raise exception 'Limite de 5 fotos por reclamação já foi atingido.';
  end if;

  -- O caminho tem de pertencer à pasta deste protocolo. Sem isso, alguém
  -- poderia apontar o anexo de uma reclamação para o arquivo de outra.
  if p_path is null or p_path not like ('reclamacoes/' || r.numero || '/%') then
    raise exception 'Caminho de arquivo inválido para este protocolo.';
  end if;

  update bpf_reclamacoes
     set anexos = coalesce(anexos,'[]'::jsonb) || jsonb_build_object(
           'nome',    coalesce(nullif(btrim(p_nome),''),'foto'),
           'path',    p_path,
           'bucket',  'publico-anexos',
           'tipo',    p_tipo,
           'tamanho', p_tamanho,
           'origem',  'cliente',
           'em',      now()
         )
   where id = r.id;

  return json_build_object('ok', true, 'total', v_qtd + 1);
end $function$;

CREATE OR REPLACE FUNCTION public.reclamacao_consultar(p_numero text)
 RETURNS json
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare r record;
begin
  select numero, data_recebimento, prazo_ate, produto, lote_ref,
         status, analise_causa, plano_acao, encerrado_em
    into r
    from bpf_reclamacoes
   where upper(btrim(numero)) = upper(btrim(p_numero));

  if not found then
    return json_build_object('encontrado', false);
  end if;

  return json_build_object(
    'encontrado',    true,
    'numero',        r.numero,
    'data',          r.data_recebimento,
    'prazo',         r.prazo_ate,
    'produto',       r.produto,
    'lote',          r.lote_ref,
    'status',        r.status,
    'analise_causa', r.analise_causa,
    'plano_acao',    r.plano_acao,
    'encerrado_em',  r.encerrado_em
  );
end $function$;

CREATE OR REPLACE FUNCTION public.turnos_publico()
 RETURNS SETOF jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select jsonb_build_object('nome',nome,'calendario',calendario,'status',status)
  from turnos where status = 'ativo';
$function$;

-- ── TRIGGERS ────────────────────────────────────────────────────────────────
create trigger tg_bpf_set_numero before insert on public.bpf_registros
  for each row execute function public.bpf_set_numero();
create trigger tg_bpf_registros_no_delete before delete on public.bpf_registros
  for each row execute function public.bpf_bloqueia_delete();
create trigger tg_bpf_trilha_imutavel before delete or update on public.bpf_registro_trilha
  for each row execute function public.bpf_trilha_imutavel();
create trigger tg_lab_set_numero_laudo before insert on public.lab_laudos
  for each row execute function public.lab_set_numero_laudo();
create trigger tg_lab_bloqueia_edicao before update on public.laboratorio
  for each row execute function public.lab_bloqueia_edicao();
create trigger tg_lab_notifica_pallet after insert on public.lab_pallet_analises
  for each row execute function public.lab_notifica_pallet_reprovado();
create trigger tg_pallet_guarda_estado before update of estoque_status, ordem_numero on public.producao_pallets
  for each row execute function public.pallet_guarda_estado();

-- ── RLS E POLICIES ──────────────────────────────────────────────────────────
-- Estado atual: RLS ligado em todas as tabelas; policy baseline "authenticated
-- pode tudo" (autenticação, não autorização — o refinamento por perfil é a
-- fase 2 do plano). Exceções: usuarios (só SADM gerencia; cada um lê a si
-- mesmo) e as duas tabelas de folha/custo (por permissão de módulo).
do $$
declare t text;
begin
  for t in
    select c.relname from pg_class c
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind='r'
  loop
    execute format('alter table public.%I enable row level security', t);
    if t not in ('usuarios','folhas_pagamento','planejamentos_custo') then
      execute format(
        'create policy baseline_authenticated_all on public.%I for all to authenticated using (true) with check (true)', t);
    end if;
  end loop;
end $$;
create policy usuarios_sadm_all on public.usuarios
  for all to authenticated
  using (auth_perfil() = 'SADM'::text) with check (auth_perfil() = 'SADM'::text);
create policy usuarios_self_read on public.usuarios
  for select to authenticated
  using ((auth_id = auth.uid()) OR (auth_perfil() = 'SADM'::text));
create policy folha_por_modulo on public.folhas_pagamento
  for all to authenticated
  using (auth_pode_modulo('custo_precificacao'::text)) with check (auth_pode_modulo('custo_precificacao'::text));
create policy plan_custo_por_modulo on public.planejamentos_custo
  for all to authenticated
  using (auth_pode_modulo('custo_precificacao'::text)) with check (auth_pode_modulo('custo_precificacao'::text));

-- ── DADOS-SEMENTE ───────────────────────────────────────────────────────────
insert into public.app_preferencias (chave, dados, atualizado_em)
values ('carregamento_liberar_pendentes',
        jsonb_build_object('valor', false, 'por', 'baseline', 'em', now()), now())
on conflict (chave) do nothing;

-- fim do baseline
