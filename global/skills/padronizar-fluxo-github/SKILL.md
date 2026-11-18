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
| **Se o fluxo ja esta instalado** | `gh api repos/<org>/<repo>/contents/.github/workflows` e `gh api repos/<org>/<repo>/rulesets` | **confira antes de aceitar o pedido como esta escrito.** Quem pede "instale o fluxo" pode estar com informacao de semanas atras: numa organizacao o fluxo ja estava inteiro, com os dois rulesets, tag saindo e card andando, e o pedido dizia "comeca do zero, sem deploy nenhum". Levantar primeiro trocou a tarefa de instalar para corrigir dois furos. Relate a diferenca antes de mexer |
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

| Ruleset | Branches | Aprovacao | Code owner | Thread resolvida |
|---|---|---|---|---|
| Protecao da develop | `develop` | nenhuma, a pessoa mergeia o proprio | nao | sim |
| Protecao das branches de entrega | `staging`, `main` | 1 | sim | sim |

Exigir revisor em `develop` trava o time sem ganho: dali sai so o ambiente de dev. Em
`staging` e `main` a aprovacao fica, porque dali saem homologacao e producao.

### Quem pode aprovar entrega

O ruleset diz **quantas** aprovacoes, o `CODEOWNERS` diz **de quem**. E e o `CODEOWNERS`
que erra calado.

`CODEOWNERS` nao sabe de branch: ele vale para o repositorio inteiro. O que separa os
ambientes e o ruleset, que exige `require_code_owner_review` so em `staging` e `main`.
Entao restringir dono nao atrapalha a `develop`, onde ninguem precisa aprovar.

**Nao aponte o `*` para um time.** Com dono de time, o GitHub aceita a aprovacao de
qualquer membro, e um developer passa a liberar homologacao e producao igual a quem
responde por elas. Nomeie as pessoas:

```bash
APROVADORES="@pessoa1 @pessoa2 @pessoa3" scripts/distribuir.sh ...
```

Tres nomes, nao dois e nunca um, e por um motivo que nao e estetico: **o GitHub nunca
aceita que o autor aprove o proprio pull request**, nem quando ele e dono do codigo. Com
dois donos, o pull request de um depende sempre da mesma pessoa; com um, ninguem aprova e
o repositorio trava. Antes de prometer a lista, confirme que cada nome tem escrita no
repositorio: quem nao tem e ignorado pelo GitHub, sem aviso.

Confira com `DRY_RUN=1`, que imprime o dono que iria para o arquivo, e leia de volta
depois de aplicar:

```bash
gh api repos/<org>/<repo>/contents/.github/CODEOWNERS --jq '.content' | base64 -d
```

`required_review_thread_resolution` fica **ligado nos dois**, inclusive na `develop`. Nao
confunda com dar veto a IA: o veredito dela continua sem bloquear nada, o que nao pode e
ignorar o apontamento em silencio. Isso so e sustentavel porque o review apaga as proprias
threads sem resposta a cada push: thread que voce resolveu ou respondeu sobrevive e nao
volta, e a que virou obsoleta some sozinha. Sem essa limpeza, cada push acumularia threads
velhas para resolver na mao antes de mergear.

```bash
ORG=<org> REPOS_PADRAO='<repo> <repo>' ci-workflows/scripts/proteger-branches.sh
```

## Armadilhas que ja custaram caro

Sao vinte e sete, e cada uma custou pelo menos um ciclo de push e espera.

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

18. **O ruleset so cobre a branch que voce listou, e repo sem a CI detectada fica com
    check a menos.** O `proteger-branches.sh` monta a lista de checks lendo o `pr.yml` do
    clone local: se o working tree estiver em outra branch na hora, ele nao ve o portao de
    qualidade e cria o ruleset sem exigi-lo. O workflow roda, mas nao bloqueia, e da para
    mergear com build vermelho sem perceber. Confira depois com
    `gh api repos/<org>/<repo>/rulesets/<id> --jq '[.rules[]|select(.type=="required_status_checks")|.parameters.required_status_checks[].context]'`
    e compare a contagem entre os repositorios: um com menos check que os outros e o sinal.

19. **`CODEOWNERS` apontando para time deixa qualquer membro liberar producao.** Nao e o
    ruleset que esta errado, e o dono. Com `require_code_owner_review` e `* @org/time`, a
    aprovacao de qualquer um dos membros conta, developer incluido. O sintoma e nenhum: o
    merge acontece e parece correto. Veja "Quem pode aprovar entrega".

20. **O autor nunca aprova o proprio pull request.** Quem abriu fica com `REVIEW_REQUIRED`
    para sempre e, sendo a unica pessoa dona, so sai por bypass de admin. Isso confunde
    porque a mensagem do GitHub fala de "code owner review", e quem le entende que falta um
    dono, quando o que falta e **outro** dono. Confira o autor antes de procurar erro de
    regra: `gh pr view <n> --json author`.

21. **Correcao pedida no review de uma promocao tem que ir na branch de trabalho.** Ela e a
    fonte das tres promocoes. Commitando direto na promocao, a branch de trabalho fica
    atrasada em silencio e a promocao seguinte sobe incompleta, com todos os checks verdes,
    porque o portao de qualidade avalia o que esta ali, nao o que deveria estar. Aconteceu
    duas vezes num mesmo PR: a de hlg nasceria com 1 de 15 commits. Antes de abrir cada
    promocao, compare: `git diff <promocao-anterior> -- <arquivos tocados> --stat` tem que
    vir vazio.

