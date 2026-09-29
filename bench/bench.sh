#!/usr/bin/env bash
# bench.sh <comando-do-modelo> <id-opencode>
# Ex.: ./bench.sh coder qwen3-coder-30b-a3b
#      ./bench.sh qwen27 qwen3.8-27b-ud-iq3_s
#      ./bench.sh oss gpt-oss-20b
# Sobe o modelo, roda o prompt via opencode headless, mede tempo/tokens e valida.

export PATH="$HOME/.nvm/versions/node/v22.23.1/bin:$PATH"   # Nest 11/Next 16 exigem Node 20+

MODELO="${1:?uso: bench.sh <comando-llama-menu> <id-opencode>}"
OC_ID="${2:?informe o id do modelo no opencode (provider llamacpp)}"
BENCH_DIR="$HOME/bench"
RUN_DIR="$BENCH_DIR/run-$MODELO"
PROMPT="$BENCH_DIR/prompt.md"

[ -f "$PROMPT" ] || { echo "Crie $PROMPT com o prompt do benchmark."; exit 1; }
rm -rf "$RUN_DIR"; mkdir -p "$RUN_DIR"

# permissões liberadas SÓ dentro da pasta da rodada (benchmark sem intervenção)
cat > "$RUN_DIR/opencode.jsonc" <<'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "permission": { "edit": "allow", "bash": "allow", "webfetch": "allow" }
}
EOF

# guardrail local: reforça a disciplina de workspace na cara do modelo
cat > "$RUN_DIR/AGENTS.md" <<'EOF'
# Regras desta tarefa (obrigatórias)

- Trabalhe SOMENTE dentro desta pasta. Nunca acesse `/`, `/tmp`, `~` ou qualquer caminho fora dela: será negado.
- Crie tudo com caminho relativo: `backend/...` e `frontend/...`.
- Permissão negada não é motivo para desistir nem mudar de estratégia: continue dentro da pasta.
- Erro de build ou comando não justifica trocar a stack pedida (NestJS e Next.js são obrigatórios): leia o erro e conserte.
- Todo import deve apontar para arquivo que você criou de verdade.

## Armadilhas que reprovam a entrega

- NestJS: CORS é `app.enableCors({...})` nativo. NUNCA importe a lib `cors` externa.
- Next.js App Router: componente com useState/useEffect/eventos exige `'use client'` na PRIMEIRA linha.
- TypeORM: `(category) => category.expenses` só funciona se `Category` declarar o `@OneToMany` inverso.
- 400 para dado inválido, 404 para recurso inexistente, 409 para duplicado.
- NestJS: `app.useGlobalPipes(new ValidationPipe({ transform: true, whitelist: true }))` no main.ts é OBRIGATÓRIO, senão DTO não valida e vira 500. Lance BadRequestException/NotFoundException/ConflictException explicitamente.
- Teste os curls dos critérios 3-5 você mesmo e confira o status code retornado.

## A tarefa SÓ termina quando você executar e mostrar passando:

1. `cd backend && npx tsc --noEmit` sem erros.
2. `cd backend && npm run seed && npm run start:dev` e um `curl localhost:4001/categories` respondendo.
3. `cd frontend && npx next build` sem erros.
Corrija e repita até os três passarem. Compilar não basta: prove em execução.
Não pergunte o que fazer a seguir: termine e reporte.
EOF

echo "=== [$MODELO] subindo servidor (com /metrics) ==="
nohup ~/llama-menu.sh "$MODELO" --metrics > "$BENCH_DIR/server-$MODELO.log" 2>&1 &
for i in $(seq 1 60); do sleep 2; curl -sf http://127.0.0.1:8080/health >/dev/null && break; done
curl -sf http://127.0.0.1:8080/health >/dev/null || { echo "servidor não subiu"; exit 1; }

echo "=== [$MODELO] executando prompt via opencode (headless) ==="
INICIO=$(date +%s)
# timeout de 30min: reasoning em loop ou request travada não segura o ciclo
( cd "$RUN_DIR" && timeout -k 30 1800 opencode run --model "llamacpp/$OC_ID" "$(cat "$PROMPT")" ) \
  > "$BENCH_DIR/opencode-$MODELO.log" 2>&1
RC=$?
FIM=$(date +%s)
DURACAO=$((FIM-INICIO))
[ $RC -eq 124 ] && echo "AVISO: estourou o timeout de 30min" | tee -a "$BENCH_DIR/opencode-$MODELO.log"

# métricas do servidor (tokens processados/gerados e velocidade média)
curl -s http://127.0.0.1:8080/metrics > "$BENCH_DIR/metrics-$MODELO.txt" 2>/dev/null

echo "=== [$MODELO] validando critérios ==="
bash "$BENCH_DIR/validate.sh" "$RUN_DIR" | tee "$BENCH_DIR/resultado-$MODELO.txt"

pkill -x llama-server 2>/dev/null

{
  echo "modelo: $MODELO"
  echo "tempo_total_s: $DURACAO"
  grep -E "prompt_tokens_total|tokens_predicted_total|prompt_seconds_total|tokens_predicted_seconds_total" \
    "$BENCH_DIR/metrics-$MODELO.txt" 2>/dev/null
} >> "$BENCH_DIR/resultado-$MODELO.txt"

echo
echo "=== [$MODELO] RESUMO ==="
echo "Tempo total: ${DURACAO}s"
echo "Detalhes: $BENCH_DIR/resultado-$MODELO.txt"
