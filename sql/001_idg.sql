-- ============================================================================
-- IOT CITY AUDIT — Indice de Desempenho Geral (IDG)
-- Primeira fatia: sistemas, escopos, indicadores, medicoes e a matematica.
--
-- Decisoes que valem para tudo o que vier depois:
--
--  1. Duas especies de cartao. 'indicador' tem valor numerico, nota de 0 a 100,
--     cor de faixa e peso no IDG. 'informacao' e um fato consolidado, sem nota
--     e sem cor de desempenho — e NUNCA entra no IDG. Um cartao informativo
--     pintado de laranja seria lido como desempenho ruim.
--
--  2. Quatro estados mais um. verde (normal), amarelo (abaixo do normal),
--     laranja (atencao) e vermelho (ruim), com cinza para dado indisponivel ou
--     velho. Mesma paleta do Raio-X: a mesma cor significa a mesma coisa nos
--     dois produtos.
--
--  3. Dado ausente nao vira zero. Indicador sem leitura valida fica cinza e sai
--     da conta do IDG; o indice guarda quantos participaram para que o numero
--     seja rastreavel ate quem o compos.
--
--  4. A coleta roda no servidor e grava aqui. O navegador so le.
--
-- A conta esta em SQL de proposito, para nao depender de servidor novo. E a
-- segunda implementacao da mesma matematica do motor do Raio-X (TypeScript) —
-- divida assumida, a ser paga extraindo um modulo comum quando os dois
-- precisarem concordar numero a numero.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Sistemas monitorados
-- ---------------------------------------------------------------------------
create table if not exists idg_sistema (
  id         uuid primary key default gen_random_uuid(),
  chave      text not null unique,
  nome       text not null,
  descricao  text,
  icone      text,
  ordem      integer not null default 0,
  ativo      boolean not null default true,
  -- Como chamar o seletor de escopo na tela ("Cliente", "Cidade", "Parque").
  escopo_rotulo text not null default 'Cliente',
  criado_em  timestamptz not null default now()
);

-- Um sistema atende varios clientes/locais. O portal nao fixa nenhum: quem
-- olha escolhe, e os indicadores sao medidos por escopo.
create table if not exists idg_escopo (
  id         uuid primary key default gen_random_uuid(),
  sistema_id uuid not null references idg_sistema(id) on delete cascade,
  chave      text not null,
  nome       text not null,
  ordem      integer not null default 0,
  ativo      boolean not null default true,
  unique (sistema_id, chave)
);

create index if not exists idg_escopo_sistema_idx on idg_escopo (sistema_id, ordem);

-- ---------------------------------------------------------------------------
-- Indicadores (os cartoes)
-- ---------------------------------------------------------------------------
create table if not exists idg_indicador (
  id         uuid primary key default gen_random_uuid(),
  sistema_id uuid not null references idg_sistema(id) on delete cascade,
  chave      text not null,
  nome       text not null,
  descricao  text,
  icone      text,

  especie    text not null default 'indicador'
             check (especie in ('indicador', 'informacao')),

  -- Apresentacao
  unidade    text,
  decimais   smallint not null default 0 check (decimais between 0 and 4),

  -- Normalizacao (so para especie 'indicador').
  -- maior_melhor: nominal e o alvo, critico e o piso.
  -- menor_melhor: nominal e o alvo, critico e o teto.
  -- faixa_ideal : nominal e o centro, critico_baixo/alto sao as bordas.
  sentido       text check (sentido in ('maior_melhor', 'menor_melhor', 'faixa_ideal')),
  nominal       numeric,
  critico       numeric,
  critico_baixo numeric,
  critico_alto  numeric,

  -- Faixas de classificacao, em pontos do indice normalizado (0 a 100).
  -- Padrao vindo do exemplo da especificacao: 90 / 75 / 50.
  faixa_verde   numeric not null default 90,
  faixa_amarelo numeric not null default 75,
  faixa_laranja numeric not null default 50,

  -- Participacao no IDG
  peso   numeric not null default 1 check (peso >= 0),
  no_idg boolean not null default true,

  -- Coleta: nome no catalogo de conectores validados, nunca codigo livre.
  funcao        text not null,
  parametros    jsonb not null default '{}'::jsonb,
  intervalo_seg integer not null default 3600 check (intervalo_seg >= 60),
  -- Depois deste tempo sem leitura nova, o valor deixa de valer e fica cinza.
  validade_seg  integer not null default 10800 check (validade_seg >= 60),

  -- Clique
  destino_url text,

  ordem integer not null default 0,
  ativo boolean not null default true,
  atualizado_em timestamptz not null default now(),

  unique (sistema_id, chave),

  -- Informacao consolidada nao tem nota, entao nao pode pesar no indice.
  constraint idg_informacao_fora_do_idg
    check (especie = 'indicador' or no_idg = false),

  -- Indicador precisa saber para que lado piora, senao nao da para normalizar.
  constraint idg_indicador_tem_sentido
    check (especie = 'informacao' or sentido is not null),

  -- As faixas tem de estar em ordem decrescente.
  constraint idg_faixas_ordenadas
    check (faixa_verde > faixa_amarelo and faixa_amarelo > faixa_laranja and faixa_laranja >= 0)
);

