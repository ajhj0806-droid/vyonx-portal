-- ============================================================================
-- ATENCAO: este arquivo NAO roda no banco do portal.
-- Ele roda no projeto Supabase do RAIO-X (vyonx = mtudqsxwylfdxaenhbfd), que
-- guarda a frota real do piloto. Fica versionado aqui porque e o contrato do
-- conector: e a unica porta pela qual o portal le o Raio-X.
--
-- Por que existe: o projeto do Raio-X e permissivo por dentro (qualquer
-- authenticated le tudo, inclusive dispositivo a dispositivo). O coletor do
-- portal nao deve ter esse alcance. Esta funcao devolve SOMENTE agregados e
-- quebras por causa — nunca uma linha de dispositivo, nunca um identificador
-- de equipamento.
-- ============================================================================

create or replace function idg_agregados(p_escopo text)
returns jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $fn$
  with alvo as (
    select id from tenants where external_id = p_escopo limit 1
  ), ultima as (
    select c.id, c.finished_at, c.index_version
      from collections c join alvo t on t.id = c.tenant_id
     where c.finished_at is not null
     order by c.finished_at desc limit 1
  ), av as (
    select a.* from assessments a join ultima u on u.id = a.collection_id
  ), causa as (
    -- Quantos dispositivos carregam cada causa. E a quebra que responde
    -- "quais itens estao por tras do numero" sem expor os itens.
    select d->>'dimension' as dimensao,
           f->>'code'      as codigo,
           max(f->>'label') as exemplo,
           count(distinct av.device_id) as dispositivos
      from av
     cross join lateral jsonb_array_elements(av.factors) as d
     cross join lateral jsonb_array_elements(d->'factors') as f
     group by 1, 2
  ), total as (
    select count(*)::numeric as n,
           count(distinct device_id) filter (
             where exists (select 1 from jsonb_array_elements(factors) d
                            cross join lateral jsonb_array_elements(d->'factors') f
                            where f->>'code' = 'PATCH_AVAILABLE')) as com_patch,
           count(distinct device_id) filter (
             where exists (select 1 from jsonb_array_elements(factors) d
                            cross join lateral jsonb_array_elements(d->'factors') f
                            where f->>'code' = 'DOWNTIME')) as com_downtime
      from av
  )
  select case when (select n from total) = 0 then null else jsonb_build_object(
    'escopo',      p_escopo,
    'nome',        (select name from tenants where external_id = p_escopo),
    'coletado_em', (select finished_at from ultima),
    'metodologia', (select index_version from ultima),
    'indicadores', jsonb_build_object(
      'device_health',       jsonb_build_object('valor', round(avg(av.device_health), 1)),
      'operational_health',  jsonb_build_object('valor', round(avg(av.operational_health), 1)),
      'cyber_health',        jsonb_build_object('valor', round(avg(av.cyber_health), 1)),
      'saudaveis_pct',       jsonb_build_object(
          'valor', round(100.0 * count(*) filter (where av.band = 'healthy') / (select n from total), 1),
          'detalhe', (select jsonb_object_agg(band, q) from (select band, count(*) q from av group by band) b)),
      'firmware_atualizado_pct', jsonb_build_object(
          'valor', round(100.0 * ((select n from total) - (select com_patch from total)) / (select n from total), 1),
          'detalhe', jsonb_build_object('desatualizados', (select com_patch from total),
                                        'total', (select n from total)::int)),
      'comunicacao_pct',     jsonb_build_object(
          'valor', round(100.0 * ((select n from total) - (select com_downtime from total)) / (select n from total), 1),
          'detalhe', jsonb_build_object('com_falha', (select com_downtime from total),
                                        'total', (select n from total)::int)),
      'dispositivos',        jsonb_build_object('valor', (select n from total)::int),
      'cobertura_pct',       jsonb_build_object('valor', round(avg(av.cyber_coverage) * 100, 1)),
      'causas',              jsonb_build_object('valor', (select count(*) from causa),
          'detalhe', (select jsonb_agg(jsonb_build_object(
                                'dimensao', dimensao, 'codigo', codigo,
                                'dispositivos', dispositivos, 'exemplo', exemplo)
                              order by dispositivos desc) from causa))
    )) end
  from av
$fn$;

-- So o coletor chama. Ninguem mais, nem anon, nem usuario logado.
revoke all on function idg_agregados(text) from public, anon, authenticated;
grant execute on function idg_agregados(text) to service_role;

comment on function idg_agregados(text) is
  'IOT CITY AUDIT: agregados do Raio-X por escopo (tenants.external_id). Somente '
  'numeros consolidados e quebra por causa — nunca linhas de dispositivo.';
