---
name: padronizar-fluxo-github
description: "Instala em repositorios de uma organizacao do GitHub o fluxo padronizado de desenvolvimento: nomenclatura de branch com chave do Jira, validacao de titulo e de conventional commit, portao de qualidade, code review por IA via OpenRouter, branch de promocao, vinculo com o Jira, movimentacao automatica do card no merge, tag de release calculada por semver e ruleset de protecao. Use quando pedirem para levar o fluxo, a CI ou o review por IA para um projeto ou organizacao nova, por exemplo: 'leva esse mesmo fluxo pro projeto X', 'quero o review por IA nos repos da org Y', 'padroniza o desenvolvimento desses repositorios'."
---

# Padronizar o fluxo de desenvolvimento numa organizacao

A logica de CI nao e copiada repositorio a repositorio. Ela vive num repositorio central
por organizacao, `<org>/ci-workflows`, e cada repositorio recebe tres arquivos finos que
chamam de la. A referencia implantada hoje e `credsolaris/ci-workflows`, e a copia para
outra organizacao sai de `scripts/clonar-para-org.sh`.

## O fluxo que se esta instalando

```
main ──► CHAVE-123/main/pessoa/assunto          trabalho, sem pull request
            │
            ├──► CHAVE-123/develop/pessoa/assunto  + merge de develop ──► PR ──► dev
            │
            └──► CHAVE-123/staging/pessoa/assunto  + merge de staging ──► PR ──► hlg

main ◄── PR de fechamento ──► tag 1.x.y ──► prd
```

No merge, duas coisas acontecem sozinhas: o **card muda de coluna** conforme a branch de
destino, e o merge na `main` **gera a tag**. O incremento vem do tipo do card no Jira, Bug
sobe o patch e o resto sobe o minor; sem credencial do Jira, cai no conventional commit.

A branch de promocao sai sempre da branch de trabalho, nunca de outra promocao. O segmento
de base do nome tem que bater com a branch de destino do pull request, e a CI recusa quando
nao bate.

## O que entra em cada repositorio

Tres arquivos finos, que so chamam o repositorio central:

| Arquivo no repo | Gatilho | O que faz |
|---|---|---|
| `padroes.yml` | pull request aberto, reaberto, editado ou atualizado | nome da branch, titulo, conventional commit e escreve `Related to <CHAVE>` com link |
| `pr.yml` | pull request aberto, reaberto ou atualizado | portao de qualidade e review por IA |
| `mover-card.yml` | pull request **fechado com merge** | move o card no Jira conforme a branch de destino |
| `promocao.yml` | `workflow_dispatch` | cria a branch de promocao e entrega o pull request |
| `release.yml` | push na `main` | calcula a proxima versao e cria a tag |

**Cada um desses arquivos precisa existir na branch de onde o gatilho dispara.** Soa obvio
e e o erro mais caro desta lista: `release.yml` so na `develop` nunca gera tag, porque ele
dispara em push na `main`. Para `pull_request`, o GitHub monta o workflow a partir do
commit de merge, entao basta estar na base **ou** na origem; para `push`, tem que estar
na branch empurrada.

## 1. Levantar antes de prometer

Nunca comece distribuindo. Levante e **relate o que estiver fora do esperado**:

| O que | Como | Por que importa |
|---|---|---|
| Papel na organizacao | `gh api orgs/<org>/memberships/<usuario>` | sem admin nos repos nao da para criar ruleset |
| Branches de cada repo | `gh api repos/<org>/<repo>/branches` | falta de `staging` ou de `develop` muda o desenho |
| Divergencia entre as branches | `gh api repos/<org>/<repo>/compare/main...develop` | **main parada e o caso mais comum**: branch de trabalho nasceria vazia |
| Workflows existentes | `gh api repos/<org>/<repo>/contents/.github/workflows` | define se ha deploy para proteger e onde o `validar-tag` se liga |
| Gatilhos do deploy | ler o `on:` de cada workflow de deploy | diz quais merges vao disparar deploy e para qual ambiente |
| Gerenciador e scripts | `package.json` e lockfile | o portao pula script que nao existe, mas e melhor saber antes |
| Time com escrita | `gh api orgs/<org>/teams/<slug>/repos` | time sem push faz o GitHub ignorar o `CODEOWNERS` |
| Secret do OpenRouter | `gh api repos/<org>/<repo>/actions/secrets` e `.../organization-secrets` | pode estar no repo em vez da org; os dois funcionam |
| Chave e site do Jira | perguntar, e confirmar em `/rest/api/3/project/search` | a chave entra na validacao de branch e de titulo |
| **Plano da organizacao** | `gh api orgs/<org> --jq .plan.name` | **plano Free nao tem ruleset nem protecao de branch em repositorio privado**: a CI roda e reporta, mas nada bloqueia merge nem push direto. Diga isso antes de prometer protecao |

