#!/usr/bin/env python3
"""Consolida Nmap, Nuclei, OWASP ZAP e testes manuais em um HTML pronto para virar PDF.

Uso: gerar-relatorio.py <diretorio> [saida.html]

O diretorio precisa conter:
  alvos.json            {"chave": "Rotulo do alvo (porta N)", ...}
  relatorio.json        {"titulo": ..., "subtitulo": ..., "destaque": ..., "escopo": [...]}
  achados-manuais.json  lista de achados escritos a mao (ver exemplos/)
  zap-<chave>.json      saida de /JSON/alert/view/alerts/ por alvo
  nuclei-<chave>.jsonl  saida de nuclei -jsonl por alvo
  nmap-host.txt         saida do nmap
  comandos.txt          apendice de comandos, versoes e limitacoes

Arquivos ausentes sao ignorados, entao da para gerar um relatorio parcial.
"""
import html
import importlib.util
import json
import os
import sys
from collections import Counter, defaultdict
from datetime import date

ORDEM = ["Crítico", "Alto", "Médio", "Baixo", "Informativo"]
COR = {
    "Crítico": "#7f1d1d",
    "Alto": "#b91c1c",
    "Médio": "#b45309",
    "Baixo": "#1d4ed8",
    "Informativo": "#475569",
}
SEV = {
    "critical": "Crítico",
    "high": "Alto",
    "medium": "Médio",
    "low": "Baixo",
    "info": "Informativo",
    "informational": "Informativo",
    "unknown": "Informativo",
}


def carregar_pt():
    caminho = os.path.join(os.path.dirname(os.path.abspath(__file__)), "traducoes.py")
    spec = importlib.util.spec_from_file_location("traducoes", caminho)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.PT


PT = carregar_pt()


def traduzir(titulo):
    """Verbete em portugues do alerta, por chave exata ou por prefixo."""
    if titulo in PT:
        return PT[titulo]
    for chave, v in PT.items():
        base = chave.split(" HTTP Response")[0]
        if titulo and titulo.startswith(base[:40]):
            return v
    return None


def mapa_sev(valor):
    return SEV.get((valor or "").strip().lower(), "Informativo")


def json_opc(caminho, padrao):
    return json.load(open(caminho)) if os.path.exists(caminho) else padrao


def texto_opc(caminho):
    return open(caminho).read() if os.path.exists(caminho) else "(saída não disponível)"


def carregar_nuclei(dir_, alvos):
    out = []
    for chave, rotulo in alvos.items():
        caminho = os.path.join(dir_, f"nuclei-{chave}.jsonl")
        if not os.path.exists(caminho):
            continue
        agrupado = defaultdict(list)
        for linha in open(caminho):
            linha = linha.strip()
            if not linha:
                continue
            d = json.loads(linha)
            info = d.get("info", {})
            agrupado[(d.get("template-id"), info.get("name"), mapa_sev(info.get("severity")))].append(d)

        for (tid, nome, sev), itens in agrupado.items():
            extraidos = []
            for i in itens:
                for e in i.get("extracted-results") or []:
                    if e and e not in extraidos:
                        extraidos.append(e)
            pt = traduzir(nome or "")
            info0 = itens[0].get("info", {})
            out.append({
                "ferramenta": "Nuclei",
                "alvo": rotulo,
                "titulo": pt["titulo"] if pt else (nome or tid),
                "severidade": sev,
                "endpoint": itens[0].get("matched-at", ""),
                "parametro": tid,
                "descricao": pt["descricao"] if pt else ((info0.get("description") or "").strip()
                                                         or f"O template {tid} do Nuclei disparou neste alvo."),
                "evidencia": f"{len(itens)} ocorrência(s). Template: {tid}. " + (
                    ("Valores extraídos: " + ", ".join(extraidos[:10])) if extraidos else "Sem extração de valores."),
                "recomendacao": pt["recomendacao"] if pt else ((info0.get("remediation") or "").strip()
                                                               or "Consultar a referência do template no catálogo do Nuclei."),
                "nota": (pt or {}).get("nota", ""),
            })
    return out


