---
name: Gerenciadores de versão (nvm, pyenv, sdkman)
description: Como instalar, trocar e ativar versões de Node (nvm), Python (pyenv) e Java/Maven (sdkman) nesta máquina, inclusive em shell não interativo. Use SEMPRE que precisar rodar node, npm, python, java ou maven, ou quando um comando falhar por versão errada de runtime.
---

# Gerenciadores de versão desta máquina

## AVISO CRÍTICO: Node default é v14

O `node`/`npm` do PATH padrão é **v14.21.3** (antigo). Projeto moderno (Nest 11+, Next 15+, Vite) QUEBRA com ele. Sempre ative uma versão adequada antes de qualquer comando node/npm.

## nvm (Node) - versões instaladas: 14, 16, 20, 22, 24

nvm é função de shell: em sessão não interativa (agente) NÃO está carregado. Ative assim:

```bash
source ~/.nvm/nvm.sh && nvm use 22
```

Ou sem nvm, direto no PATH (mais confiável em script):

```bash
export PATH="$HOME/.nvm/versions/node/v22.23.1/bin:$PATH"
```

- Projeto com `.nvmrc`: `nvm use` (sem argumento) respeita o arquivo.
- Instalar nova: `nvm install 24`. Default moderno recomendado: 22 (LTS).

## pyenv (Python) - global: 3.12.11

Os shims já estão no PATH (`~/.pyenv/shims`), então `python` funciona direto e aponta para 3.12.11.

```bash
pyenv versions              # listar
pyenv local 3.12.11         # fixa a versão do projeto (cria .python-version)
pyenv install 3.13          # instalar nova
```

- venv por projeto: `python -m venv .venv && source .venv/bin/activate`.

## sdkman (Java/Maven) - javas: 6, 7, 8, 11, 17, 21, 25

sdkman é função de shell: em sessão não interativa, carregue antes:

```bash
source "$HOME/.sdkman/bin/sdkman-init.sh" && sdk use java 21.0.9-zulu
```

```bash
sdk list java | grep installed   # ver instaladas
sdk use java 11.0.30-zulu        # trocar na sessão
sdk default java 21.0.9-zulu     # trocar o default
sdk env                          # respeita .sdkmanrc do projeto
```

- Projeto lyra usa **Java 11** (11.0.30-zulu). Spring Boot 4+ exige **21+** (21.0.9-zulu instalada).
- Maven também vem do sdkman (`sdk use maven ...`); prefira o wrapper `./mvnw` do projeto quando existir.

## Regra geral

1. Antes de rodar build/teste, confira a versão exigida pelo projeto (.nvmrc, .python-version, .sdkmanrc, engines do package.json, pom.xml).
2. Comando falhou com erro estranho de sintaxe/engine? Primeira suspeita: versão errada do runtime. Verifique com `node -v` / `python --version` / `java -version`.
3. Em scripts, prefira PATH absoluto (ex: `~/.nvm/versions/node/v22.23.1/bin`) a depender de função de shell.
