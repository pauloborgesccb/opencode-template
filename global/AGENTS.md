# Regras globais

## Disciplina de workspace (crítico)

- Trabalhe SOMENTE dentro do diretório do projeto atual. Nunca acesse `/`, `/tmp`, `~` ou qualquer caminho fora do projeto: será negado.
- Crie arquivos sempre com caminho relativo ao projeto.
- Se uma permissão for negada, NÃO abandone a tarefa e NÃO tente outro caminho externo: continue de outra forma dentro do projeto.
- Se um comando ou build falhar, leia a mensagem de erro e corrija o problema apontado. NUNCA troque a arquitetura ou a stack pedida por causa de um erro (ex: trocar NestJS por express): conserte o que quebrou.
- Antes de dar a tarefa por concluída, rode o build/typecheck do projeto e corrija TODOS os erros. Entregar código que não compila é falha, não entrega.
- Import que você escrever deve apontar para arquivo que existe. Criou um import? Confirme que o arquivo alvo foi criado.
- Compilar não basta: suba a aplicação e faça uma chamada real (curl, teste, ou execução direta) provando que funciona ANTES de declarar concluído. Erro de runtime não aparece no typecheck.
- Não pergunte "o que fazer a seguir" ao final de uma tarefa completa: execute até o fim e reporte o resultado.

## Armadilhas clássicas (respeite em qualquer stack)

- NestJS: CORS é `app.enableCors({...})` nativo. NUNCA importe a lib `cors` externa.
- Next.js App Router: componente com useState/useEffect/eventos exige `'use client'` na PRIMEIRA linha do arquivo.
- TypeORM/JPA: relação bidirecional exige o lado inverso declarado (ex: `category.expenses` só existe se `Category` declarar `@OneToMany`).
- Validação de entrada devolve 400; recurso inexistente devolve 404; duplicidade devolve 409. Não misture.
- NestJS: registre `app.useGlobalPipes(new ValidationPipe({ transform: true, whitelist: true }))` no main.ts, senão os DTOs não validam e tudo vira 500. Lance `BadRequestException`/`NotFoundException`/`ConflictException` explicitamente; erro genérico não tratado vira 500 e reprova.
- Chave estrangeira: DTO não valida existência no banco. Antes de criar/atualizar registro com FK, busque a entidade referenciada e lance `NotFoundException` se não existir. Criar com FK inexistente devolvendo 201 é bug.
- Endpoint de agregação/relatório: o contrato pedido (nomes de campos, ordenação, formato) é obrigatório. Depois de implementar, chame o endpoint e compare o JSON retornado campo a campo com o pedido.
- Em tarefa fullstack, feche e valide o backend ANTES de começar o frontend; reserve tempo para o build do front passar.
- Scripts npm referenciados (seed, start:dev) devem existir no package.json que VOCÊ escreveu.

## Fluxo com subagents (critério objetivo)

Mudança PEQUENA (1-2 arquivos, sem estrutura nova, sem API nova):
- Implemente direto e valide só com `tester`.

Mudança MÉDIA ou GRANDE (3+ arquivos, arquivo/módulo novo, refatoração, endpoint/contrato novo):
1. ANTES: consulte `arquiteto` em modo ORIENTAR e siga as diretrizes (onde criar, o que imitar, o que reutilizar).
2. DEPOIS, nesta ordem:
   - `revisor`: o pedido foi cumprido por completo?
   - `tester`: funciona de verdade? (dono exclusivo da execução de testes)
   - `qualidade`: lint, tipos e análise estática do que mudou.
   - `arquiteto` em modo REVISAR: conformidade arquitetural.
3. `bug-hunter` quando a mudança tocar lógica crítica (dinheiro, auth, concorrência, migração).

Nunca acione dois subagents para a mesma pergunta. Cada um tem dono único:
- Executar testes e provar funcionamento: `tester`.
- Lint, tipos, análise estática: `qualidade`.
- Conformidade com o pedido: `revisor`.
- Caça a bugs no diff: `bug-hunter`.
- Arquitetura, reuso e componentização: `arquiteto`.
- Criar skills do projeto: `skill-gen`.

## Convenções

- Responda em português.
- Reuso primeiro: antes de criar código novo, procure componente, service ou util existente que resolva.
- Siga os padrões do projeto atual; na dúvida, imite o módulo vizinho mais parecido.
