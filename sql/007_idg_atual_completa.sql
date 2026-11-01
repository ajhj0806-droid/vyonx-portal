-- ============================================================================
-- A view ganha o que a tela precisa para EXPLICAR o numero, nao so mostra-lo.
--
-- Alem do valor e do estado, o cartao ampliado responde "como esta nota saiu":
-- para que lado piora (sentido), onde esta o alvo (nominal), onde esta o limite
-- (critico / critico_baixo / critico_alto) e em que faixa cai. Sem esses campos
-- a explicacao teria de ser escrita no javascript, longe de onde a conta vive.
--
-- security_invoker e os grants sao repetidos de proposito: recriar a view perde
-- as opcoes e os privilegios, e foi exatamente por isso que ela vazou antes
-- (ver 005). Qualquer recriacao futura tem de copiar estas tres ultimas linhas.
-- ============================================================================

drop view if exists idg_atual;

create view idg_atual
with (security_invoker = true) as
select distinct on (m.indicador_id, m.escopo_id)
       i.sistema_id, m.indicador_id, m.escopo_id,
       i.chave, i.nome, i.descricao, i.observacao, i.especie, i.unidade, i.decimais, i.icone,
       i.peso, i.no_idg, i.destino_url, i.ordem, i.validade_seg,
       i.sentido, i.nominal, i.critico, i.critico_baixo, i.critico_alto,
       i.faixa_verde, i.faixa_amarelo, i.faixa_laranja,
       m.valor, m.texto, m.detalhe, m.medido_em, m.ok, m.erro,
       case when m.medido_em < now() - make_interval(secs => i.validade_seg) then null else m.indice end as indice,
       case when m.medido_em < now() - make_interval(secs => i.validade_seg)
            then (case when i.especie = 'informacao' then 'neutro' else 'cinza' end)
            else m.estado end as estado,
       m.medido_em < now() - make_interval(secs => i.validade_seg) as vencido
  from idg_medicao m
  join idg_indicador i on i.id = m.indicador_id
 where i.ativo
 order by m.indicador_id, m.escopo_id, m.medido_em desc;

comment on view idg_atual is
  'Ultima medicao valida de cada indicador por escopo, com a calibracao que '
  'explica a nota. security_invoker: le com os direitos de quem consulta, para '
  'o RLS das tabelas base valer aqui tambem.';

revoke all on idg_atual from anon;
grant select on idg_atual to authenticated;
