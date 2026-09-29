# Benchmark de modelos locais para agente de código

Harness que mede, de forma automática e repetível, se um modelo local serve como agente de código no opencode. A tarefa: gerar um sistema fullstack (NestJS + SQLite na porta 4001, Next.js na 4000) a partir de [prompt.md](prompt.md), sem nenhuma intervenção humana.

## Como rodar

Requisitos: opencode, llama-server via `~/llama-menu.sh` (porta 8080), Node 20+ no PATH do script, portas 4000/4001 livres, `psmisc` (fuser).

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

| Modelo | Melhor placar | tokens/s (geração de código) |
|---|---|---|
| Qwen3.8-27B UD-IQ3_S + MTP nativo | **6/6 (2x)** | 89.1 (56.5 sem MTP) |
| Qwen3.6-35B-A3B MTP UD-IQ3_S | 4/6 | 142.2 |
| Qwen3-Coder-30B-A3B UD-Q3_K_XL | 4/6 | 85.2 |
| Qwen3.5-4B Q4_K_M | 3/6 | — |
| Qwen3.5-9B MTP Q4_K_M | 2/6 | 146.5 |
| gpt-oss-20b MXFP4 | 1/6 (nem com reasoning high melhora) | 166.2 |
| Gemma 4 12B QAT | 0/6 (ignora estrutura pedida) | — |

Placares por rodada em [resultados/](resultados/).

## Lições (importam mais que o placar)

1. **Harness > modelo, até saturar.** As rodadas 1→4 foram de 0 pontos somados a 6/6 + 4/6 sem trocar nenhum peso, só melhorando AGENTS.md/guardrail: disciplina de workspace, armadilhas clássicas (ValidationPipe, 'use client', enableCors), checklist executável, timeout.
2. **Saturação de instrução é real e mensurável.** Ao passar de ~10-12 regras objetivas no guardrail, adicionar 3 regras novas REGREDIU os três modelos testados (4→3, 4→2, 3→2). Política: regra nova substitui antiga; regra de stack vai para skill (carrega sob demanda), não para o global.
3. **MTP é ganho grátis, mas exige tuning.** Com `--spec-draft-n-max 2`: +58% no 27B (aceitação 68%). Com 3: só +19% (aceitação 36%). Vale checar se o GGUF já embute as heads antes de baixar variante.
4. **Reasoning ganha de velocidade em tarefa autônoma.** O 27B "lento" foi o único a gabaritar, duas vezes. Modelos rápidos que não se auto-verificam (gpt-oss) estagnam mesmo com harness bom.
5. **Valide o validador.** Dois bugs de harness quase mudaram conclusões: porta ocupada gerando PASS falso e `((PASS++))` retornando erro com contador em zero.
