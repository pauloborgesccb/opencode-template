# Instrumentar aplicação Node/NestJS e Next.js

Trabalho por repositório. São quatro arquivos por backend, e a ordem importa pouco, mas a verificação no fim importa muito: só o dado chegando no ClickHouse prova que funcionou.

## 1. `src/tracer.js`

Copie `assets/tracer.js` e troque `<APP>` pelo nome do serviço. Ele monta trace, log e métrica num `NodeSDK`, normaliza o endpoint e registra três gauges de heap do V8.

Pontos do arquivo que não são decoração:

- **Normalização do endpoint.** Corta `/v1/<sinal>` e barra no fim. Existe porque o manifesto errado é o erro mais comum, e aqui ele deixa de importar.
- **`PeriodicExportingMetricReader` a cada 60s.** Métrica de runtime não precisa de resolução maior, e intervalo curto multiplica série à toa.
- **Gauges de heap.** `nodejs.v8.heap.used_bytes`, `nodejs.v8.heap.limit_bytes` e `nodejs.v8.heap.usage_ratio`. O `heap_size_limit` do V8 reflete o `--max-old-space-size`, então o ratio já nasce comparável entre ambientes de tamanhos diferentes. É a série que antecipa `JavaScript heap out of memory`.
- **`SIGTERM`** fecha SDK e logger antes de sair, para não perder o último lote.

As dependências (`@opentelemetry/sdk-node`, `auto-instrumentations-node`, os três exporters OTLP, `sdk-logs`, `sdk-metrics`, `resources`, `semantic-conventions`) precisam estar em `dependencies`, não em `devDependencies`: a imagem de produção instala só as primeiras.

## 2. `Dockerfile`

```dockerfile
CMD ["node", "--require", "./src/tracer.js", "dist/main"]
```

Em build multi-stage, garanta que o arquivo exista no estágio final:

```dockerfile
COPY --from=builder /usr/src/app/src/tracer.js ./tracer.js
CMD ["node", "--require", "./tracer.js", "dist/main"]
```

Duas checagens que já pegaram erro:

- `nest build` com `tsc` **não copia `.js`** para `dist/` sem `allowJs` ou entrada em `nest-cli.json > compilerOptions.assets`. Um `CMD` apontando para `./dist/tracer.js` que não existe derruba o container no boot.
- Não fixe `--max-old-space-size` aqui. A imagem é a mesma em dev, hlg e prd, e o limit do pod não é.

## 3. Deployment

```yaml
env:
  - name: OTEL_SERVICE_NAME
    value: "${APP_NAME}"
  # Endpoint base, sem /v1/<sinal>: o SDK concatena o caminho de cada sinal.
  - name: OTEL_EXPORTER_OTLP_ENDPOINT
    value: "http://signoz-otel-collector.observability.svc.cluster.local:4318"
  - name: OTEL_EXPORTER_OTLP_PROTOCOL
    value: "http/protobuf"
  - name: OTEL_RESOURCE_ATTRIBUTES
    value: "k8s.namespace.name=${APP_NAMESPACE},deployment.environment=${APP_NAMESPACE}"
  - name: NODE_OPTIONS
    value: "--max-old-space-size=${NODE_MAX_OLD_SPACE}"
resources:
  requests:
    memory: ${CONTAINER_MEMORY}
    cpu: ${CONTAINER_CPU}
  limits:
    memory: ${CONTAINER_MEMORY_LIMIT}
    cpu: ${CONTAINER_CPU_LIMIT}
```

`deployment.environment` tem de ser o ambiente de verdade. Um `prod` fixo no template faz dev e hlg aparecerem como produção na tela, e a primeira investigação em cima disso custa caro.

`limits` precisa estar no manifesto. Limite aplicado por `kubectl patch` sobrevive até o próximo deploy e some sem avisar.

Heap em 66% a 70% do limit:

| limit do pod | `NODE_MAX_OLD_SPACE` |
|---|---|
| 768Mi | 512 |
| 1536Mi | 1024 |
| 3Gi | 2048 |
| 4000Mi | 2816 |

Se a aplicação usa Puppeteer, lembre que o Chromium é processo separado dentro do mesmo limit: deixe a folga maior.

## 4. Frontend Next.js

`@vercel/otel` em `src/instrumentation.ts`, com dois filtros no exportador:

- **cardinalidade**: descarte os spans internos de render (`resolve page components`, `resolve segment modules`, `build component tree`, `start response`, `generateMetadata`). Podem ser dois terços do volume. Mantenha os spans de `fetch` sem rota, que ligam o trace do front ao do backend.
- **dado sensível**: se alguma rota pública carrega código ou token na URL, filtre antes de exportar. Telemetria sai do cluster na cabeça de quem a lê.

O SDK do front já trata o sufixo do endpoint (`endpoint.endsWith('/v1/traces')`), o que explica o caso clássico de "o front aparece no SigNoz e o backend não".

## Verificar

Pelo ClickHouse, 10 minutos após o deploy:

```sql
SELECT serviceName, count() FROM signoz_traces.distributed_signoz_index_v3
WHERE timestamp > now() - INTERVAL 10 MINUTE GROUP BY serviceName;
```

```sql
SELECT JSONExtractString(ts.labels,'service.name') svc,
       round(max(if(s.metric_name='nodejs.v8.heap.limit_bytes', s.value, 0))/1024/1024) teto_mb,
       round(max(if(s.metric_name='nodejs.v8.heap.usage_ratio', s.value, 0)), 2) razao
FROM signoz_metrics.distributed_samples_v4 s
INNER JOIN signoz_metrics.distributed_time_series_v4 ts ON s.fingerprint = ts.fingerprint
WHERE s.unix_milli > toUnixTimestamp64Milli(now64() - INTERVAL 10 MINUTE)
  AND s.metric_name LIKE 'nodejs.v8.heap%'
GROUP BY svc;
```

O `teto_mb` tem de bater com o `NODE_OPTIONS` daquele ambiente (a diferença de algumas dezenas de MB é o resto dos espaços do V8). Se não bater, o `NODE_OPTIONS` não chegou no processo.