def carregar_zap(dir_, alvos):
    out = []
    for chave, rotulo in alvos.items():
        caminho = os.path.join(dir_, f"zap-{chave}.json")
        if not os.path.exists(caminho):
            continue
        try:
            alertas = json.load(open(caminho)).get("alerts", [])
        except (ValueError, OSError):
            continue

        agrupado = defaultdict(list)
        for a in alertas:
            agrupado[(a.get("alert"), mapa_sev(a.get("risk")))].append(a)

        for (nome, sev), itens in agrupado.items():
            p = itens[0]
            urls, params = [], []
            for i in itens:
                u, pa = i.get("url", ""), i.get("param") or ""
                if u and u not in urls:
                    urls.append(u)
                if pa and pa not in params:
                    params.append(pa)

            pt = traduzir(nome or "")
            confianca = {"High": "alta", "Medium": "média", "Low": "baixa"}.get(
                p.get("confidence", ""), p.get("confidence", ""))
            ev = (p.get("evidence") or "").strip()
            outro = (p.get("other") or "").strip()

            evid = f"{len(itens)} instância(s) agrupada(s). Confiança relatada pelo ZAP: {confianca}. "
            if ev:
                evid += f"Trecho capturado: {ev[:300]} "
            if outro and ("CVE" in outro or "vulnerable" in outro.lower()):
                evid += f"Detalhe da ferramenta: {outro[:400]}"

            out.append({
                "ferramenta": "OWASP ZAP",
                "alvo": rotulo,
                "titulo": pt["titulo"] if pt else nome,
                "severidade": sev,
                "endpoint": "; ".join(urls[:4]) + (f" (e mais {len(urls) - 4})" if len(urls) > 4 else ""),
                "parametro": ", ".join(params[:6]) or "nenhum",
                "descricao": pt["descricao"] if pt else (p.get("description") or "").strip(),
                "evidencia": evid.strip(),
                "recomendacao": pt["recomendacao"] if pt else (p.get("solution") or "").strip(),
                "nota": (pt or {}).get("nota", ""),
            })
    return out


def carregar_manuais(dir_):
    itens = json_opc(os.path.join(dir_, "achados-manuais.json"), [])
    for i in itens:
        i.setdefault("ferramenta", "Teste manual (curl)")
        i.setdefault("nota", "")
    return itens


def esc_cru(t):
    """Escapa sem reescrever enderecos. Para os apendices, que mostram os comandos reais."""
    return html.escape(str(t or ""))


def esc(t):
    """Escapa e troca o nome que o container usa pelo endereco local, para leitura do relatorio."""
    return esc_cru(t).replace("host.docker.internal", "127.0.0.1")


ESTILO = """
  @page { size: A4; margin: 18mm 14mm; }
  body { font: 10.5pt/1.5 "DejaVu Sans", Arial, sans-serif; color:#111827; }
  h1 { font-size: 22pt; margin:0 0 4px; }
  h2.sev { font-size: 14pt; margin:26px 0 10px; padding-left:10px; border-left:6px solid #999; page-break-after:avoid; }
  h2.cap { font-size: 15pt; margin:28px 0 10px; border-bottom:2px solid #111827; padding-bottom:4px; }
  h3 { font-size: 11.5pt; margin:0 0 8px; }
  .sub { color:#4b5563; margin:0 0 18px; }
  table { border-collapse: collapse; width:100%; margin:8px 0 14px; }
  th, td { border:1px solid #d1d5db; padding:5px 8px; text-align:left; vertical-align:top; font-size:9.5pt; }
  th { background:#f3f4f6; }
  td.num, th.num { text-align:center; }
  .pill { color:#fff; border-radius:9px; padding:1px 9px; font-size:8.5pt; white-space:nowrap; }
  .achado { border:1px solid #e5e7eb; border-radius:6px; padding:12px 14px; margin:0 0 14px; page-break-inside:avoid; }
  .achado .num { background:#111827; color:#fff; border-radius:50%; display:inline-block;
                 width:20px; height:20px; text-align:center; font-size:9pt; line-height:20px; margin-right:6px; }
  table.meta { margin:6px 0 10px; }
  table.meta th { width:100px; }
  .rot { font-weight:bold; margin:10px 0 2px; font-size:9.5pt; color:#374151; }
  .mono, pre { font-family:"DejaVu Sans Mono", monospace; font-size:8.5pt; }
  pre { background:#f9fafb; border:1px solid #e5e7eb; border-radius:4px;
        padding:8px; white-space:pre-wrap; word-break:break-word; margin:2px 0; }
  .nota { background:#fffbeb; border:1px solid #fcd34d; border-radius:5px; padding:10px 12px; font-size:9.5pt; }
"""


