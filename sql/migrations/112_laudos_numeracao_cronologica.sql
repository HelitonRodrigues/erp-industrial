-- 112 — Numeração dos laudos em ordem cronológica do lote (nov/2026)
-- LAU-AAAA-0001 = lote mais antigo do ano (data de fabricação → linha → produto → lote).
-- Só renumera enquanto NENHUM certificado foi entregue em carga (lab_laudo_carregamentos vazio):
-- depois disso o número já saiu para o cliente e fica congelado (retorna -1).
-- Laudo que mudou de número perde o arquivo_path → a folha é regravada com o número novo ao abrir/imprimir.

create or replace function public.lab_renumerar_laudos()
returns integer
language plpgsql
set search_path to 'public'
as $$
declare v_mud int;
begin
  if exists(select 1 from lab_laudo_carregamentos) then return -1; end if;
  perform pg_advisory_xact_lock(hashtext('lab_renumerar_laudos'));

  drop table if exists _lau_num;
  create temp table _lau_num on commit drop as
  select id, numero antigo,
         'LAU-'||extract(year from coalesce(data_fabricacao,emitido_em::date,current_date))::int||'-'||
         lpad(row_number() over (partition by extract(year from coalesce(data_fabricacao,emitido_em::date,current_date))
              order by coalesce(data_fabricacao,emitido_em::date,current_date), coalesce(dados_snapshot->>'linha',''),
                       coalesce(produto,''), coalesce(lote,''), emitido_em, id)::text, 4, '0') novo
  from lab_laudos;

  select count(*) into v_mud from _lau_num where antigo is distinct from novo;
  if v_mud = 0 then return 0; end if;

  -- 2 fases: os índices únicos de numero não aceitam troca direta
  update lab_laudos l set numero = 'TMP-'||l.id from _lau_num n where n.id=l.id and n.antigo is distinct from n.novo;
  update lab_laudos l set numero = n.novo, arquivo_path = null from _lau_num n where n.id=l.id and n.antigo is distinct from n.novo;

  update producao p set laudo_numero = l.numero from lab_laudos l
   where p.laudo_id = l.id and p.laudo_numero is distinct from l.numero;

  insert into lab_laudo_sequencia(ano, ultimo)
  select split_part(numero,'-',2)::int, max(split_part(numero,'-',3)::int) from lab_laudos
   where numero ~ '^LAU-\d{4}-\d+$' group by 1
  on conflict (ano) do update set ultimo = excluded.ultimo;

  return v_mud;
end $$;

grant execute on function public.lab_renumerar_laudos() to authenticated;
