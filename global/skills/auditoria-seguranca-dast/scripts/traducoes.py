#!/usr/bin/env python3
# Verbetes em portugues para os alertas recorrentes do OWASP ZAP e do Nuclei.
# Chave: titulo original da ferramenta. Campos: titulo, descricao, recomendacao e,
# quando o achado costuma ser artefato do ambiente de teste, nota.
# Alerta sem verbete aqui cai no texto original em ingles. Acrescente os que faltarem.

PT = {
    "Vulnerable JS Library": {
        "titulo": "Biblioteca JavaScript com vulnerabilidade conhecida",
        "descricao": "O bundle servido ao navegador carrega uma biblioteca em versão com falha publicada. "
        "O ZAP identifica a versão pela assinatura no próprio arquivo e cruza com o catálogo Retire.js.",
        "recomendacao": "Atualizar a dependência para a versão corrigida indicada na evidência e reconstruir o bundle. "
        "Incluir uma verificação de dependências vulneráveis no pipeline para pegar o próximo caso antes do deploy.",
    },
    "Cross-Domain Misconfiguration": {
        "titulo": "Política de origem cruzada permissiva",
        "descricao": "A resposta traz Access-Control-Allow-Origin com curinga, o que autoriza qualquer site a ler o "
        "conteúdo a partir do navegador de quem estiver autenticado. Em conjunto com rotas que devolvem dados sem "
        "token, isso permite que uma página de terceiros colete os dados da aplicação.",
        "recomendacao": "Trocar o curinga por uma lista explícita de origens por ambiente, mantida em variável de ambiente.",
    },
    "Missing Anti-clickjacking Header": {
        "titulo": "Proteção contra clickjacking ausente",
        "descricao": "A resposta não traz X-Frame-Options nem a diretiva frame-ancestors em uma política de segurança "
        "de conteúdo. Sem isso, a página pode ser embutida em um iframe invisível sobre um site controlado pelo "
        "atacante, que induz o usuário a clicar em ações reais sem perceber.",
        "recomendacao": "Definir frame-ancestors 'none' na política de segurança de conteúdo, ou enviar X-Frame-Options DENY.",
    },
    "Content Security Policy (CSP) Header Not Set": {
        "titulo": "Política de segurança de conteúdo não definida",
        "descricao": "Nenhuma das respostas define Content-Security-Policy. Essa política é a principal defesa em "
        "profundidade contra XSS: ela restringe de onde scripts, estilos e imagens podem ser carregados e bloqueia "
        "execução inline. Sem ela, qualquer falha de injeção vira execução de script completa.",
        "recomendacao": "Publicar uma política restritiva, começando por default-src 'self' e liberando apenas as origens "
        "realmente usadas. Subir primeiro em modo de relatório com Content-Security-Policy-Report-Only para medir o impacto.",
    },
    "CSP: Failure to Define Directive with No Fallback": {
        "titulo": "Política de segurança de conteúdo sem diretivas de fallback",
        "descricao": "A política encontrada não define diretivas que não herdam de default-src, como frame-ancestors e "
        "form-action. O resultado é que esses vetores ficam liberados mesmo com uma política aparentemente presente.",
        "recomendacao": "Declarar explicitamente frame-ancestors, form-action e base-uri, sem contar com herança de default-src.",
    },
    "HTTP Only Site": {
        "titulo": "Alvo atendido apenas em HTTP",
        "descricao": "O alvo respondeu em HTTP sem TLS. Tráfego em texto claro expõe token de sessão e dados pessoais a "
        "qualquer um no caminho de rede.",
        "recomendacao": "Garantir TLS obrigatório no ambiente real, com redirecionamento de HTTP para HTTPS e HSTS com "
        "max-age de pelo menos um ano. Marcar os cookies de sessão como Secure.",
        "nota": "Esperado quando a auditoria roda em HTTP local sem TLS. O que precisa ser verificado no ambiente real é "
        "se existe HSTS e redirecionamento obrigatório para HTTPS.",
    },
    "Directory Browsing": {
        "titulo": "Listagem de diretório habilitada",
        "descricao": "O servidor devolve o índice do diretório em vez de negar o acesso. Isso entrega a estrutura de "
        "arquivos da aplicação e facilita encontrar arquivos que não deveriam estar públicos.",
        "recomendacao": "Desligar a listagem de diretório no servidor que atende o build de produção e devolver 404 para "
        "caminhos que não correspondem a um arquivo conhecido.",
        "nota": "Costuma ser artefato do servidor de desenvolvimento, que lista diretórios. O build de produção servido "
        "por um servidor estático não se comporta assim. Confirmar na configuração do ambiente real.",
    },
    'Server Leaks Information via "X-Powered-By" HTTP Response Header Field(s)': {
        "titulo": "Cabeçalho X-Powered-By revela a stack do servidor",
        "descricao": "A resposta anuncia o framework que atende a requisição. O dado isolado tem pouco valor, mas reduz "
        "o trabalho de quem procura exploits específicos de versão.",
        "recomendacao": "Desabilitar o cabeçalho no servidor de aplicação. Em Express, disable('x-powered-by') ou helmet.",
    },
    "X-Content-Type-Options Header Missing": {
        "titulo": "Cabeçalho X-Content-Type-Options ausente",
        "descricao": "Sem nosniff, o navegador pode ignorar o Content-Type declarado e interpretar o conteúdo por "
        "adivinhação. Um arquivo enviado por usuário pode acabar executado como script.",
        "recomendacao": "Enviar X-Content-Type-Options: nosniff em todas as respostas, principalmente nas que servem "
        "arquivos enviados por usuários.",
    },
    "Timestamp Disclosure - Unix": {
        "titulo": "Possível exposição de marca de tempo",
        "descricao": "Foi encontrada uma sequência numérica compatível com um timestamp Unix no corpo da resposta.",
        "recomendacao": "Conferir a ocorrência antes de tratar como achado.",
        "nota": "Alta taxa de falso positivo. O ZAP marca qualquer sequência numérica com formato de epoch, inclusive "
        "hashes e identificadores de bundle.",
    },
    "Private IP Disclosure": {
        "titulo": "Endereço de rede interna exposto na resposta",
        "descricao": "O corpo da resposta contém um endereço IP de faixa privada, o que entrega detalhe da topologia interna.",
        "recomendacao": "Verificar se o endereço aparece também no build de produção. Se aparecer, remover o valor fixo do "
        "código e passar a configuração por variável de ambiente.",
        "nota": "Decorrente do bundle de desenvolvimento, que carrega endereços locais. Reavaliar sobre o build de produção.",
    },
    "Modern Web Application": {
        "titulo": "Aplicação de página única detectada",
        "descricao": "Item informativo. O ZAP registra que o alvo usa JavaScript para montar a navegação, o que limita o "
        "alcance do spider tradicional e justifica o uso do AJAX spider.",
        "recomendacao": "Nenhuma ação. Registrado apenas para explicar a estratégia de varredura usada.",
        "nota": "Item informativo. Apenas registra que o alvo é uma aplicação de página única.",
    },
    "Information Disclosure - Suspicious Comments": {
        "titulo": "Comentários suspeitos no código entregue ao navegador",
        "descricao": "O bundle contém comentários com palavras como TODO, FIXME ou BUG. Eles podem revelar trechos "
        "incompletos, decisões de implementação ou caminhos internos.",
        "recomendacao": "Remover comentários de desenvolvimento no build de produção.",
    },
    "User Agent Fuzzer": {
        "titulo": "Resposta varia conforme o user agent",
        "descricao": "Item informativo. A aplicação devolveu respostas diferentes para user agents distintos durante o teste.",
        "recomendacao": "Nenhuma ação necessária, a menos que a variação esconda conteúdo que deveria ser igual para todos.",
        "nota": "Item informativo. Registra que a aplicação respondeu de forma diferente a user agents distintos.",
    },
    "Re-examine Cache-control Directives": {
        "titulo": "Diretivas de cache merecem revisão",
        "descricao": "A resposta não define diretivas de cache que impeçam o armazenamento de conteúdo sensível em "
        "proxies ou no próprio navegador.",
        "recomendacao": "Enviar Cache-Control: no-store nas respostas que carregam dados pessoais ou token de sessão.",
    },
    "Hidden File Found": {
        "titulo": "Arquivo oculto acessível",
        "descricao": "Um caminho que normalmente não deveria estar público respondeu com sucesso.",
        "recomendacao": "Conferir o conteúdo do arquivo e bloquear o acesso no servidor que atende o build de produção.",
    },
    "Absence of Anti-CSRF Tokens": {
        "titulo": "Formulário sem token anti-CSRF",
        "descricao": "O ZAP encontrou um formulário sem campo de token anti-CSRF. Em aplicações que autenticam por cookie, "
        "isso permite que um site de terceiros submeta ações em nome do usuário logado.",
        "recomendacao": "Adicionar token anti-CSRF nos formulários que alteram estado, ou confirmar que a autenticação usa "
        "apenas cabeçalho Authorization, caso em que o risco não se aplica e o achado pode ser encerrado como não aplicável.",
    },
    "Session ID in URL Rewrite": {
        "titulo": "Identificador de sessão na URL",
        "descricao": "Um identificador de sessão apareceu na URL. URLs vazam por histórico do navegador, cabeçalho Referer "
        "e logs de servidor e de proxy.",
        "recomendacao": "Transportar a sessão apenas em cookie com os atributos HttpOnly, Secure e SameSite, ou em cabeçalho "
        "Authorization.",
    },
    # Nuclei
    "HTTP Missing Security Headers": {
        "titulo": "Cabeçalhos de segurança ausentes",
        "descricao": "O Nuclei confirmou a ausência de um conjunto de cabeçalhos de defesa nas respostas, entre eles "
        "Content-Security-Policy, Strict-Transport-Security, X-Frame-Options, X-Content-Type-Options, Referrer-Policy e "
        "Permissions-Policy. Cada ocorrência na evidência corresponde a um cabeçalho faltante.",
        "recomendacao": "Aplicar helmet ou equivalente no backend e configurar o mesmo conjunto de cabeçalhos no servidor "
        "estático que atende os frontends em produção.",
    },
    "Wappalyzer Technology Detection": {
        "titulo": "Tecnologias identificadas por impressão digital",
        "descricao": "Item informativo. O Nuclei identificou as tecnologias do alvo a partir de cabeçalhos e do conteúdo "
        "da resposta.",
        "recomendacao": "Nenhuma ação direta. Reduzir a superfície de identificação removendo cabeçalhos que anunciam o framework.",
    },
    "FingerprintHub Technology Fingerprint": {
        "titulo": "Impressão digital de tecnologia reconhecida",
        "descricao": "Item informativo. O alvo bateu com uma assinatura conhecida do catálogo FingerprintHub.",
        "recomendacao": "Nenhuma ação direta.",
    },
    "Metatag CMS Detection": {
        "titulo": "Meta tag de gerador presente no HTML",
        "descricao": "Item informativo. O HTML traz a meta tag generator, usada para identificar a ferramenta que produziu "
        "a página.",
        "recomendacao": "Remover a meta tag generator do index.html, já que ela não tem função para o usuário.",
    },
    "Allowed Options Method": {
        "titulo": "Método OPTIONS habilitado",
        "descricao": "O servidor responde a requisições OPTIONS informando os métodos aceitos. Em si não é falha, mas "
        "entrega informação sobre a superfície exposta.",
        "recomendacao": "Manter OPTIONS apenas onde o preflight de CORS exige e revisar a lista de métodos anunciada.",
    },
}
