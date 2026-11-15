/*
 * Converte markdown simples em ADF (Atlassian Document Format), que é o formato
 * aceito pelo campo description da API v3 do Jira.
 *
 * Como usar pelo BrowserOS: injete este arquivo com
 *   page.cdp('Runtime.evaluate', JSON.stringify({expression: <conteudo deste arquivo>, returnByValue:true}))
 * e depois chame window.__mk(markdown) para obter o documento ADF.
 *
 * Cobre: ## e ### como títulos, listas com - e 1., tabelas em pipe,
 * parágrafos, **negrito** e `código` inline.
 * Tabelas viram lista com a primeira coluna em negrito, porque tabela ADF
 * dentro de description é frágil e quebra em alguns temas do Jira.
 */
window.__inline = function (t) {
  return t
    .split(/(\*\*[^*]+\*\*|`[^`]+`)/g)
    .filter(function (x) { return x !== ''; })
    .map(function (x) {
      if (/^\*\*[^*]+\*\*$/.test(x)) return { type: 'text', text: x.slice(2, -2), marks: [{ type: 'strong' }] };
      if (/^`[^`]+`$/.test(x)) return { type: 'text', text: x.slice(1, -1), marks: [{ type: 'code' }] };
      return { type: 'text', text: x };
    });
};

window.__li = function (t) {
  return { type: 'listItem', content: [{ type: 'paragraph', content: window.__inline(t) }] };
};

window.__mk = function (md) {
  var lines = md.split('\n'), out = [], i = 0;
  while (i < lines.length) {
    var l = lines[i];
    if (!l.trim()) { i++; continue; }

    if (/^### /.test(l)) { out.push({ type: 'heading', attrs: { level: 4 }, content: window.__inline(l.slice(4)) }); i++; continue; }
    if (/^## /.test(l))  { out.push({ type: 'heading', attrs: { level: 3 }, content: window.__inline(l.slice(3)) }); i++; continue; }

    if (/^\|/.test(l)) {
      var rows = [];
      while (i < lines.length && /^\|/.test(lines[i])) {
        var cells = lines[i].split('|').slice(1, -1).map(function (c) { return c.trim(); });
        var sep = cells.every(function (c) { return /^-{2,}$/.test(c.replace(/:/g, '')); });
        if (!sep) rows.push(cells);
        i++;
      }
      if (rows.length) {
        var head = rows.shift();
        out.push({ type: 'paragraph', content: window.__inline('**' + head.join(' | ') + '**') });
        out.push({
          type: 'bulletList',
          content: rows.map(function (r) {
            return window.__li(r.map(function (c, ix) { return ix === 0 ? '**' + c + '**' : c; }).join(' — '));
          })
        });
      }
      continue;
    }

    if (/^- /.test(l)) {
      var it = [];
      while (i < lines.length && /^- /.test(lines[i])) { it.push(window.__li(lines[i].slice(2))); i++; }
      out.push({ type: 'bulletList', content: it });
      continue;
    }

    if (/^\d+\. /.test(l)) {
      var it2 = [];
      while (i < lines.length && /^\d+\. /.test(lines[i])) { it2.push(window.__li(lines[i].replace(/^\d+\.\s/, ''))); i++; }
      out.push({ type: 'orderedList', content: it2 });
      continue;
    }

    var buf = [];
    while (i < lines.length && lines[i].trim() && !/^[|\-#]/.test(lines[i]) && !/^\d+\. /.test(lines[i])) { buf.push(lines[i]); i++; }
    if (buf.length) out.push({ type: 'paragraph', content: window.__inline(buf.join(' ')) });
  }
  return { type: 'doc', version: 1, content: out };
};
'md-para-adf carregado';
