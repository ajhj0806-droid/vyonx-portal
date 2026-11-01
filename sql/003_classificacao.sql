-- ============================================================================
-- Classificacao automatica no banco.
--
-- O coletor traz o valor cru e mais nada. Normalizar e classificar e trabalho
-- do banco, para a matematica nao se espalhar: um dia o Raio-X e o portal
-- precisam concordar numero a numero, e isso so e possivel se cada conta tiver
-- um dono unico.
-- ============================================================================

-- "cinza" e "neutro" nao sao a mesma coisa. Cinza e um indicador que DEVIA ter
-- nota e nao tem (dado faltando ou vencido). Neutro e um cartao de informacao,
-- que nunca teve nota para dar. Pintar os dois de cinza faria o operador
-- procurar defeito onde nao ha.
alter table idg_medicao drop constraint if exists idg_medicao_estado_check;
alter table idg_medicao add constraint idg_medicao_estado_check
  check (estado in ('verde', 'amarelo', 'laranja', 'vermelho', 'cinza', 'neutro'));

create or replace function idg_classificar() returns trigger
language plpgsql as $fn$
declare i idg_indicador%rowtype;
begin
  select * into i from idg_indicador where id = new.indicador_id;
  if not found then return new; end if;

  if i.especie = 'informacao' then
    new.indice := null;
    new.estado := 'neutro';
  else
    if new.indice is null then
      new.indice := idg_normalizar(new.valor, i.sentido, i.nominal, i.critico, i.critico_baixo, i.critico_alto);
    end if;
    new.estado := idg_estado(new.indice, i.faixa_verde, i.faixa_amarelo, i.faixa_laranja);
  end if;
  return new;
end $fn$;

drop trigger if exists idg_medicao_classificar on idg_medicao;
create trigger idg_medicao_classificar
  before insert on idg_medicao
  for each row execute function idg_classificar();

-- A visao ganhou descricao e passou a respeitar o neutro ao marcar vencido.
drop view if exists idg_atual;
create view idg_atual as
select distinct on (m.indicador_id, m.escopo_id)
       i.sistema_id, m.indicador_id, m.escopo_id,
       i.chave, i.nome, i.descricao, i.especie, i.unidade, i.decimais, i.icone,
       i.peso, i.no_idg, i.destino_url, i.ordem,
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
