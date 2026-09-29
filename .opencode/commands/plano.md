---
description: Plano de implementação enxuto para uma tarefa (usa o agente nativo plan, read-only)
agent: plan
---
Monte um plano de implementação para: $ARGUMENTS

Formato obrigatório, nada além destas 4 seções:

1. ARQUIVOS: caminho exato de cada arquivo a criar/alterar, com uma frase do que muda.
2. PASSOS: em ordem de execução, cada um verificável isoladamente.
3. RISCOS: apenas os reais, cada um com sua validação.
4. VERIFICAÇÃO: comandos exatos para provar que funcionou ao final.

Regras: não escreva código completo, só o suficiente para remover ambiguidade.
Antes de propor arquivo novo, procure o que já existe para reutilizar.
Consulte o AGENTS.md do projeto e imite o módulo vizinho mais parecido.