create index if not exists idg_indicador_sistema_idx on idg_indicador (sistema_id, ordem);

-- ---------------------------------------------------------------------------
-- Medicoes
-- ---------------------------------------------------------------------------
create table if not exists idg_medicao (
  id           bigserial primary key,
  indicador_id uuid not null references idg_indicador(id) on delete cascade,
  escopo_id    uuid references idg_escopo(id) on delete cascade,
  medido_em    timestamptz not null default now(),

  -- Valor cru, como a funcao devolveu.
  valor numeric,
  texto text,

  -- Resultado da classificacao.
  indice numeric check (indice is null or (indice >= 0 and indice <= 100)),
  estado text not null default 'cinza'
         check (estado in ('verde', 'amarelo', 'laranja', 'vermelho', 'cinza')),

  -- O detalhamento por tras do numero: a lista ou a quebra que responde
  -- "quais itens compoem isto". Guardado so na leitura mais recente — manter em
  -- todo o historico incharia a tabela sem necessidade (ver trigger abaixo).
  detalhe jsonb,

  -- Execucao
  ok  boolean not null default true,
  erro text,

  unique (indicador_id, escopo_id, medido_em)
);

create index if not exists idg_medicao_recente_idx
  on idg_medicao (indicador_id, escopo_id, medido_em desc);

-- Só a leitura mais recente guarda o detalhamento.
create or replace function idg_limpar_detalhe() returns trigger
language plpgsql as $$
begin
  if new.detalhe is not null then
    update idg_medicao
       set detalhe = null
     where indicador_id = new.indicador_id
       and escopo_id is not distinct from new.escopo_id
       and id <> new.id
       and detalhe is not null;
  end if;
  return new;
end $$;

drop trigger if exists idg_medicao_detalhe on idg_medicao;
create trigger idg_medicao_detalhe
  after insert on idg_medicao
  for each row execute function idg_limpar_detalhe();

-- ---------------------------------------------------------------------------
-- A matematica
-- ---------------------------------------------------------------------------

-- Traduz uma leitura para um indice de 0 a 100. Devolve null quando a conta nao
-- e possivel — nunca um palpite. Melhor que o nominal nao ganha pontos extras,
-- e pior que o critico nao fica negativo.
create or replace function idg_normalizar(
  p_valor         numeric,
  p_sentido       text,
  p_nominal       numeric,
  p_critico       numeric,
  p_critico_baixo numeric default null,
  p_critico_alto  numeric default null
) returns numeric
language sql immutable as $$
  select case
    when p_valor is null or p_sentido is null or p_nominal is null then null

    when p_sentido = 'maior_melhor' then
      case when p_critico is null or p_nominal = p_critico then null
           else greatest(0, least(100, 100 * (p_valor - p_critico) / (p_nominal - p_critico))) end

    when p_sentido = 'menor_melhor' then
      case when p_critico is null or p_critico = p_nominal then null
           else greatest(0, least(100, 100 * (p_critico - p_valor) / (p_critico - p_nominal))) end

    when p_sentido = 'faixa_ideal' then
      case
        when p_valor >= p_nominal then
          case when p_critico_alto is null or p_critico_alto = p_nominal then null
               else greatest(0, least(100, 100 * (1 - (p_valor - p_nominal) / (p_critico_alto - p_nominal)))) end
        else
          case when p_critico_baixo is null or p_nominal = p_critico_baixo then null
               else greatest(0, least(100, 100 * (1 - (p_nominal - p_valor) / (p_nominal - p_critico_baixo)))) end
      end
  end
