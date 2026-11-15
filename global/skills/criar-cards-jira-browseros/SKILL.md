---
name: criar-cards-jira-browseros
description: "Cria cards no Jira Cloud (épico, história, tarefa ou bug) usando o BrowserOS neo autenticado, com descrição formatada em ADF, responsável, label, prioridade e ordem no board. Levanta a configuração do projeto antes, apresenta a lista para aprovação e só então cria. Use quando pedirem para criar, mover, converter ou reordenar demandas no Jira, por exemplo: 'cria os cards no Jira', 'abre as demandas no board', 'move esses cards para o projeto X', 'coloca em ordem de prioridade'."
---

# Criar cards no Jira pelo BrowserOS

Criar e organizar issues no Jira Cloud pelo BrowserOS neo, que já está autenticado com a sessão do usuário. Nenhuma API token é necessária: as chamadas REST saem de dentro da página do Jira, com o cookie da sessão.

## Regra inegociável

**Nunca crie nada sem a aprovação explícita da lista.** Monte a proposta, mostre, espere o "pode criar". Criar card é ação visível para o time inteiro e não tem desfazer em massa.

## 1. Perguntar antes de qualquer coisa

Pergunte, e não assuma:

1. **Onde criar**: URL do board ou a key do projeto. Se o usuário mandar só a URL, extraia a key e o board id dela (`/projects/<KEY>/boards/<ID>`)
2. **Tipo de issue**: Epic, História, Tarefa, Bug, Melhoria
3. **Responsável**: nome; resolva o accountId pela API
4. **Escopo de cada card**: o conteúdo. Se vier de um documento ou de uma conversa, confirme o recorte: um card por tema ou um card por item
5. **Granularidade**: um card por épico com tudo dentro, ou épico mais tasks filhas. Isso muda o desenho inteiro
6. **Marcação**: label ou component, para separar do backlog existente
7. **Prioridade e ordem** no board

Se o usuário já respondeu algo em mensagens anteriores, não pergunte de novo.

## 2. Levantar a configuração do projeto, antes de propor

Sempre faça este levantamento e **relate o que faltar**. É o que evita card criado errado.

Veja `referencias/api-jira.md` para os endpoints. Cheque no mínimo:

- Tipos de issue disponíveis e seus ids (`/rest/api/3/project/<KEY>`)
- Campos obrigatórios do tipo escolhido (`/rest/api/3/issue/createmeta/<KEY>/issuetypes/<id>`)
- Permissões do usuário (`CREATE_ISSUES`, `ASSIGN_ISSUES`, `EDIT_ISSUES`)
- Status disponíveis e o mapeamento de colunas do board (`/rest/agile/1.0/board/<ID>/configuration`)
- Se o projeto é `classic` (company-managed) ou `next-gen`, porque muda o campo de épico
- Versões e componentes existentes, se o pedido depender deles
- Se há integração de desenvolvimento ativa, quando o pedido envolver branch, PR ou deploy no card (`/rest/dev-status/1.0/issue/summary?issueId=<id>`)

## 3. Apresentar para aprovação

Liste: título, tipo, prioridade, responsável, label e um resumo do escopo de cada card. Aponte o que você decidiu por conta própria e o que ainda depende do usuário. Espere o aceite.

## 4. Criar

Siga `referencias/api-jira.md`. Pontos que quebram se forem ignorados:

- **Descrição é ADF**, não texto nem markdown. Use `scripts/md-para-adf.js`
- **Payloads grandes não passam por `page.evaluate`**: argumento e retorno são truncados por volta de 5 KB, e o estado em `window` não persiste entre chamadas. Use `page.cdp('Runtime.evaluate', ...)`, que roda no mundo principal e mantém o estado
- **Ordem no board é rank**, não é o campo prioridade. Crie e depois encadeie com `rankAfterIssue`
- **Board scrum**: épico não aparece em Sprints ativos, só no painel de épicos do Backlog
- **Projeto classic**: épico sem o campo `Rótulo Epic` preenchido aparece em branco no painel. Descubra o id do campo em `/rest/api/3/field`, costuma ser `customfield_10011`

## 5. Conferir e relatar

Depois de criar, consulte de volta por JQL e confirme, item a item: key, tipo, status, prioridade, responsável, label e se a descrição tem conteúdo. Relate a lista com os links. Nunca diga que criou sem ter lido de volta.

## Operações além de criar

| Pedido | Como fazer |
|---|---|
| Mover entre projetos | `POST /rest/api/3/bulk/issues/move` e acompanhe a task. É move de verdade, preserva histórico. A key muda |
| Converter o tipo | `PUT /rest/api/3/issue/<KEY>` com `fields.issuetype`. Avise que épico convertido perde filhos e o rótulo de épico |
| Reordenar | `PUT /rest/agile/1.0/issue/rank` |
| Colocar na sprint | `POST /rest/agile/1.0/sprint/<ID>/issue`. **Avise o impacto**: entrar numa sprint em andamento distorce burndown e velocidade. Pergunte antes |
| Apagar | Só com confirmação explícita, dizendo que não tem volta |

## Transporte de conteúdo grande

Quando o texto dos cards vier de arquivo local e não couber no argumento:

1. Sirva o arquivo em `127.0.0.1` com um servidor HTTP temporário
2. Abra a URL local numa aba do BrowserOS e leia com `Runtime.evaluate` + `returnByValue`
3. Injete na aba do Jira com `window.__RAW = <json>` por `Runtime.evaluate`
4. Encerre o servidor ao terminar

Não tente `fetch` de `127.0.0.1` de dentro da página do Jira: fica pendurado por restrição de rede privada.

## Erros já vistos, não repita

- `page.evaluate` devolvendo `undefined` para string grande: use CDP
- `window.__X` sumindo entre chamadas de `page.evaluate`: mundo isolado, use CDP
- Épico criado sem `Rótulo Epic`: some do painel do board classic
- Buscar o card em Sprints ativos quando ele é épico: ele nunca estará lá
- Sessão do BrowserOS trocando de id no meio do trabalho: refaça `tabs list` e pegue as páginas com `ownership: mine`
