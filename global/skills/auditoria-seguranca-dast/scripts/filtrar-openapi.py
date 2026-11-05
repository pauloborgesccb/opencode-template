#!/usr/bin/env python3
"""Remove da spec OpenAPI as operacoes que escrevem de forma destrutiva.

Uso: filtrar-openapi.py <entrada.json> <saida.json> <url-base> [metodos-permitidos]
     metodos-permitidos: lista separada por virgula, padrao "get,post"

Serve para rodar varredura ativa contra uma API sem disparar PATCH, PUT e DELETE
reais contra a base. Depois de gerar, copie para dentro do container:
    docker cp saida.json zapd:/zap/saida.json
"""
import json
import sys


def main():
    if len(sys.argv) < 4:
        print(__doc__.strip())
        return 1

    entrada, saida, base = sys.argv[1], sys.argv[2], sys.argv[3]
    permitidos = {m.strip().lower() for m in (sys.argv[4] if len(sys.argv) > 4 else "get,post").split(",")}

    spec = json.load(open(entrada))
    paths = {}
    removidas = 0
    for caminho, ops in spec.get("paths", {}).items():
        mantidas = {}
        for metodo, op in ops.items():
            if metodo.lower() in permitidos or not metodo.isalpha():
                mantidas[metodo] = op
            else:
                removidas += 1
        if mantidas:
            paths[caminho] = mantidas

    spec["paths"] = paths
    spec["servers"] = [{"url": base}]
    json.dump(spec, open(saida, "w"))

    mantidas_total = sum(len(v) for v in paths.values())
    print(f"operacoes mantidas: {mantidas_total} | removidas: {removidas} | metodos: {sorted(permitidos)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
