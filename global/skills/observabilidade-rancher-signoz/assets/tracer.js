const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');
const { OTLPLogExporter } = require('@opentelemetry/exporter-logs-otlp-http');
const { OTLPMetricExporter } = require('@opentelemetry/exporter-metrics-otlp-http');
const { LoggerProvider, BatchLogRecordProcessor } = require('@opentelemetry/sdk-logs');
const { PeriodicExportingMetricReader } = require('@opentelemetry/sdk-metrics');
const { Resource } = require('@opentelemetry/resources');
const { ATTR_SERVICE_NAME, ATTR_SERVICE_VERSION } = require('@opentelemetry/semantic-conventions');

const rawEndpoint =
  process.env.OTEL_EXPORTER_OTLP_ENDPOINT ||
  'http://signoz-otel-collector.observability.svc.cluster.local:4318';

// O endpoint tem de ser a base (host:4318). Os exporters abaixo concatenam
// /v1/<sinal>: se a env ja vier com o sufixo, o POST vai para /v1/traces/v1/traces
// e o collector descarta em silencio. Normalizar aqui evita depender do manifesto.
const baseUrl = rawEndpoint.replace(/\/+$/, '').replace(/\/v1\/(traces|logs|metrics)$/, '');

const traceExporter = new OTLPTraceExporter({
  url: `${baseUrl}/v1/traces`,
});

const logExporter = new OTLPLogExporter({
  url: `${baseUrl}/v1/logs`,
});

const metricExporter = new OTLPMetricExporter({
  url: `${baseUrl}/v1/metrics`,
});

const serviceName = process.env.OTEL_SERVICE_NAME || `<APP>-${process.env.ENV || 'dev'}`;

const resource = new Resource({
  [ATTR_SERVICE_NAME]: serviceName,
  [ATTR_SERVICE_VERSION]: process.env.npm_package_version || '1.0.0',
  'deployment.environment': process.env.ENV || 'dev',
});

// Configurar Logger Provider
const loggerProvider = new LoggerProvider({ resource });
loggerProvider.addLogRecordProcessor(new BatchLogRecordProcessor(logExporter));

// Configurar Metric Reader
const metricReader = new PeriodicExportingMetricReader({
  exporter: metricExporter,
  exportIntervalMillis: 60000, // Exporta métricas a cada 60s
});

const sdk = new NodeSDK({
  traceExporter,
  metricReader,
  instrumentations: [getNodeAutoInstrumentations({
    '@opentelemetry/instrumentation-http': {
      requestHook: (span, request) => {
        span.setAttribute('http.request.body.size', request.headers['content-length'] || 0);
      },
      responseHook: (span, response) => {
        span.setAttribute('http.response.body.size', response.headers['content-length'] || 0);
      },
    },
  })],
  resource,
  logRecordProcessor: new BatchLogRecordProcessor(logExporter),
});

sdk.start();
console.log('[OpenTelemetry] SDK iniciado com sucesso');
console.log(`[OpenTelemetry] Service: ${serviceName}`);
console.log('[OpenTelemetry] Traces, Logs e Metrics habilitados');

// ---------------------------------------------------------------------------
// Memoria do V8
//
// O auto-instrumentations-node 0.52 NAO inclui instrumentation-runtime-node,
// entao nenhum backend exportava heap. Era justamente a serie que teria
// antecipado o "FATAL ERROR: Ineffective mark-compacts near heap limit" que
// derrubou o apisantander de prd em 13/11/2026: o heap subiu a 1.5Gi em 147s
// e o processo morreu com exit 139.
//
// Tres gauges lidos direto do V8, sem dependencia nova. heap_size_limit
// reflete o --max-old-space-size que vem do NODE_OPTIONS, entao o ratio ja
// nasce comparavel entre ambientes de tamanhos diferentes.
// Alerta sugerido: nodejs.v8.heap.usage_ratio acima de 0.85 por alguns minutos.
// ---------------------------------------------------------------------------
const v8 = require('node:v8');
const { metrics } = require('@opentelemetry/api');

const medidorHeap = metrics.getMeter('runtime-heap');

const heapUsado = medidorHeap.createObservableGauge('nodejs.v8.heap.used_bytes', {
  description: 'Heap do V8 em uso',
  unit: 'By',
});
const heapTeto = medidorHeap.createObservableGauge('nodejs.v8.heap.limit_bytes', {
  description: 'Teto de heap do V8, vindo do --max-old-space-size',
  unit: 'By',
});
const heapRazao = medidorHeap.createObservableGauge('nodejs.v8.heap.usage_ratio', {
  description: 'Fracao do teto de heap em uso',
  unit: '1',
});

medidorHeap.addBatchObservableCallback(
  (observador) => {
    const { used_heap_size: usado, heap_size_limit: teto } = v8.getHeapStatistics();
    observador.observe(heapUsado, usado);
    observador.observe(heapTeto, teto);
    observador.observe(heapRazao, teto > 0 ? usado / teto : 0);
  },
  [heapUsado, heapTeto, heapRazao],
);

process.on('SIGTERM', () => {
  Promise.all([
    sdk.shutdown(),
    loggerProvider.shutdown(),
  ])
    .then(() => console.log('[OpenTelemetry] Tracing, Logging and Metrics terminated'))
    .catch((error) => console.log('[OpenTelemetry] Error terminating', error))
    .finally(() => process.exit(0));
});
