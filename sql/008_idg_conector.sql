-- ============================================================================
-- Catalogo de conectores, com o banco recusando o que nao existe.
--
-- A secao 5.1 da especificacao: "o cadastro nao devera permitir a execucao
-- arbitraria de codigo ... as funcoes deverao pertencer a um catalogo validado".
-- O coletor ja respeitava isso (so executa o que esta no objeto CONECTORES e
-- grava "conector desconhecido" no resto), mas idg_indicador.funcao era TEXTO
-- LIVRE: dava para cadastrar qualquer coisa e so descobrir na coleta.
--
-- Agora e chave estrangeira. O catalogo nao tem politica de escrita: so migra
-- quem tambem mexe no codigo da Edge Function, que e onde o conector de fato
-- vive. Tabela e codigo podem divergir num sentido seguro — conector cadastrado
-- e nao implementado vira falha registrada, nunca numero inventado.
-- ============================================================================

create table if not exists idg_conector (
  chave     text primary key,
  nome      text not null,
  descricao text,
  -- As chaves que a fonte devolve. A tela de cadastro oferece como lista para
  -- o administrador nao ter de adivinhar o nome da metrica.
  metricas  text[] not null default '{}',
  ativo     boolean not null default true
);

insert into idg_conector (chave, nome, descricao, metricas) values
  ('raiox.agregados', 'Raio-X — agregados por cliente',
   'Lê o projeto do Raio-X e devolve apenas números consolidados e a quebra por causa, nunca linhas de dispositivo. O escopo é o código do cliente no Raio-X.',
   array['device_health','cyber_health','operational_health','firmware_atualizado_pct',
         'comunicacao_pct','saudaveis_pct','dispositivos','cobertura_pct','causas'])
on conflict (chave) do update
   set nome = excluded.nome, descricao = excluded.descricao, metricas = excluded.metricas;

alter table idg_indicador drop constraint if exists idg_indicador_conector_fk;
alter table idg_indicador add constraint idg_indicador_conector_fk
  foreign key (funcao) references idg_conector(chave);

alter table idg_conector enable row level security;

-- Leitura para quem esta logado (a tela de cadastro precisa da lista).
-- Escrita: ninguem pela API. Conector novo entra por migracao, junto do codigo.
drop policy if exists idg_conector_ler on idg_conector;
create policy idg_conector_ler on idg_conector for select to authenticated using (ativo);

comment on table idg_conector is
  'Catalogo fechado de fontes de coleta (secao 5.1). idg_indicador.funcao e chave '
  'estrangeira daqui: o banco recusa conector que nao exista.';
