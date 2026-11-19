#!/usr/bin/env node
// Review por IA local, com as mesmas regras e o mesmo formato do review que roda no pull request.
//
// As regras nao sao copiadas para ca. O script le o prompt de sistema direto do
// review-ia.mjs de <org>/ci-workflows, a mesma fonte que a CI usa, para nao haver
// divergencia entre o que o terminal diz e o que o GitHub vai dizer.
//
// Subcomandos:
//   regras            mostra o prompt de sistema vigente e de onde ele veio
//   prompt            grava prompt-sistema.md e prompt-usuario.md para o agente analisar
//   ia                chama o OpenRouter (precisa de OPENROUTER_API_KEY) e imprime o card
//   render <json>     monta o card a partir de um JSON de achados ja produzido
//
// Opcoes: --base <ref> | --staged | --working | --max-bytes <n> | --modelo <id> | --saida <dir> | --json

import { execFileSync } from 'node:child_process'
import { existsSync, readFileSync, writeFileSync, mkdirSync } from 'node:fs'
import { homedir } from 'node:os'
import { join, dirname } from 'node:path'

const ARQUIVO_REGRAS = '.github/actions/review-ia/review-ia.mjs'
const REF_CI = process.env.REVIEW_IA_REF || 'v1'
const MARCADOR_CARD = '<!-- review-ia -->'

const SEVERIDADES = {
  BLOCKING: { emoji: '🔴', ordem: 0 },
  SUGGESTION: { emoji: '🟡', ordem: 1 },
  NIT: { emoji: '🟢', ordem: 2 },
  QUESTION: { emoji: '❓', ordem: 3 },
}
const CATEGORIAS = ['correctness', 'security', 'performance', 'data', 'tests', 'infra', 'process']

const IGNORAR_PADRAO = [
  'package-lock.json', 'yarn.lock', 'pnpm-lock.yaml', '*.snap',
  'dist/**', 'build/**', 'coverage/**', 'node_modules/**',
  '*.svg', '*.png', '*.jpg', '*.jpeg', '*.gif', '*.ico', '*.pdf',
  '*.min.js', '*.min.css',
]

const git = (args, opcoes = {}) =>
  execFileSync('git', args, { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024, ...opcoes })

const tentar = (fn, padrao = null) => { try { return fn() } catch { return padrao } }

// ---------------------------------------------------------------- argumentos

function lerArgumentos(argv) {
  const o = { comando: argv[0] || 'ia', alvo: null, base: null, modo: 'faixa', maxBytes: 180000, modelo: null, saida: null, json: false }
  for (let i = 1; i < argv.length; i++) {
    const a = argv[i]
    if (a === '--base') o.base = argv[++i]
    else if (a === '--staged') o.modo = 'staged'
    else if (a === '--working') o.modo = 'working'
    else if (a === '--max-bytes') o.maxBytes = Number(argv[++i])
    else if (a === '--modelo') o.modelo = argv[++i]
    else if (a === '--saida') o.saida = argv[++i]
    else if (a === '--json') o.json = true
    else if (!a.startsWith('--')) o.alvo = a
    else { console.error(`opcao desconhecida: ${a}`); process.exit(1) }
  }
  return o
}

// ---------------------------------------------------------------- repositorio

function dadosDoRepo() {
  const raiz = tentar(() => git(['rev-parse', '--show-toplevel']).trim())
  if (!raiz) { console.error('nao estou dentro de um repositorio git'); process.exit(1) }

  const remoto = tentar(() => git(['remote', 'get-url', 'origin']).trim(), '')
  const m = remoto.match(/[:/]([^/:]+)\/([^/]+?)(?:\.git)?$/)
  const org = m ? m[1] : 'credsolaris'
  const nome = m ? m[2] : raiz.split('/').pop()
  const branch = tentar(() => git(['rev-parse', '--abbrev-ref', 'HEAD']).trim(), 'HEAD')

  return { raiz, org, nome, repositorio: `${org}/${nome}`, branch }
}

function baseAutomatica() {
  for (const ref of ['origin/main', 'main', 'origin/master', 'master']) {
    if (tentar(() => git(['rev-parse', '--verify', '--quiet', ref]))) return ref
  }
  console.error('nao achei main nem master, passe --base <ref>')
  process.exit(1)
}

// ---------------------------------------------------------------- regras da CI

