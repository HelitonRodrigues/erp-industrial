-- 092 — BPF: aviso de atraso resumido (aplicado direto no banco em 28/10/2026)
-- O levantamento desde a vigência gerou 651 avisos "ficha atrasada" — apagados.
-- bpf_notificar_atrasos: só o que venceu nos últimos 7 dias e UM aviso por POP por dia, com a quantidade.
delete from notificacoes where fonte='bpf' and chave like 'bpf_atraso%';
create or replace function public.bpf_notificar_atrasos()
returns integer language plpgsql security definer set search_path=public as $$
declare x record; n integer := 0; v_dia text := to_char(now() at time zone 'America/Sao_Paulo','YYYY-MM-DD');
begin
  for x in select t.pop_cod, count(*) qtd, min(t.prazo) mais_antigo from bpf_tarefas t
            where t.status='aberta' and t.prazo < now() and t.prazo >= now() - interval '7 days' group by t.pop_cod loop
    if not exists (select 1 from notificacoes where chave = 'bpf_atraso_'||x.pop_cod||'_'||v_dia) then
      insert into notificacoes (tipo, modulo, titulo, descricao, chave, fonte, destinatarios)
      values ('urgente','bpf','BPF '||x.pop_cod||': '||x.qtd||' ficha(s) atrasada(s)',
              'Venceram nos últimos 7 dias · a mais antiga em '||to_char(x.mais_antigo at time zone 'America/Sao_Paulo','DD/MM HH24:MI'),
              'bpf_atraso_'||x.pop_cod||'_'||v_dia,'bpf', bpf_pessoas_pop(x.pop_cod, array['lanca','responsavel','aviso']));
      n := n + 1;
    end if;
  end loop;
  return n;
end $$;
