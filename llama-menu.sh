#!/usr/bin/env bash
# llama-menu.sh - sobe modelos GGUF do LM Studio no llama-server
# Uso interativo : ~/llama-menu.sh            (menu de comandos)
# Uso direto     : ~/llama-menu.sh <comando> [extras...]
# Extras         : ~/llama-menu.sh qwen27 --port 8081   (sobrescrevem os defaults)
#
# Sufixo -vis em qualquer comando ativa visão (mmproj), ex: gemma12-vis

BIN="/home/pauloborges/.lmstudio/extensions/backends/llama.cpp-linux-x86_64-nvidia-cuda12-avx2-2.38.0/llama-server"
MODELS_DIR="$HOME/.lmstudio/models"

[ -x "$BIN" ] || { echo "llama-server não encontrado em $BIN"; exit 1; }

# ===== COMANDOS: atalho|arquivo|descrição =====
COMANDOS=(
  "qwen27|Qwen3.8-27B-UD-IQ3_S.gguf|driver principal (opencode)"
  "qwen27-fast|Qwen3.8-27B-UD-IQ3_S.gguf|27B SEM thinking (browser, tarefas mecânicas)"
  "coder|Qwen3-Coder-30B-A3B-Instruct-UD-Q3_K_XL.gguf|código MoE, rápido"
  "qwen35|Qwen3.6-35B-A3B-MTP-UD-IQ3_S.gguf|MoE 35B + MTP speculative"
  "qwen4|Qwen3.5-4B-Q4_K_M.gguf|ultra-rápido"
  "gemma12|gemma-4-12B-it-QAT-Q4_0.gguf|generalista"
  "qwen9|Qwen3.5-9B-MTP-Q8_0.gguf|rápido e preciso (Q8 + MTP)"
)

resolve_atalho() {  # $1 = atalho sem -vis; define MODEL ou retorna 1
  local padrao=""
  for c in "${COMANDOS[@]}"; do
    IFS='|' read -r a p _ <<< "$c"
    [ "$a" = "$1" ] && { padrao="$p"; break; }
  done
  [ -n "$padrao" ] || return 1
  MODEL=$(find "$MODELS_DIR" -type f -iname "$padrao" 2>/dev/null | head -1)
  [ -n "$MODEL" ] || { echo "Modelo não encontrado: $padrao"; exit 1; }
}

VIS=0
if [ $# -gt 0 ] && [[ "$1" != -* ]]; then
  # ===== MODO DIRETO =====
  ATALHO="$1"
  [[ "$ATALHO" == *-vis ]] && { VIS=1; ATALHO="${ATALHO%-vis}"; }
  if ! resolve_atalho "$ATALHO"; then
    echo "Comando desconhecido: $1"
    echo "Válidos: $(printf '%s ' "${COMANDOS[@]%%|*}")(+sufixo -vis)"
    exit 1
  fi
  shift
else
  # ===== MENU DE COMANDOS =====
  # monta as opções: só comandos cujo GGUF existe; -vis quando há mmproj
  OPCOES=()   # "atalho|vis|caminho|descrição"
  for c in "${COMANDOS[@]}"; do
    IFS='|' read -r a p d <<< "$c"
    m=$(find "$MODELS_DIR" -type f -iname "$p" 2>/dev/null | head -1)
    [ -n "$m" ] || continue
    OPCOES+=("$a|0|$m|$d")
    mp=$(find "$(dirname "$m")" -maxdepth 1 -iname "mmproj*.gguf" 2>/dev/null | head -1)
    [ -n "$mp" ] && OPCOES+=("$a-vis|1|$m|$d + visão")
  done
  [ ${#OPCOES[@]} -eq 0 ] && { echo "Nenhum GGUF encontrado em $MODELS_DIR"; exit 1; }

  echo "=== Comandos disponíveis ==="
  i=1
  for o in "${OPCOES[@]}"; do
    IFS='|' read -r a _ m d <<< "$o"
    tam=$(du -h "$m" | cut -f1)
    printf "  %2d) %-12s %-42s [%4s]  %s\n" "$i" "$a" "$(basename "$m" .gguf)" "$tam" "$d"
    ((i++))
  done
  echo

  while true; do
    read -rp "Número do comando (1-${#OPCOES[@]}): " N || exit 1
    [[ "$N" =~ ^[0-9]+$ ]] && [ "$N" -ge 1 ] && [ "$N" -le ${#OPCOES[@]} ] && break
    echo "Opção inválida."
  done
  IFS='|' read -r ATALHO VIS MODEL _ <<< "${OPCOES[$((N-1))]}"
fi

ALIAS=$(basename "$MODEL" .gguf | tr ' ' '_')
MMPROJ=$(find "$(dirname "$MODEL")" -maxdepth 1 -iname "mmproj*.gguf" 2>/dev/null | head -1)

# ===== CONTEXTO E KV CACHE ADAPTATIVOS (16 GB VRAM) =====
# GGUF >= 12 GiB: pesos ocupam quase toda a VRAM, contexto reduzido
# GGUF <  8 GiB: sobra VRAM, KV cache inteiro em q8_0
SZ=$(stat -c%s "$MODEL")
CTX=61440
CTK=q8_0     # K em q8_0 sempre: q4_0 no K degrada demais a qualidade
CTV=q4_0
if [ "$SZ" -ge $((12*1024*1024*1024)) ]; then
  CTX=32768
elif [ "$SZ" -lt $((8*1024*1024*1024)) ]; then
  CTV=q8_0
fi

# ===== SAMPLING E EXTRAS POR MODELO (extras do usuário sobrescrevem) =====
TEMP=0.7; TOPP=0.95; TOPK=40; MINP=0.0; RP=1.0; XTRA=()
case "${ALIAS,,}" in
  qwen3.8-*|*qwq*)        TEMP=0.6;  TOPP=0.95; TOPK=20     # Qwen thinking
                          XTRA=(--spec-type draft-mtp --spec-draft-n-max 2) ;;  # MTP nativo: +58% medido
  qwen3-coder*)           TEMP=0.7;  TOPP=0.8;  TOPK=20; RP=1.05
                          XTRA=(--n-cpu-moe 8) ;;  # experts de 8 camadas na RAM: libera ~2 GiB de VRAM
  qwen3.6-35b-a3b-mtp*)   TEMP=0.6;  TOPP=0.95; TOPK=20
                          XTRA=(--spec-type draft-mtp --spec-draft-n-max 2 --n-cpu-moe 16) ;;
  qwen3.5-9b-mtp*)        TEMP=0.7;  TOPP=0.8;  TOPK=20
                          XTRA=(--spec-type draft-mtp --spec-draft-n-max 2) ;;
  qwen3.5-*)              TEMP=0.7;  TOPP=0.8;  TOPK=20 ;;
  gemma*)                 TEMP=1.0;  TOPP=0.95; TOPK=64 ;;
  gpt-oss*)               TEMP=1.0;  TOPP=1.0;  TOPK=0  ;;  # recomendação OpenAI
