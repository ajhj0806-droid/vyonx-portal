-- ============================================================================
-- Quem pode mandar coletar.
--
-- O coletor estava protegido so pelo verify_jwt, que aceita a chave publicavel
-- — a mesma que esta no icones.js, versionado e publico. Qualquer pessoa podia
-- disparar coleta a vontade: nao vazaria dado (a funcao so grava), mas enche a
-- tabela de medicoes e bate na fonte sem limite.
--
-- Agora a propria funcao decide, por dentro:
--   · cabecalho x-idg-token valido  -> e o agendador
--   · JWT de um admin do portal     -> e o botao "Coletar" da tela
--   · qualquer outra coisa          -> 403
--
-- O token nasce aqui, aleatorio, e fica no Vault (cifrado). Ninguem precisa
-- ve-lo: o agendador le do Vault na hora de chamar, e a funcao nunca recebe o
-- token de volta — so pergunta "este confere?" por uma funcao que so o
-- service_role executa.
-- ============================================================================

create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron;

-- Cria o segredo uma vez so. Se ja existir, nao mexe: trocar o token aqui
-- derrubaria o agendamento ate o proximo deploy.
do $$
begin
  if not exists (select 1 from vault.secrets where name = 'idg_cron_token') then
    perform vault.create_secret(
      encode(extensions.gen_random_bytes(32), 'hex'),
      'idg_cron_token',
      'Token do agendador do IDG. Vai no cabecalho x-idg-token da chamada a idg-coletar.');
  end if;
end $$;

-- A funcao responde sim/nao e nunca devolve o token.
create or replace function idg_cron_token_ok(p_token text)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, pg_temp
as $fn$
  select coalesce(p_token, '') <> ''
     and exists (select 1 from vault.decrypted_secrets
                  where name = 'idg_cron_token' and decrypted_secret = p_token)
$fn$;

revoke all on function idg_cron_token_ok(text) from public, anon, authenticated;
grant execute on function idg_cron_token_ok(text) to service_role;

comment on function idg_cron_token_ok(text) is
  'Confere o token do agendador do IDG. So o service_role executa, e a resposta '
  'e booleana: o token nunca sai do banco.';
