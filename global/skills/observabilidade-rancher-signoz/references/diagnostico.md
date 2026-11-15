# Diagnóstico

A tela do SigNoz é a última coisa a consultar quando a dúvida é "está chegando?". Ela depende de janela de tempo, de filtro salvo e de cache; o ClickHouse responde direto. Todas as consultas abaixo rodam assim:

```bash
KUBECONFIG=<kubeconfig> kubectl exec -n observability chi-signoz-clickhouse-cluster-0-0-0 \
  -c clickhouse -- clickhouse-client -q "<SQL>"
```

`scripts/verificar.sh` roda as principais de uma vez.

## Quem está mandando o quê

```sql
-- trace
SELECT serviceName, count() spans, max(timestamp) ultimo
FROM signoz_traces.distributed_signoz_index_v3
WHERE timestamp > now() - INTERVAL 30 MINUTE GROUP BY serviceName ORDER BY spans DESC;

-- log
SELECT resources_string['service.name'] svc,
       resources_string['deployment.environment'] amb,
       if(severity_text='','(sem nivel)',severity_text) nivel, count()
FROM signoz_logs.distributed_logs_v2
WHERE timestamp > toUnixTimestamp64Nano(now64() - INTERVAL 30 MINUTE)
GROUP BY svc, amb, nivel ORDER BY 4 DESC;

-- metrica
SELECT metric_name, count() FROM signoz_metrics.distributed_samples_v4
WHERE unix_milli > toUnixTimestamp64Milli(now64() - INTERVAL 30 MINUTE)
  AND metric_name LIKE 'nodejs%' GROUP BY metric_name;
```

Um serviço que aparece em trace e some em log quer dizer agente de node faltando ou `include` do filelog sem aquele namespace. Nenhum backend em lugar nenhum, com o front aparecendo, é o sufixo do endpoint.

## Os labels de uma série

Serve para descobrir de quem é uma métrica e quais atributos ela carrega. Foi assim que se descobriu que `v8js.memory.heap.limit` vinha do front, não do backend, e que era por espaço do V8:

```sql
SELECT metric_name, labels FROM signoz_metrics.distributed_time_series_v4
WHERE metric_name = '<nome>' LIMIT 1 FORMAT Vertical;
```

## O coletor está mandando?

Métricas internas do agente, na porta 8888. Separam "a aplicação não exporta" de "o collector não grava":

```bash
kubectl port-forward -n observability <pod-do-agente> 18888:8888 >/dev/null 2>&1 &
curl -s --retry 10 --retry-connrefused http://127.0.0.1:18888/metrics \
  | grep -E "^otelcol_(receiver_accepted|receiver_refused|exporter_sent|exporter_send_failed|process_memory_rss)"
```

`exporter_sent` subindo com `send_failed` em zero e ClickHouse vazio significa problema **depois** do agente: pipeline do collector do SigNoz, ou tabela. `process_memory_rss` perto do limit do agente é o aviso de OOMKill a caminho.

## Disco e retenção

```sql
SELECT table, extract(create_table_query, 'TTL [^S]*') ttl
FROM system.tables WHERE database='signoz_logs' AND name='logs_v2';

SELECT table, name, default_expression FROM system.columns
WHERE name='_retention_days' AND table IN ('logs_v2','signoz_index_v3');
```

```bash
kubectl exec -n observability chi-signoz-clickhouse-cluster-0-0-0 -c clickhouse -- df -h /var/lib/clickhouse
```

## Consumo real de um pod, sem metrics-server

Nem todo cluster tem `metrics-server`, e sem ele `kubectl top` não responde. O cgroup responde:

```bash
kubectl exec -n <ns> <pod> -- sh -c '
  echo "memory.current=$(cat /sys/fs/cgroup/memory.current)"
  echo "memory.peak=$(cat /sys/fs/cgroup/memory.peak)"
  grep -E "^(anon|file) " /sys/fs/cgroup/memory.stat
  grep ^usage_usec /sys/fs/cgroup/cpu.stat'
```

`usage_usec` é CPU acumulada desde o start do container: dividida pelo uptime (de `.status.containerStatuses[0].state.running.startedAt`) dá a média de cores do período. Duas leituras espaçadas dão a taxa instantânea.

Em `memory.stat`, `anon` é memória de verdade e `file` é page cache, reclamável. Para dimensionar banco, olhe `anon`; o total engana.

## Por que o pod morreu

```bash
kubectl describe pod -n <ns> <pod> | sed -n '/Last State/,/Ready/p'
kubectl logs -n <ns> <pod> --previous --tail=50
```

Os códigos que mais aparecem:

| Código | Significado | Caminho |
|---|---|---|
| 137 | OOMKill do kernel | limit do pod pequeno, ou heap do V8 maior que o limit |
| 139 | SIGSEGV; em Node, quase sempre heap do V8 | `--max-old-space-size` ausente ou alto demais |
| 1 | saída da aplicação | ler o log anterior; em Nest costuma ser boot (migration, lock) |

Para o 139, o log anterior traz `FATAL ERROR: Ineffective mark-compacts near heap limit` e as últimas linhas de GC, com o heap no momento da morte. Compare com o limit do pod: se morreu em ~1,5GB com limit maior, falta a flag.
