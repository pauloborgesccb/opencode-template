---
name: Observabilidade em cluster Rancher com SigNoz
description: Monta do zero, ou conserta, a observabilidade completa de um projeto em Kubernetes/Rancher: SigNoz com trace, log e métrica, agente OTel por node, estado do cluster, métricas de Postgres, Redis, RabbitMQ e Nginx, dashboards e alertas no Telegram. Serve para backend em Node/NestJS, Java ou Python e front Angular ou React atrás de Nginx. Use sempre que o pedido envolver observabilidade, SigNoz, OpenTelemetry, telemetria, APM, "não tenho log", "não sei por que caiu", trace distribuído, métrica de aplicação, dashboard de infraestrutura, alerta de queda, alerta de disco ou aviso no Telegram, e também quando a observabilidade já existir mas não mostrar nada, porque o motivo quase nunca é a ferramenta.
---

# Observabilidade em cluster Rancher com SigNoz

Padrão extraído de dois clusters em produção e escrito para ser reaproveitado em outros projetos, com outras linguagens. O que se repete entre projetos não é o código: é a topologia. Quase sempre existe um Postgres, um Redis, um RabbitMQ, um ou mais backends e um front servido por Nginx. Esta skill instrumenta essa topologia, não um sistema específico.

## Quando usar

Projeto novo que precisa de observabilidade, projeto que já tem e não entrega nada, ou replicar o padrão num cluster novo.

## O princípio

Um coletor no cluster, um endereço OTLP, e todo o resto pluga nele. Cada peça é independente: dá para subir só o agente de log hoje e instrumentar a aplicação daqui a um mês, sem refazer nada.

Duas convenções sustentam o conjunto, e quebrá-las custa caro depois:

- **`service.name`** identifica o processo, igual em trace, log e métrica. Sem isso, as três telas falam de coisas diferentes e não se cruzam.
- **`deployment.environment`** carrega o ambiente **real** (`dev`, `hlg`, `prd`). Um `prod` fixo no template faz dev aparecer como produção, e a primeira investigação em cima disso custa uma madrugada.

## As quatro camadas

| Camada | O que instala | Responde |
|---|---|---|
| Aplicação | SDK ou agente OTel no processo | o que essa requisição fez, e por quanto tempo |
| Serviços de apoio | receivers de Postgres, Redis, RabbitMQ, Nginx | a fila encheu, a conexão esgotou, o cache parou de acertar |
| Node e cluster | DaemonSet de log e métrica, coletor de estado | quem reiniciou, quem está sem réplica, quanto consome |
| Aviso | CronJob de watchdog, regras no SigNoz, relay Telegram | alguém é avisado sem olhar tela |

As quatro entregam valor sozinhas, mas a de aviso é a que transforma as outras em operação. Dado que ninguém olha é museu.

## Ordem de instalação

Cada passo valida o anterior. Pular um faz o seguinte parecer quebrado quando não está.

**1. Levantar o terreno.** `scripts/verificar.sh <kubeconfig>` diz se o SigNoz existe, em que versão, quanto de disco sobra, qual a retenção, quem já manda dado e que agentes existem. Rode antes de instalar e de novo depois de cada passo. Não presuma que falta tudo.

**2. Agente de node** (`assets/1-otel-agent.yaml`). Maior ganho por esforço: traz log de **todo** pod, inclusive banco, fila e aplicação legada, sem tocar em código. Comece com um namespace no `include`, meça volume e disco, depois abra.

**3. Estado do cluster** (`assets/2-otel-cluster-estado.yaml`). Réplica única de propósito: são séries do cluster inteiro e dois pods contariam dobrado.

**4. Serviços de apoio.** `references/infra-postgres-redis-rabbitmq.md`. Postgres, Redis, RabbitMQ e Nginx entram por receiver no coletor, com credencial de leitura. Nenhuma mudança nas aplicações.

**5. Aplicação.** Escolha o caminho pela linguagem:

| Stack | Caminho | Referência |
|---|---|---|
| Node/NestJS | `tracer.js` com `--require` | `references/backend-node-nest.md` |
| Java/Spring | `-javaagent`, sem tocar no código | `references/backend-java.md` |
| Python/FastAPI/Django | `opentelemetry-instrument` | `references/backend-python.md` |
| Angular/React + Nginx | log e métrica do Nginx; browser só se houver pergunta a responder | `references/frontend-nginx-spa.md` |

**6. Dashboards** (`references/dashboards.md`). Três prontos em `assets/signoz/`, construídos sobre métrica de cluster, não de aplicação, então servem em qualquer projeto.

**7. Alertas** (`references/alertas-e-telegram.md`). Watchdog por CronJob, regras no SigNoz e o relay que leva alerta do SigNoz ao Telegram.

## Armadilhas que custaram caro

