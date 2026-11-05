---
name: auditoria-seguranca-dast
description: "Auditoria dinâmica de segurança (DAST) em aplicações web locais com OWASP ZAP, Nuclei e Nmap, incluindo spider, AJAX spider, varredura ativa, importação de OpenAPI, testes manuais com curl e relatório consolidado em PDF por severidade. Use SOMENTE quando o usuário solicitar explicitamente, por exemplo: 'Rode a auditoria de segurança', 'Faça um pentest local', 'Execute a varredura DAST', 'Teste de segurança nos frontends e na API'. NUNCA execute automaticamente durante outras tarefas, revisões de código, implementações ou conversas."
---

# Auditoria dinâmica de segurança (DAST)

Executar varredura de segurança contra uma aplicação em execução, consolidando OWASP ZAP, Nuclei, Nmap e testes manuais dirigidos em um relatório único em PDF.

Os scripts citados ficam em `scripts/`, dentro do diretório desta skill, e os modelos de arquivo de entrada em `exemplos/`. Resolva esses caminhos a partir da pasta da skill, nunca do projeto auditado. Toda saída intermediária vai para um diretório de trabalho fora do projeto.

## Regras de execução

Esta skill só roda quando o usuário solicita explicitamente. Varredura ativa envia tráfego de ataque real e pode criar, alterar ou apagar dados. Nunca a dispare por iniciativa própria.

1. **Apenas alvos locais** (localhost, 127.0.0.1, serviços do próprio usuário). Alvo de terceiros exige autorização por escrito do dono do sistema, registrada antes de qualquer varredura.
2. **Não corrija nada durante a auditoria.** Reporte os achados. Correção é um segundo pedido, com autorização separada.
3. **Pare e pergunte** antes de qualquer ação que possa destruir dados, expor serviços na rede ou exigir decisão do usuário.
4. **Nunca inclua segredos no relatório**: senha, token, chave de API, conteúdo de `.env`, credencial de teste. Cite nomes de variáveis, nunca valores.
5. Se a varredura revelar um mecanismo que o usuário já declarou intencional, não o reporte como falha nem o cite no relatório.

## Fase 1: reconhecimento

Antes de subir qualquer ferramenta, levante:

1. **Alvos e portas.** Leia `package.json` (scripts `start`), os `environment*.ts` dos frontends e o `main.ts` ou equivalente do backend. Registre a porta de cada alvo.
2. **Versão do runtime.** Para projetos Node, a versão vem do `.gitlab-ci.yml` ou `.github/workflows`, não do default do nvm. Use `nvm use <versão>` antes de qualquer npm.
3. **Portas em uso:** `ss -ltn`. Anote o que já está no ar e em qual interface. Um serviço em `0.0.0.0` ou `*` já é um achado de exposição.
4. **Superfície da API.** Suba o backend e extraia as rotas do log de inicialização. Em NestJS:
   `grep -oP "Mapped \{\K[^}]+" backend.log | sort -u`
   Separe as rotas GET sem parâmetro de caminho: são as candidatas seguras para popular a árvore do scanner.
5. **OpenAPI.** Procure o endpoint JSON do Swagger (`/api/<prefixo>-json`). Se existir, ele vira entrada do ZAP.

## Fase 2: ferramentas

Verifique o que está instalado:

```bash
which nmap nuclei zap.sh zaproxy; docker info >/dev/null 2>&1 && echo "docker ok"
```

Faltando alguma, **pergunte ao usuário** como obtê-la, oferecendo três caminhos: via Docker (não precisa de sudo, mas baixa imagens), instalação no sistema (precisa de sudo) ou seguir sem baixar nada (só curl e `ss`, cobertura bem menor).

Imagens usadas na via Docker:

| Ferramenta | Imagem |
|---|---|
| OWASP ZAP | `zaproxy/zap-stable` |
| Nuclei | `projectdiscovery/nuclei` |
| Nmap | `uzyexe/nmap` ou `instrumentisica/nmap` |

### Armadilhas do Docker Desktop

Verifique o contexto: `docker context ls`. Se for `desktop-linux`, o daemon roda numa VM e as regras abaixo valem.

