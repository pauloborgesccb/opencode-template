# Benchmark de modelos locais para agente de código

Harness que mede, de forma automática e repetível, se um modelo local serve como agente de código no opencode. A tarefa: gerar um sistema fullstack (NestJS + SQLite na porta 4001, Next.js na 4000) a partir de [prompt.md](prompt.md), sem nenhuma intervenção humana.

## Como rodar

Requisitos: opencode, llama-server via [`../llama-menu.sh`](../llama-menu.sh) na porta 8080 (ajuste a variável BIN para o caminho do seu llama-server e MODELS_DIR para sua pasta de GGUFs), Node 20+ no PATH do script, portas 4000/4001 livres, `psmisc` (fuser).

```bash
./bench.sh <comando-llama-menu> <id-do-modelo-no-opencode>
# ex.: ./bench.sh qwen27 qwen3.8-27b-ud-iq3_s
```

O bench.sh: sobe o modelo (com /metrics), cria pasta limpa `run-<modelo>/` com permissões liberadas e guardrail local, roda o prompt via `opencode run` (headless, timeout 30min), valida com [validate.sh](validate.sh) e grava placar + tokens em `resultado-<modelo>.txt`.

## O placar (6 critérios automáticos)

1. Backend instala, seeda e sobe
2. Frontend builda
3. Valor inválido retorna 400
4. FK inexistente retorna 404
5. Endpoint de agregação com contrato e ordenação corretos
6. Typecheck do backend limpo

Mais 1 critério manual (reatividade da UI). O validate.sh mata processos nas portas 4000/4001 antes e depois (sem isso, o backend de uma rodada anterior gera PASS falso).

## Resultados obtidos (RTX 5080 16GB, set/2026)

Servidor: [`../llama-menu.sh`](../llama-menu.sh) (llama-server), que aplica os parâmetros por modelo automaticamente. Comum a todos: flash-attn, offload total (`-ngl 999`), `--ubatch-size 1024`, `--jinja`. KV cache: K sempre q8_0; V q8_0 quando o GGUF < 8 GiB, senão q4_0. Contexto: 61440, reduzido a 32768 quando o GGUF >= 12 GiB.

| Alias | Modelo | Quantização | Ctx | KV (K/V) | Sampling (temp/top-p/top-k) | Extras | Placar | tok/s |
|---|---|---|---|---|---|---|---|---|
| `qwen27` | Qwen3.8-27B | UD-IQ3_S (3.4 bpw, 11.2 GiB) | 61440 | q8_0/q4_0 | 0.6 / 0.95 / 20 | MTP nativo, draft 2 | **6/6 (2x)** | **89.1** (56.5 sem MTP) |
| `qwen35` | Qwen3.6-35B-A3B (MoE 3B ativos) | UD-IQ3_S MTP (14.3 GiB) | 32768 | q8_0/q4_0 | 0.6 / 0.95 / 20 | MTP draft 2, `--n-cpu-moe 16` | 4/6 | 142.2 |
| `coder` | Qwen3-Coder-30B-A3B (MoE) | UD-Q3_K_XL (12.9 GiB) | 32768 | q8_0/q4_0 | 0.7 / 0.8 / 20, repeat 1.05 | `--n-cpu-moe 8` | 4/6 | 85.2 |
| `qwen4` | Qwen3.5-4B | Q4_K_M (2.6 GiB) | 61440 | q8_0/q8_0 | 0.7 / 0.8 / 20 | mmproj disponível | 3/6 | — |
| `qwen9` | Qwen3.5-9B | Q4_K_M MTP (5.5 GiB) | 61440 | q8_0/q8_0 | 0.7 / 0.8 / 20 | MTP draft 2 | 2/6 | **146.5** (123.4 sem MTP) |
| `oss` | gpt-oss-20b (MoE) | MXFP4 nativo (11.3 GiB) | 61440 | q8_0/q4_0 | 1.0 / 1.0 / off | reasoning medium (high não melhorou) | 1/6 | 166.2 |
| `gemma12` | Gemma 4 12B IT | Q4_0 QAT (6.5 GiB) | 61440 | q8_0/q8_0 | 1.0 / 0.95 / 64 | mmproj (visão) | 0/6 | — |

Aprendizado de quantização que os dados sustentam: quant dinâmico (UD) em 3 bits de modelo grande > quant estático em 3-4 bits de modelo menor (o 27B UD-IQ3_S gabaritou; o Devstral 24B Q3_K_L estático, testado antes do harness, era inutilizável). QAT (gemma) preserva bem o Q4_0, mas não salva instruction-following fraco.

Placares por rodada em [resultados/](resultados/). Nota: os tok/s de `qwen4` e `gemma12` ficaram pendentes de medição.

## Lições (importam mais que o placar)

1. **Harness > modelo, até saturar.** As rodadas 1→4 foram de 0 pontos somados a 6/6 + 4/6 sem trocar nenhum peso, só melhorando AGENTS.md/guardrail: disciplina de workspace, armadilhas clássicas (ValidationPipe, 'use client', enableCors), checklist executável, timeout.
2. **Saturação de instrução é real e mensurável.** Ao passar de ~10-12 regras objetivas no guardrail, adicionar 3 regras novas REGREDIU os três modelos testados (4→3, 4→2, 3→2). Política: regra nova substitui antiga; regra de stack vai para skill (carrega sob demanda), não para o global.
3. **MTP é ganho grátis, mas exige tuning.** Com `--spec-draft-n-max 2`: +58% no 27B (aceitação 68%). Com 3: só +19% (aceitação 36%). Vale checar se o GGUF já embute as heads antes de baixar variante.
4. **Reasoning ganha de velocidade em tarefa autônoma.** O 27B "lento" foi o único a gabaritar, duas vezes. Modelos rápidos que não se auto-verificam (gpt-oss) estagnam mesmo com harness bom.
5. **Valide o validador.** Dois bugs de harness quase mudaram conclusões: porta ocupada gerando PASS falso e `((PASS++))` retornando erro com contador em zero.
