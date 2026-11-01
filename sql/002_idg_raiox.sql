-- ============================================================================
-- Primeiro sistema monitorado: o Raio-X de dispositivos.
--
-- Cuidado que manda na composicao do IDG (secao 8.1 da especificacao: "os
-- indicadores derivados nao deverao ser contados duas vezes"):
--
--   No Raio-X existem apenas DUAS familias de fato medidas hoje — firmware
--   (que forma o Cyber Health) e disponibilidade (que forma o Operational
--   Health). Todo o resto e releitura das mesmas evidencias:
--     device_health           = media de CH e OH
--     firmware_atualizado_pct = os mesmos fatos de firmware, contados de outro jeito
--     comunicacao_pct         = os mesmos fatos de disponibilidade
--     saudaveis_pct           = a distribuicao de device_health em faixas
--
--   Entao SO Cyber Health e Operational Health participam do IDG. Os demais
--   aparecem como cartao com nota e cor, porque sao uteis de ver, mas com
--   no_idg = false para nao contar o mesmo fato duas vezes.
--
--   Efeito colateral bem-vindo: com peso 50/50, o IDG do portal reproduz o
--   Device Health do Raio-X. Os dois motores concordam — e quando divergirem,
--   sera porque alguem mudou um peso de proposito.
-- ============================================================================

insert into idg_sistema (chave, nome, descricao, icone, escopo_rotulo, ordem)
values ('raiox', 'Raio-X de dispositivos',
        'Saúde operacional e cibernética da frota, medida pelo método do Raio-X.',
        'activity', 'Cliente', 1)
on conflict (chave) do update
   set nome = excluded.nome, descricao = excluded.descricao, icone = excluded.icone;

insert into idg_escopo (sistema_id, chave, nome, ordem)
select s.id, v.chave, v.nome, v.ordem
  from idg_sistema s,
       (values ('25', 'FM RODRIGUES - CAIEIRAS', 1),
               ('19', 'DCL - MEDIÇÃO DE UTILITIES', 2)) as v(chave, nome, ordem)
 where s.chave = 'raiox'
on conflict (sistema_id, chave) do update set nome = excluded.nome;

insert into idg_indicador (
  sistema_id, chave, nome, descricao, icone, especie, unidade, decimais,
  sentido, nominal, critico, faixa_verde, faixa_amarelo, faixa_laranja,
  peso, no_idg, funcao, intervalo_seg, validade_seg, ordem
)
select s.id, v.chave, v.nome, v.descricao, v.icone, v.especie, v.unidade, v.decimais,
       v.sentido, v.nominal, v.critico, 90, 75, 50,
       v.peso, v.no_idg, 'raiox.agregados', 3600, 86400, v.ordem
  from idg_sistema s, (values
    -- Participam do IDG: as duas familias de fato realmente medidas.
    ('cyber_health', 'Saúde cibernética', 'Firmware da frota, pelo índice do Raio-X.',
     'shield', 'indicador', null, 1, 'maior_melhor', 100, 0, 50, true, 1),
    ('operational_health', 'Saúde operacional', 'Disponibilidade da frota na semana.',
     'pulse', 'indicador', null, 1, 'maior_melhor', 100, 0, 50, true, 2),

    -- Mostram, mas nao contam: sao releitura dos mesmos fatos.
    ('device_health', 'Device Health', 'Índice geral do Raio-X — média das duas metades.',
     'gauge', 'indicador', null, 1, 'maior_melhor', 100, 0, 0, false, 3),
    ('firmware_atualizado_pct', 'Firmware atualizado', 'Parcela da frota na versão mais recente do seu modelo.',
     'chip', 'indicador', '%', 1, 'maior_melhor', 100, 0, 0, false, 4),
    ('comunicacao_pct', 'Comunicação', 'Parcela da frota que comunicou a semana inteira.',
     'wifi', 'indicador', '%', 1, 'maior_melhor', 100, 80, 0, false, 5),
    ('saudaveis_pct', 'Dispositivos saudáveis', 'Parcela da frota na faixa saudável do índice.',
     'check', 'indicador', '%', 1, 'maior_melhor', 100, 50, 0, false, 6),

    -- Fatos consolidados, sem nota e sem cor de desempenho.
    ('dispositivos', 'Dispositivos medidos', 'Tamanho da frota na última coleta.',
     'cpu', 'informacao', null, 0, null, null, null, 0, false, 7),
    ('cobertura_pct', 'Cobertura do índice', 'Quanto do modelo de saúde pôde ser medido nesta fonte.',
     'layers', 'informacao', '%', 0, null, null, null, 0, false, 8),
    ('causas', 'Causas encontradas', 'Famílias de problema identificadas e quantos dispositivos cada uma atinge.',
     'list', 'informacao', null, 0, null, null, null, 0, false, 9)
  ) as v(chave, nome, descricao, icone, especie, unidade, decimais,
         sentido, nominal, critico, peso, no_idg, ordem)
 where s.chave = 'raiox'
on conflict (sistema_id, chave) do update
   set nome = excluded.nome, descricao = excluded.descricao, peso = excluded.peso,
       no_idg = excluded.no_idg, sentido = excluded.sentido, nominal = excluded.nominal,
       critico = excluded.critico, especie = excluded.especie, ordem = excluded.ordem,
       atualizado_em = now();
