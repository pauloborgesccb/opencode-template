#!/usr/bin/env bash
# Varredura do ZAP contra uma API REST: importa a spec OpenAPI ja filtrada,
# popula a arvore com as rotas GET conhecidas e so entao roda a varredura ativa.
# Uso: zap-api.sh <nome> <url-alvo> <arquivo-com-rotas-get> [caminho-da-spec-no-container]
# A spec precisa ter sido copiada antes com: docker cp spec.json zapd:/zap/spec.json
set -u

Z="${ZAP_URL:-http://127.0.0.1:8090}"
H=(-H "Host: zap")
S="${SAIDA:-$(pwd)}"
NOME="${1:?informe o nome do alvo}"
ALVO="${2:?informe a url do alvo}"
ROTAS="${3:?informe o arquivo com as rotas GET}"
SPEC="${4:-}"

api() { curl -s --max-time 180 "${H[@]}" "$Z$1"; }
enc() { python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1],safe=''))" "$1"; }
campo() { python3 -c "import json,sys;print(json.load(sys.stdin).get('$1','$2'))"; }

E=$(enc "$ALVO")

if [ -n "$SPEC" ]; then
  echo "### [$NOME] importando OpenAPI de $SPEC"
  api "/JSON/openapi/action/importFile/?file=$(enc "$SPEC")&target=$E"; echo
fi

echo "### [$NOME] populando a arvore com as rotas GET conhecidas"
n=0
while read -r r; do
  [ -z "$r" ] && continue
  api "/JSON/core/action/accessUrl/?url=$(enc "$ALVO$r")&followRedirects=false" >/dev/null
  n=$((n+1))
done < "$ROTAS"
echo "rotas acessadas: $n"

echo "### [$NOME] spider"
SID=$(api "/JSON/spider/action/scan/?url=$E&recurse=true&maxChildren=0" | campo scan "")
while :; do
  P=$(api "/JSON/spider/view/status/?scanId=$SID" | campo status 100)
  [ "$P" = "100" ] && break
  sleep 5
done

echo "### [$NOME] drenando passive scan"
while :; do
  R=$(api "/JSON/pscan/view/recordsToScan/" | campo recordsToScan 0)
  [ "$R" = "0" ] && break
  sleep 3
done

echo "### [$NOME] varredura ativa"
AID=$(api "/JSON/ascan/action/scan/?url=$E&recurse=true&inScopeOnly=false" | campo scan "")
while :; do
  P=$(api "/JSON/ascan/view/status/?scanId=$AID" | campo status 100)
  echo "  ascan $P%"
  [ "$P" = "100" ] && break
  sleep 20
done

curl -s --max-time 300 "${H[@]}" "$Z/JSON/alert/view/alerts/?baseurl=$E&start=0&count=9999" > "$S/zap-$NOME.json"
echo "alertas salvos em $S/zap-$NOME.json: $(python3 -c "import json;print(len(json.load(open('$S/zap-$NOME.json'))['alerts']))")"
