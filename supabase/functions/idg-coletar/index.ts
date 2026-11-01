// IOT CITY AUDIT — coletor de indicadores.
//
// Roda no servidor, por agendamento, independente de alguém estar com a tela
// aberta. Busca os valores nas fontes autorizadas e grava a medição bruta; a
// normalização e a classificação são do banco (gatilho idg_classificar), para
// a matemática viver num lugar só.
//
// Quem pode chamar (o verify_jwt sozinho não bastava: ele aceita a chave
// publicável, que está no icones.js, público):
//   · cabeçalho x-idg-token válido → é o agendador (pg_cron lê do Vault)
//   · JWT de um admin do portal    → é o botão "Coletar" da tela
//   · qualquer outra coisa         → 403
//
// Segurança da fonte: a credencial do Raio-X nunca sai daqui. O conector chama
// UMA função remota (idg_agregados) que devolve apenas números consolidados e
// quebra por causa — nunca uma linha de dispositivo.

import { createClient } from 'jsr:@supabase/supabase-js@2'

type Leitura = { valor?: number | null; texto?: string | null; detalhe?: unknown }
type Conector = (escopo: string) => Promise<{ leituras: Record<string, Leitura>; origem: string }>

const PORTAL = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  { auth: { persistSession: false } },
)

/** Catálogo de conectores. Só o que está aqui pode ser chamado — nunca código
 *  informado no cadastro (seção 5.1 da especificação). O banco também recusa,
 *  por chave estrangeira com idg_conector; aqui é a segunda tranca. */
const CONECTORES: Record<string, Conector> = {
  'raiox.agregados': async (escopo) => {
    const url = Deno.env.get('RAIOX_URL')
    const key = Deno.env.get('RAIOX_SERVICE_KEY')
    if (!url || !key) throw new Error('RAIOX_URL/RAIOX_SERVICE_KEY não configurados')

    const r = await fetch(`${url}/rest/v1/rpc/idg_agregados`, {
      method: 'POST',
      headers: { apikey: key, authorization: `Bearer ${key}`, 'content-type': 'application/json' },
      body: JSON.stringify({ p_escopo: escopo }),
      signal: AbortSignal.timeout(20_000),
    })
    if (!r.ok) throw new Error(`Raio-X respondeu ${r.status}: ${(await r.text()).slice(0, 200)}`)

    const dados = await r.json()
    if (!dados) throw new Error(`Raio-X não tem coleta para o escopo ${escopo}`)
    return { leituras: dados.indicadores ?? {}, origem: dados.coletado_em ?? '' }
  },
}

/** Devolve quem está chamando, ou null se ninguém autorizado. */
async function autorizar(req: Request): Promise<string | null> {
  const token = req.headers.get('x-idg-token')
  if (token) {
    const { data } = await PORTAL.rpc('idg_cron_token_ok', { p_token: token })
    if (data === true) return 'agendador'
  }
  const jwt = (req.headers.get('authorization') ?? '').replace(/^Bearer\s+/i, '')
  if (jwt) {
    const { data: u } = await PORTAL.auth.getUser(jwt)
    if (u?.user) {
      const { data: p } = await PORTAL
        .from('portal_usuario').select('papel')
        .eq('user_id', u.user.id).eq('ativo', true).maybeSingle()
      if (p?.papel === 'admin') return `admin:${u.user.email}`
    }
  }
  return null
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('método', { status: 405 })

  const quem = await autorizar(req)
  if (!quem) return Response.json({ erro: 'não autorizado' }, { status: 403 })

  // O botão da tela pode forçar; o agendador respeita o intervalo do cadastro.
  let forcar = false
  try { forcar = (await req.json())?.forcar === true } catch (_) { /* corpo vazio */ }

  const inicio = Date.now()
  const resumo: Record<string, unknown>[] = []

  const { data: indicadores, error } = await PORTAL
    .from('idg_indicador')
    .select('id, chave, funcao, parametros, especie, intervalo_seg, sistema_id, idg_sistema!inner(chave, ativo)')
    .eq('ativo', true)
  if (error) return Response.json({ erro: error.message }, { status: 500 })

  const { data: escopos } = await PORTAL.from('idg_escopo').select('id, chave, sistema_id').eq('ativo', true)

  // Quando cada par (indicador, escopo) foi medido pela última vez. idg_atual
  // já é exatamente isso, e indicador que nunca foi medido simplesmente não
  // aparece aqui — então entra como vencido, que é o certo.
  const { data: ultimas } = await PORTAL.from('idg_atual').select('indicador_id, escopo_id, medido_em')
  const quando = new Map((ultimas ?? []).map((m) => [`${m.indicador_id}|${m.escopo_id}`, Date.parse(m.medido_em)]))
  const agora = Date.now()
  const naHora = (indId: string, escId: string, intervalo: number) => {
    if (forcar) return true
    const t = quando.get(`${indId}|${escId}`)
    return t === undefined || agora - t >= (intervalo ?? 3600) * 1000
  }

  // Uma chamada por (sistema, escopo) serve todos os indicadores daquele par.
  // Se nenhum deles está na hora, o par inteiro é pulado e a fonte nem é tocada.
  const pares = new Map<string, { funcao: string; escopo: { id: string; chave: string }; itens: typeof indicadores }>()
  let adiados = 0
  for (const ind of indicadores ?? []) {
    for (const esc of (escopos ?? []).filter((e) => e.sistema_id === ind.sistema_id)) {
      if (!naHora(ind.id, esc.id, ind.intervalo_seg)) { adiados++; continue }
      const k = `${ind.funcao}|${esc.id}`
      const atual = pares.get(k) ?? { funcao: ind.funcao, escopo: esc, itens: [] }
      atual.itens.push(ind)
      pares.set(k, atual)
    }
  }

  for (const [, par] of pares) {
    const conector = CONECTORES[par.funcao]
    const linhas: Record<string, unknown>[] = []

    if (!conector) {
      // Função fora do catálogo não é executada, e isso fica registrado.
      for (const i of par.itens) {
        linhas.push({ indicador_id: i.id, escopo_id: par.escopo.id, ok: false, erro: `conector desconhecido: ${par.funcao}` })
      }
    } else {
      try {
        const { leituras, origem } = await conector(par.escopo.chave)
        for (const i of par.itens) {
          const chave = (i.parametros as Record<string, string>)?.metrica ?? i.chave
          const l = leituras[chave]
          if (l === undefined) {
            // Falta de dado é registrada como falta, nunca como zero.
            linhas.push({ indicador_id: i.id, escopo_id: par.escopo.id, ok: false, erro: `a fonte não devolveu "${chave}"` })
            continue
          }
          linhas.push({
            indicador_id: i.id,
            escopo_id: par.escopo.id,
            valor: typeof l.valor === 'number' ? l.valor : null,
            texto: l.texto ?? null,
            detalhe: l.detalhe ?? null,
            ok: true,
          })
        }
        resumo.push({ funcao: par.funcao, escopo: par.escopo.chave, indicadores: par.itens.length, origem })
      } catch (e) {
        const erro = e instanceof Error ? e.message : String(e)
        for (const i of par.itens) linhas.push({ indicador_id: i.id, escopo_id: par.escopo.id, ok: false, erro })
        resumo.push({ funcao: par.funcao, escopo: par.escopo.chave, erro })
      }
    }

    const { error: e2 } = await PORTAL.from('idg_medicao').insert(linhas)
    if (e2) resumo.push({ funcao: par.funcao, escopo: par.escopo.chave, gravacao: e2.message })
  }

  return Response.json({ quem, forcar, pares: pares.size, adiados, ms: Date.now() - inicio, resumo })
})
