---
name: auditoria-pre-publicacao
description: "Auditoria de conformidade pré-publicação de sistemas web: privacidade, LGPD, cookies, acessibilidade (WCAG 2.2 AA), transparência comercial e credibilidade, com relatório de 17 requisitos e parecer final. Use SOMENTE quando o usuário solicitar explicitamente a auditoria, por exemplo: 'Execute a auditoria pré publicação', 'Rode a skill de conformidade', 'Valide os requisitos de publicação'. NUNCA execute automaticamente durante outras tarefas, revisões de código, implementações ou conversas."
---

# Auditoria de Conformidade Pré-Publicação

Auditar sistemas web e aplicações antes da publicação, verificando privacidade, proteção de dados, transparência, acessibilidade, experiência do usuário e confiabilidade das informações. Identificar problemas reais no projeto, analisando código e configurações disponíveis, e gerar relatório objetivo com evidências.

## Regra de execução

Esta skill só roda quando o usuário solicita explicitamente. Nunca a execute automaticamente durante outras tarefas, revisões de código, implementações ou conversas. Não interrompa o fluxo de desenvolvimento para executá-la sem autorização.

A auditoria é somente de leitura: não altere código, não instale dependências, não modifique configurações e não publique o sistema. Apresente as correções recomendadas antes de qualquer alteração; implemente-as apenas com autorização posterior do usuário.

## Processo de auditoria

1. Identifique a arquitetura, as tecnologias, os módulos, as funcionalidades e o público-alvo do sistema.
2. Inspecione o código-fonte, os arquivos de configuração, as dependências, as rotas, os componentes de interface e as integrações disponíveis.
3. Para cada requisito do checklist, determine se ele é aplicável ao sistema.
4. Verifique somente os requisitos aplicáveis, sem presumir que uma funcionalidade existe apenas porque é comum em aplicações web.
5. Para requisitos não aplicáveis, registre a justificativa técnica.
6. Quando não houver evidências suficientes, marque o item como inconclusivo e solicite somente as informações necessárias.
7. Não invente evidências, não considere documentação como prova de implementação e não declare conformidade sem verificação.

## Checklist de requisitos

### Privacidade e proteção de dados

1. **Política de Privacidade**: verifique se o sistema coleta ou processa dados pessoais, se existe política de privacidade acessível e se o conteúdo corresponde às práticas reais da aplicação.

2. **Termos de Uso**: determine se os termos são necessários considerando o tipo de sistema, seus usuários, suas funcionalidades e seu modelo de negócio. Quando aplicáveis, verifique se estão disponíveis e adequados ao serviço oferecido.

3. **Consentimento de Cookies**: verifique se há cookies ou tecnologias de armazenamento e rastreamento que exijam consentimento. Analise cookies próprios, cookies de terceiros, categorias de cookies, mecanismos de consentimento e bloqueio prévio quando exigido. Não exija um banner de consentimento indiscriminadamente para todos os cookies.

4. **Formulários e LGPD**: inspecione formulários e fluxos de coleta de dados. Verifique finalidade, necessidade dos dados, transparência, base legal, informações ao titular e consentimento quando essa for a base legal aplicável. Não presuma que consentimento é obrigatório em toda operação de tratamento.

5. **Política de Reembolso**: determine se o sistema vende produtos ou serviços, recebe pagamentos, oferece assinaturas ou realiza transações que exijam regras de cancelamento, devolução ou reembolso. Se aplicável, verifique a existência e a clareza da política e sua adequação às obrigações legais pertinentes.

6. **Coleta Mínima de Dados**: avalie se os dados solicitados são necessários para as funcionalidades oferecidas. Identifique campos, permissões, informações e dados coletados sem finalidade demonstrável.

7. **Exclusão de Dados**: verifique se existe tratamento de dados pessoais e se há procedimentos adequados para atender solicitações de exclusão, eliminação ou anonimização, quando aplicáveis. Considere retenções legalmente justificadas, obrigações regulatórias e limitações técnicas. Não presuma que todos os dados devem ser excluídos imediatamente.

8. **Google Analytics**: verifique especificamente se o Google Analytics está instalado, configurado ou carregado por meio de scripts, gerenciadores de tags, dependências ou integrações externas. Se estiver presente, valide a configuração, a transparência sobre a coleta e os mecanismos de consentimento aplicáveis. Se não estiver presente, classifique o item como não aplicável, apresentando evidências.

9. **Scripts de Rastreamento**: identifique ferramentas como pixels publicitários, scripts de marketing, mapas de calor, rastreadores e ferramentas de monitoramento comportamental. Se existirem, avalie sua finalidade, configuração, impacto na privacidade e necessidade de consentimento. Não confunda monitoramento técnico de erros com rastreamento publicitário.