// Ordem: variavel de ambiente, clone local do ci-workflows, cache, GitHub via gh.
function localizarRegras(repo) {
  if (process.env.REVIEW_IA_MJS && existsSync(process.env.REVIEW_IA_MJS)) {
    return { texto: readFileSync(process.env.REVIEW_IA_MJS, 'utf8'), origem: process.env.REVIEW_IA_MJS }
  }

  const candidatos = [
    join(repo.raiz, ARQUIVO_REGRAS),
    join(repo.raiz, '..', 'ci-workflows', ARQUIVO_REGRAS),
    join(repo.raiz, '..', '..', 'ci-workflows', ARQUIVO_REGRAS),
    join(homedir(), 'projetos', 'cred', 'ci-workflows', ARQUIVO_REGRAS),
  ]
  for (const c of candidatos) {
    if (existsSync(c)) return { texto: readFileSync(c, 'utf8'), origem: c }
  }

  const cache = join(homedir(), '.cache', 'review-ia', `${repo.org}-${REF_CI}.mjs`)
  const baixar = () => {
    const b64 = execFileSync('gh', [
      'api', `repos/${repo.org}/ci-workflows/contents/${ARQUIVO_REGRAS}?ref=${REF_CI}`, '--jq', '.content',
    ], { encoding: 'utf8' })
    return Buffer.from(b64.replace(/\s/g, ''), 'base64').toString('utf8')
  }

  const texto = tentar(baixar)
  if (texto) {
    mkdirSync(dirname(cache), { recursive: true })
    writeFileSync(cache, texto)
    return { texto, origem: `${repo.org}/ci-workflows@${REF_CI} (gh)` }
  }
  if (existsSync(cache)) return { texto: readFileSync(cache, 'utf8'), origem: `${cache} (cache)` }

  console.error(`nao consegui ler ${ARQUIVO_REGRAS}. Clone ${repo.org}/ci-workflows ao lado do projeto, autentique o gh ou aponte REVIEW_IA_MJS`)
  process.exit(1)
}

function extrairRegras(repo) {
  const { texto, origem } = localizarRegras(repo)

  const sistema = texto.match(/const SISTEMA = `([\s\S]*?)`\s*\n/)
  if (!sistema) {
    console.error(`achei ${origem} mas nao reconheci o prompt de sistema; a CI mudou de formato`)
    process.exit(1)
  }

  const bloco = texto.match(/const IGNORAR = \[([\s\S]*?)\]\s*\n?\s*\.map/)
  const ignorar = bloco ? [...bloco[1].matchAll(/'([^']+)'/g)].map((m) => m[1]) : IGNORAR_PADRAO

  return { sistema: sistema[1], ignorar, origem }
}

// ---------------------------------------------------------------- diff

function coletarDiff(opcoes, regras) {
  const exclusoes = regras.ignorar.map((p) => `:(exclude)**/${p}`)
  const faixa =
    opcoes.modo === 'staged' ? ['--cached'] :
    opcoes.modo === 'working' ? ['HEAD'] :
    [`${opcoes.base}...HEAD`]

  const arquivos = git(['diff', '--name-status', ...faixa, '--', '.', ...exclusoes]).trim()
  let diff = git(['diff', '--unified=3', ...faixa, '--', '.', ...exclusoes])
  let truncado = false
  if (diff.length > opcoes.maxBytes) {
    diff = diff.slice(0, opcoes.maxBytes)
    truncado = true
  }
  return { arquivos, diff, truncado }
}