- `--network host` é a rede **da VM**, não a do seu host. Containers não enxergam `127.0.0.1` do host.
- Use `--add-host=host.docker.internal:host-gateway` e aponte os alvos para `http://host.docker.internal:<porta>`.
- Só serviços bindados em `0.0.0.0` são alcançáveis assim. Um serviço em `127.0.0.1` precisa ser rebindado para a varredura.
- Volumes em `/tmp` são recusados ("path is not shared from the host"). Para tirar saída do container, use stdout (`> arquivo.jsonl`); para colocar arquivo dentro, use `docker cp`.

## Fase 3: Nmap

```bash
docker run --rm --cap-add=NET_RAW --cap-add=NET_ADMIN \
  --add-host=host.docker.internal:host-gateway uzyexe/nmap \
  -Pn -sS -sV -p 1-10000 host.docker.internal
```

Sem `--cap-add=NET_RAW` todas as portas voltam como `filtered`.

Esse scan mostra o que está exposto **fora do loopback**, que é exatamente a pergunta de exposição. Complemente com `ss -ltn` no host para a visão de loopback. Banco de dados aparecendo aqui é achado alto.

## Fase 4: Nuclei

Um por alvo, capturando JSON em stdout:

```bash
docker run --rm --add-host=host.docker.internal:host-gateway \
  projectdiscovery/nuclei:latest \
  -u http://host.docker.internal:<porta> -jsonl -silent -timeout 10 > nuclei-<alvo>.jsonl
```

Zero achados em um alvo que responde 200 geralmente significa que o container não alcançou o serviço. Confirme com um curl de dentro de um container antes de aceitar o resultado.

## Fase 5: OWASP ZAP

Suba o daemon com memória folgada e a regra de DOM XSS desligada:

```bash
docker run -d --name zapd -m 5g -e JAVA_OPTS="-Xmx3500m" \
  --add-host=host.docker.internal:host-gateway -p 127.0.0.1:8090:8080 \
  zaproxy/zap-stable zap.sh -daemon -host 0.0.0.0 -port 8080 \
  -config api.disablekey=true -config api.addrs.addr.name=.* -config api.addrs.addr.regex=true
```

Dois pontos que travam quem nunca rodou isso:

- **A API REST só responde com o header `Host: zap`.** Sem ele o ZAP trata a chamada como requisição de proxy e devolve connection refused.
  `curl -H "Host: zap" http://127.0.0.1:8090/JSON/core/view/version/`
- **`DomXssScanRule` (id 40026) abre navegadores headless e estoura a memória**, derrubando o container com exit 137. Desligue antes de varrer:
  `curl -H "Host: zap" "http://127.0.0.1:8090/JSON/ascan/action/disableScanners/?ids=40026"`
  Registre no relatório que XSS baseado em DOM ficou fora da cobertura.

Rode o driver, que faz acesso inicial, contexto, spider, AJAX spider, drenagem do passive scan, varredura ativa e exportação:

```bash
scripts/zap-scan.sh <nome> http://host.docker.internal:<porta> [ajax]
```

Use `ajax` nos frontends SPA (Angular, React, Vue) e omita na API.

### API com OpenAPI

Antes de varrer o backend, **pergunte ao usuário** se pode disparar PATCH, PUT e DELETE reais contra a base. O padrão recomendado é limitar a GET e POST.

Para limitar, filtre a spec e importe a versão filtrada:

```bash
scripts/filtrar-openapi.py openapi.json openapi-filtrado.json http://host.docker.internal:3000
docker cp openapi-filtrado.json zapd:/zap/openapi-filtrado.json
curl -H "Host: zap" "http://127.0.0.1:8090/JSON/openapi/action/importFile/?file=/zap/openapi-filtrado.json&target=<alvo-urlencoded>"
```

O Swagger costuma cobrir só um módulo. Para alcançar o resto da API, adicione as rotas GET levantadas na fase 1 à árvore do ZAP com `/JSON/core/action/accessUrl/` antes da varredura ativa. O script `zap-api.sh` faz isso lendo um arquivo com uma rota por linha.

## Fase 6: testes manuais dirigidos

As ferramentas não entendem a lógica de negócio. Faça sempre, com curl:

1. **Rotas sem autenticação.** Percorra todas as rotas GET sem token e separe as que respondem 2xx. Para cada uma, inspecione as **chaves** do payload, nunca os valores, procurando dado pessoal: nome, email, telefone, CPF, endereço, data de nascimento.
2. **Cabeçalhos.** `curl -s -D - -o /dev/null <alvo>`: procure ausência de CSP, HSTS, X-Frame-Options, X-Content-Type-Options e presença de X-Powered-By.
3. **CORS.** Repita com `-H "Origin: http://evil.localhost"` e veja se o `Access-Control-Allow-Origin` reflete ou devolve curinga.
4. **Limite de tentativas.** Doze POST seguidos no login com credencial inválida. Se não aparecer 429, é achado. Se aparecer, registre como controle positivo no relatório.
5. **Documentação exposta.** O Swagger responde sem autenticação?

