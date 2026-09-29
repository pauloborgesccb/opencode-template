# plugins

Arquivos `.ts` e `.js` colocados aqui são carregados automaticamente pelo opencode, assim como diretórios de pacote de plugin.

O mesmo vale para `~/.config/opencode/plugins/` no escopo global.

Pacotes publicados podem ser declarados no `opencode.jsonc` ou gerenciados pela CLI:

```bash
opencode plugin add <pkg>
```

```bash
opencode plugin list
```

Prefixo `-` desabilita uma entrada e `*` casa com todas.

Remova este README quando adicionar plugins reais.