function mapearLinhasComentaveis(diff) {
  const mapa = new Map()
  let arquivo = null
  let linha = 0

  for (const l of diff.split('\n')) {
    if (l.startsWith('+++ ')) {
      const caminho = l.slice(4).trim().replace(/^"(.*)"$/, '$1')
      arquivo = caminho === '/dev/null' ? null : caminho.replace(/^b\//, '')
      if (arquivo && !mapa.has(arquivo)) mapa.set(arquivo, { todas: new Set(), adicionadas: new Set() })
      continue
    }
    if (l.startsWith('@@')) {
      const m = l.match(/@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@/)
      linha = m ? Number(m[1]) : 0
      continue
    }
    if (!arquivo || !linha) continue

    if (l.startsWith('+')) {
      mapa.get(arquivo).todas.add(linha)
      mapa.get(arquivo).adicionadas.add(linha)
      linha++
    } else if (l.startsWith('-') || l.startsWith('\\')) {
      // linha removida nao existe do lado novo
    } else if (l.startsWith(' ')) {
      mapa.get(arquivo).todas.add(linha)
      linha++
    }
  }
  return mapa
}

function ancorar(mapa, arquivo, linha) {
  const info = mapa.get(arquivo)
  if (!info) return null
  if (linha && info.todas.has(linha)) return linha

  const candidatas = [...info.adicionadas]
  if (!candidatas.length) return null
  if (!linha) return candidatas[0]

  return candidatas.reduce((melhor, atual) =>
    Math.abs(atual - linha) < Math.abs(melhor - linha) ? atual : melhor)
}

// ---------------------------------------------------------------- prompt

function contextoDoRepositorio(raiz) {
  for (const nome of ['.github/review-ia.md', '.github/REVIEW-IA.md']) {
    const caminho = join(raiz, nome)
    if (existsSync(caminho)) return readFileSync(caminho, 'utf8').slice(0, 8000)
  }
  return ''
}

function montarPrompt(repo, opcoes, coletado) {
  const contexto = contextoDoRepositorio(repo.raiz)
  const commits =
    opcoes.modo === 'faixa'
      ? tentar(() => git(['log', '--no-merges', '--format=- %s', `${opcoes.base}..HEAD`]).trim(), '')
      : ''
  const alvo =
    opcoes.modo === 'staged' ? 'alteracoes no index (git diff --cached)' :
    opcoes.modo === 'working' ? 'alteracoes na arvore de trabalho (git diff HEAD)' :
    `branch ${repo.branch} contra ${opcoes.base}`

  return [
    `Repositorio: ${repo.repositorio}`,
    `Revisao local, antes do pull request: ${alvo}`,
    commits ? `\nCommits da faixa:\n${commits}` : '',
    contexto ? `\nContexto especifico deste repositorio:\n${contexto}` : '',
    `\nArquivos alterados:\n${coletado.arquivos || '(nenhum)'}`,
    coletado.truncado ? '\nATENCAO: o diff foi truncado por tamanho. Diga no resumo que a revisao foi parcial.' : '',
    `\nDiff:\n\`\`\`diff\n${coletado.diff}\n\`\`\``,
  ].filter(Boolean).join('\n')
}

// ---------------------------------------------------------------- modelo

function extrairJson(texto) {
  const semCerca = texto.replace(/^\s*```(?:json)?\s*/i, '').replace(/\s*```\s*$/, '')
  const inicio = semCerca.indexOf('{')
  if (inicio === -1) throw new Error(`resposta sem JSON: ${texto.slice(0, 300)}`)
  const bruto = semCerca.slice(inicio)
  const fim = bruto.lastIndexOf('}')
  if (fim !== -1) {
    try { return JSON.parse(bruto.slice(0, fim + 1)) } catch { /* cai no reparo */ }
  }
  return repararJson(bruto)
}

function repararJson(bruto) {
  const resumo = bruto.match(/"resumo"\s*:\s*"((?:[^"\\]|\\.)*)"/)
  const achados = []
  const inicioLista = bruto.indexOf('"achados"')

  if (inicioLista !== -1) {
    let profundidade = 0
    let comeco = -1
    for (let i = bruto.indexOf('[', inicioLista); i < bruto.length && i !== -1; i++) {
      const c = bruto[i]
      if (c === '{') { if (profundidade === 0) comeco = i; profundidade++ }
      else if (c === '}') {
        profundidade--
        if (profundidade === 0 && comeco !== -1) {
          try { achados.push(JSON.parse(bruto.slice(comeco, i + 1))) } catch { /* achado cortado */ }
          comeco = -1
        }
      }
    }
  }
  if (!resumo && !achados.length) throw new Error(`resposta sem JSON utilizavel: ${bruto.slice(0, 300)}`)

  return {
    resumo: resumo ? JSON.parse(`"${resumo[1]}"`) : 'A resposta do modelo veio cortada. Os achados abaixo sao os que chegaram inteiros.',
    achados,
  }
}

