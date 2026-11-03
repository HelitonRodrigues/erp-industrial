-- 099 — Portaria / aba "Caulim e Grafitoso" (minério)
--  • minerio_materiais: lista de materiais da pesagem (Caulim, Grafitoso + "＋ Outro")
--  • perfil PRT (Porteiro): aba minerio explícita (tudo menos excluir) — o catálogo de abas da
--    portaria entrou no utils.js; sem isso, salvar o perfil no perfis.html deixaria a aba só "ver"
--  • perfil MIN (Minério — consulta): só a aba minerio da portaria, só ver/imprimir/exportar
--  • usuário Fabio Gomes (perfil MIN). O LOGIN (senha) é criado pelo dono em Usuários → 🔑.

create table if not exists public.minerio_materiais (
  codigo     text primary key,              -- o que fica gravado em minerio_viagens.material
  nome       text not null,
  ordem      int  not null default 100,
  ativo      boolean not null default true,
  criado_por text,
  criado_em  timestamptz not null default now()
);
alter table public.minerio_materiais enable row level security;
drop policy if exists baseline_authenticated_all on public.minerio_materiais;
create policy baseline_authenticated_all on public.minerio_materiais for all to authenticated using (true) with check (true);
insert into public.minerio_materiais (codigo, nome, ordem) values ('CAULIM','Caulim',10), ('GRAFITOSO','Grafitoso',20)
  on conflict (codigo) do nothing;

-- Porteiro: aba minerio com as mesmas ações das outras (sem excluir) + imprimir
update public.perfis
   set permissoes = jsonb_set(permissoes, '{portaria,abas,minerio}',
         '{"view":true,"create":true,"edit":true,"delete":false,"export":true,"imprimir":true}'::jsonb, true)
 where codigo = 'PRT';

-- Minério (consulta): todos os módulos desligados, só portaria → aba minerio (ver)
insert into public.perfis (codigo, nome, descricao, cor, permissoes)
select 'MIN', 'Minério (consulta)', 'Só a aba Caulim e Grafitoso da Portaria — ver, imprimir e exportar.', '#475569',
       (select jsonb_object_agg(k, '{"view":false,"create":false,"edit":false,"delete":false,"export":false}'::jsonb)
          from (select jsonb_object_keys(permissoes) k from public.perfis where codigo = 'PRT') x)
       || jsonb_build_object('portaria', jsonb_build_object(
            'view', true, 'create', false, 'edit', false, 'delete', false, 'export', true,
            'abas', jsonb_build_object(
              'fila',       '{"view":false,"create":false,"edit":false,"delete":false,"export":false}'::jsonb,
              'ordens',     '{"view":false,"create":false,"edit":false,"delete":false,"export":false}'::jsonb,
              'motoristas', '{"view":false,"create":false,"edit":false,"delete":false,"export":false}'::jsonb,
              'fechamento', '{"view":false,"create":false,"edit":false,"delete":false,"export":false}'::jsonb,
              'historico',  '{"view":false,"create":false,"edit":false,"delete":false,"export":false}'::jsonb,
              'visitantes', '{"view":false,"create":false,"edit":false,"delete":false,"export":false}'::jsonb,
              'minerio',    '{"view":true,"create":false,"edit":false,"delete":false,"export":true,"imprimir":true}'::jsonb)))
 where not exists (select 1 from public.perfis where codigo = 'MIN');

insert into public.usuarios (nome, email, login, perfil, status, setor, funcao)
select 'Fabio Gomes', 'fabio@silicate.com.br', 'fabio', 'MIN', 'ativo', 'Mineração', 'Consulta de minério'
 where not exists (select 1 from public.usuarios where lower(email) = 'fabio@silicate.com.br' or login = 'fabio');
