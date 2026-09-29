---
description: Implementa uma tarefa com loop de correção até a verificação passar, depois valida com revisor e tester
---
Implemente a seguinte tarefa e só a considere entregue após o ciclo completo de verificação: $ARGUMENTS

Processo obrigatório:

1. IMPLEMENTE a tarefa seguindo o AGENTS.md e os padrões do projeto.
2. VERIFIQUE você mesmo, executando nesta ordem o que existir no projeto:
   - typecheck (tsc, mypy, etc.)
   - build
   - testes
   - subir a aplicação e exercitar o que mudou com uma chamada real (curl, execução direta)
3. Se QUALQUER passo falhar: leia o erro, corrija e volte ao passo 2. Repita até tudo passar (máximo 5 ciclos; se não convergir, pare e reporte o que está travado com o erro completo).
4. Com tudo verde, acione o subagent `revisor` para conferir se o pedido foi cumprido por completo.
5. Acione o subagent `tester` para prova independente de funcionamento.
6. Reporte: o que foi feito, saída das verificações, veredito do revisor e do tester.

Nunca declare concluído com verificação falhando. Nunca pergunte "o que fazer a seguir": termine o ciclo e reporte.
