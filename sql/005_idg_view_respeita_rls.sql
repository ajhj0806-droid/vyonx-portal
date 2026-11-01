-- ============================================================================
-- A view idg_atual estava entregando tudo para quem nao tem login.
--
-- No Postgres uma view roda, por padrao, com os privilegios de QUEM A CRIOU, e
-- nao de quem consulta. Resultado: o RLS das tabelas base era aplicado so a
-- quem lia a tabela direto; pela view, nao era aplicado a ninguem. E o Supabase
-- concede select das tabelas de public a anon por padrao.
--
-- Como foi descoberto, com a chave publicavel que esta no icones.js (publico):
--   GET /rest/v1/idg_medicao  -> []                      (RLS funcionando)
--   GET /rest/v1/idg_atual    -> a frota inteira dos clientes
-- Vazavam notas de saude, contagem de aparelhos e causas de falha por cliente.
--
-- security_invoker faz a view ser avaliada com os direitos de quem consulta,
-- e so entao o RLS das tabelas base vale pela view tambem. O revoke e cinto e
-- suspensorio: se algum dia alguem recriar a view sem a opcao, anon ainda nao
-- alcanca.
-- ============================================================================

alter view idg_atual set (security_invoker = true);

revoke all on idg_atual from anon;
grant select on idg_atual to authenticated;

comment on view idg_atual is
  'Ultima medicao valida de cada indicador por escopo. security_invoker: le com '
  'os direitos de quem consulta, para o RLS das tabelas base valer aqui tambem.';
