# Postgres, Redis, RabbitMQ e o que perguntar a cada um

Essas três peças aparecem em quase todo projeto, e são a origem de boa parte das quedas que a aplicação só reflete. A aplicação diz "está lento"; a fila diz "tenho 40 mil mensagens paradas porque o consumidor caiu".

Todas entram por receiver do coletor, com credencial de leitura. Nenhuma mudança nas aplicações. Coloque-as num Deployment de coletor próprio (uma réplica), não no DaemonSet: são alvos únicos no cluster e um coletor por node consultaria o mesmo Postgres quatro vezes.

## Configuração

```yaml
receivers:
  postgresql:
    endpoint: "<servico-postgres>:5432"
    username: "${env:PG_USER}"
    password: "${env:PG_PASS}"
    databases: ["<banco>"]
    collection_interval: 60s
    tls:
      insecure: true          # dentro do cluster; fora dele, configure o CA

  redis:
    endpoint: "<servico-redis>:6379"
    password: "${env:REDIS_PASS}"
    collection_interval: 60s

  rabbitmq:
    endpoint: "http://<servico-rabbitmq>:15672"   # API de gestão, não AMQP
    username: "${env:RABBIT_USER}"
    password: "${env:RABBIT_PASS}"
    collection_interval: 60s

service:
  pipelines:
    metrics:
      receivers: [postgresql, redis, rabbitmq]
      processors: [memory_limiter, batch]
      exporters: [otlp]
```

Crie um usuário só de leitura para cada um. O coletor precisa de visibilidade, não de poder. No Postgres, um papel com `pg_monitor` basta; no RabbitMQ, a tag `monitoring`.

## O que olhar em cada um

**Postgres.** `postgresql.backends` contra `max_connections` é o que antecipa "too many clients"; `postgresql.db_size` dá o crescimento real sem ninguém medir à mão; `postgresql.deadlocks` e `postgresql.rollbacks` sobem antes do suporte ligar; `postgresql.blocks_read` contra `postgresql.blks_hit` mostra se o cache está sendo suficiente.

Uma leitura que engana: memória de container de banco inclui page cache, reclamável. Para dimensionar, leia `anon` em `memory.stat`, não o total. Um Postgres com 2,16GiB de `memory.current` tinha 8,5MB de memória anônima de verdade.

**Redis.** `redis.memory.used` contra `maxmemory` é o alerta que importa, porque Redis cheio começa a despejar chave em silêncio e a aplicação só vê cache miss. `redis.keyspace.hits` e `redis.keyspace.misses` dizem se o cache está servindo para alguma coisa. `redis.clients.blocked` denuncia consumidor travado em `BLPOP`.

Se o projeto usa Redis como fila (BullMQ e parecidos), o tamanho das chaves de fila é métrica de negócio, não de infra: vale um gauge próprio na aplicação.

**RabbitMQ.** As duas que resolvem a maioria dos incidentes: `rabbitmq.message.current` com atributo de estado `ready` (mensagem parada esperando consumidor) e `rabbitmq.consumer.count` por fila. Fila com `ready` subindo e `consumer.count` zero é consumidor morto, e isso costuma acontecer sem derrubar o pod, então nenhum alerta de réplica pega. `rabbitmq.message.published` contra `rabbitmq.message.delivered` mostra represamento antes de virar fila gigante.

**Nginx.** Veja `frontend-nginx-spa.md`.

## Alertas que valem para essas peças

| Sinal | Condição | Por que importa |
|---|---|---|
| Conexões do Postgres | acima de 80% de `max_connections` | o próximo erro é a aplicação inteira sem conexão |
| Fila sem consumidor | `rabbitmq.consumer.count` = 0 por 5 min numa fila com mensagem | o pod está de pé e o trabalho não anda |
| Fila represando | `rabbitmq.message.current{state=ready}` acima da linha de base por 10 min | dá tempo de agir antes do estouro |
| Memória do Redis | acima de 85% de `maxmemory` | despejo silencioso de chave |
| Crescimento de banco | `postgresql.db_size` projetado contra o disco | troca de plano com antecedência, não na véspera |

A primeira coisa a fazer depois de ligar esses receivers é olhar uma semana de série antes de definir limiar. Limiar chutado gera alerta que ninguém respeita, e alerta que ninguém respeita é pior que alerta nenhum.