Controles que passaram no teste entram no relatório como item informativo. O usuário precisa saber o que foi verificado e está correto, não só o que falhou.

## Fase 7: área autenticada

Pergunte as credenciais de teste no começo, não no fim. Ofereça: o usuário informa, você cria usuários de teste a partir dos seeds do projeto, ou a varredura cobre só a área pública.

Sem credenciais, declare a limitação em destaque no relatório, dizendo quantas rotas responderam 401 e ficaram sem exercício. Controle de acesso entre papéis e IDOR só saem da segunda passada.

## Fase 8: relatório

```bash
scripts/gerar-relatorio.py <diretório-de-saída>
scripts/html-para-pdf.sh <diretório>/relatorio.html relatorio-seguranca-<projeto>-<AAAA-MM-DD>.pdf
```

O gerador espera encontrar no diretório: `nuclei-<alvo>.jsonl`, `zap-<alvo>.json`, `nmap-host.txt`, `comandos.txt` e `achados-manuais.json`. Os nomes de alvo e seus rótulos vêm de `alvos.json`.

Estrutura do relatório:

1. Resumo executivo com contagem por severidade e as duas frases que dizem onde está o risco real
2. Distribuição por alvo
3. Escopo e limitações, em destaque
4. Achados detalhados, agrupados por severidade: alvo, endpoint, parâmetro, origem, descrição, evidência, recomendação
5. Apêndice A com a saída do Nmap
6. Apêndice B com comandos, versões e limitações

### Qualidade do texto

- **Nunca use o caractere travessão.**
- Escreva em português com acentuação correta. Rode `scripts/acentuar.py` sobre os arquivos de conteúdo e confira o resultado: ele não acentua URLs nem comandos, mas revise o apêndice mesmo assim, porque uma rota acentuada por engano quebra o comando que o usuário vai copiar.
- Traduza os alertas das ferramentas. `scripts/traducoes.py` traz os verbetes recorrentes do ZAP e do Nuclei. Alerta sem verbete cai no texto original em inglês, então vale acrescentar o verbete novo ao arquivo.
- Nas URLs dos achados, troque `host.docker.internal` pelo endereço que o usuário reconhece (`127.0.0.1`). Nos apêndices, preserve o comando como foi executado.
- Marque com uma linha de contexto todo achado que é artefato do servidor de desenvolvimento e não do produto: listagem de diretório, IP privado no bundle, ausência de TLS, comentários TODO. Dizer que precisa ser reconfirmado sobre o build de produção vale mais do que inflar a contagem.
- Agrupe instâncias do mesmo alerta em um achado só, informando quantas foram.

## Encerramento

1. Remova o container do ZAP: `docker rm -f zapd`.
2. Diga quais servidores ficaram no ar e quais você subiu.
3. Se derrubou algum processo do usuário durante a preparação, avise.
4. Entregue o PDF e ofereça a segunda passada autenticada.

## Erros conhecidos

| Sintoma | Causa | Saída |
|---|---|---|
| ZAP sai com código 137 | OOM na regra de DOM XSS | `-m 5g` e desabilitar o id 40026 |
| API do ZAP recusa conexão | Falta o header `Host: zap` | Enviar o header em toda chamada |
| Nmap devolve tudo `filtered` | Container sem raw socket | `--cap-add=NET_RAW --cap-add=NET_ADMIN` |
| `mounts denied` no docker run | Docker Desktop não compartilha `/tmp` | stdout para sair, `docker cp` para entrar |
| Nuclei com zero achados | Container não alcança o alvo | Testar com curl de dentro de um container |
| `ERR_OSSL_EVP_UNSUPPORTED` no Angular | Webpack antigo com OpenSSL 3 | `NODE_OPTIONS=--openssl-legacy-provider` |
| Apêndice do relatório vazio | `open(p,"w")` truncou antes do read | Ler o arquivo inteiro antes de abrir para escrita |
| `pkill -f <padrão>` mata a própria sessão | O padrão casa a linha do shell que o executa | Matar por PID, ou por porta com `ss -ltnp` |
