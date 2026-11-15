# Dashboards

Três dashboards prontos em `assets/signoz/`. Foram construídos sobre métrica de **cluster e container**, não de aplicação, por isso servem em qualquer projeto sem edição: um cluster novo com outros serviços preenche os mesmos gráficos.

| Arquivo | Responde |
|---|---|
| `dashboard-estado-do-cluster.json` | tem réplica faltando, algo reiniciou, ainda cabe pod |
| `dashboard-saude-dos-nodes.json` | o node aguenta, ou está saturando CPU, memória, disco ou rede |
| `dashboard-infra-cpu-memoria-disco.json` | quanto cada aplicação consome, para dimensionar e cortar desperdício |

## O que cada um mostra, e por quê

**Estado do cluster.** Desejado contra disponível por deployment: quando as linhas se separam, falta réplica, e isso aparece antes de o usuário reclamar. Reinícios de container como contador acumulado, onde o que importa é o degrau, não o valor. Node pronto e node sob pressão, esse último avisando **antes** de o kubelet começar a despejar pod. E reservado contra capacidade, de CPU e de memória: quando o reservado passa da capacidade, pod novo simplesmente não agenda, e o sintoma aparece no deploy, não no monitoramento.

**Saúde dos nodes.** CPU, memória usada e memória disponível por node, mais disco, page faults graves e erros de rede. Os dois últimos são os que ninguém olha e que dão o aviso mais cedo: page fault grave subindo é o node buscando memória no disco, sinal precoce de saturação; erro de rede diferente de zero já merece investigação.

**Infra por aplicação.** Memória e CPU por aplicação, working set, rede e disco do container. É o dashboard que se usa para dimensionar `requests` e `limits` com dado, em vez de chute, e para achar o pod que consome dez vezes mais que os outros.

## Importar num cluster novo

Pela tela: *Dashboards → + New dashboard → Import JSON*, colando o arquivo. É o caminho mais rápido para três arquivos.

Por API, quando forem muitos ou quando entrar em automação:

```bash
curl -X POST "https://<signoz>/api/v1/dashboards" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  --data @assets/signoz/dashboard-estado-do-cluster.json
```

O token sai de *Settings → API Keys* na própria instância.

## Exportar os que você criar

`scripts/exportar-signoz.sh <kubeconfig> <destino>` lê o banco interno do SigNoz e grava um JSON por dashboard e por regra de alerta. Serve para versionar no repositório de infraestrutura o que hoje só existe dentro do produto, e para levar de um cluster a outro.

Vale o hábito: dashboard e alerta criados na tela são configuração, e configuração que vive só no banco de uma ferramenta some junto com ela. O volume do SigNoz não entra em backup na maioria das instalações, justamente porque "é só telemetria" — mas o que se perde não é a telemetria, é o trabalho de desenhar os painéis.

## Antes de criar dashboard de aplicação

Os três acima não dependem de instrumentação. Painel de aplicação (latência por rota, taxa de erro, fila) só faz sentido depois que trace e métrica da aplicação estiverem chegando, e depois de confirmar que o nível de log e o status dos spans dizem a verdade. Dashboard bonito sobre dado que mente é pior que nenhum: ele dá confiança onde não deveria.
