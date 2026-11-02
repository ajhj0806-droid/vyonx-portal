-- ============================================================================
-- search_path fixo nas funcoes do IDG.
--
-- Sem isso, a funcao resolve nomes pelo search_path de QUEM a chama. Nos dois
-- gatilhos isso e o que mais incomoda: eles rodam dentro do insert de qualquer
-- um, e bastaria alguem conseguir criar um objeto com o nome certo em um schema
-- que venha antes de public para a conta passar a ser outra. Hoje nao da (so
-- admin cria em public neste projeto), mas a trava custa uma linha por funcao.
--
-- pg_temp vai no FIM de proposito: se viesse antes, uma tabela temporaria com
-- o nome de uma tabela de verdade a substituiria.
--
-- As funcoes que ja nasceram com search_path fixo (idg_agregados no projeto do
-- Raio-X, idg_cron_token_ok, idg_disparar_coleta, idg_coletas_recentes e as
-- portal_*) nao aparecem aqui porque ja estao resolvidas.
-- ============================================================================

alter function public.idg_calcular(p_sistema_id uuid, p_escopo_id uuid)
  set search_path = pg_catalog, public, pg_temp;
alter function public.idg_classificar()
  set search_path = pg_catalog, public, pg_temp;
alter function public.idg_estado(p_indice numeric, p_verde numeric, p_amarelo numeric, p_laranja numeric)
  set search_path = pg_catalog, public, pg_temp;
alter function public.idg_limpar_detalhe()
  set search_path = pg_catalog, public, pg_temp;
alter function public.idg_normalizar(p_valor numeric, p_sentido text, p_nominal numeric, p_critico numeric, p_critico_baixo numeric, p_critico_alto numeric)
  set search_path = pg_catalog, public, pg_temp;
alter function public.idg_simular(p_valor numeric, p_sentido text, p_nominal numeric, p_critico numeric, p_critico_baixo numeric, p_critico_alto numeric, p_verde numeric, p_amarelo numeric, p_laranja numeric)
  set search_path = pg_catalog, public, pg_temp;
