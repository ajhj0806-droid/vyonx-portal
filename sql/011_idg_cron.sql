-- ============================================================================
-- O agendamento.
--
-- De hora em hora o banco chama a Edge Function. O token sai do Vault na hora
-- da chamada e nao fica escrito no comando do cron. A chave publicavel aparece
-- aqui de proposito: ela e publica, serve so para passar pelo verify_jwt, e
-- quem de fato autoriza e o x-idg-token.
--
-- Respeitar o intervalo e trabalho do coletor, nao do cron: o cadastro guarda
-- intervalo_seg por indicador, e a funcao pula o que ainda nao venceu. Entao o
-- cron pode bater de hora em hora sem forcar coleta de quem pede menos.
--
-- Fica um registro das execucoes porque "sera que rodou?" e a primeira pergunta
-- depois de automatizar qualquer coisa — e a resposta do pg_net some sozinha em
-- poucas horas.
-- ============================================================================

create table if not exists idg_coleta_execucao (
  id          bigserial primary key,
  pedido_id   bigint,
  disparada_em timestamptz not null default now(),
  origem      text not null default 'agendador'
);
create index if not exists idg_coleta_execucao_tempo_idx on idg_coleta_execucao (disparada_em desc);

alter table idg_coleta_execucao enable row level security;
-- Sem politica: ninguem le pela API. O admin ve pelo idg_coletas_recentes().

create or replace function idg_disparar_coleta(p_origem text default 'agendador')
returns bigint
language plpgsql
security definer
set search_path = pg_catalog, public, pg_temp
as $fn$
declare tok text; pedido bigint;
begin
  select decrypted_secret into tok from vault.decrypted_secrets where name = 'idg_cron_token';
  if tok is null then raise exception 'o token do agendador nao existe (ver 010)'; end if;

  select net.http_post(
    url := 'https://zuabqwshrbqkhcjzhkhq.supabase.co/functions/v1/idg-coletar',
    body := '{}'::jsonb,
    headers := jsonb_build_object(
      'content-type','application/json',
      'authorization','Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp1YWJxd3NocmJxa2hjanpoa2hxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMyOTAyNzAsImV4cCI6MjEwODg2NjI3MH0.9nAmXy2oD6Tc187xD1lt1nashZ-fcgxlVnx3oG7iwg4',
      'x-idg-token', tok),
    timeout_milliseconds := 60000
  ) into pedido;

  insert into idg_coleta_execucao (pedido_id, origem) values (pedido, p_origem);
  delete from idg_coleta_execucao where disparada_em < now() - interval '30 days';
  return pedido;
end $fn$;

revoke all on function idg_disparar_coleta(text) from public, anon, authenticated;

-- O que o administrador ve na tela: as ultimas execucoes com a resposta do
-- coletor, enquanto o pg_net ainda a guarda.
create or replace function idg_coletas_recentes()
returns table (disparada_em timestamptz, origem text, status integer, resposta jsonb, erro text)
language sql
stable
security definer
set search_path = pg_catalog, public, net, pg_temp
as $fn$
  select e.disparada_em, e.origem, r.status_code,
         case when r.content is null or r.content = '' then null else r.content::jsonb end,
         r.error_msg
    from public.idg_coleta_execucao e
    left join net._http_response r on r.id = e.pedido_id
   where public.portal_admin()
   order by e.disparada_em desc
   limit 20
$fn$;

revoke all on function idg_coletas_recentes() from public, anon;
grant execute on function idg_coletas_recentes() to authenticated;

-- De hora em hora, no minuto 7 (fora do topo da hora, onde todo mundo agenda).
select cron.unschedule('idg-coletar') where exists (select 1 from cron.job where jobname = 'idg-coletar');
select cron.schedule('idg-coletar', '7 * * * *', $cron$select public.idg_disparar_coleta('agendador')$cron$);
