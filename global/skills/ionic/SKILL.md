---
name: Ionic React (padrão superapp-sicar)
description: Arquitetura do projeto superapp-sicar (Ionic React, Vite, Capacitor, Rematch). Use APENAS ao trabalhar no superapp-sicar ou em app que declaradamente siga esse padrão; em outros apps Ionic, siga as convenções locais do projeto.
---

# Ionic React (arquitetura superapp-sicar)

## Quando usar

Desenvolvimento em app Ionic **React** (não Angular): página nova, componente, estado, chamada de API, plugin nativo.

## Stack de referência

Ionic React 8 + React 19 + Vite + TypeScript, Capacitor 8, Rematch (Redux) + react-redux, axios, react-router v5 (`useHistory`, `component=`), Tailwind v4, react-toastify, pnpm.

## Estrutura (organização por tipo)

```
src/
├── App.tsx          # rotas + tabs + providers globais
├── components/      # 1 componente por pasta, PascalCase
├── enums/           # routes.enum.ts (RoutesEnum) e afins
├── models/          # estado Rematch: state + reducers + effects (API aqui)
├── pages/           # 1 arquivo .tsx por página, pasta kebab-case
├── services/        # axios (index.ts) e services de integração (*.service.ts)
├── theme/variables.css
└── utils/
```

## Criar uma página nova (5 passos)

1. Adicionar a rota em `src/enums/routes.enum.ts` (`RoutesEnum`).
2. Criar `src/pages/<kebab>/<Nome>.tsx`: `const Nome: React.FC = () => ...` com `IonPage > IonHeader/IonToolbar > IonContent`, export default. Estilo via classes Tailwind inline.
3. Criar o model `src/models/<dominio>.ts` com `createModel<RootModel>()({ state, reducers, effects })`. Effects são async e concentram: chamada axios, flags de loading e toast de erro.
4. Registrar o model em `src/models/index.ts` (interface `RootModel` + objeto `models`).
5. Registrar a rota em `App.tsx`: `<Route exact path={RoutesEnum.X} component={X} />`, dentro do wrapper `*Tab` correspondente se a página exibe tab bar.

## API e autenticação

- Toda chamada usa `httpRequest` de `src/services/index.ts` (axios com `baseURL: import.meta.env.VITE_API_URL`).
- Interceptor de request injeta `Authorization: Bearer` do localStorage; response 401 dispara `user/clearSession`; erros ganham `error.userMessage` em PT-BR.
- Contrato BFF: `{ status: 's' | 'e', mensagem?, dados? }`.
- Chamadas ficam nos `effects` do model; endpoints agrupados podem ir para um objeto em `services/` (padrão `centralApi`).

## Estado (Rematch)

- Leitura: `useSelector((state: RootState) => state.dominio)`.
- Ação: `useDispatch<Dispatch>()` e `dispatch.dominio.efeito()`.
- Nunca usar Context API ou useState para estado de domínio; useState só para estado local de UI.
- Sessão espelhada em localStorage (`user`, `access_token`, `refreshToken`).

## Nomenclatura

- Páginas/componentes `PascalCase.tsx`; pastas de página `kebab-case`; enums `*.enum.ts` (classe `XxxEnum`); services `*.service.ts` (classe + singleton exportado); models camelCase do domínio.
- Domínio e mensagens em português; nomes técnicos em inglês.

## Comandos (pnpm)

```bash
pnpm dev                 # vite --host
pnpm build:dev|hom|prod  # tsc && vite build --mode <env>
pnpm test.unit           # vitest
pnpm test.e2e            # cypress
pnpm lint
pnpm run:android:dev     # build + cap sync + cap open
```

## Pontos de atenção

- Rotas NÃO têm guard: proteção é reativa via interceptor 401. Não presuma guard existente.
- Tabs: wrappers `HomeTab`/`NoticiasTab`/`PerfilTab` em App.tsx, cada um com seu IonTabs; visibilidade via `state.global.showTabs`.
- Safe area: use os componentes `SafeArea*` existentes; StatusBar em overlay.
- Sem i18n: strings PT-BR direto no código (siga o padrão).
- Models grandes (600+ linhas) são dívida conhecida: em código novo, extraia endpoints para `services/` no estilo `centralApi`.
