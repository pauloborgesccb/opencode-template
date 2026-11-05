#!/usr/bin/env bash
# Converte o HTML do relatorio em PDF usando o Chrome em modo headless.
# Uso: html-para-pdf.sh <entrada.html> <saida.pdf>
set -eu

ENTRADA="${1:?informe o html de entrada}"
SAIDA="${2:?informe o pdf de saida}"

CHROME=""
for c in google-chrome chromium chromium-browser google-chrome-stable; do
  command -v "$c" >/dev/null 2>&1 && { CHROME="$c"; break; }
done
[ -z "$CHROME" ] && { echo "Nenhum Chrome ou Chromium encontrado. Alternativas: weasyprint, wkhtmltopdf." >&2; exit 1; }

PERFIL=$(mktemp -d)
trap 'rm -rf "$PERFIL"' EXIT

"$CHROME" --headless=new --disable-gpu --no-sandbox \
  --user-data-dir="$PERFIL" --no-pdf-header-footer \
  --print-to-pdf="$SAIDA" "file://$(realpath "$ENTRADA")" 2>&1 | tail -2

python3 - "$SAIDA" <<'PY'
import re, sys
d = open(sys.argv[1], "rb").read()
print("paginas:", len(re.findall(rb"/Type\s*/Page[^s]", d)), "| KB:", round(len(d) / 1024))
PY
