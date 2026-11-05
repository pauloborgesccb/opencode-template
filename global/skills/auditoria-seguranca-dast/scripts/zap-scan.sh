#!/usr/bin/env bash
# Driver de varredura do OWASP ZAP pela API REST.
# Uso: zap-scan.sh <nome> <url-alvo> [ajax]
#   nome       rotulo curto do alvo, usado no nome do arquivo de saida
#   url-alvo   como o container enxerga o alvo (ex.: http://host.docker.internal:4200)
#   ajax       passe "ajax" para rodar tambem o AJAX spider (SPAs)
# Saida: <dir-do-script-ou-SAIDA>/zap-<nome>.json
set -u

Z="${ZAP_URL:-http://127.0.0.1:8090}"
H=(-H "Host: zap")
S="${SAIDA:-$(pwd)}"
NOME="${1:?informe o nome do alvo}"
ALVO="${2:?informe a url do alvo}"
AJAX="${3:-nao}"

api() { curl -s --max-time 180 "${H[@]}" "$Z$1"; }
enc() { python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1],safe=''))" "$1"; }
campo() { python3 -c "import json,sys;print(json.load(sys.stdin).get('$1','$2'))"; }

E=$(enc "$ALVO")

echo "### [$NOME] contexto e acesso inicial"
api "/JSON/core/action/accessUrl/?url=$E&followRedirects=true" >/dev/null
api "/JSON/context/action/newContext/?contextName=$NOME"; echo
api "/JSON/context/action/includeInContext/?contextName=$NOME&regex=$(enc "${ALVO}.*")"; echo

echo "### [$NOME] spider"
SID=$(api "/JSON/spider/action/scan/?url=$E&recurse=true&maxChildren=0" | campo scan "")
while :; do
  P=$(api "/JSON/spider/view/status/?scanId=$SID" | campo status 100)
  [ "$P" = "100" ] && break
  sleep 5
done
echo "spider concluido; urls=$(api "/JSON/spider/view/results/?scanId=$SID" | python3 -c "import json,sys;print(len(json.load(sys.stdin).get('results',[])))")"

if [ "$AJAX" = "ajax" ]; then
  echo "### [$NOME] ajax spider"
  api "/JSON/ajaxSpider/action/setOptionMaxDuration/?Integer=3" >/dev/null
  api "/JSON/ajaxSpider/action/setOptionNumberOfBrowsers/?Integer=1" >/dev/null
  api "/JSON/ajaxSpider/action/setOptionBrowserId/?String=firefox-headless" >/dev/null
  api "/JSON/ajaxSpider/action/scan/?url=$E&inScope=true" >/dev/null
  while :; do
    ST=$(api "/JSON/ajaxSpider/view/status/" | campo status "")
    [ "$ST" != "running" ] && break
    sleep 10
  done
  echo "ajax spider: $ST, urls=$(api "/JSON/ajaxSpider/view/numberOfResults/" | campo numberOfResults 0)"
fi

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
  sleep 15
done

curl -s --max-time 300 "${H[@]}" "$Z/JSON/alert/view/alerts/?baseurl=$E&start=0&count=9999" > "$S/zap-$NOME.json"
echo "alertas salvos em $S/zap-$NOME.json: $(python3 -c "import json;print(len(json.load(open('$S/zap-$NOME.json'))['alerts']))")"
