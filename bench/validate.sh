#!/usr/bin/env bash
# validate.sh <dir-do-projeto-gerado>
# Valida os critérios de aceite do benchmark e imprime o placar.
# Critérios automatizados: 1-5 + typecheck. O critério 6 (reatividade da UI) é manual.

export PATH="$HOME/.nvm/versions/node/v22.23.1/bin:$PATH"   # Nest 11/Next 16 exigem Node 20+

DIR="${1:?uso: validate.sh <dir>}"
PASS=0; TOTAL=6
r() { printf "  %-52s %s\n" "$1" "$2"; }

cd "$DIR" || exit 1

# garante que as portas do benchmark estão livres: sem isso, o backend de uma
# rodada anterior responde no lugar do avaliado e gera PASS falso
fuser -k -n tcp 4001 2>/dev/null; fuser -k -n tcp 4000 2>/dev/null; sleep 1

# 1. backend instala, seeda e sobe
( cd backend && npm install --silent && npm run seed --silent ) >/dev/null 2>&1
( cd backend && (npm run start:dev >/tmp/bench-back.log 2>&1 &) )
BACK_OK=0
for i in $(seq 1 30); do sleep 2; curl -sf http://localhost:4001/categories >/dev/null 2>&1 && { BACK_OK=1; break; }; done
[ $BACK_OK -eq 1 ] && { r "1) backend sobe + seed" PASS; PASS=$((PASS+1)); } || r "1) backend sobe + seed" FAIL

# 2. frontend builda (build é mais objetivo que dev server)
( cd frontend && npm install --silent && npx next build ) >/tmp/bench-front.log 2>&1 \
  && { r "2) frontend builda" PASS; PASS=$((PASS+1)); } || r "2) frontend builda" FAIL

if [ $BACK_OK -eq 1 ]; then
  # 3. amount negativo -> 400
  C=$(curl -s -o /dev/null -w "%{http_code}" -X POST localhost:4001/expenses \
    -H 'Content-Type: application/json' \
    -d '{"description":"x","amount":-5,"date":"2026-09-01","categoryId":1}')
  [ "$C" = "400" ] && { r "3) amount<=0 retorna 400 (obteve $C)" PASS; PASS=$((PASS+1)); } || r "3) amount<=0 retorna 400 (obteve $C)" FAIL

  # 4. categoria inexistente -> 404
  C=$(curl -s -o /dev/null -w "%{http_code}" -X POST localhost:4001/expenses \
    -H 'Content-Type: application/json' \
    -d '{"description":"x","amount":10,"date":"2026-09-01","categoryId":999}')
  [ "$C" = "404" ] && { r "4) categoria inexistente retorna 404 (obteve $C)" PASS; PASS=$((PASS+1)); } || r "4) categoria inexistente retorna 404 (obteve $C)" FAIL

  # 5. summary com totalGeral e array ordenado desc
  curl -s 'localhost:4001/summary?month=2026-09' | python3 -c "
import json,sys
d=json.load(sys.stdin)
tg=[v for k,v in d.items() if 'total' in k.lower() and isinstance(v,(int,float))]
arr=[v for v in d.values() if isinstance(v,list)]
assert tg and arr and len(arr[0])>0
vals=[list(x.values()) for x in arr[0]]
nums=[[v for v in row if isinstance(v,(int,float))] for row in vals]
col=[max(r) for r in nums if r]
assert col==sorted(col,reverse=True)
" 2>/dev/null && { r "5) summary correto e ordenado" PASS; PASS=$((PASS+1)); } || r "5) summary correto e ordenado" FAIL
else
  r "3-5) pulados (backend fora do ar)" FAIL
fi

# 6. typecheck do backend (proxy automático de qualidade)
( cd backend && npx tsc --noEmit ) >/dev/null 2>&1 \
  && { r "6) typecheck backend sem erro" PASS; PASS=$((PASS+1)); } || r "6) typecheck backend sem erro" FAIL

fuser -k -n tcp 4001 2>/dev/null; fuser -k -n tcp 4000 2>/dev/null
pkill -f "nest start" 2>/dev/null; pkill -f "start:dev" 2>/dev/null

echo
echo "PLACAR AUTOMÁTICO: $PASS/$TOTAL"
echo "Critério manual restante: criar despesa pela UI atualiza lista/resumo sem reload."

# diagnóstico para o ciclo de melhoria: por que falhou?
if [ $PASS -lt $TOTAL ]; then
  echo
  echo "=== DIAGNÓSTICO ==="
  [ $BACK_OK -eq 0 ] && { echo "--- backend (últimas 15 linhas) ---"; tail -15 /tmp/bench-back.log 2>/dev/null; }
  grep -q "FAIL" <<< "$(cd frontend 2>/dev/null && echo ok)" 2>/dev/null || true
  if [ -f /tmp/bench-front.log ] && ! grep -q "Compiled successfully\|Generating static" /tmp/bench-front.log 2>/dev/null; then
    echo "--- frontend build (últimas 10 linhas) ---"; tail -10 /tmp/bench-front.log 2>/dev/null
  fi
  echo "--- estrutura entregue ---"
  find . -maxdepth 2 -not -path "*/node_modules*" -not -path "*/.next*" -not -path "*/dist*" | head -30
fi
exit 0
