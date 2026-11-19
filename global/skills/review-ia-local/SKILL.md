---
name: review-ia-local
description: "Roda localmente o mesmo code review por IA que a CI executa no pull request, com as regras lidas direto de <org>/ci-workflows e a saida no mesmo formato do card e dos comentarios inline do GitHub. Use quando pedirem para revisar o codigo antes de abrir o pull request, prever o que o review automatico vai apontar, rodar o review local, ou quando perguntarem onde ficam as regras desse review."
---

# Review por IA local

A CI de pull request dos repositorios roda `credsolaris/ci-workflows/.github/actions/review-ia`,
que manda o diff para um modelo no OpenRouter e publica um card de resumo mais um comentario
inline por achado. Esta skill reproduz isso no terminal, antes do pull request existir.

O script fica em `scripts/review-local.mjs`, dentro do diretorio desta skill. Nos exemplos,
`$SKILL` e a pasta desta skill, que depende do agente:

```bash
SKILL=~/.claude/skills/review-ia-local      # Claude Code
SKILL=~/.config/opencode/skills/review-ia-local   # opencode
```

Troque pelo caminho real antes de rodar. O diretorio de trabalho e sempre o repositorio que
esta sendo revisado, nunca a pasta da skill.

**As regras nao sao copiadas para ca.** O script le o prompt de sistema e a lista de arquivos
ignorados direto do `review-ia.mjs` da CI, para o que o terminal diz nao divergir do que o
GitHub vai dizer. Onde o script procura o arquivo, nessa ordem:

1. `$REVIEW_IA_MJS`, se apontar para um arquivo existente
2. `.github/actions/review-ia/review-ia.mjs` no proprio repositorio
3. `../ci-workflows/` e `../../ci-workflows/` ao lado do projeto
4. `~/projetos/cred/ci-workflows/`
5. `gh api repos/<org>/ci-workflows/contents/...?ref=v1`, com cache em `~/.cache/review-ia/`

A `<org>` sai do remote `origin`. Se nenhuma dessas fontes responder, o script para e diz o que
falta; nao invente regras nem use um prompt de memoria.

## Dois modos

| Modo | Quem analisa | Precisa de chave | Quando |
|---|---|---|---|
| agente (padrao) | voce, seguindo o prompt de sistema da CI | nao | sempre que nao houver `OPENROUTER_API_KEY` no ambiente |
| `ia` | o mesmo modelo que a CI usa, via OpenRouter | sim, `OPENROUTER_API_KEY` | quando o usuario quer o veredito identico ao do pull request, com custo |

O modo agente da uma analise fiel as regras, mas nao e byte a byte o que o modelo da CI diria.
Diga isso ao usuario quando ele comparar os dois.

## Modo agente, passo a passo

Node 20 ou superior. Se o projeto fixa versao, use a skill de version managers antes.

1. Gere o prompt a partir do diff:

   ```bash
   node $SKILL/scripts/review-local.mjs prompt
   ```

   Sem opcao, a faixa e `origin/main...HEAD`, igual a baseline da CI. Use `--base origin/develop`
   para outra base, `--staged` para o que esta no index ou `--working` para a arvore de trabalho.
   Saem tres arquivos em `.git/review-ia/`: `prompt-sistema.md`, `prompt-usuario.md` e
   `contexto.json`.

2. Leia os dois prompts por inteiro e analise o diff **seguindo o prompt de sistema ao pe da letra**:
   no maximo 8 achados, nada de estilo ou formatacao, severidade conforme a tabela da CI, categoria
   da lista fechada, `detalhe` com no maximo 3 frases e `sugestao` com no maximo 2. Nao acrescente
   criterio seu nem relaxe nenhum dos itens.

3. Grave o resultado no mesmo JSON que a CI espera, em `.git/review-ia/achados.json`:

   ```json
   {
     "resumo": "um paragrafo",
     "achados": [
       {
         "severidade": "BLOCKING",
         "arquivo": "src/x.ts",
         "linha": 42,
         "categoria": "correctness",
         "titulo": "frase curta",
         "detalhe": "o que acontece e por que e problema",
         "sugestao": "o que fazer, opcional"
       }
     ]
   }
   ```

   Lista vazia e resposta valida e esperada quando nao ha problema.

4. Renderize no formato do GitHub e mostre a saida ao usuario como ela sai:

   ```bash
   node $SKILL/scripts/review-local.mjs render .git/review-ia/achados.json
   ```

   O script ancora cada achado numa linha que o GitHub aceitaria como comentario; o que nao tem
   ancora cai no bloco "Achados sem linha no diff", exatamente como no pull request. Saida 1
   quando ha BLOCKING, 0 nos outros casos.

Nao reescreva o card a mao e nao resuma a saida do `render`: o valor da skill e o formato ser o
mesmo. Depois dela, voce pode comentar em texto corrido o que faria primeiro.

## Modo ia

```bash
OPENROUTER_API_KEY=... node $SKILL/scripts/review-local.mjs ia
```

Mesmo modelo, mesma temperatura, mesmo `max_tokens` e mesmo tratamento de resposta cortada da
CI. O modelo vem de `--modelo`, senao de `MODELO_REVIEW_IA`, senao
`anthropic/claude-sonnet-5.5`. Avise o usuario que essa chamada e paga antes de rodar, e nunca
imprima a chave.

## Opcoes

| Opcao | Efeito |
|---|---|
| `--base <ref>` | base da faixa, padrao `origin/main` (cai para `main`, `origin/master`, `master`) |
| `--staged` | revisa `git diff --cached` |
| `--working` | revisa `git diff HEAD` |
| `--max-bytes <n>` | limite do diff, padrao 180000, o mesmo da CI |
| `--modelo <id>` | modelo no OpenRouter, so no modo `ia` |
| `--saida <dir>` | onde gravar os prompts, padrao `.git/review-ia` |
| `--json` | imprime o JSON em vez do card |

O subcomando `regras` mostra o prompt de sistema vigente e de onde ele veio. Use quando o
usuario perguntar quais sao os criterios do review, em vez de descrever de cabeca.

## Contexto por repositorio

Se o repositorio tem `.github/review-ia.md`, os primeiros 8000 caracteres entram no prompt como
"Contexto especifico deste repositorio", igual na CI. E ali que se ensina ao revisor o que e
regra de negocio do projeto, nao no prompt de sistema central.

## Armadilhas

- **Diff vazio nao e repositorio limpo.** Lockfile, binario e artefato gerado saem da faixa pelas
  exclusoes da CI. O script imprime o card de "nenhum arquivo revisavel" nesse caso.
- **`origin/main` desatualizado muda o veredito.** `git fetch origin` antes, senao o diff local
  carrega o que a main ja tem e aparece achado que a CI nao vai ver.
- **Faixa de tres pontos.** `base...HEAD` usa o merge-base, igual ao que o GitHub manda para a
  action. Nao troque por dois pontos.
- **Review local nao substitui o check.** O check do pull request continua sendo a fonte da
  verdade, e o campo `bloquear_em_bloqueador` da CI decide se BLOCKING reprova o PR.
