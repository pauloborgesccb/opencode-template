# Backend Java (Spring Boot e legado)

O caminho em Java é mais barato que nas outras linguagens: o agente faz tudo sem uma linha de código. Isso vale muito em sistema legado, onde ninguém quer mexer e às vezes nem há quem conheça o código.

## O agente

Baixe `opentelemetry-javaagent.jar` (release do `opentelemetry-java-instrumentation`) e carregue antes da aplicação:

```dockerfile
ADD https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v<VERSAO>/opentelemetry-javaagent.jar /otel/javaagent.jar
ENTRYPOINT ["java", "-javaagent:/otel/javaagent.jar", "-jar", "/app/app.jar"]
```

Fixe a versão. `latest` num `ADD` de Dockerfile é mudança silenciosa de comportamento no próximo build.

Se não der para mexer no Dockerfile, `JAVA_TOOL_OPTIONS=-javaagent:/otel/javaagent.jar` por variável de ambiente também funciona, desde que o jar chegue ao container por volume ou init container.

## Variáveis

```yaml
env:
  - name: OTEL_SERVICE_NAME
    value: "<nome-do-servico>"
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://<collector>:4318"     # base, sem /v1/<sinal>
  - name: OTEL_EXPORTER_OTLP_PROTOCOL
    value: "http/protobuf"
  - name: OTEL_RESOURCE_ATTRIBUTES
    value: "deployment.environment=<ambiente>,k8s.namespace.name=<ns>"
  - name: OTEL_LOGS_EXPORTER
    value: "otlp"                        # sem isto, log não sai pelo agente
  - name: OTEL_METRICS_EXPORTER
    value: "otlp"
```

O agente instrumenta sozinho servlet, JDBC, JPA, HTTP client, Kafka, JMS e o cliente do RabbitMQ. Em projeto com Postgres, Redis e RabbitMQ, isso já cobre a maior parte das perguntas sem configuração extra.

## Memória, que é onde o Java morre

O equivalente ao `--max-old-space-size` do Node:

```
-XX:MaxRAMPercentage=70 -XX:InitialRAMPercentage=50
```

Percentual, não valor fixo: a mesma imagem roda em pods de tamanhos diferentes e a JVM lê o limit do cgroup. Sem isso, a JVM moderna assume 25% da memória visível, e em container com limit alto ela usa muito menos do que poderia; com `-Xmx` fixo acima do limit, o kernel mata com `exit 137`.

Métricas de JVM (`jvm.memory.used`, `jvm.gc.duration`, `jvm.threads.count`) vêm do agente sem configuração. Use `jvm.memory.used / jvm.memory.limit` como alerta, equivalente ao `usage_ratio` do Node.

## Log

Duas opções, e a escolha depende de quanto se pode mexer:

- **Nada no código**: o agente de node coleta o `stdout`. É o caminho do legado. Perde a correlação com trace, porque a linha não carrega `trace_id`.
- **Appender OTLP** (`OTEL_LOGS_EXPORTER=otlp` com Logback ou Log4j2 e o appender do OTel): o log sai com `trace_id` e a tela liga log e trace num clique. Vale quando a aplicação está em manutenção ativa.

Se o log for texto corrido com formato próprio, o parser de severidade fica no agente de node, não na aplicação. Veja `backend-node-nest.md`, a mecânica é a mesma.
