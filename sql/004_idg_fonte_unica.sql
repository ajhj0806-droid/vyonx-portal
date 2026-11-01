-- ============================================================================
-- Uma conta, um dono.
--
-- O 002 fez o IDG do Raio-X somar Cyber e Operational em 50/50, esperando
-- reproduzir o Device Health. Reproduz so quando a cobertura e completa.
--
-- Prova em DCL (escopo 19), primeira coleta real:
--   140 aparelhos, 140 com metade cibernetica, apenas 136 com metade operacional
--   media das medias ..... 69.70   <- o que o portal calculava
--   media do indice ...... 70.56   <- o que o Raio-X publica
--   8 aparelhos onde device_health != media das duas metades
--
-- O Raio-X calcula a saude APARELHO POR APARELHO e exclui do indice a dimensao
-- que falta (cap. da cobertura declarada). Essa exclusao so tem sentido no
-- aparelho: na frota, a metade "faltante" de um aparelho e diluida na media dos
-- outros e o peso deixa de valer 50%. Media de medias nao e media.
--
-- Entao o portal para de recalcular e passa a consumir: device_health vira o
-- unico participante do IDG deste sistema. Cyber e Operational continuam como
-- cartao, com nota e cor, porque e por elas que se enxerga de onde vem a queda
-- — mas fora da conta, que agora tem um dono so.
-- ============================================================================

update idg_indicador i
   set peso   = v.peso,
       no_idg = v.no_idg,
       ordem  = v.ordem,
       descricao = v.descricao,
       atualizado_em = now()
  from (values
    ('device_health',      100, true,  1,
     'Índice geral do Raio-X, calculado aparelho por aparelho e depois promediado.'),
    ('cyber_health',         0, false, 2,
     'Metade cibernética do Raio-X: firmware da frota. Mostra de onde vem a nota, sem entrar na conta.'),
    ('operational_health',   0, false, 3,
     'Metade operacional do Raio-X: disponibilidade na semana. Mostra de onde vem a nota, sem entrar na conta.')
  ) as v(chave, peso, no_idg, ordem, descricao)
 where i.chave = v.chave
   and i.sistema_id = (select id from idg_sistema where chave = 'raiox');
