#!/usr/bin/env python3
"""Aplica acentuacao portuguesa nos textos do relatorio, preservando URLs e comandos.

Uso: acentuar.py <diretorio>

Acentua:
  achados-manuais.json   apenas os VALORES, nunca as chaves
  relatorio.json         apenas os valores
  comandos.txt           texto corrido, com URLs e comandos protegidos

Nao toque em traducoes.py com este script: aquele arquivo ja nasce acentuado.

Protecao: trechos que parecem URL, caminho, flag de linha de comando ou identificador
de codigo sao mascarados antes da substituicao e restaurados depois, para que uma rota
como /api/integracao nao vire /api/integracao com acento e quebre o comando copiado.

Depois de rodar, LEIA o resultado. A lista de palavras cobre o vocabulario tecnico
recorrente, mas nao resolve "e" conjuncao contra "e" verbo: confira as frases.
"""
import json
import os
import re
import sys

PALAVRAS = {
    "nao": "não", "sao": "são", "ate": "até", "ja": "já", "so": "só", "tres": "três",
    "tambem": "também", "alem": "além", "entao": "então", "ingles": "inglês",
    "apos": "após", "atraves": "através",
    "acao": "ação", "acoes": "ações", "opcao": "opção", "opcoes": "opções",
    "autenticacao": "autenticação", "autenticacoes": "autenticações",
    "aplicacao": "aplicação", "aplicacoes": "aplicações",
    "informacao": "informação", "informacoes": "informações",
    "configuracao": "configuração", "configuracoes": "configurações",
    "execucao": "execução", "versao": "versão", "versoes": "versões",
    "seguranca": "segurança", "servico": "serviço", "servicos": "serviços",
    "codigo": "código", "publico": "público", "publica": "pública",
    "publicos": "públicos", "publicas": "públicas",
    "pagina": "página", "paginas": "páginas",
    "usuario": "usuário", "usuarios": "usuários",
    "proprio": "próprio", "propria": "própria", "proprios": "próprios", "proprias": "próprias",
    "possivel": "possível", "possiveis": "possíveis",
    "disponivel": "disponível", "disponiveis": "disponíveis",
    "vulneravel": "vulnerável", "vulneraveis": "vulneráveis",
    "responsavel": "responsável", "variavel": "variável", "variaveis": "variáveis",
    "cabecalho": "cabeçalho", "cabecalhos": "cabeçalhos",
    "decisao": "decisão", "decisoes": "decisões",
    "exposicao": "exposição", "injecao": "injeção", "protecao": "proteção",
    "projecao": "projeção", "diretorio": "diretório", "diretorios": "diretórios",
    "referencia": "referência", "referencias": "referências",
    "dependencia": "dependência", "dependencias": "dependências",
    "instancia": "instância", "instancias": "instâncias",
    "confianca": "confiança", "politica": "política", "politicas": "políticas",
    "obrigatorio": "obrigatório", "obrigatoria": "obrigatória",
    "relatorio": "relatório", "relatorios": "relatórios", "apendice": "apêndice",
    "distribuicao": "distribuição", "limitacoes": "limitações",
    "enumeracao": "enumeração", "analise": "análise",
    "dinamica": "dinâmica", "estatica": "estática", "estatico": "estático",
    "numerica": "numérica", "sequencia": "sequência",
    "identificacao": "identificação", "inscricao": "inscrição", "inscricoes": "inscrições",
    "unica": "única", "unico": "único",
    "requisicao": "requisição", "requisicoes": "requisições",
    "memoria": "memória", "privilegio": "privilégio", "privilegios": "privilégios",
    "sessao": "sessão", "sessoes": "sessões", "dominio": "domínio", "dominios": "domínios",
    "modulo": "módulo", "modulos": "módulos",
    "operacao": "operação", "operacoes": "operações",
    "implementacao": "implementação", "migracao": "migração", "resolucao": "resolução",
    "area": "área", "areas": "áreas", "papeis": "papéis",
    "basica": "básica", "estrategia": "estratégia",
    "necessaria": "necessária", "necessario": "necessário",
    "especifico": "específico", "especificos": "específicos",
    "especificacao": "especificação", "catalogo": "catálogo",
    "heranca": "herança", "explicita": "explícita",
    "ocorrencia": "ocorrência", "ocorrencias": "ocorrências",
    "permissao": "permissão", "permissoes": "permissões",
    "forca": "força", "trafego": "tráfego",
    "comentario": "comentário", "comentarios": "comentários",
    "licenca": "licença", "minificacao": "minificação", "producao": "produção",
    "indice": "índice", "conteudo": "conteúdo", "conteudos": "conteúdos",
    "adivinhacao": "adivinhação", "compativel": "compatível",
    "navegacao": "navegação", "maquina": "máquina",
    "superficie": "superfície", "criacao": "criação", "importacao": "importação",
    "verificacao": "verificação", "exportacao": "exportação",
    "arbitrario": "arbitrário", "arbitraria": "arbitrária",
    "repositorio": "repositório", "repositorios": "repositórios",
    "alcanca": "alcança", "alcancam": "alcançam",
    "preparacao": "preparação", "integracao": "integração",
    "inicializacao": "inicialização", "atualizacao": "atualização", "revisao": "revisão",
    "manutencao": "manutenção", "comecando": "começando",
    "relacao": "relação", "situacao": "situação", "legitima": "legítima",
    "identificaveis": "identificáveis", "vitima": "vítima",
    "documentacao": "documentação", "recuperacao": "recuperação",
    "invalida": "inválida", "parametro": "parâmetro", "parametros": "parâmetros",
    "duvida": "dúvida", "excecao": "exceção", "excecoes": "exceções",
    "funcao": "função", "funcoes": "funções",
    "consequencia": "consequência", "frequencia": "frequência",
    "ultima": "última", "ultimo": "último", "proximo": "próximo", "proxima": "próxima",
    "minimo": "mínimo", "maximo": "máximo", "metodo": "método", "metodos": "métodos",
    "historico": "histórico", "generico": "genérico", "pratica": "prática",
    "praticas": "práticas", "nivel": "nível", "niveis": "níveis",
    "criterio": "critério", "numero": "número", "numeros": "números",
    "cenario": "cenário", "endereco": "endereço", "enderecos": "endereços",
    "ausencia": "ausência", "correcao": "correção", "correcoes": "correções",
    "renderizacao": "renderização", "variacao": "variação", "evidencia": "evidência",
    "padrao": "padrão", "padroes": "padrões", "automatica": "automática",
    "automatico": "automático", "obvio": "óbvio", "serie": "série",
}

