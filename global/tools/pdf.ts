import { tool } from "@opencode-ai/plugin"
import path from "path"
import os from "os"

// Tool global: extração de conteúdo de PDF.
// pdf_text  -> PDFs digitais (texto embutido), via pdftotext
// pdf_pages -> PDFs escaneados: gera PNGs para usar com modelo de visão (-vis)

export const text = tool({
  description:
    "Extrai o texto de um PDF digital usando pdftotext (poppler). " +
    "Use antes de qualquer análise de PDF. Se retornar vazio, o PDF é escaneado: use pdf_pages.",
  args: {
    path: tool.schema.string().describe("Caminho absoluto do arquivo PDF"),
    first: tool.schema.number().optional().describe("Primeira página (opcional)"),
    last: tool.schema.number().optional().describe("Última página (opcional)"),
  },
  async execute(args) {
    const flags: string[] = ["-layout", "-nopgbrk"]
    if (args.first) flags.push("-f", String(args.first))
    if (args.last) flags.push("-l", String(args.last))
    const out = await Bun.$`pdftotext ${flags} ${args.path} -`.text()
    if (!out.trim()) {
      return (
        "Nenhum texto extraído: o PDF provavelmente é escaneado (imagem). " +
        "Use a tool pdf_pages para gerar PNGs das páginas e analise com um modelo de visão."
      )
    }
    return out
  },
})

export const pages = tool({
  description:
    "Converte páginas de um PDF em imagens PNG (pdftoppm) para leitura por modelo com visão. " +
    "Retorna os caminhos dos PNGs gerados. Use quando pdf_text não encontrar texto.",
  args: {
    path: tool.schema.string().describe("Caminho absoluto do arquivo PDF"),
    first: tool.schema.number().optional().describe("Primeira página (opcional)"),
    last: tool.schema.number().optional().describe("Última página (opcional)"),
    dpi: tool.schema.number().optional().describe("Resolução em DPI (default 150)"),
  },
  async execute(args) {
    const base = path.basename(args.path, ".pdf").replace(/[^\w.-]/g, "_")
    const dir = path.join(os.tmpdir(), "opencode-pdf", base)
    await Bun.$`mkdir -p ${dir}`
    const flags: string[] = ["-png", "-r", String(args.dpi ?? 150)]
    if (args.first) flags.push("-f", String(args.first))
    if (args.last) flags.push("-l", String(args.last))
    await Bun.$`pdftoppm ${flags} ${args.path} ${path.join(dir, "pagina")}`
    const lista = await Bun.$`ls ${dir}`.text()
    const arquivos = lista
      .split("\n")
      .filter(Boolean)
      .map((f) => path.join(dir, f))
    return `PNGs gerados:\n${arquivos.join("\n")}`
  },
})
