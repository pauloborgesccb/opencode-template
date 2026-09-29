#!/usr/bin/env bash
# install.sh - instala a configuração global do opencode desta pasta em ~/.config/opencode
# Seguro para rodar mais de uma vez: faz backup do que for sobrescrever.

set -e
SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="$HOME/.config/opencode"
BKP="$DEST/backup-$(date +%Y%m%d-%H%M%S)"

mkdir -p "$DEST/agents" "$DEST/skills" "$DEST/tools"

backup() { [ -e "$1" ] && { mkdir -p "$BKP"; cp -r "$1" "$BKP/"; }; return 0; }

# AGENTS.md global (regras de comportamento para todo agente)
backup "$DEST/AGENTS.md"
cp "$SRC/AGENTS.md" "$DEST/AGENTS.md"

# agentes globais
for f in "$SRC"/agents/*.md; do
  backup "$DEST/agents/$(basename "$f")"
  cp "$f" "$DEST/agents/"
done

# skills de stack
for d in "$SRC"/skills/*/; do
  nome=$(basename "$d")
  backup "$DEST/skills/$nome"
  mkdir -p "$DEST/skills/$nome"
  cp -r "$d"/. "$DEST/skills/$nome/"
done

# tools customizadas
for f in "$SRC"/tools/*.ts; do
  backup "$DEST/tools/$(basename "$f")"
  cp "$f" "$DEST/tools/"
done

# commands globais
mkdir -p "$DEST/commands"
for f in "$SRC"/commands/*.md; do
  [ -e "$f" ] || continue
  backup "$DEST/commands/$(basename "$f")"
  cp "$f" "$DEST/commands/"
done

# config: NUNCA sobrescreve a sua; instala como exemplo para consulta
cp "$SRC/opencode.jsonc.example" "$DEST/opencode.jsonc.example"
if [ ! -f "$DEST/opencode.jsonc" ]; then
  cp "$SRC/opencode.jsonc.example" "$DEST/opencode.jsonc"
  echo "opencode.jsonc criado a partir do exemplo: AJUSTE os providers/modelos para a sua máquina."
fi

echo "Instalado em $DEST"
[ -d "$BKP" ] && echo "Backup do que foi sobrescrito: $BKP"
echo "Reinicie o opencode para carregar. A tool pdf exige poppler-utils (pdftotext/pdftoppm)."
