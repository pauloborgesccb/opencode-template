# Backend Python (FastAPI, Django, Flask, Celery)

Como no Java, existe um caminho sem tocar no código da aplicação: um wrapper que instrumenta o que estiver instalado.

## Instrumentação automática

```
pip install opentelemetry-distro opentelemetry-exporter-otlp
opentelemetry-bootstrap -a install
```

`opentelemetry-bootstrap` olha as dependências do projeto e instala só os instrumentadores que fazem sentido: FastAPI, Django, Flask, `psycopg`, `redis`, `pika`, `requests`, `httpx`, SQLAlchemy, Celery.

No container, o processo passa a subir pelo wrapper:

```dockerfile
CMD ["opentelemetry-instrument", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

Vale a mesma regra das outras linguagens: se o `CMD` não passar pelo wrapper, não há instrumentação, por mais que o pacote esteja instalado.

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
    value: "otlp"
  - name: OTEL_PYTHON_LOG_CORRELATION
    value: "true"                        # injeta trace_id nas linhas do logging
```

## Dois cuidados específicos de Python

**Gunicorn e Uvicorn com vários workers.** Cada worker é um processo, e o SDK vive por processo. Com `--preload` no Gunicorn a instrumentação inicializada antes do fork não sobrevive direito; o caminho estável é instrumentar no `post_fork` ou simplesmente não usar `--preload`. Se as métricas de um serviço aparecerem pela metade, suspeite disso antes de suspeitar do coletor.

**Celery.** O instrumentador cobre a publicação e o consumo da tarefa, mas o trace só atravessa a fila se o contexto for propagado, o que o instrumentador já faz. Se o worker roda em outro deployment, confira que ele também tem as variáveis: é comum instrumentar a API e esquecer o worker, e aí metade do trabalho do sistema fica invisível.

## Memória

Python não tem heap gerenciado com teto configurável como V8 ou JVM, então o controle é o limit do pod e o número de workers. A métrica que importa é `process.runtime.cpython.memory` (vem do instrumentador de runtime) contra o limit; e, em serviço com vazamento, o crescimento monotônico do RSS entre reinícios diz mais que qualquer valor instantâneo.
