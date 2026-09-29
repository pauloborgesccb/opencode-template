#!/usr/bin/env bash
# new-project.sh <nome> [dir-base]
# Gera um projeto blank pronto para codar com IA a partir deste template.
# Ex.: ./new-project.sh minha-api            -> ~/projetos/minha-api
#      ./new-project.sh minha-api ~/clientes -> ~/clientes/minha-api

set -e
NOME="${1:?uso: ./new-project.sh <nome> [dir-base]}"
BASE="${2:-$HOME/projetos}"
DEST="$BASE/$NOME"
SRC="$(cd "$(dirname "$0")" && pwd)"

[ -e "$DEST" ] && { echo "Já existe: $DEST"; exit 1; }

mkdir -p "$DEST"
cp -r "$SRC/.opencode" "$DEST/"
cp "$SRC/AGENTS.md" "$DEST/"
cp "$SRC/opencode.jsonc" "$DEST/"

cat > "$DEST/.gitignore" <<'EOF'
node_modules/
dist/
.next/
.env*
!.env.example
*.log
EOF

cd "$DEST"
git init -q
git add -A
git commit -qm "chore: scaffold inicial do projeto (opencode-template)"

echo "Projeto criado: $DEST"
echo
echo "Próximos passos:"
echo "  1. cd $DEST"
echo "  2. opencode"
echo "  3. Descreva o que quer construir; depois do primeiro código, rode /init"
echo "     para o AGENTS.md ser preenchido a partir do repositório real."
echo "  4. @skill-gen para gerar as skills do projeto quando ele tomar forma."