22. **O review por IA reescreve as proprias threads a cada push.** Responder uma rodada
    depois de empurrar a correcao devolve `Parent comment not found`, porque o comentario
    deixou de existir. Em PR que vai e volta, publique o fechamento como comentario de
    issue (`gh api repos/<org>/<repo>/issues/<n>/comments`), que nao e apagado, e deixe as
    threads so para o que ainda esta vivo. A descricao do PR tambem entra no prompt do
    review: justificativa acumulada a cada rodada infla o custo e chega a estourar credito.

23. **`dismiss_stale_reviews_on_push: true` mata a aprovacao no push seguinte.** Combinado
    com o autor nao poder se aprovar, isso cria uma ordem obrigatoria: aprovar e mergear,
    sem nenhum commit no meio. Um push de ajuste de comentario derruba a aprovacao e manda
    pedir de novo.

24. **Falha de billing se disfarca de falha de codigo.** Dois casos no mesmo dia. Actions
    recusando iniciar job: todos os checks vermelhos em 2s, **zero steps**, log inexistente
    (`BlobNotFound`) e a unica pista na annotation do check run, dizendo que o pagamento
    falhou ou o teto de gasto foi atingido. E a IA do review sem saldo: 402 do OpenRouter,
    `weight_exceeds_budget`, que deixa so aquele check vermelho. O que distingue os dois e
    simples: se o check de validacao de **nome de branch** tambem caiu, nao e a IA, porque
    ele nao chama modelo nenhum. Leia a annotation antes de procurar erro no diff:
    `gh api repos/<org>/<repo>/check-runs/<id>/annotations --jq '.[].message'`

25. **`http.extraheader` do `actions/checkout` vence a credencial da URL do `origin`.**
    O workflow que cria a tag reescreve o `origin` com o token do App e empurra. Nao
    funciona: o `actions/checkout` gravou `http.https://github.com/.extraheader` com o
    `GITHUB_TOKEN`, e esse header tem prioridade sobre a credencial da URL. O push sai como
    `github-actions[bot]`, e push com o token padrao **nao aciona outro workflow**, entao a
    tag nasce e o deploy de producao nao dispara. O sintoma engana porque a tag aparece
    certa: so o deploy falta. Remova o header antes do push:

    ```bash
    git config --unset-all "http.https://github.com/.extraheader"
    ```

    Confira de quem saiu a tag com
    `gh api repos/<org>/<repo>/git/refs/tags/<tag> --jq .object.sha` e o autor do push nos
    eventos do repositorio. Aconteceu na TGB-Digital porque o `@v1` dela estava numa versao
    anterior a correcao que a outra organizacao ja tinha: **`@v1` de organizacoes diferentes
    nao andam juntos**, e mover a tag numa nao move na outra.

26. **Rodar o `distribuir.sh` de novo afrouxa o portao que voce ja endureceu.** Ele nao
    costura so o `CODEOWNERS`: regrava o `pr.yml` inteiro a partir dos modelos, com os
    valores das variaveis **daquela execucao**. Como `PORTOES_BLOQUEIAM` tem padrao
    `false`, redistribuir num repositorio onde lint e tipos ja bloqueavam devolve os dois
    para informativo, em silencio, e o build vermelho volta a passar. O mesmo vale para
    `CHAVES_JIRA`, `STATUS_*` e `cobertura_minima`: o que voce nao passar volta ao padrao.

    Em repositorio ja instalado, redistribuir e a excecao, nao a regra. Para mudar so uma
    peca, gere so aquela peca com a mesma logica do script, e confira o diff antes de
    commitar: `git diff --stat` tem que mostrar apenas o arquivo que voce quis mudar. Se
    for redistribuir mesmo, leia primeiro o `pr.yml` que esta no repositorio e passe todas
    as variaveis que reproduzem o estado atual.

27. **Branch espelhada transforma a protecao de entrega em enfeite.** Onde o produto ainda
    nao tem hlg e prd, o `espelhar-ambientes.yml` leva a `develop` para `staging` e `main`
    por fast-forward depois do deploy verde em dev. Enquanto ele existir no repositorio,
    tudo que entra na `develop`, que nao exige aprovacao nenhuma, chega sozinho nas duas
    branches de entrega: o `CODEOWNERS` e a exigencia de 1 aprovacao passam a valer so
    para quem abrir pull request direto para elas. Nao e descuido, e o preco de ter as
    tres branches antes dos ambientes, e o proprio arquivo diz isso no cabecalho.

    Junto com ele vem a guarda `vars.PUBLICAR_HLG` e `vars.PUBLICAR_PRD` nos jobs de
    deploy: sem a **variavel** de Actions criada (nao o secret), todo run de `staging` e de
    tag aparece como `skipped`. Ao levantar, confira
    `gh api repos/<org>/<repo>/actions/variables`: variavel vazia com job `skipped` nao e
    defeito, e ambiente que ainda nao existe. E diga ao time, porque "protegido" ali quer
    dizer outra coisa: a protecao de entrega so morde quando o espelho sair.

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