async function pedirRevisao(sistema, prompt, modelo, repositorio) {
  const corpo = {
    model: modelo,
    max_tokens: 16000,
    temperature: 0.1,
    usage: { include: true },
    reasoning: { effort: 'low', exclude: true },
    messages: [
      { role: 'system', content: sistema },
      { role: 'user', content: prompt },
    ],
  }

  let ultimoErro
  for (let tentativa = 1; tentativa <= 3; tentativa++) {
    try {
      const controlador = new AbortController()
      const relogio = setTimeout(() => controlador.abort(), 180000)
      const resposta = await fetch('https://openrouter.ai/api/v1/chat/completions', {
        method: 'POST',
        signal: controlador.signal,
        headers: {
          Authorization: `Bearer ${process.env.OPENROUTER_API_KEY}`,
          'Content-Type': 'application/json',
          'HTTP-Referer': `https://github.com/${repositorio}`,
          'X-Title': `${repositorio} code review local`,
        },
        body: JSON.stringify(corpo),
      })
      clearTimeout(relogio)

      if (!resposta.ok) {
        const texto = await resposta.text()
        if (resposta.status === 400 && /reasoning/i.test(texto) && corpo.reasoning) {
          delete corpo.reasoning
          tentativa--
          continue
        }
        throw new Error(`OpenRouter respondeu ${resposta.status}: ${texto.slice(0, 500)}`)
      }

      const dados = await resposta.json()
      const escolha = dados?.choices?.[0]
      const conteudo = escolha?.message?.content
      if (!conteudo) throw new Error(`resposta sem conteudo, finish_reason ${escolha?.finish_reason}`)
      if (escolha.finish_reason === 'length') throw new Error('resposta truncada por max_tokens')

      return { analise: extrairJson(conteudo), uso: dados.usage || {}, modelo: dados.model || modelo }
    } catch (erro) {
      ultimoErro = erro
      console.error(`tentativa ${tentativa} falhou: ${erro.message}`)
      if (tentativa < 3) await new Promise((r) => setTimeout(r, tentativa * 5000))
    }
  }
  throw ultimoErro
}

// ---------------------------------------------------------------- card

function corpoDoAchado(a, linha) {
  const sev = SEVERIDADES[a.severidade] || SEVERIDADES.SUGGESTION
  const categoria = CATEGORIAS.includes(a.categoria) ? a.categoria : 'correctness'
  const partes = [`${sev.emoji} **${a.severidade}: ${a.titulo}**`, '', a.detalhe]
  if (a.sugestao) partes.push('', `**Sugestao:** ${a.sugestao}`)
  partes.push('', `_Categoria: ${categoria}_`)
  partes.push('', `📍 \`${a.arquivo}${linha ? ':' + linha : ''}\``)
  return partes.join('\n')
}

function montarSaida({ repo, analise, coletado, uso, modelo, origem }) {
  const achados = Array.isArray(analise.achados) ? analise.achados : []
  const contagem = { BLOCKING: 0, SUGGESTION: 0, NIT: 0, QUESTION: 0 }
  for (const a of achados) {
    if (contagem[a.severidade] === undefined) a.severidade = 'SUGGESTION'
    contagem[a.severidade]++
  }
  achados.sort((x, y) => (SEVERIDADES[x.severidade]?.ordem ?? 1) - (SEVERIDADES[y.severidade]?.ordem ?? 1))

  const mapa = mapearLinhasComentaveis(coletado.diff)
  const comLinha = []
  const semPosicao = []
  for (const a of achados) {
    const linha = ancorar(mapa, a.arquivo, Number(a.linha) || 0)
    if (linha) comLinha.push({ a, linha })
    else semPosicao.push(a)
  }

  const veredito = contagem.BLOCKING > 0
    ? `🛑 ${contagem.BLOCKING} bloqueio${contagem.BLOCKING > 1 ? 's' : ''}`
    : '✅ Sem bloqueios'

  const linhas = [
    MARCADOR_CARD,
    `## 🤖 Review automatico · ${repo.org}`,
    '',
    `**Veredito:** ${veredito}`,
    '',
    analise.resumo || 'Sem resumo.',
  ]
  if (coletado.truncado) linhas.push('', '> O diff foi truncado por tamanho, a revisao e parcial.')

  linhas.push(
    '',
    '| Severidade | Qtd |',
    '|---|---|',
    ...Object.entries(SEVERIDADES).map(([nome, s]) => `| ${s.emoji} ${nome} | ${contagem[nome]} |`),
    '',
    `Threads: ${comLinha.length} inline, ${semPosicao.length} sem posicao.`,
  )

  for (const { a, linha } of comLinha) {
    linhas.push('', '---', '', corpoDoAchado(a, linha))
  }

  if (semPosicao.length) {
    linhas.push('', '<details><summary>Achados sem linha no diff</summary>', '')
    for (const a of semPosicao) {
      const sev = SEVERIDADES[a.severidade] || SEVERIDADES.SUGGESTION
      linhas.push(`- ${sev.emoji} **${a.severidade}: ${a.titulo}** · 📍 \`${a.arquivo}${a.linha ? ':' + a.linha : ''}\` · _${a.categoria || 'correctness'}_`)
      if (a.detalhe) linhas.push(`  ${a.detalhe}`)
    }
    linhas.push('', '</details>')
  }

  const rodape = [`regras de \`${origem}\``]
  if (modelo) rodape.unshift(`modelo \`${String(modelo).replace(/^.*\//, '')}\``)
  if (uso && uso.cost !== undefined) rodape.push(`custo ${Number(uso.cost).toFixed(4)} USD`)
  if (uso && uso.prompt_tokens !== undefined) rodape.push(`${uso.prompt_tokens} tokens de entrada, ${uso.completion_tokens ?? '?'} de saida`)

  linhas.push('', `_Review local · ${rodape.join(' · ')} · nao substitui o review humano nem o check do pull request_`)

  return { texto: linhas.join('\n'), contagem }
}

