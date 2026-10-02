---
name: Gerenciadores de versão (nvm, pyenv, sdkman)
description: Como descobrir, instalar, trocar e ativar versões de Node (nvm), Python (pyenv) e Java/Maven (sdkman) em Linux, macOS e Windows, inclusive em shell não interativo. Use SEMPRE que precisar rodar node, npm, python, java ou maven, ou quando um comando falhar por versão errada de runtime.
---

# Gerenciadores de versão (multiplataforma)

## Passo 0: descubra o ambiente ANTES de rodar qualquer coisa

```bash
uname -s 2>/dev/null || echo Windows   # Linux / Darwin / Windows
node -v; python --version; java -version
```

NUNCA assuma que o runtime do PATH é moderno: é comum o `node` default ser uma versão antiga (ex: v14) que quebra Nest 11+/Next 15+/Vite em silêncio ou com erro de sintaxe confuso. Verifique sempre; o projeto declara o que precisa em `.nvmrc`, `engines` do package.json, `.python-version`, `.sdkmanrc` ou pom.xml.

## Node

### Linux/macOS (nvm)
nvm é função de shell: em sessão não interativa (agente) NÃO está carregado.

```bash
source ~/.nvm/nvm.sh && nvm use 22       # ativa na sessão
ls ~/.nvm/versions/node/                 # ver instaladas
nvm install 22                           # instalar
```

Em scripts, prefira PATH direto (não depende de função de shell):

```bash
export PATH="$HOME/.nvm/versions/node/v22.23.1/bin:$PATH"   # ajuste à versão instalada
```

### Windows (nvm-windows)
Ferramenta diferente do nvm Unix: é executável, sem `source`.

```powershell
nvm list                 # instaladas
nvm use 22.23.1          # troca GLOBAL (afeta todo o sistema; pode pedir admin)
nvm install 22.23.1
```

Alternativas Windows sem nvm: `winget install OpenJS.NodeJS.LTS` ou usar o Node do projeto via `corepack`/volta se existir.

## Python

### Linux/macOS (pyenv)
Shims costumam estar no PATH, então `python` já aponta para a versão do pyenv.

```bash
pyenv versions
pyenv local 3.12         # fixa no projeto (cria .python-version)
pyenv install 3.13
```

### Windows (pyenv-win)
Mesmos comandos (`pyenv versions/local/install`) mas é projeto separado; se não existir, use o Python Launcher nativo: `py -3.12 ...` ou `winget install Python.Python.3.12`.

Em ambos: venv por projeto com `python -m venv .venv` e ative (`source .venv/bin/activate` no Unix, `.venv\Scripts\activate` no Windows).

## Java/Maven

### Linux/macOS (sdkman)
Função de shell: carregue antes em sessão não interativa.

```bash
source "$HOME/.sdkman/bin/sdkman-init.sh"
sdk list java | grep installed
sdk use java 21.0.9-zulu       # na sessão
sdk default java 21.0.9-zulu   # default
sdk env                        # respeita .sdkmanrc do projeto
```

### Windows
sdkman NÃO roda em PowerShell/cmd nativos (só via Git Bash ou WSL). Alternativas nativas: `winget install EclipseAdoptium.Temurin.21.JDK` e ajustar `JAVA_HOME`, ou usar o JDK configurado na IDE. Para Maven, prefira SEMPRE o wrapper do projeto: `./mvnw` (Unix) / `mvnw.cmd` (Windows), que dispensa Maven instalado.

## Regras universais

1. Antes de build/teste: confira a versão exigida pelo projeto e ative-a. Não exigida? Use a LTS mais recente instalada.
2. Erro estranho de sintaxe, engine ou "unsupported class file version"? Primeira suspeita: runtime errado. Rode `node -v`/`python --version`/`java -version` antes de debugar o código.
3. Em scripts e CI, prefira caminho absoluto do binário a depender de função de shell (nvm/sdkman não existem em shell não interativo).
4. Wrappers do projeto (`./mvnw`, `./gradlew`, `corepack`) vencem instalação global: use-os quando existirem.