def main():
    if len(sys.argv) < 2:
        print(__doc__.strip())
        return 1

    dir_ = os.path.abspath(sys.argv[1])
    destino = sys.argv[2] if len(sys.argv) > 2 else os.path.join(dir_, "relatorio.html")

    alvos = json_opc(os.path.join(dir_, "alvos.json"), {})
    meta = json_opc(os.path.join(dir_, "relatorio.json"), {})
    titulo = meta.get("titulo", "Auditoria dinâmica de segurança")
    subtitulo = meta.get("subtitulo", f"Data: {date.today().isoformat()}.")
    destaque = meta.get("destaque", "")
    escopo = meta.get("escopo", [])

    achados = carregar_manuais(dir_) + carregar_zap(dir_, alvos) + carregar_nuclei(dir_, alvos)
    achados.sort(key=lambda a: (ORDEM.index(a["severidade"]), a["alvo"], a["titulo"]))

    contagem = Counter(a["severidade"] for a in achados)
    por_alvo = defaultdict(Counter)
    for a in achados:
        por_alvo[a["alvo"]][a["severidade"]] += 1

    linhas_resumo = "".join(
        f'<tr><td><span class="pill" style="background:{COR[s]}">{s}</span></td>'
        f'<td class="num">{contagem.get(s, 0)}</td></tr>' for s in ORDEM)

    cab_alvo = "".join(f'<th class="num">{s}</th>' for s in ORDEM)
    linhas_alvo = ""
    for alvo in sorted(por_alvo):
        c = por_alvo[alvo]
        linhas_alvo += (f"<tr><td>{esc(alvo)}</td>"
                        + "".join(f'<td class="num">{c.get(s, 0) or "-"}</td>' for s in ORDEM)
                        + f'<td class="num"><b>{sum(c.values())}</b></td></tr>')

    blocos, atual = "", None
    for n, a in enumerate(achados, 1):
        if a["severidade"] != atual:
            atual = a["severidade"]
            blocos += f'<h2 class="sev" style="border-color:{COR[atual]}">Severidade: {atual}</h2>'
        nota = f'<p class="nota">Contexto: {esc(a["nota"])}</p>' if a.get("nota") else ""
        blocos += f"""
<div class="achado">
  <h3><span class="num">{n}</span> {esc(a['titulo'])}
    <span class="pill" style="background:{COR[a['severidade']]}">{a['severidade']}</span></h3>
  <table class="meta">
    <tr><th>Alvo</th><td>{esc(a['alvo'])}</td></tr>
    <tr><th>Endpoint</th><td class="mono">{esc(a['endpoint'])}</td></tr>
    <tr><th>Parâmetro</th><td class="mono">{esc(a['parametro'])}</td></tr>
    <tr><th>Origem</th><td>{esc(a['ferramenta'])}</td></tr>
  </table>
  <p class="rot">Descrição</p><p>{esc(a['descricao'])}</p>
  <p class="rot">Evidência</p><pre>{esc(a['evidencia'])}</pre>
  <p class="rot">Recomendação</p><p>{esc(a['recomendacao'])}</p>
  {nota}
</div>"""

    bloco_escopo = ""
    if escopo:
        itens = "".join(f'<p style="margin:0 0 6px">{esc(p)}</p>' for p in escopo)
        bloco_escopo = f'<h2 class="cap">3. Escopo e limitações</h2>\n<div class="nota">{itens}</div>'

    doc = f"""<!doctype html>
<html lang="pt-br"><head><meta charset="utf-8">
<title>{esc(titulo)}</title>
<style>{ESTILO}</style></head><body>

<h1>{esc(titulo)}</h1>
<p class="sub">{esc(subtitulo)}</p>

<h2 class="cap">1. Resumo executivo</h2>
<p>Foram consolidados <b>{len(achados)}</b> achados a partir de varredura ativa com OWASP ZAP,
varredura de templates com Nuclei, enumeração de serviços com Nmap e testes manuais dirigidos.</p>
<table style="width:45%"><tr><th>Severidade</th><th class="num">Achados</th></tr>{linhas_resumo}</table>
{f"<p>{esc(destaque)}</p>" if destaque else ""}

<h2 class="cap">2. Distribuição por alvo</h2>
<table><tr><th>Alvo</th>{cab_alvo}<th class="num">Total</th></tr>{linhas_alvo}</table>

{bloco_escopo}

<h2 class="cap">4. Achados detalhados</h2>
{blocos}

<h2 class="cap">5. Apêndice A: serviços expostos (Nmap)</h2>
<pre>{esc_cru(texto_opc(os.path.join(dir_, 'nmap-host.txt')))}</pre>

<h2 class="cap">6. Apêndice B: comandos e ferramentas</h2>
<pre>{esc_cru(texto_opc(os.path.join(dir_, 'comandos.txt')))}</pre>

</body></html>"""

    with open(destino, "w") as f:
        f.write(doc)
    print("HTML gerado:", destino)
    print("achados:", len(achados), dict(contagem))
    return 0


if __name__ == "__main__":
    sys.exit(main())
