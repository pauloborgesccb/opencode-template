---
name: probe-e-pool-que-nao-mentem
description: "Desenha health check, probe de Kubernetes e pool de conexão de banco para que um pod travado seja detectado em vez de ficar recebendo tráfego. Use ao criar ou revisar /health, readinessProbe e livenessProbe, ao configurar pool do TypeORM, Hikari, SQLAlchemy ou pg, e ao investigar pod que está Ready mas não responde, requisição que pendura até o timeout do proxy, 504 sem log, ou serviço que só volta com restart manual."
---

# Probe e pool que não mentem

Escrito a partir de um incidente real: um pod ficou 40 minutos sem responder, em produção, duas vezes no mesmo dia, **continuando `Ready`** e recebendo metade do tráfego. CPU em 10m, nenhum log de erro, nenhum alerta. O remédio foi restart manual nas duas vezes.

Nada daquilo era bug de negócio. Eram três configurações de fábrica somadas a um health check que mentia.

## O princípio

Health check existe para **ser desconfiado de si mesmo**. Se a resposta dele pode vir de outro processo, de um cache, ou de um caminho que não é o que o usuário percorre, ele não está medindo o pod: está contando uma história.

Três perguntas antes de aceitar qualquer `/health`:

1. Se este pod travar, esta resposta muda?
2. Se o banco cair, ela muda **no pod certo**?
3. Quem mais consegue chamar esta rota, e o que ela entrega para quem chama?

## As cinco armadilhas

### 1. Cache compartilhado cega a probe

Um decorator de cache no endpoint de health, com Redis compartilhado entre réplicas e chave sem identidade de pod, faz a probe de um pod ler a resposta de outro.

O sintoma é inconfundível quando se procura: **dois pods devolvem o mesmo `uptime`**.

```bash
for p in $(kubectl -n prd get pods -l app=api -o name); do
  kubectl -n prd exec $p -- wget -qO- localhost:3000/health
done
# uptime idêntico nos dois = a probe não está medindo pod nenhum
```

Nunca cacheie health. Se a preocupação é custo de sondagem, guarde o último resultado **em memória do processo**, com validade curta, nunca num cache que atravessa réplicas.

### 2. Liveness que depende do banco é uma bomba

Liveness responde "me reinicie". Se ela consulta o banco, um pico que satura o pool faz **todas as réplicas** falharem ao mesmo tempo, e o Kubernetes reinicia o serviço inteiro. Você troca lentidão por indisponibilidade, no pior momento possível.

| Rota | Checa | Falha significa |
|---|---|---|
| `/health/live` | só o processo responde | me reinicie |
| `/health/ready` | a dependência que **todo** tráfego atravessa | me tire do rodízio |
| `/health` | tudo, informativo | nada, é diagnóstico |

Readiness olha o banco. Não olha cache, fila nem serviço externo: reprovar por eles tira todas as réplicas do Service por uma falha que o tráfego nem sente. Eles aparecem no corpo e não entram no veredito.

### 3. A probe não pode disputar vaga no pool que ela mede

Se a readiness faz `SELECT 1` no mesmo pool que os workers ocupam, ela mede a **fila do pool**, não a saúde do banco: reprova com o banco inteiro saudável, e ainda consome a conexão que faltava para o usuário.

Dê à sondagem uma conexão dedicada, com `max: 1` e prazo próprio, fora do pool de trabalho. Custa uma conexão por réplica: conte isso no orçamento do servidor.

Abra sob demanda, não no boot: banco fora na subida impediria o processo de subir, trocando pod degradado por pod inexistente. E memoize a promessa, senão duas chamadas simultâneas disputam o `initialize()`.

### 4. Pool sem prazo transforma lentidão em invisibilidade

O default de vários drivers é uma fila de espera **sem prazo**. A requisição não falha: ela espera, até o proxy cortar. E requisição que não termina **não gera linha de log nem span**, então o incidente fica invisível para log, APM e qualquer alerta baseado em trace.

```
connectionTimeoutMillis: 5000   ← o que importa: erro visível em 5s
idleTimeoutMillis:      30000
statement_timeout:      generoso até alguém medir
keepAlive:              true
```

O `connectionTimeoutMillis` é a linha mais importante deste documento. Ele não deixa o sistema mais rápido; deixa a falha **visível**.

