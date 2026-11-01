-- ============================================================================
-- Simulador de calibracao para a tela de cadastro.
--
-- Ao cadastrar um indicador o administrador precisa ver, ANTES de salvar, que
-- nota uma leitura vai gerar — senao a calibracao so e conferida na primeira
-- coleta, que e tarde. A tentacao seria repetir a formula no javascript; isso
-- criaria uma segunda versao da conta, exatamente o problema que o 004 resolveu
-- em outro lugar. Entao a simulacao chama a MESMA funcao que o gatilho usa, e a
-- tela so mostra o resultado.
-- ============================================================================

create or replace function idg_simular(
  p_valor         numeric,
  p_sentido       text,
  p_nominal       numeric,
  p_critico       numeric,
  p_critico_baixo numeric default null,
  p_critico_alto  numeric default null,
  p_verde         numeric default 90,
  p_amarelo       numeric default 75,
  p_laranja       numeric default 50
) returns table (indice numeric, estado text)
language sql stable as $$
  select i, idg_estado(i, p_verde, p_amarelo, p_laranja)
    from idg_normalizar(p_valor, p_sentido, p_nominal, p_critico, p_critico_baixo, p_critico_alto) as i
$$;

comment on function idg_simular is
  'Previa da nota para a tela de cadastro. Usa idg_normalizar e idg_estado, as '
  'mesmas do gatilho: a conta continua tendo um dono so.';
