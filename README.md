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

**`global/skills/`**, padrões por stack e fluxos de trabalho (carregadas quando a tarefa bate com a descrição):

| Skill | Base |
|---|---|
| `ionic` | Ionic React + Vite + Capacitor + Rematch (arquitetura superapp-sicar) |
| `nextjs` | Next 16 App Router + next-auth + RHF/zod + Tailwind 4 (arquitetura santander-solar-front) |
| `nestjs` | NestJS 11 + TypeORM + PostgreSQL + Liquibase, módulos em português (arquitetura santander-solar-api) |
| `java-spring` | Hexagonal por usecase em fatias verticais (arquitetura lyra), modernizada para Spring Boot 4+ |
| `angular` | Angular 22+: signals, zoneless, standalone, Signal Forms |
| `fastapi` | Pydantic v2, SQLAlchemy 2, router por domínio, DI com Depends |
| `version-managers` | nvm, pyenv e sdkman em Linux, macOS e Windows: descoberta do ambiente, ativação em shell não interativo e alternativas nativas por SO |
| `browseros-neo` | Browser real dedicado a agentes (BrowserOS neo via MCP): logins vivos, perfil persistente, loop snapshot→act→verify. Skill da comunidade, em inglês |
| `regras-de-resposta` | Regras permanentes de concisão, precisão e formato para todas as respostas (teto de 2.000 caracteres, sem U+2014, direto ao ponto) |
| `auditoria-pre-publicacao` | Conformidade antes de publicar: privacidade, LGPD, cookies, acessibilidade WCAG 2.2 AA, transparência comercial. Checklist de 17 requisitos e parecer final. Só roda sob pedido explícito |
| `auditoria-seguranca-dast` | Varredura dinâmica de segurança em alvo local com OWASP ZAP, Nuclei e Nmap, mais testes manuais com curl e relatório em PDF por severidade. Traz `scripts/` próprios. Só roda sob pedido explícito |
| `publicar-lojas-capacitor` | Publicação automática nas lojas em apps Capacitor (padrão validado no AoVivinho): tag `v*` publica Android na faixa interna e iOS no TestFlight; push em branch não faz nada. Traz `templates/` (workflows, Fastfiles, Matchfile, scheme) com placeholders `{{BUNDLE_ID}}`/`{{TEAM_ID}}`/`{{ORG}}`/`{{CERT_REPO}}`. Uso: no projeto Capacitor, peça "configure a publicação automática nas lojas" e informe bundle id, org, repo de certificados e Team ID; o agente monta arquivos e workflows e te passa o checklist de contas/secrets (guia narrativo em `contrictor/docs-uteis/README-CI.md`) |

**`global/commands/`**:

| Command | O que faz |
|---|---|
| `/entregar <tarefa>` | Implementa com loop de correção: verifica (typecheck → build → testes → execução real), corrige e repete até passar (máx. 5 ciclos), depois valida com `revisor` e `tester`. Essencial com modelos locais, que tendem a entregar sem iterar |

**MCPs de browser** (no `opencode.jsonc.example`), papéis distintos:

| MCP | Papel | Default |
|---|---|---|
| `browseros-neo` | Browser real do usuário para agentes (logins, perfil persistente). Preferir para qualquer tarefa de site. ATENÇÃO: a porta do endpoint muda entre builds do BrowserOS; confira na página MCP dele | ligado (desligue no global se pesar nos modelos menores) |
| `playwright` | Automação limpa SEM perfil/logins: testes de UI isolados e benchmark headless | desligado; ligue por projeto |

**`global/tools/pdf.ts`**: tools `pdf_text` (extrai texto de PDF digital) e `pdf_pages` (converte páginas em PNG para modelos com visão). Requer `poppler-utils`.

