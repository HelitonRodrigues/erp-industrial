-- (16/11/2026) 🔄 Mudar a carga na portaria com NÚMERO de ordem novo: leva o que já foi bipado para o número novo.
-- O gatilho pallet_guarda_estado barra trocar ordem_numero de pallet carregado; aqui é a troca da MESMA carga, então liga a exceção só nesta transação.
create or replace function public.trocar_numero_ordem(p_de text, p_para text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare n_car int; n_pal int;
begin
  if coalesce(p_de,'')='' or coalesce(p_para,'')='' or p_de=p_para then return jsonb_build_object('ok',false); end if;
  perform set_config('app.pallet_guarda_off','on',true);
  update carregamentos set ordem_numero=p_para where ordem_numero=p_de; get diagnostics n_car = row_count;
  update producao_pallets set ordem_numero=p_para where ordem_numero=p_de; get diagnostics n_pal = row_count;
  begin update carregamento_ao_vivo set ordem_numero=p_para where ordem_numero=p_de; exception when others then null; end;
  begin update lab_laudo_carregamentos set ordem_numero=p_para where ordem_numero=p_de; exception when others then null; end;
  perform set_config('app.pallet_guarda_off','',true);
  return jsonb_build_object('ok',true,'cargas',n_car,'pallets',n_pal);
end $$;
grant execute on function public.trocar_numero_ordem(text,text) to authenticated;