// ---------------------------------------------------------------- principal

async function principal() {
  const opcoes = lerArgumentos(process.argv.slice(2))
  const repo = dadosDoRepo()
  const regras = extrairRegras(repo)

  if (opcoes.comando === 'regras') {
    console.log(`origem: ${regras.origem}\nignorados: ${regras.ignorar.join(', ')}\n\n--- prompt de sistema ---\n${regras.sistema}`)
    return
  }

  if (opcoes.modo === 'faixa' && !opcoes.base) opcoes.base = baseAutomatica()
  const coletado = coletarDiff(opcoes, regras)
  const saida = opcoes.saida || join(repo.raiz, '.git', 'review-ia')

  if (!coletado.diff.trim()) {
    console.log(`${MARCADOR_CARD}\n## 🤖 Review automatico · ${repo.org}\n\n**Veredito:** ✅ Sem bloqueios\n\nNenhum arquivo revisavel nesta faixa: so lockfile, binario ou artefato gerado.`)
    return
  }

  if (opcoes.comando === 'prompt') {
    mkdirSync(saida, { recursive: true })
    const prompt = montarPrompt(repo, opcoes, coletado)
    writeFileSync(join(saida, 'prompt-sistema.md'), regras.sistema)
    writeFileSync(join(saida, 'prompt-usuario.md'), prompt)
    writeFileSync(join(saida, 'contexto.json'), JSON.stringify({
      repositorio: repo.repositorio, branch: repo.branch, base: opcoes.base, modo: opcoes.modo,
      origemDasRegras: regras.origem, bytesDoDiff: coletado.diff.length, truncado: coletado.truncado,
    }, null, 2))
    console.log(`${join(saida, 'prompt-sistema.md')}\n${join(saida, 'prompt-usuario.md')}\n${join(saida, 'contexto.json')}`)
    console.log(`diff com ${coletado.diff.length} bytes, regras de ${regras.origem}${coletado.truncado ? ', truncado' : ''}`)
    return
  }

  if (opcoes.comando === 'render') {
    if (!opcoes.alvo) { console.error('uso: render <achados.json>'); process.exit(1) }
    const analise = JSON.parse(readFileSync(opcoes.alvo, 'utf8'))
    const { texto, contagem } = montarSaida({ repo, analise, coletado, origem: regras.origem })
    console.log(opcoes.json ? JSON.stringify({ analise, contagem }, null, 2) : texto)
    process.exit(contagem.BLOCKING > 0 ? 1 : 0)
  }

  if (opcoes.comando !== 'ia') { console.error(`comando desconhecido: ${opcoes.comando}`); process.exit(1) }

  if (!process.env.OPENROUTER_API_KEY) {
    console.error('OPENROUTER_API_KEY ausente. Use o subcomando prompt para o agente analisar sem chave.')
    process.exit(2)
  }

  const modelo = opcoes.modelo || process.env.MODELO_REVIEW_IA || 'anthropic/claude-sonnet-5.5'
  const prompt = montarPrompt(repo, opcoes, coletado)
  const { analise, uso, modelo: usado } = await pedirRevisao(regras.sistema, prompt, modelo, repo.repositorio)
  const { texto, contagem } = montarSaida({ repo, analise, coletado, uso, modelo: usado, origem: regras.origem })
  console.log(opcoes.json ? JSON.stringify({ analise, contagem, uso }, null, 2) : texto)
  process.exit(contagem.BLOCKING > 0 ? 1 : 0)
}

principal().catch((erro) => {
  console.error(`review local falhou: ${erro.message}`)
  process.exit(1)
})
