-- 084 — BPF: numeração dos registros em ordem de data (aplicado direto no banco em 27/10/2026)
-- • data do registro = data do EVENTO (antes ficava a do prazo).
-- • bpf_renumerar(form): o registro mais antigo (desde a vigência) é o 000001; canceladas vão para o fim.
--   Só renumera se nenhuma ficha ATIVA daquele registro foi impressa, lançada ou assinada.
--   Chamado pelo BPF depois de gerar fichas novas; aplicado nos POPs 01 a 04.
create or replace function public.bpf_renumerar(p_form text) returns integer
language plpgsql security definer set search_path=public as $$
declare n integer;
begin
  if exists(select 1 from bpf_registros where formulario_cod=p_form and cancelado_em is null and (ficha_impressa_em is not null or lancado_em is not null
        or concluido_em is not null or jsonb_array_length(coalesce(assinaturas,'[]'::jsonb))>0)) then return 0; end if;
  update bpf_registros set numero='TMP-'||id::text where formulario_cod=p_form;
  with o as (select id, row_number() over (order by (cancelado_em is not null), data, hora nulls last, created_at, id) rn
               from bpf_registros where formulario_cod=p_form)
  update bpf_registros r set numero=p_form||'-'||lpad(o.rn::text,6,'0') from o where o.id=r.id;
  get diagnostics n = row_count;
  insert into bpf_sequencias(formulario_cod, ultimo) values (p_form, n)
    on conflict (formulario_cod) do update set ultimo=excluded.ultimo;
  return n;
end $$;
grant execute on function public.bpf_renumerar(text) to authenticated;
