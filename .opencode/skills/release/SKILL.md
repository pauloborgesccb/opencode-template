---
name: Release
description: Prepara release deste projeto, com bump de versão, changelog e tag. Use quando o pedido envolver publicar, versionar ou gerar notas de release.
---

# Release

## Quando usar

Pedidos de publicação, bump de versão, changelog ou criação de tag.

## Passos

1. Confirme que a working tree está limpa e que a suíte de testes passa.
2. Levante os commits desde a última tag:

   ```bash
   git log $(git describe --tags --abbrev=0)..HEAD --oneline
   ```

3. Decida o tipo de bump a partir dos commits: patch, minor ou major.
4. Atualize o arquivo de versão do projeto: `<ajuste para o seu stack>`.
5. Atualize o `CHANGELOG.md` agrupando por Adicionado, Alterado, Corrigido e Removido.
6. Commite com a mensagem `chore(release): v<versao>`.
7. Crie a tag `v<versao>`.
8. Pare aqui. O push e a publicação são feitos por quem pediu.

## Estrutura opcional

```
.opencode/skills/release/
├── SKILL.md
├── scripts/       # scripts auxiliares chamados nos passos acima
└── references/    # material de apoio consultado sob demanda
```
