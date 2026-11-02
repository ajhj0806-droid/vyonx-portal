-- ============================================================================
-- Tira o modo Visitante do banco.
--
-- O modo acabou em 01/11/2026 ("nao ha necessidade, podemos juntar tudo na
-- abertura"). O index.html e o admin.html ja nao citam a palavra, mas o banco
-- continuava aceitando: o CHECK permitia 'visitante' em portal_app.modos e a
-- politica de leitura ainda tratava o termo. Ficava uma porta sem porteiro —
-- um botao gravado com modos = {visitante} seria aceito pelo banco, apareceria
-- para quem nao tem login (a politica o liberava) e nao apareceria em tela
-- nenhuma, porque o codigo so conhece apresentacao e cliente.
--
-- Conferido antes: nenhum dos 18 botoes usa 'visitante'.
--
-- portal_config.visitante_texto FICA. Tem texto escrito pelo Airton e apagar
-- conteudo dele nao e trabalho de arrumacao; a coluna so deixou de ser lida.
-- ============================================================================

alter table portal_app drop constraint if exists portal_app_modos;
alter table portal_app add constraint portal_app_modos
  check (cardinality(modos) > 0 and modos <@ array['apresentacao', 'cliente']);

drop policy if exists portal_app_ler on portal_app;
create policy portal_app_ler on portal_app for select to anon, authenticated
  using (
    portal_admin()
    or (exibicao <> 'oculto'
        and (('apresentacao' = any (modos))
             or (('cliente' = any (modos)) and portal_cliente())))
  );

comment on column portal_app.modos is
  'Onde o botao aparece: apresentacao (abertura, sem login) e/ou cliente. '
  'O modo visitante foi removido em 01/11/2026.';
