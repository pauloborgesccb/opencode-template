#!/usr/bin/env bash
# Levanta o estado da observabilidade de um cluster, sem alterar nada.
#
#   ./verificar.sh <caminho-do-kubeconfig> [janela_em_minutos]
#
# Responde, nesta ordem: o SigNoz existe, quanto de disco e retencao tem,
# quem esta mandando trace/log/metrica, quais agentes estao no ar e se os
# alertas estao montados. Rode antes de instalar qualquer coisa e de novo
# depois de cada passo.

set -uo pipefail

KUBECONFIG_PATH="${1:-}"
JANELA="${2:-30}"

if [ -z "$KUBECONFIG_PATH" ] || [ ! -f "$KUBECONFIG_PATH" ]; then
  echo "uso: $0 <caminho-do-kubeconfig> [janela_em_minutos]" >&2
  exit 1
fi

export KUBECONFIG="$KUBECONFIG_PATH"
CH_POD="chi-signoz-clickhouse-cluster-0-0-0"

titulo() { printf '\n=== %s\n' "$1"; }

ch() {
  kubectl exec -n observability "$CH_POD" -c clickhouse -- \
    clickhouse-client -q "$1" 2>/dev/null
}

titulo "SigNoz"
if ! kubectl get ns observability >/dev/null 2>&1; then
  echo "namespace observability nao existe: nao ha SigNoz neste cluster"
  exit 0
fi
kubectl get pods -n observability --no-headers 2>/dev/null \
  | awk '{printf "  %-46s %s\n", $1, $3}'

versao=$(kubectl get secret -n observability -o name 2>/dev/null | grep -m1 'sh.helm.release.v1.signoz')
if [ -n "$versao" ]; then
  kubectl get "$versao" -n observability -o jsonpath='{.data.release}' 2>/dev/null \
    | base64 -d 2>/dev/null | base64 -d 2>/dev/null | gunzip 2>/dev/null \
    | python3 -I -c "import json,sys; c=json.load(sys.stdin)['chart']['metadata']; print('  chart', c['name'], c['version'], 'app', c.get('appVersion'))" 2>/dev/null
fi

titulo "Disco e retencao do ClickHouse"
kubectl exec -n observability "$CH_POD" -c clickhouse -- df -h /var/lib/clickhouse 2>/dev/null | tail -1 | sed 's/^/  /'
ch "SELECT concat('  retencao ', table, ' = ', default_expression, ' dias') FROM system.columns WHERE name='_retention_days' AND table IN ('logs_v2','signoz_index_v3')"

titulo "Trace recebido nos ultimos ${JANELA} min"
ch "SELECT concat('  ', serviceName, '  ', toString(count()), ' spans') FROM signoz_traces.distributed_signoz_index_v3 WHERE timestamp > now() - INTERVAL ${JANELA} MINUTE GROUP BY serviceName ORDER BY count() DESC" \
  | grep . || echo "  (nenhum)"

titulo "Log recebido nos ultimos ${JANELA} min"
ch "SELECT concat('  ', svc, ' [', amb, ']  ', toString(linhas), ' linhas') FROM (SELECT resources_string['service.name'] AS svc, resources_string['deployment.environment'] AS amb, count() AS linhas FROM signoz_logs.distributed_logs_v2 WHERE timestamp > toUnixTimestamp64Nano(now64() - INTERVAL ${JANELA} MINUTE) GROUP BY svc, amb ORDER BY linhas DESC LIMIT 15)" \
  | grep . || echo "  (nenhum: falta agente de node, ou o include do filelog nao cobre o namespace)"

titulo "Metrica de runtime Node nos ultimos ${JANELA} min"
ch "SELECT concat('  ', metric_name, '  ', toString(count()), ' amostras') FROM signoz_metrics.distributed_samples_v4 WHERE unix_milli > toUnixTimestamp64Milli(now64() - INTERVAL ${JANELA} MINUTE) AND (metric_name LIKE 'nodejs%' OR metric_name LIKE 'v8js%') GROUP BY metric_name ORDER BY metric_name LIMIT 12" \
  | grep . || echo "  (nenhuma: o auto-instrumentations nao traz runtime-node; ver assets/tracer.js)"

titulo "Agentes"
for alvo in "daemonset otel-agent" "deployment otel-cluster"; do
  set -- $alvo
  if kubectl get "$1" "$2" -n observability >/dev/null 2>&1; then
    kubectl get "$1" "$2" -n observability --no-headers | awk -v n="$2" '{printf "  %-16s no ar  (%s)\n", n, $0}'
  else
    echo "  $2 ausente"
  fi
done

titulo "Alertas"
kubectl get cronjob -A -o custom-columns='NS:.metadata.namespace,NOME:.metadata.name,QUANDO:.spec.schedule' --no-headers 2>/dev/null \
  | grep -E 'alerta-' | awk -F'  +' '{printf "  %-16s ns=%-6s schedule=%s\n", $2, $1, $3}' \
  | grep . || echo "  nenhum cronjob de alerta"
kubectl get secret -A --no-headers 2>/dev/null | grep -q telegram-alertas \
  && echo "  secret telegram-alertas presente" || echo "  secret telegram-alertas AUSENTE"
kubectl get deploy -A --no-headers 2>/dev/null | grep -q alerta-relay-telegram \
  && echo "  relay do SigNoz para o Telegram no ar" || echo "  relay ausente: alerta criado na tela do SigNoz nao chega no Telegram"

echo
