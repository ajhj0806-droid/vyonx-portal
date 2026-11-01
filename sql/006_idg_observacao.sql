-- ============================================================================
-- "Por que este cartao esta fora da conta?"
--
-- A tela amplia o indicador e precisa responder isso com palavras. A resposta
-- existia so em comentario de SQL, que ninguem le na tela e o cadastro nao
-- edita. Entao vira dado.
-- ============================================================================

alter table idg_indicador add column if not exists observacao text;

comment on column idg_indicador.observacao is
  'Explicacao mostrada quando o cartao e ampliado: por que ele entra ou nao '
  'entra no indice, e o que o numero quer dizer. Editavel no cadastro.';

update idg_indicador i set observacao = v.txt, atualizado_em = now()
  from (values
    ('device_health',
     'É a nota que o próprio Raio-X publica, calculada aparelho por aparelho e depois promediada. O portal consome esse número em vez de recalculá-lo, para o índice ter um dono só.'),
    ('cyber_health',
     'Fora da conta de propósito: é uma das duas metades que já formam o Device Health. Somá-la outra vez contaria o mesmo fato duas vezes. Fica aqui porque é por ela que se vê de onde vem a queda.'),
    ('operational_health',
     'Fora da conta de propósito: é a outra metade do Device Health. Somá-la outra vez contaria o mesmo fato duas vezes. Fica aqui porque é por ela que se vê de onde vem a queda.'),
    ('firmware_atualizado_pct',
     'Fora da conta: são as mesmas evidências de firmware que formam a saúde cibernética, contadas de outro jeito. Útil de ver porque fala em aparelhos, não em nota.'),
    ('comunicacao_pct',
     'Fora da conta: são as mesmas evidências de disponibilidade que formam a saúde operacional, contadas de outro jeito. Útil de ver porque fala em aparelhos, não em nota.'),
    ('saudaveis_pct',
     'Fora da conta: é a distribuição do próprio Device Health em faixas. Diz quantos aparelhos estão bem, não o quanto estão bem.'),
    ('dispositivos',
     'Fato consolidado, sem nota. Serve para dar tamanho aos percentuais: 2% de falha em 4 mil aparelhos não é a mesma conversa que 2% em 140.'),
    ('cobertura_pct',
     'Quanto do modelo de saúde pôde ser medido nesta fonte. Cobertura baixa não é nota baixa — é nota com menos apoio, e vale saber disso antes de decidir.'),
    ('causas',
     'Cada causa vem com quantos aparelhos ela atinge. É por aqui que se decide o que atacar primeiro: a causa que pega mais aparelhos, não a que tem o nome mais feio.')
  ) as v(chave, txt)
 where i.chave = v.chave
   and i.sistema_id = (select id from idg_sistema where chave = 'raiox');