## 2. Alinhar as branches antes de instalar

Se a `main` estiver atras da `develop` e nao houver nada em producao, alinhe as tres no
mesmo commit antes de instalar. Use a API, que recusa o que nao for fast-forward:

```bash
SHA=$(gh api repos/<org>/<repo>/git/ref/heads/develop --jq .object.sha)
gh api -X PATCH repos/<org>/<repo>/git/refs/heads/main -f sha=$SHA -F force=false
gh api -X POST repos/<org>/<repo>/git/refs -f ref=refs/heads/staging -f sha=$SHA
```

Se houver algo em producao, **pergunte**: alinhar a `main` ali e publicar.

## 3. Criar o repositorio central da organizacao

O GitHub so compartilha workflow reutilizavel privado **dentro da mesma organizacao**. Nao
existe chamar `orgA/ci-workflows` de um repo da `orgB`.

```bash
/caminho/para/ci-workflows/scripts/clonar-para-org.sh <org> <destino>
```

Ele imprime os comandos seguintes. O que nao pode faltar depois do push:

```bash
gh api -X PUT repos/<org>/ci-workflows/actions/permissions/access -f access_level=organization
```

Sem isso, todo run morre em `startup_failure` sem log.

## 4. Distribuir

Tudo que varia por organizacao sai por variavel de ambiente:

```bash
export ORG=<org> TIME=<slug-do-time> \
       CHAVES_JIRA='<CHAVE>' URL_JIRA='https://<site>.atlassian.net/browse' \
       NODE_REPOS='<repo> <repo>' TF_REPOS='' MANIFESTO_REPOS='' \
       DONO_FALLBACK='@<usuario>'
ci-workflows/scripts/distribuir.sh <raiz-dos-clones> <CHAVE-N> <pessoa>
```

`DRY_RUN=1` mostra o que faria. O script e idempotente: reaproveita branch e pull request
que ja existam.

## 5. Mergear, depois proteger

Protecao de branch exige plano Team ou Pro na organizacao. Em plano Free o script avisa e
segue: o fluxo todo funciona, menos o bloqueio.

O ruleset exige status check que precisa existir no repositorio, e so passa a existir
depois do primeiro merge. Proteger antes trava todos os pull requests.

Sao **dois rulesets**, porque o risco nao e o mesmo:

| Ruleset | Branches | Aprovacao | Code owner |
|---|---|---|---|
| Protecao da develop | `develop` | nenhuma, a pessoa mergeia o proprio | nao |
| Protecao das branches de entrega | `staging`, `main` | 1 | sim |

Exigir revisor em `develop` trava o time sem ganho: dali sai so o ambiente de dev. Em
`staging` e `main` a aprovacao fica, porque dali saem homologacao e producao.

```bash
ORG=<org> REPOS_PADRAO='<repo> <repo>' ci-workflows/scripts/proteger-branches.sh
```

## Armadilhas que ja custaram caro

Sao dezessete, e cada uma custou pelo menos um ciclo de push e espera.

1. **`default_workflow_permissions: read` na organizacao.** Workflow reutilizavel que pede
   `pull-requests: write` derruba o run em `startup_failure`, **sem log nenhum**. O job que
   chama precisa declarar `permissions:` ele mesmo. Confira com
   `gh api repos/<org>/<repo>/actions/permissions/workflow`.
2. **`hashFiles()` dentro de `if:` de step devolve vazio** e o step e pulado em silencio.
   Detecte arquivo em bash e use output de step.
3. **Job pulado por `if` conta como sucesso** em status check obrigatorio. Nunca coloque no
   mesmo workflow um check obrigatorio e um job condicional: editar o titulo depois de um
   build vermelho deixaria o check verde no mesmo commit.
4. **Check obrigatorio que nao roda fica pendente para sempre.** Para `pull_request`, o
   GitHub usa os workflows do merge commit. Se a branch de origem nao tiver o `pr.yml`, o
   check nunca reporta e o merge trava. Por isso a `main` precisa receber a CI.
5. **`CODEOWNERS` com dono unico trava o repositorio**: com `require_code_owner_review`, o
   pull request do proprio dono nao tem quem aprove. Sempre mais de um dono por caminho.
   Time sem permissao de escrita e ignorado pelo GitHub, sem aviso.