10. **Integrações de Terceiros**: identifique serviços externos utilizados pelo sistema, incluindo autenticação, pagamentos, hospedagem, análise de dados, comunicação, armazenamento e APIs. Avalie os dados compartilhados, a finalidade, os riscos e os requisitos de transparência e proteção de dados.

### Acessibilidade e experiência do usuário

11. **Auditoria de Acessibilidade**: verifique a acessibilidade das interfaces, preferencialmente com base na WCAG 2.2 nível AA, considerando os critérios aplicáveis. Analise estrutura semântica, leitores de tela, formulários, foco, navegação, mensagens de erro e compatibilidade com tecnologias assistivas.

12. **Textos Alternativos**: verifique imagens informativas, ícones funcionais e outros elementos visuais. Confirme se possuem alternativas textuais adequadas. Imagens puramente decorativas devem ser ignoradas pelas tecnologias assistivas quando apropriado.

13. **Contraste Visual**: verifique o contraste entre texto e fundo, elementos gráficos relevantes, estados de componentes e indicadores de foco. Utilize os limites aplicáveis da WCAG e considere exceções previstas no padrão.

14. **Navegação por Teclado**: verifique se as funcionalidades podem ser utilizadas pelo teclado, se a ordem de foco é lógica, se o foco é visível e se não existem armadilhas de teclado.

15. **Botões Claros**: avalie se botões, links e ações possuem nomes compreensíveis, objetivos e acessíveis. Identifique ações ambíguas, elementos sem identificação e diferenças pouco claras entre ações principais e secundárias.

### Credibilidade e transparência comercial

16. **Depoimentos Reais**: determine se o sistema apresenta depoimentos, avaliações ou recomendações de clientes. Quando existirem, verifique se há evidências de autenticidade e se as alegações são apresentadas de maneira transparente. Não classifique depoimentos como reais sem comprovação.

17. **Promessas Comprováveis**: identifique alegações sobre resultados, benefícios, desempenho, economia, segurança, garantias e outras promessas comerciais. Verifique se há evidências que sustentem essas afirmações. Marque alegações não verificáveis como pendentes de comprovação, sem presumir que sejam falsas.

## Classificação obrigatória

Cada requisito recebe exatamente um status:

- **CONFORME**: o requisito é aplicável e existem evidências suficientes de atendimento.
- **NÃO CONFORME**: o requisito é aplicável e foram encontrados problemas concretos.
- **NÃO APLICÁVEL**: o requisito não se aplica ao sistema, com justificativa técnica.
- **INCONCLUSIVO**: faltam informações, acesso ou evidências para determinar a situação.

Nunca utilize "não aplicável" apenas porque a funcionalidade não foi encontrada em uma busca superficial. Quando houver dúvida, utilize "inconclusivo".

## Evidências obrigatórias

Para cada requisito aplicável, informe:

- Status.
- Evidências encontradas.
- Arquivos, componentes, rotas ou configurações relacionados, quando disponíveis.
- Problema identificado e seu impacto.
- Correção recomendada.
- Prioridade: crítica, alta, média ou baixa.

Diferencie problemas confirmados de riscos potenciais e limitações da auditoria.

## Relatório final

Apresente o resultado nesta ordem:

1. Resumo executivo da auditoria.
2. Quantidade de requisitos conformes, não conformes, não aplicáveis e inconclusivos.
3. Lista detalhada dos 17 requisitos, preservando a numeração original.
4. Problemas encontrados, organizados por prioridade.
5. Correções recomendadas, com referências aos arquivos e componentes pertinentes.
6. Pendências que dependem de informações externas, como contratos, políticas internas, comprovação de depoimentos ou validação jurídica.
7. Parecer final: apto para publicação, apto com ressalvas ou não recomendado para publicação.

O parecer deve considerar a gravidade dos problemas, os riscos legais, a segurança, a acessibilidade e o impacto para os usuários. Não declare que um sistema é integralmente seguro ou legalmente conforme com base apenas nessa checklist.

## Regras de qualidade

- Não invente funcionalidades, integrações, políticas ou evidências.
- Não exija Google Analytics, depoimentos, reembolsos ou qualquer recurso comercial quando não houver aplicabilidade.
- Não confunda ausência de evidência com comprovação de ausência.
- Não faça alterações automaticamente.
- Priorize problemas reproduzíveis e evidências verificáveis.
- Seja objetivo e técnico.
- Se não houver acesso ao ambiente de execução, testes ou configurações externas, deixe essa limitação explícita.

Resultado esperado: uma auditoria contextualizada ao sistema real, que diferencie obrigações aplicáveis de recursos opcionais e identifique o que precisa ser corrigido antes da publicação.
