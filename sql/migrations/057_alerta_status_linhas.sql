-- 057 — Aviso de mudança no Status das Linhas (som nas telas + notificação no celular)
-- Fonte: laboratorio (análise mais nova de cada linha). Cada mudança vira 1 evento.

create extension if not exists pg_net;

-- Status atual de cada linha (= status da análise mais nova do laboratório)
create table if not exists public.linhas_status_atual(
  linha text primary key,
  status text not null,
  analise_id uuid,
  data date,
  hora time,
  produto text,
  turno text,
  responsavel text,
  mudou_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

-- Cada mudança de status vira 1 evento (som nas telas + notificação no celular)
create table if not exists public.linhas_status_eventos(
  id bigint generated always as identity primary key,
  linha text not null,
  status_antes text,
  status_novo text not null,
  analise_id uuid,
  produto text,
  turno text,
  responsavel text,
  data date,
  hora time,
  criado_em timestamptz not null default now(),
  push_enviado_em timestamptz,
  push_resultado jsonb
);
create index if not exists linhas_status_eventos_criado on public.linhas_status_eventos(criado_em desc);

-- Aparelhos que recebem notificação (Web Push)
create table if not exists public.push_inscricoes(
  id uuid primary key default gen_random_uuid(),
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  usuario_id uuid,
  usuario_nome text,
  auth_uid uuid default auth.uid(),
  aparelho text,
  status_filtro text[] not null default array['OK','Ajuste','Manutenção','Parada'],
  linhas_filtro text[],
  ativo boolean not null default true,
  falhas int not null default 0,
  ultimo_erro text,
  ultimo_envio_em timestamptz,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

-- Chaves VAPID: só o servidor (service_role) lê. Sem policy = ninguém do app lê.
-- A função push-linhas gera o par na 1ª chamada; a chave privada nunca sai do servidor.
create table if not exists public.push_config(
  id int primary key default 1 check (id=1),
  vapid_publica text,
  vapid_privada text,
  criado_em timestamptz not null default now()
);

alter table public.linhas_status_atual   enable row level security;
alter table public.linhas_status_eventos enable row level security;
alter table public.push_inscricoes       enable row level security;
alter table public.push_config           enable row level security;

drop policy if exists linhas_status_atual_ler on public.linhas_status_atual;
create policy linhas_status_atual_ler on public.linhas_status_atual for select to authenticated using (true);
drop policy if exists linhas_status_eventos_ler on public.linhas_status_eventos;
create policy linhas_status_eventos_ler on public.linhas_status_eventos for select to authenticated using (true);
drop policy if exists baseline_authenticated_all on public.push_inscricoes;
create policy baseline_authenticated_all on public.push_inscricoes for all to authenticated using (true) with check (true);

-- Gatilho: análise nova/alterada no laboratório → atualiza status da linha;
-- se mudou, grava evento, avisa as telas (Realtime) e chama o envio de push.
create or replace function public.lab_status_linha_trg() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_atual public.linhas_status_atual;
  v_tem boolean;
  v_ts timestamp;
  v_ts_atual timestamp;
  v_ev bigint;
begin
  if new.linha is null or coalesce(trim(new.status),'') = '' then return new; end if;
  if tg_op = 'UPDATE'
     and new.status is not distinct from old.status
     and new.linha  is not distinct from old.linha
     and new.data   is not distinct from old.data
     and new.hora   is not distinct from old.hora then
    return new;
  end if;

  select * into v_atual from public.linhas_status_atual where linha = new.linha for update;
  v_tem := found;
  v_ts := coalesce(new.data, current_date) + coalesce(new.hora, time '00:00');

  if v_tem then
    v_ts_atual := coalesce(v_atual.data, current_date) + coalesce(v_atual.hora, time '00:00');
    -- análise mais velha que a que manda hoje (lançamento atrasado) não muda o status
    if v_atual.analise_id is distinct from new.id and v_ts < v_ts_atual then return new; end if;
    if v_atual.status = new.status then
      update public.linhas_status_atual
         set analise_id = new.id, data = new.data, hora = new.hora, produto = new.produto,
             turno = new.turno, responsavel = new.responsavel, atualizado_em = now()
       where linha = new.linha;
      return new;
    end if;
  end if;

  insert into public.linhas_status_atual(linha,status,analise_id,data,hora,produto,turno,responsavel,mudou_em,atualizado_em)
  values (new.linha,new.status,new.id,new.data,new.hora,new.produto,new.turno,new.responsavel,now(),now())
  on conflict (linha) do update set status = excluded.status, analise_id = excluded.analise_id, data = excluded.data,
     hora = excluded.hora, produto = excluded.produto, turno = excluded.turno, responsavel = excluded.responsavel,
     mudou_em = now(), atualizado_em = now();

  insert into public.linhas_status_eventos(linha,status_antes,status_novo,analise_id,produto,turno,responsavel,data,hora)
  values (new.linha, case when v_tem then v_atual.status end, new.status, new.id, new.produto, new.turno, new.responsavel, new.data, new.hora)
  returning id into v_ev;

  -- Aviso não pode travar o laboratório: se falhar, fica registrado no evento.
  begin
    perform realtime.send(
      jsonb_build_object('id', v_ev, 'linha', new.linha, 'status', new.status,
                         'antes', case when v_tem then v_atual.status end,
                         'produto', new.produto, 'turno', new.turno),
      'mudou', 'linhas-status', false);
    perform net.http_post(
      url := 'https://zodgbitbflkepbszshmu.supabase.co/functions/v1/push-linhas',
      body := jsonb_build_object('acao','enviar'),
      headers := '{"Content-Type":"application/json"}'::jsonb,
      timeout_milliseconds := 10000);
  exception when others then
    update public.linhas_status_eventos
       set push_resultado = jsonb_build_object('erro_gatilho', sqlerrm)
     where id = v_ev;
  end;
  return new;
end $$;

drop trigger if exists lab_status_linha on public.laboratorio;
create trigger lab_status_linha after insert or update of status, linha, data, hora on public.laboratorio
for each row execute function public.lab_status_linha_trg();

-- Carga inicial (sem gerar evento): status da análise mais nova de cada linha
insert into public.linhas_status_atual(linha,status,analise_id,data,hora,produto,turno,responsavel,mudou_em)
select distinct on (linha) linha, status, id, data, hora, produto, turno, responsavel, coalesce(created_at, now())
  from public.laboratorio
 where linha is not null and coalesce(trim(status),'') <> ''
 order by linha, data desc nulls last, hora desc nulls last, created_at desc nulls last
on conflict (linha) do nothing;