Todas falham em silêncio: nada quebra, só não aparece. Vale ler antes.

**Endpoint OTLP com sufixo.** Se a variável termina em `/v1/traces` e o SDK concatena o caminho do sinal, o POST vai para `/v1/traces/v1/traces` e o collector devolve 404 sem reclamar em nível visível. O endpoint é a **base** (`http://<collector>:4318`). Em código próprio, normalize o valor recebido em vez de confiar no manifesto.

**Instrumentação que não é carregada.** SDK de OTel só instrumenta o que é carregado **antes** da aplicação: `--require` no Node, `-javaagent` no Java, `opentelemetry-instrument` no Python. Um `package.json` ou um `README` corretos não valem nada se o `CMD` do container ignora. Confirme no container que roda.

**Heap descasado do limit do pod.** Vale para toda runtime com heap gerenciado. No Node, sem `--max-old-space-size` o V8 trava em ~1,5GB e morre com `exit 139` mesmo com limit de 3Gi; com valor acima do limit, o kernel mata com `exit 137` antes do GC reagir. Na JVM é o mesmo problema com `-XX:MaxRAMPercentage`. Acerte em 66% a 70% do limit, por ambiente, via variável de ambiente, nunca fixo na imagem, que é a mesma para todos os ambientes.

**Memória de runtime não vem de graça.** Pacotes de auto-instrumentação costumam trazer HTTP e banco, e deixar runtime de fora. Confirme que existe série de heap antes de confiar que existe; se não houver, instrumente à mão (o `assets/tracer.js` mostra como, com três gauges lidos do V8).

**Severidade de log não se adivinha.** O agente entrega a linha, não o nível. Se a aplicação escreve em mais de um formato, é preciso um parser por formato, cada um com condição para só pegar a linha que é dele, e todos com `on_error: send`, para que linha que não casa passe mesmo assim. Sem a condição, o operador registra erro para cada linha que não casa e inunda o log do próprio agente.

**Nível de log que mente.** Antes de criar alerta em cima de `ERROR`, veja o que `ERROR` significa naquele sistema. Num caso real, 15 dos 29 `ERROR` de 15 minutos eram `401` de token expirado e o resto era regra de negócio negando proposta. Alertar nesse nível ensina a ignorar alerta.

**Memória do coletor.** Agente com limit de 256Mi mede 215Mi de RSS na primeira hora e vira OOMKill depois. Deixe 512Mi e fixe `GOMEMLIMIT` abaixo disso, para o GC do Go mirar um teto. Derrubar o processo que observa os outros é a falha mais inútil possível.

**Cardinalidade.** Span com id na URL, métrica com label por usuário e log com payload inteiro explodem a cardinalidade e o disco. Em SPA com Next.js, os spans internos de render podem ser dois terços do volume. Filtre no exportador, mas mantenha os spans de chamada HTTP de saída: são eles que ligam o trace do front ao do backend.

**Um pod pode engolir o cluster.** Num dos clusters, o cliente de linha de comando do MinIO gerou 117 mil linhas em 15 minutos, contra 800 do banco e 60 da aplicação. Depois de abrir a coleta, olhe o ranking por serviço e exclua o que não serve para nada.

**Page cache parece consumo.** `memory.current` de um banco inclui cache de arquivo, reclamável. Para dimensionar, leia `anon` em `memory.stat`. Um Postgres com 2,16GiB de `memory.current` tinha 8,5MB de memória anônima.

**Disco e retenção.** Log é o sinal que mais cresce. Antes de abrir para produção, confira espaço livre e retenção (no SigNoz, a coluna `_retention_days`, padrão 15 dias) e deixe o alerta de disco cobrindo o volume do banco de telemetria.

## Quando o pedido for "não está chegando nada"

Não reinstale. A ordem que resolve: `scripts/verificar.sh` diz se o dado chega ao armazenamento; as métricas internas do coletor (porta 8888, `otelcol_exporter_sent_*` e `otelcol_exporter_send_failed_*`) dizem se o agente manda e se o collector aceita. Com as duas medidas o problema fica entre "a aplicação não exporta", "o agente não lê" e "o collector não grava", e cada caso tem conserto diferente. `references/diagnostico.md` tem as consultas.

Detalhe que engana: agente recém-aplicado sobe lendo só linha nova. Entre o pod subir e o primeiro lote, a tela fica vazia e parece falha. Confira a contagem no armazenamento, não a tela.

## Trocar de ferramenta quase nunca é a resposta

Quando alguém diz que configurou observabilidade e não serve de nada, a causa costuma ser uma destas quatro: endpoint com sufixo duplicado, instrumentação nunca carregada, nenhum agente coletando `stdout`, ou dado chegando sem nenhum alerta. Nos quatro casos, trocar o backend de telemetria reproduz o mesmo silêncio com mais custo. Diagnostique primeiro.
