# Alertas e aviso no Telegram

Duas famílias, que resolvem problemas diferentes e não se substituem.

**Watchdog por CronJob** (`assets/3-alerta-apis.yaml`, `assets/4-alerta-disco.yaml`). Perguntam ao Kubernetes, não ao backend de telemetria. A vantagem é exatamente essa: continuam funcionando quando o SigNoz está fora, que é quando mais se precisa de aviso. Use para estado de cluster.

**Regra no SigNoz** (criada na tela, entregue pelo relay de `assets/5-alerta-relay-telegram.yaml`). Enxerga série temporal: tendência, percentil, taxa. Use para o que depende do dado da aplicação.

Quem só tem a primeira descobre queda, mas não descobre degradação. Quem só tem a segunda fica cego justo quando o monitoramento cai junto.

## O canal

Um bot do Telegram e um secret, usado pelos três componentes, para tudo cair no mesmo chat:

```bash
kubectl -n <ns> create secret generic telegram-alertas \
  --from-literal=TELEGRAM_TOKEN='<token do bot>' \
  --from-literal=TELEGRAM_CHAT_ID='<chat id>'
```

Um canal só é decisão de projeto, não limitação. Alerta espalhado em três lugares é alerta que ninguém lê.

## O relay, e por que ele existe

O SigNoz não tem canal nativo de Telegram: tem webhook genérico, e manda o payload no formato do Alertmanager. A API do Telegram espera `chat_id` e `text`. Os dois formatos não casam, então entra um serviço de poucas linhas no meio, que recebe, formata e posta.

É o elo que falha em silêncio: o SigNoz marca o alerta como entregue porque o webhook respondeu 200, e nada chega ao celular de ninguém. Depois de subir, **dispare um alerta de teste pela tela e confirme no Telegram**. Não considere a camada pronta antes disso.

Em `assets/5-alerta-relay-telegram.yaml` o relay já reaproveita o mesmo secret dos CronJobs e carrega o nome do cluster na mensagem, que é o que permite um chat só para vários clusters.

## Watchdog de réplica

A cada 2 minutos, em janela comercial, compara réplica desejada com pronta em todo deployment e statefulset dos namespaces vigiados.

O detalhe que faz a diferença é avisar **na mudança de estado**, não enquanto o estado dura. Alerta que repete a cada 2 minutos vira ruído em meia hora, e ruído é o que faz as pessoas silenciarem o canal, inclusive para o alerta que importa. O arquivo guarda o estado anterior num ConfigMap.

A janela de horário é escolha de operação: fora dela ninguém vai agir mesmo, e acordar alguém com alerta que não se pode atender gasta a confiança no canal.

## Watchdog de disco

A cada 30 minutos, lê o uso de todo volume da storageClass escolhida. Avisa em 70% e em 85%, e **repete a cada 6 horas enquanto seguir acima**, porque disco cheio não se resolve sozinho e o lembrete é o ponto.

Cuide para que ele cubra o volume do próprio banco de telemetria. Ligar coleta de log sem vigiar esse disco é a receita para descobrir o problema quando o banco parar de gravar.

## Regras no SigNoz

Duas em `assets/signoz/`, prontas para importar e ajustar:

| Arquivo | O que pega |
|---|---|
| `alerta-latencia-p99.json` | p99 do serviço acima de 5s: degradação que não derruba réplica e que nenhum watchdog vê |
| `alerta-taxa-de-erro.json` | taxa de erro acima de 2%: regressão de deploy aparece aqui antes de chegar ao suporte |

Troque `<SERVICO>` pelo nome do serviço e revise o limiar contra a linha de base real.

Outras que valem, por ordem de retorno:

- **Memória da runtime perto do teto** (`usage_ratio` acima de 0,85 por 5 min). Pega o estouro de heap com minutos de antecedência, em vez de descobrir pelo código de saída do container.
- **Fila sem consumidor** (`rabbitmq.consumer.count` = 0 com mensagem parada). O pod está de pé e o trabalho não anda: nenhum alerta de réplica vê isso.
- **Conexões de banco** acima de 80% do limite.
- **Volume de log de erro** acima da linha de base, para erro que não vira exceção HTTP.

## Antes de alertar sobre erro, veja o que "erro" significa ali

Num sistema real, 15 dos 29 `ERROR` de 15 minutos eram `401 Unauthorized` de token expirado e o resto era regra de negócio negando proposta. Alertar nesse nível só ensina a ignorar alerta.

Ou se corrige o nível no código, que é o certo, ou o alerta filtra o que não é erro de verdade. O que não funciona é alertar e depois pedir para as pessoas ignorarem alguns.

## Ordem de montagem

1. Secret do Telegram.
2. Watchdogs de réplica e disco. Já entregam valor sozinhos e não dependem do SigNoz.
3. Relay, e teste de ponta a ponta.
4. Regras no SigNoz, começando pelas duas prontas.
5. Uma semana depois, revise os limiares contra o que realmente aconteceu.
