# opencode-template

Template para codar com IA no [opencode v2](https://opencode.ai/v2/docs): scaffold de projeto novo, kit mínimo por projeto e a configuração global compartilhável (agentes, skills e tools).

## Começar um projeto novo (blank)

```bash
./new-project.sh meu-app            # cria ~/projetos/meu-app
./new-project.sh meu-app ~/clientes # cria ~/clientes/meu-app
```

O script copia o kit do template, cria `.gitignore` e inicia o git com o primeiro commit. Fluxo depois disso:

1. `cd meu-app && opencode`
2. Descreva o que quer construir.
3. Quando houver código, rode `/init` para o `AGENTS.md` ser preenchido a partir do repositório real.
4. `@skill-gen` para gerar as skills do projeto quando ele tomar forma.

## O kit mínimo de cada projeto

| Arquivo | Papel |
|---|---|
| `AGENTS.md` | Contrato do projeto: stack, comandos reais, arquitetura, convenções e verificação antes de concluir |
| `opencode.jsonc` | Permissões do projeto (deny em `.env`, `git push`, `rm -rf`; ask no bash) e overrides |
|  `.opencode/agents/` | `bug-hunter` (caça bugs no diff); planejamento usa o agente nativo `plan` |
| `.opencode/commands/` | `/plano`, `/test`, `/commit`, `/team/review` |
| `.opencode/skills/` | Fluxos do projeto (release incluída; gere as demais com `@skill-gen`) |

O template não fixa modelo: o projeto herda o default global. Para fixar, descomente `model` no `opencode.jsonc`.

## Configuração global compartilhável (`global/`)

Tudo que vale para TODOS os projetos fica em `~/.config/opencode`. A pasta [`global/`](global/) deste repositório versiona esses arquivos para o time. Instalação:

```bash
./global/install.sh
```

O script faz backup do que sobrescrever e nunca troca seu `opencode.jsonc` existente (instala só o `.example`; ajuste providers/modelos para a sua máquina).

### O que vem dentro

**`global/AGENTS.md`**: regras de comportamento para todo agente, incluindo a disciplina de workspace (nunca sair do projeto, nunca trocar a stack pedida por causa de erro, build/typecheck limpos antes de concluir, import só para arquivo que existe) e o fluxo de subagents com dono único por responsabilidade.

**`global/agents/`**, cada um com trava de escrita:

| Agente | Responsabilidade (dono único) |
|---|---|
| `revisor` | O pedido foi cumprido? Compara requisito a requisito, veredito APROVADO/REPROVADO |
| `tester` | Funciona de verdade? Dono exclusivo da execução de testes (suíte, manual, e2e) |
| `qualidade` | Lint, tipos e análise estática do que mudou (não roda testes) |
| `arquiteto` | Modo ORIENTAR (antes: onde criar, o que imitar, o que reutilizar) e REVISAR (depois: conformidade) |
| `skill-gen` | Lê o projeto e gera as skills que faltam em `.opencode/skills/` (só escreve lá) |

Fluxo: mudança pequena (1-2 arquivos) implementa direto e valida com `tester`; mudança média/grande consulta `arquiteto` antes e valida com `revisor` → `tester` → `qualidade` → `arquiteto` depois.

**`global/skills/`**, padrões por stack (carregadas quando a tarefa bate com a descrição):

| Skill | Base |
|---|---|
| `ionic` | Ionic React + Vite + Capacitor + Rematch (arquitetura superapp-sicar) |
| `nextjs` | Next 16 App Router + next-auth + RHF/zod + Tailwind 4 (arquitetura santander-solar-front) |
| `nestjs` | NestJS 11 + TypeORM + PostgreSQL + Liquibase, módulos em português (arquitetura santander-solar-api) |
| `java-spring` | Hexagonal por usecase em fatias verticais (arquitetura lyra), modernizada para Spring Boot 4+ |
| `angular` | Angular 22+: signals, zoneless, standalone, Signal Forms |
| `fastapi` | Pydantic v2, SQLAlchemy 2, router por domínio, DI com Depends |
| `version-managers` | nvm, pyenv e sdkman em Linux, macOS e Windows: descoberta do ambiente, ativação em shell não interativo e alternativas nativas por SO |

**`global/commands/`**:

| Command | O que faz |
|---|---|
| `/entregar <tarefa>` | Implementa com loop de correção: verifica (typecheck → build → testes → execução real), corrige e repete até passar (máx. 5 ciclos), depois valida com `revisor` e `tester`. Essencial com modelos locais, que tendem a entregar sem iterar |

**`global/tools/pdf.ts`**: tools `pdf_text` (extrai texto de PDF digital) e `pdf_pages` (converte páginas em PNG para modelos com visão). Requer `poppler-utils`.

## Benchmark de modelos locais

A pasta [`bench/`](bench/) traz o harness completo para medir se um modelo local serve como agente (placar automático de 6 critérios), os resultados já obtidos e as lições do ciclo de melhoria. Ver [bench/README.md](bench/README.md).

## Referência opencode v2

### AGENTS.md

Único arquivo de regras do v2 (não lê `CLAUDE.md`). Descoberta hierárquica com merge: `~/.config/opencode/AGENTS.md` → raiz do projeto → pastas intermediárias → diretório atual. Gere com `/init`. Desativar descoberta de projeto: `OPENCODE_DISABLE_PROJECT_CONFIG=1`.

### opencode.jsonc

Precedência crescente: global → `projeto/opencode.jsonc` → `projeto/.opencode/opencode.jsonc`. A busca sobe da pasta atual até a raiz com merge.

### Permissions (formato válido do schema)

`permission` é um objeto: chave = ação (`read`, `edit`, `glob`, `grep`, `bash`, `webfetch`, `external_directory`, ...), valor = `"allow" | "ask" | "deny"` ou um objeto padrão → efeito:

```jsonc
"permission": {
  "edit": { "*": "allow", ".env*": "deny" },
  "bash": { "*": "ask", "git status*": "allow", "git push*": "deny" }
}
```

Atenção: o formato em array `[{ action, resource, effect }]` NÃO existe no schema; regras nesse formato são ignoradas silenciosamente.

### Agentes

`~/.config/opencode/agents/<nome>.md` (global) ou  `.opencode/agents/` (projeto). Markdown com frontmatter (`description`, `mode: primary|subagent|all`, `tools`, `permission`, `model`); o corpo é o system prompt.

### Commands

`~/.config/opencode/commands/` ou `.opencode/commands/`. Caminho aninhado vira nome com `/` (`team/review.md` → `/team/review`). Frontmatter: `template`, `description`, `agent`, `model`, `subagent`. Argumentos: `$ARGUMENTS`, `$1`, `$2`...

### Skills

`SKILL.md` em `<fonte>/skills/<id>/`. O ID vem do caminho. `description` é obrigatória e é o gatilho de carregamento: escreva com as palavras que o pedido usaria.

### Tools customizadas

Arquivos `.ts` em `~/.config/opencode/tools/` (global) ou `.opencode/tools/` (projeto), usando `tool()` de `@opencode-ai/plugin`. O nome do arquivo vira o nome da tool; exports nomeados viram `<arquivo>_<export>`.

### MCP e Plugins

```bash
opencode mcp add context7 --url https://mcp.context7.com/mcp
opencode plugin add <pkg>
```

MCP local roda sobre stdio; remoto usa Streamable HTTP com OAuth/PKCE. `"disabled": true` mantém configurado sem conectar.

## Ordem sugerida de adoção

1. `./global/install.sh` (uma vez por máquina)
2. `./new-project.sh <nome>` para cada projeto novo
3. `AGENTS.md` do projeto preenchido via `/init`, commitado
4. Commands do dia a dia, depois skills do projeto via `@skill-gen`
5. MCP quando precisar de fonte externa

## Fontes

- [Instructions (AGENTS.md)](https://opencode.ai/v2/docs/instructions/)
- [Config](https://opencode.ai/v2/docs/config)
- [Agents](https://opencode.ai/v2/docs/agents/)
- [Commands](https://opencode.ai/v2/docs/commands)
- [Permissions](https://opencode.ai/v2/docs/permissions/)
- [Skills](https://opencode.ai/v2/docs/skills/)
- [Custom Tools](https://opencode.ai/v2/docs/custom-tools/)
- [MCP Servers](https://opencode.ai/v2/docs/mcp-servers)
- [Plugins](https://opencode.ai/v2/docs/plugins)