# "e" que na verdade e verbo, e outros trechos que a lista de palavras nao resolve.
FRASES = [
    (r"\bversao e afetada\b", "versão é afetada"),
    (r"\bnao e falha\b", "não é falha"),
    (r"\bO resultado e que\b", "O resultado é que"),
    (r"\be a principal defesa\b", "é a principal defesa"),
    (r"\bo alvo e uma\b", "o alvo é uma"),
    (r"\bo valor e um\b", "o valor é um"),
    (r"\bque e justamente\b", "que é justamente"),
    (r"\bdiretorio e artefato\b", "diretório é artefato"),
    (r"\bnao esta\b", "não está"), (r"\bja esta\b", "já está"),
    (r"\besta ativo\b", "está ativo"), (r"\besta marcado\b", "está marcado"),
    (r"\besta corrigida\b", "está corrigida"),
    (r"\be necessaria para\b", "é necessária para"),
    (r"\be necessario para\b", "é necessário para"),
]

# Trechos preservados tal como estao: URL, caminho, flag, identificador com ponto ou sublinhado.
PROTEGIDO = re.compile(
    r"(https?://\S+|\B/[A-Za-z0-9_./{}:-]+|\b[A-Za-z0-9_]+\.[A-Za-z0-9_.]+\b|--?[A-Za-z][\w-]*|\b\w+_\w[\w_]*\b)"
)
RX = re.compile(r"\b(" + "|".join(sorted(PALAVRAS, key=len, reverse=True)) + r")\b", re.IGNORECASE)


def acentua(texto):
    if not isinstance(texto, str) or not texto:
        return texto

    guardados = []

    def esconde(m):
        guardados.append(m.group(0))
        return f"\x00{len(guardados) - 1}\x00"

    t = PROTEGIDO.sub(esconde, texto)

    for padrao, sub in FRASES:
        t = re.sub(padrao, sub, t, flags=re.IGNORECASE)

    def troca(m):
        orig = m.group(0)
        novo = PALAVRAS[orig.lower()]
        if orig.isupper() and len(orig) > 1:
            return novo.upper()
        if orig[0].isupper():
            return novo[0].upper() + novo[1:]
        return novo

    t = RX.sub(troca, t)
    return re.sub(r"\x00(\d+)\x00", lambda m: guardados[int(m.group(1))], t)


def acentua_json(caminho):
    if not os.path.exists(caminho):
        return 0
    d = json.load(open(caminho))

    def anda(o):
        if isinstance(o, dict):
            return {k: anda(v) for k, v in o.items()}  # chaves intactas
        if isinstance(o, list):
            return [anda(v) for v in o]
        return acentua(o)

    novo = anda(d)
    with open(caminho, "w") as f:
        json.dump(novo, f, ensure_ascii=False, indent=2)
    return len(novo) if isinstance(novo, (list, dict)) else 1


def acentua_txt(caminho):
    if not os.path.exists(caminho):
        return 0
    with open(caminho) as f:
        texto = f.read()          # le tudo ANTES de abrir para escrita
    novo = acentua(texto)
    with open(caminho, "w") as f:
        f.write(novo)
    return novo.count("\n")


def main():
    if len(sys.argv) < 2:
        print(__doc__.strip())
        return 1
    d = os.path.abspath(sys.argv[1])
    print("achados-manuais.json:", acentua_json(os.path.join(d, "achados-manuais.json")), "itens")
    print("relatorio.json:", acentua_json(os.path.join(d, "relatorio.json")), "campos")
    print("comandos.txt:", acentua_txt(os.path.join(d, "comandos.txt")), "linhas")
    print("\nRevise o resultado antes de gerar o PDF.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