6. **Repo privado nao deixa `actions/checkout` buscar outro repo** com o token padrao. Por
   isso o script do review e composite action, que o GitHub compartilha dentro da org.
7. **O modelo corta a resposta** se o raciocinio comer o orcamento de token. O Sonnet 5.5
   recusa `reasoning` desligado com 400: use `effort: low`.
8. **Nunca sobrescreva a identidade do git** com `-c user.email`. Commite com a config do
   repositorio e confira com `git log -1 --format='%an <%ae>'` antes de pushar.
9. **`continue-on-error: true` esconde a falha na API.** O passo que falha volta com
   `conclusion: success`, e so o campo `outcome` (que a API REST de jobs nao expoe) diz a
   verdade. Nao conclua que a base esta verde lendo `conclusion` de portao informativo:
   ligue o bloqueio num repositorio de teste, ou leia o log.
10. **`npx --yes tsc` e `pnpm dlx tsc` baixam um pacote homonimo do registro**, que nao e o
   compilador e sai com erro dizendo isso. Rode sempre `./node_modules/.bin/tsc`, o
   compilador que o proprio projeto instalou, e avise em vez de falhar quando o repositorio
   tem `tsconfig.json` mas nao tem `typescript` nas dependencias.
11. **Re-executar um run nao atualiza o workflow reutilizavel.** O GitHub fixa a versao
   resolvida na primeira tentativa, entao corrigir o `@v1` e mandar re-run roda o codigo
   antigo. Force um evento novo: um commit, ou fechar e reabrir o pull request.
12. **`${VAR:-padrao}` trata string vazia como ausente.** Passar `TF_REPOS=''` para dizer
   "nenhum" cai no padrao e o script vai mexer em repositorio que nao existe naquela
   organizacao. Use `${VAR-padrao}`, sem os dois pontos.
13. **`sed` com delimitador `|` quebra quando o valor tem `|`.** A alternativa de chaves do
   Jira e literalmente `CN|SMS|SOL|REN`. Use `#` como delimitador.
14. **Casamento guloso de regex pega o campo errado em JSON aninhado.** Lendo o status de
   volta com `sed`, o `name` que casava era o de `statusCategory`, nao o de `status`: o
   card ia para "Em teste" e o log dizia "Em andamento". Use `jq` para ler campo de JSON,
   nunca `sed`.
15. **Substituicao de texto que nao casa falha calada.** Em script de geracao, sempre
   `assert` que o trecho casou antes de escrever. Um `release.yml` inteiro deixou de ser
   distribuido por causa disso, e so apareceu conferindo os arquivos depois.
16. **Teste que indexa passo por posicao quebra ao inserir passo.** Busque pelo nome.
17. **Filtro de caminho nao vale para push de tag**, entao `paths-ignore` num workflow que
   tambem dispara em tag nao quebra o deploy de producao. Esta na documentacao do GitHub.

## O que depende de gente, e nao de script

- **`OPEN_ROUTER_APIKEY`**, no repositorio ou na organizacao. Nunca crie credencial: peca.
- **GitHub for Jira**, para o painel de desenvolvimento do card. Precisa de **admin do site
  Jira**, nao de admin de projeto. Confira quem e com
  `/rest/api/3/group/member?groupname=site-admins`.
- **A credencial de CI: use GitHub App, nao PAT.** Sem ela o workflow de promocao devolve
  o link em vez de abrir o pull request, e a tag nasce sem disparar o deploy, porque o que
  o token padrao do GitHub cria **nao aciona outro workflow**.

  PAT falha de um jeito que engana: o erro e `Could not resolve to a Repository`, que
  parece permissao e e **visibilidade**. Classico sem escopo `repo` nao ve repositorio
  privado; fine-grained sem concessao a organizacao nao ve nada. Confira em
  `https://github.com/organizations/<org>/settings/personal-access-tokens/active`: se
  disser que nao ha nenhum, o token nao chega nos repositorios.

  O app resolve os tres problemas de uma vez: nao expira, nao pertence a ninguem, e o
  token e gerado por execucao e vive uma hora. Permissoes de repositorio: `Contents`
  leitura e escrita, `Pull requests` leitura e escrita, `Workflows` leitura e escrita.
  Secrets: `CI_APP_ID` e `CI_APP_PRIVATE_KEY`, e o workflow usa
  `actions/create-github-app-token`.

## Adotar sem travar o time

Na primeira leva, so o `build` bloqueia. Lint, tipos, teste e cobertura entram informando,
porque a base costuma comecar vermelha. Cada portao passa a bloquear quando a base daquele
repositorio ficar verde, repositorio por repositorio.