esac

# atalho qwen27-fast: mesmo modelo, thinking desligado (sampling de não-thinking)
if [ "${ATALHO:-}" = "qwen27-fast" ]; then
  TEMP=0.7; TOPP=0.8
  XTRA+=(--reasoning off)
fi

echo
echo "Modelo   : $MODEL"
echo "Alias    : $ALIAS"
echo "Contexto : $CTX | KV: K=$CTK V=$CTV"
echo "Sampling : temp=$TEMP top-p=$TOPP top-k=$TOPK min-p=$MINP repeat=$RP"
if [ "$VIS" = "1" ]; then
  [ -n "$MMPROJ" ] || { echo "Visão pedida (-vis) mas nenhum mmproj encontrado para esse modelo."; exit 1; }
  echo "Visão    : ATIVA ($MMPROJ)"
elif [ -n "$MMPROJ" ]; then
  echo "Visão    : mmproj disponível, use o sufixo -vis ou --mmproj \"$MMPROJ\""
fi
[ $# -gt 0 ] && echo "Extras   : $*  (sobrescrevem os defaults)"
echo

# ===== DEFAULTS =====
ARGS=(
  --model "$MODEL"
  --device CUDA0
  --host 127.0.0.1
  --port 8080
  --alias "$ALIAS"
  --ctx-size "$CTX"
  --parallel 1
  --n-gpu-layers 999
  --flash-attn on
  --cache-type-k "$CTK"
  --cache-type-v "$CTV"
  --ubatch-size 1024
  --load-mode none
  --jinja
  --temp "$TEMP"
  --top-p "$TOPP"
  --top-k "$TOPK"
  --min-p "$MINP"
  --repeat-penalty "$RP"
)
[ ${#XTRA[@]} -gt 0 ] && ARGS+=("${XTRA[@]}")

# visão: -vis usa o mmproj do modelo; --mmproj manual também é aceito
usa_mmproj=$VIS
for a in "$@"; do [[ "$a" == --mmproj || "$a" == --mmproj=* ]] && usa_mmproj=1; done
if [ "$VIS" = "1" ]; then
  ARGS+=(--mmproj "$MMPROJ")
elif [ "$usa_mmproj" = "0" ]; then
  ARGS+=(--no-mmproj)
fi

# extras do usuário por último: no llama.cpp, o último flag de cada tipo vence
ARGS+=("$@")

lms unload --all 2>/dev/null   # libera VRAM se o LM Studio tiver algo carregado
pkill -x llama-server 2>/dev/null && sleep 1   # mata instância anterior segurando a porta

exec "$BIN" "${ARGS[@]}"
