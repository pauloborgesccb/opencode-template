#!/usr/bin/env bash
# Exporta dashboards e regras de alerta do SigNoz para JSON, um arquivo por item.
#
#   ./exportar-signoz.sh <kubeconfig> <diretorio-destino>
#
# Serve para versionar no repositorio de infraestrutura o que hoje so existe
# dentro do produto, e para levar de um cluster para outro. So le.
#
# O banco interno do SigNoz e um SQLite em /var/lib/signoz/signoz.db. A copia
# e apagada no fim porque o arquivo tambem contem dado de usuario.

set -euo pipefail

KUBECONFIG_PATH="${1:-}"
DESTINO="${2:-}"

if [ -z "$KUBECONFIG_PATH" ] || [ -z "$DESTINO" ]; then
  echo "uso: $0 <kubeconfig> <diretorio-destino>" >&2
  exit 1
fi

export KUBECONFIG="$KUBECONFIG_PATH"
mkdir -p "$DESTINO"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "copiando o banco interno do SigNoz..."
kubectl cp observability/signoz-0:/var/lib/signoz/signoz.db "$TMP/signoz.db" -c signoz >/dev/null 2>&1

if [ ! -s "$TMP/signoz.db" ]; then
  echo "nao consegui copiar /var/lib/signoz/signoz.db do pod signoz-0" >&2
  exit 1
fi

BANCO="$TMP/signoz.db" DEST="$DESTINO" python3 -I - <<'PY'
import json, os, pathlib, re, sqlite3, unicodedata

banco = sqlite3.connect(os.environ['BANCO'])
destino = pathlib.Path(os.environ['DEST'])

def slug(texto):
    # tira acento antes de trocar por hifen, senao "memoria" vira "mem-ria"
    texto = unicodedata.normalize('NFKD', texto or 'sem-nome')
    texto = texto.encode('ascii', 'ignore').decode()
    texto = re.sub(r'[^a-z0-9]+', '-', texto.lower().strip())
    return re.sub(r'-+', '-', texto).strip('-')[:48]

def limpar(d, campos):
    for c in campos:
        d.pop(c, None)
    return d

def tabela_existe(nome):
    return bool(banco.execute(
        "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", (nome,)).fetchone())

total = 0

if tabela_existe('dashboard'):
    for (dados,) in banco.execute('SELECT data FROM dashboard'):
        d = limpar(json.loads(dados), ('uuid', 'id', 'createdAt', 'updatedAt',
                                       'created_at', 'updated_at'))
        if not (d.get('widgets') or []):
            continue  # dashboard vazio e rascunho, nao configuracao
        arq = destino / ('dashboard-%s.json' % slug(d.get('title')))
        arq.write_text(json.dumps(d, ensure_ascii=False, indent=2))
        print('  %-52s %d widgets' % (arq.name, len(d['widgets'])))
        total += 1

if tabela_existe('rule'):
    cols = [r[1] for r in banco.execute('PRAGMA table_info(rule)')]
    for row in banco.execute('SELECT * FROM rule'):
        d = limpar(json.loads(dict(zip(cols, row)).get('data', '{}')),
                   ('id', 'createAt', 'createBy', 'updateAt', 'updateBy', 'state'))
        arq = destino / ('alerta-%s.json' % slug(d.get('alert')))
        arq.write_text(json.dumps(d, ensure_ascii=False, indent=2))
        print('  %-52s %s' % (arq.name, d.get('alertType', '')))
        total += 1

print('\n%d item(ns) em %s' % (total, destino))
if total == 0:
    print('nada para exportar: nenhum dashboard com widget e nenhuma regra de alerta')
PY