**Compressão de contexto ([billion-context](https://github.com/ranxianglei/billion-context))**: proxy que comprime a conversa consumida em resumos incrementais e reversíveis, decididos pelo próprio modelo (tools `compress`/`decompress`/`search_context`/`acp_status`, painel `/acp`). Especialmente útil com modelos locais de contexto pequeno (32-61k): a sessão não morre ao estourar a janela. O `opencode.jsonc.example` já registra o plugin e desliga a `compaction.auto` nativa (o bili passa a ser o dono da compressão). Instalação por máquina (node >= 20):

```bash
npm install -g billion-context --prefix=~/.local
bili plugin install opencode
```

Também funciona no Claude Code (`bili plugin install claude`) e em outros clients; ver [CLIENTS.md](https://github.com/ranxianglei/billion-context/blob/master/CLIENTS.md). Atenção: a aba Code do Claude Desktop ignora o proxy (issue #2290); só sessões de terminal são comprimidas.

## Acesso remoto (`opencode web`)

Para usar o opencode pelo navegador (inclusive do celular):

```bash
OPENCODE_SERVER_PASSWORD=<senha-forte> opencode web --port 4096 --hostname 0.0.0.0
```

```bash
ngrok http 4096
```

Abra a URL do ngrok no navegador e informe usuário `opencode` + a senha.

**Segurança (obrigatório):**

- A variável é `OPENCODE_SERVER_PASSWORD`. `OPENCODE_PASSWORD` NÃO existe e é ignorada silenciosamente: o servidor sobe **sem autenticação nenhuma** (testado na 1.19.5). Como o servidor executa comandos na máquina, nunca exponha túnel sem essa variável setada e com senha longa.
- O aviso `OPENCODE_SERVER_PASSWORD is not set; server is unsecured` no startup é literal: se apareceu, não abra túnel.

**Escolha do túnel** (o web UI recebe tudo em tempo real por SSE em `/global/event`; túnel que bufferiza SSE congela a tela em "Pensando" e os modais de permissão só aparecem com F5):

| Túnel | Tempo real | Observação |
|---|---|---|
| `ngrok http 4096` | funciona | Testado; eventos chegam ao vivo |
| Cloudflare Quick Tunnel (`cloudflared tunnel --url`) | NÃO funciona | [Limitação documentada](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/do-more-with-tunnels/trycloudflare/): Quick Tunnels não suportam SSE. Não é bug do opencode |
| Cloudflare Named Tunnel | funciona | Requer domínio na Cloudflare |
| Tailscale/WireGuard | funciona | Mais seguro: nada fica público |

Para testar se um túnel entrega SSE em tempo real (esperado: `server.connected` imediato + `server.heartbeat` a cada 10s; nada em 25s = túnel bufferiza):

```bash
curl -sN -u "opencode:<senha>" https://<url-do-tunel>/global/event | while IFS= read -r l; do echo "[$(date +%T)] $l"; done
```

## Guia de bolso: qual modelo usar

Baseado em medição própria (ver [bench/](bench/)), não em opinião:

| Situação | Modelo | Por quê |
|---|---|---|
| Tarefa autônoma SEM rede de proteção | `qwen27` (thinking) | 6/6 em 2/2 rodadas; é o seguro contra a falha silenciosa |
| Tarefa autônoma COM verificação (`/entregar`, CI, testes) | `qwen27-fast` | 6/6 em 2/3 rodadas e 2-4x mais rápido; a verificação pega o 1/3 que desiste cedo e basta re-rodar |
| Dev interativo, humano revisando | `coder` | 4/6 em 497s, direto, sem token de raciocínio |
| Browser (BrowserOS/Playwright) e tarefas mecânicas | `coder` ou `qwen27-fast` | Thinking em browser = 30k tokens para abrir uma página |
| Pergunta rápida, tarefa de um passo | `qwen9` (Q8+MTP) | 135 tok/s com 4/6 de qualidade |
| Visão (imagem, PDF escaneado) | `gemma12-vis` ou `qwen27-vis` | Únicos com mmproj ativo |

Regra de ouro medida: **thinking compra consistência, não capacidade. Sem rede de proteção = thinking; com verificação automática ou humano no loop = modelo direto.**

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

A skill pode levar arquivos de apoio no mesmo diretório (`scripts/`, `exemplos/`, referências). O `install.sh` copia a pasta inteira, então o SKILL.md referencia esses arquivos por caminho relativo à própria skill. Tire do SKILL.md o que for procedimento longo ou código repetido e deixe no script: o markdown é contexto carregado, o script não.

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
- [billion-context](https://github.com/ranxianglei/billion-context) (compressão de contexto)