Sobre o tamanho do pool: calcule o orçamento antes. `max_connections` do servidor, menos as reservadas ao superusuário, dividido pelo teto de réplicas do HPA, descontando a conexão da sondagem. Ponha o teto **no código**, não só em variável de ambiente, para ninguém o levantar por engano e derrubar o banco para todos os serviços.

Sobre `statement_timeout`: ele vale para toda consulta daquele pool, inclusive dos workers. Se nenhuma consulta foi medida contra produção, um valor curto aposta num número que ninguém conhece, e consulta cancelada no meio derruba job que não tem retry. Comece folgado e aperte depois de medir. Relatório pesado merece prazo próprio, com `SET LOCAL` dentro de uma transação (em Postgres, `set_config($1,$2,true)`, porque `SET` não aceita parâmetro no protocolo estendido).

### 5. Uma falha não pode tirar todas as réplicas

Readiness rigorosa demais é tão ruim quanto frouxa: um soluço de rede atinge as réplicas todas ao mesmo tempo, elas saem juntas do Service, e o proxy fica sem endpoint. 503 para tudo.

Janela de tolerância resolve, com uma regra que não pode ser invertida:

- pod que **já** conversou com o banco: qualquer falha é tolerada por alguns segundos, e só reprova se passar a janela inteira sem resposta
- pod que **nunca** conversou com o banco desde que subiu: reprova na hora, sem janela

O marco começa em zero, não em "agora". Começar no agora faz um pod que subiu com o banco fora entrar no rodízio como degradado, sem nunca ter falado com o banco.

E calcule o tempo real de detecção: janela mais `failureThreshold × periodSeconds`. Uma janela de 15s com 3 falhas de 5s dá até 30s, não 15.

## Coerência da probe com o manifesto

Três números têm que conversar, e quase nunca conversam:

```
prazo interno da coleta  <  timeoutSeconds  <  periodSeconds
```

`timeoutSeconds` igual ao `periodSeconds` faz uma probe lenta ocupar o intervalo inteiro. E `timeoutSeconds` menor que o prazo interno faz o kubelet cortar antes de a resposta chegar, transformando um 200 honesto em timeout.

## O health é público

Se o Ingress publica `/`, o `/health` é público, mesmo que ninguém o divulgue. Duas consequências:

**Não devolva mensagem crua de erro.** `Database falhou: connection refused to pg-prod-01:5432` entrega host, topologia e versão. Corpo genérico, detalhe no log. Procure todas as ocorrências antes de dizer que corrigiu: costuma haver uma num helper que você esqueceu.

**Não deixe que chamá-lo derrube o pod.** Se a rota pública sonda o banco a cada chamada, qualquer cliente enfileira sondagem na conexão da readiness e faz o pod reprovar de fora. Sirva o último quadro coletado, com validade curta.

## O HPA não te salva disso

HPA escala por CPU e memória. O pod travado deste incidente estava em **10m de CPU**: ele não estava ocupado, estava esperando. Nenhuma regra de utilização ia reagir, e mais réplicas não consertariam nada.

## Como investigar quando acontecer

Na ordem, porque cada passo elimina uma hipótese:

```bash
# 1. um pod só, ou todos? agrupe o access log do proxy por IP de upstream
kubectl -n ingress-nginx logs <controller> --since=30m \
  | awk '{for(i=1;i<=NF;i++) if($i ~ /^\[/) ip=$(i+2)} {print ip}' | sort | uniq -c

# 2. o pod está ocupado ou esperando? CPU baixa com tudo pendurado = esperando
kubectl -n prd top pods

# 3. quantas conexões ele abriu? bater exatamente no default do driver é o sinal
kubectl -n prd exec <pod> -- sh -c \
  "awk 'NR>1{split(\$3,a,\":\"); if (a[2]==\"1538\" && \$4==\"01\") n++} END{print n+0}' /proc/net/tcp"
```

Se o passo 1 mostra um pod concentrando 499 e 504 enquanto o outro vai bem, pare de procurar causa externa: é o pod.

## Antes de dizer que está pronto

- os dois pods devolvem `uptime` **diferente**
- liveness responde com o banco desligado
- readiness devolve 503 com o banco desligado, e só depois da janela
- o corpo público não tem mensagem crua de erro em nenhuma das rotas
- `prazo interno < timeoutSeconds < periodSeconds`
- o orçamento de conexões fecha no pior caso do HPA
- existe alerta que pega isso **sem depender de trace**, porque requisição que não termina não gera span
