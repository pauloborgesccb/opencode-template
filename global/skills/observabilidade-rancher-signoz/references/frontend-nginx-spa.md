# Front Angular ou React servido por Nginx

Em SPA servida por Nginx, o Nginx responde por arquivo estático e normalmente faz proxy para o backend. Quase toda pergunta de operação ("está no ar?", "está lento?", "quem está dando 5xx?") se responde no Nginx, sem telemetria no navegador.

## O que vale instrumentar, nesta ordem

**1. Log de acesso em JSON.** O agente de node já coleta o `stdout` do Nginx; o que muda tudo é o formato. Texto corrido vira uma linha sem campo; JSON vira filtro por status, rota e tempo.

```nginx
log_format json_analytics escape=json '{'
  '"tempo":"$time_iso8601",'
  '"rota":"$uri",'
  '"status":$status,'
  '"duracao":$request_time,'
  '"upstream":"$upstream_addr",'
  '"duracao_upstream":"$upstream_response_time",'
  '"metodo":"$request_method",'
  '"bytes":$body_bytes_sent'
'}';
access_log /dev/stdout json_analytics;
```

Use `$uri`, não `$request`: `$request` traz a query string inteira, o que explode cardinalidade e vaza token que ande em URL.

**2. Métrica do Nginx.** Habilite `stub_status` numa porta interna e colete pelo receiver `nginx` do coletor:

```nginx
server {
  listen 8080;
  location /nginx_status { stub_status; allow 127.0.0.1; allow 10.0.0.0/8; deny all; }
}
```

```yaml
receivers:
  nginx:
    endpoint: "http://<servico-nginx>:8080/nginx_status"
    collection_interval: 30s
```

Entrega conexões ativas, aceitas, tratadas e total de requisições. É pouco, mas é o suficiente para ver pico de carga e conexão pendurada.

**3. Telemetria no navegador: só com pergunta em mãos.** O SDK web do OTel (ou `@vercel/otel` em Next.js) traz tempo de carregamento, erro de JavaScript e chamada de API vista do lado do usuário. Custa volume alto e cardinalidade fácil de estourar, e expõe ao backend de telemetria o que o usuário faz. Vale quando a pergunta é "por que está lento para o cliente e rápido para nós"; não vale como padrão.

Se ligar, dois filtros no exportador:

- **cardinalidade**: descarte span interno de render do framework. Em Next.js (`resolve page components`, `start response`, `generateMetadata`) podem ser dois terços do volume. Mantenha os spans de `fetch`, que ligam o trace do front ao do backend.
- **dado sensível**: rota pública com token ou código na URL não pode ir para telemetria. Filtre antes de exportar.

## Erro clássico

SDK de navegador costuma tratar o sufixo do endpoint sozinho (`endpoint.endsWith('/v1/traces')`), e SDK de backend costuma não tratar. É por isso que aparece o caso "o front está no SigNoz e o backend não", que parece problema de backend e é problema de variável de ambiente. Veja a armadilha do endpoint no `SKILL.md`.