$$;

-- Indice vira estado. Sem indice, cinza: dado que nao existe nao e desempenho.
create or replace function idg_estado(
  p_indice  numeric,
  p_verde   numeric default 90,
  p_amarelo numeric default 75,
  p_laranja numeric default 50
) returns text
language sql immutable as $$
  select case
    when p_indice is null     then 'cinza'
    when p_indice >= p_verde  then 'verde'
    when p_indice >= p_amarelo then 'amarelo'
    when p_indice >= p_laranja then 'laranja'
    else 'vermelho'
  end
$$;

-- A leitura mais recente e ainda valida de cada indicador de um escopo.
create or replace view idg_atual as
select distinct on (m.indicador_id, m.escopo_id)
       i.sistema_id,
       m.indicador_id,
       m.escopo_id,
       i.chave, i.nome, i.especie, i.unidade, i.decimais, i.icone,
       i.peso, i.no_idg, i.destino_url, i.ordem,
       m.valor, m.texto, m.detalhe, m.medido_em, m.ok, m.erro,
       -- Leitura velha deixa de valer: nao se mostra dado vencido como atual.
       case when m.medido_em < now() - make_interval(secs => i.validade_seg)
            then null else m.indice end as indice,
       case when m.medido_em < now() - make_interval(secs => i.validade_seg)
            then 'cinza' else m.estado end as estado,
       m.medido_em < now() - make_interval(secs => i.validade_seg) as vencido
  from idg_medicao m
  join idg_indicador i on i.id = m.indicador_id
 where i.ativo
 order by m.indicador_id, m.escopo_id, m.medido_em desc;

-- IDG = media ponderada dos indicadores validos que participam.
-- Devolve tambem de quantos ele saiu, para o numero ser rastreavel.
create or replace function idg_calcular(p_sistema_id uuid, p_escopo_id uuid)
returns table (idg numeric, estado text, participantes integer, elegiveis integer)
language sql stable as $$
  with elegivel as (
    select i.id, i.peso, i.faixa_verde, i.faixa_amarelo, i.faixa_laranja
      from idg_indicador i
     where i.sistema_id = p_sistema_id and i.ativo and i.no_idg
       and i.especie = 'indicador' and i.peso > 0
  ), valido as (
    select e.peso, a.indice
      from elegivel e
      join idg_atual a on a.indicador_id = e.id
     where a.escopo_id is not distinct from p_escopo_id and a.indice is not null
  ), conta as (
    select round(sum(peso * indice) / nullif(sum(peso), 0), 1) as idg,
           count(*)::int as participantes
      from valido
  )
  select c.idg,
         -- As faixas do IDG sao as mesmas do padrao dos indicadores.
         idg_estado(c.idg),
         c.participantes,
         (select count(*)::int from elegivel)
    from conta c
$$;

-- ---------------------------------------------------------------------------
-- Acesso
-- ---------------------------------------------------------------------------
alter table idg_sistema   enable row level security;
alter table idg_escopo    enable row level security;
alter table idg_indicador enable row level security;
alter table idg_medicao   enable row level security;

-- Leitura: cliente cadastrado e admin. O IDG e area de cliente.
-- (A coleta roda com service_role, que nao passa por RLS.)
create policy idg_sistema_ler on idg_sistema for select to authenticated
  using (portal_admin() or (ativo and portal_cliente()));

create policy idg_escopo_ler on idg_escopo for select to authenticated
  using (portal_admin() or (ativo and portal_cliente()));

create policy idg_indicador_ler on idg_indicador for select to authenticated
  using (portal_admin() or (ativo and portal_cliente()));

create policy idg_medicao_ler on idg_medicao for select to authenticated
  using (portal_admin() or portal_cliente());

-- Escrita da configuracao: so admin.
create policy idg_sistema_adm   on idg_sistema   for all to authenticated
  using (portal_admin()) with check (portal_admin());
create policy idg_escopo_adm    on idg_escopo    for all to authenticated
  using (portal_admin()) with check (portal_admin());
create policy idg_indicador_adm on idg_indicador for all to authenticated
  using (portal_admin()) with check (portal_admin());
