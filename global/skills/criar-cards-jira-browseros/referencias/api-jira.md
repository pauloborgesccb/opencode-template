# API do Jira Cloud pelo BrowserOS

Todas as chamadas saem de dentro de uma aba já autenticada no site do Jira. Abra uma aba leve e estável para servir de base:

```
browser.open('https://<site>.atlassian.net/rest/api/3/myself')
```

Use `page.cdp('Runtime.evaluate', JSON.stringify({expression, awaitPromise:true, returnByValue:true}))`. O retorno vem em `r.result.result.value`, e pode vir `undefined` em erro: sempre proteja a leitura.

## Levantamento

| O que | Endpoint |
|---|---|
| Projeto, tipos de issue, componentes | `GET /rest/api/3/project/<KEY>` |
| Campos obrigatórios do tipo | `GET /rest/api/3/issue/createmeta/<KEY>/issuetypes/<typeId>` |
| Permissões | `GET /rest/api/3/mypermissions?projectKey=<KEY>&permissions=CREATE_ISSUES,ASSIGN_ISSUES,EDIT_ISSUES,ADMINISTER_PROJECTS` |
| Quem sou eu | `GET /rest/api/3/myself` |
| Achar usuário | `GET /rest/api/3/user/search?query=<nome>` |
| Prioridades | `GET /rest/api/3/priority` |
| Campos customizados | `GET /rest/api/3/field` |
| Status por tipo | `GET /rest/api/3/project/<KEY>/statuses` |
| Config do board | `GET /rest/agile/1.0/board/<ID>/configuration` |
| Backlog do board | `GET /rest/agile/1.0/board/<ID>/backlog` |
| Painel de épicos | `GET /rest/agile/1.0/board/<ID>/epic?maxResults=50&startAt=N` |
| Sprint ativa | `GET /rest/agile/1.0/board/<ID>/sprint?state=active` |
| Versões | `GET /rest/api/3/project/<KEY>/versions` |
| Info de desenvolvimento | `GET /rest/dev-status/1.0/issue/summary?issueId=<id>` |
| Listar projetos | `GET /rest/api/3/project/search?maxResults=50` |

## Criar

```js
POST /rest/api/3/issue
{
  "fields": {
    "project":   {"key": "CN"},
    "issuetype": {"id": "10000"},
    "summary":   "título",
    "description": <ADF>,
    "assignee":  {"accountId": "..."},
    "labels":    ["plataforma"],
    "priority":  {"id": "1"}
  }
}
```

201 devolve `{id, key, self}`. Prioridades padrão: `1 Highest`, `2 High`, `3 Medium`, `4 Low`, `5 Lowest`. Confirme pela API, podem ser renomeadas.

## Editar, ordenar, mover

```js
PUT  /rest/api/3/issue/<KEY>                 // 204; troca tipo, prioridade, campo customizado
PUT  /rest/agile/1.0/issue/rank              // {issues:[K], rankAfterIssue: anterior} ou rankBeforeIssue
POST /rest/agile/1.0/sprint/<ID>/issue       // {issues:[...]}, máx 50
POST /rest/api/3/bulk/issues/move            // ver abaixo
GET  /rest/api/3/task/<taskId>               // acompanha o move até COMPLETE
```

Move em lote entre projetos:

```js
{
  "sendBulkNotification": false,
  "targetToSourcesMapping": {
    "<KEY_DESTINO>,<issueTypeId>": {
      "inferClassificationDefaults": true,
      "inferFieldDefaults": true,
      "inferStatusDefaults": true,
      "inferSubtaskTypeDefault": true,
      "issueIdsOrKeys": ["AAA-1","AAA-2"],
      "targetClassification": [], "targetMandatoryFields": [], "targetStatus": []
    }
  }
}
```

Responde 201 com `taskId`. Acompanhe até `status: COMPLETE` e cheque `result.failedIssues`.

Para ordenar vários na sequência desejada, encadeie par a par:

```js
for (var i = 1; i < seq.length; i++)
  rank({issues:[seq[i]], rankAfterIssue: seq[i-1]});
```

## Conferir

```
GET /rest/api/3/search/jql?jql=<encoded>&maxResults=50&fields=summary,status,priority,assignee,labels,description
```

Use `ORDER BY Rank ASC` para ver a ordem real do board. O endpoint novo não devolve `total` confiável: conte `issues.length`.

## Armadilhas

- **ADF obrigatório** no campo `description` da API v3
- **Limite de payload** do `page.evaluate`: use CDP
- **`Rótulo Epic`** (`customfield_10011` em geral) em projeto classic: sem ele o épico fica em branco no painel do board
- **Épico não entra em sprint**, nem aparece em Sprints ativos
- **Converter épico em tarefa** remove a capacidade de ter filhos e descarta o rótulo de épico
- **Coluna do board** não é status: uma coluna agrupa vários status. Escolha o status olhando o `columnConfig`
- **403 em `/rest/atlassian-connect/1/addons`** é normal sem admin do site. Para saber se a integração com Git existe, use o `dev-status` de uma issue
