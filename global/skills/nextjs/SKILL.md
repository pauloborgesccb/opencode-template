---
name: Next.js (padrão santander-solar-front)
description: Arquitetura do projeto santander-solar-front (Next.js 16, next-auth, RHF+zod, Tailwind 4). Use APENAS ao trabalhar no santander-solar-front ou em projeto que declaradamente siga esse padrão; em outros projetos Next.js, siga as convenções locais do projeto.
---

# Next.js (arquitetura santander-solar-front)

## Quando usar

Desenvolvimento em projeto Next.js App Router: rota nova, componente, form, service, auth.

## Stack de referência

Next 16 (App Router, turbopack) + React 19 + TS strict, Tailwind 4 (tokens via `@theme inline`, sem tailwind.config), next-auth 4 (Credentials + JWT), react-hook-form + zod, CVA + clsx + tailwind-merge (`cn()`), pnpm.

## Estrutura

```
src/
├── app/            # route groups por domínio: (auth), (company), (administration)...
│   └── <rota>/
│       ├── page.tsx
│       ├── _components/   # componentes privados da rota
│       ├── _form/         # schemas zod da rota
│       └── _hooks/ _utils/ _types/
├── components/ui/  # componentes compartilhados (2+ rotas)
├── services/       # *.service.ts por domínio (objeto literal com métodos async)
├── lib/api/        # ApiClient singleton (client.ts), baseUrl.ts
├── context/        # ToastContext, LoadingContext, contexts de fluxo
├── hooks/ types/ enums/ utils/
└── proxy.ts        # middleware do Next 16 (não middleware.ts!)
```

Regra de colocation: componente/schema usado só numa rota fica em `_components/`/`_form/` dela; usado em 2+ rotas sobe para `src/components/ui/`.

## Criar uma rota nova

1. Pasta no route group certo: `src/app/(company)/<rota>/page.tsx` com `'use client'` e `export default function XxxPage()`.
2. Topo da página: `Breadcrumb` + `SectionHeader`.
3. Dados via service (`src/services/<dominio>.service.ts`), nunca fetch direto no componente.
4. Registrar no matcher de `src/proxy.ts` se exigir auth, e adicionar link no `Sidebar.tsx`.
5. Next 16: `params` é Promise; use `use(params)` do React 19.

## Componentes

- Quase tudo é Client Component; componente puro de apresentação fica sem hooks e sem diretiva.
- Com variantes: CVA + `VariantProps` + `cn()` (padrão `Button.tsx`).
- Props em `interface XxxProps` explícita; import direto por caminho (`@components/ui/Button`), não confie no barrel.

## API (client-side, sem server actions)

- Todo acesso via `getApiClient()` de `src/lib/api/client.ts`: `get/post/put/patch/delete<T>(endpoint, body?, { auth, params, formData, onProgress })`.
- `auth: true` injeta Bearer da sessão next-auth; 401 faz signOut automático com `?expired=true`.
- Browser fala com `/api/proxy/*` (rewrite no next.config.ts), nunca direto com o backend.
- Service por domínio: objeto literal exportado com métodos async tipados. Endpoints do backend em português (`/usuarios`, `/auth/login`).
- Erros do backend chegam como `{ title, message, status, erros }`: exiba com `useToast()`.

## Estado e forms

- Sem Redux/Zustand/React Query: useState local + Context (`useToast`, `useLoading`, contexts de fluxo por layout).
- Form: `useForm<T>({ resolver: zodResolver(schema), mode: 'onChange' })`; `Controller` + `MaskedInput` para campos mascarados; schema em `_form/` da rota; tipos com `z.input<>`/`z.output<>`.

## Comandos

```bash
pnpm dev     # next dev --turbopack
pnpm build   # next build (única verificação: NÃO existe lint nem test no projeto)
```

Não rode `pnpm lint`/`pnpm test`: esses scripts não existem. Validação = `pnpm build` (TS strict).

## Pontos de atenção

- Middleware é `src/proxy.ts` exportando `proxy` + `config.matcher` (Next 16). O README que manda criar middleware.ts está desatualizado.
- Autorização por `ProfilesEnum`/`PermissionEnum` checada dentro dos componentes.
- Módulo `(publico-pos-venda)` é todo nomeado em português (Botao, Icone, useCapturarFoto); os demais em inglês. Siga o idioma do módulo em que estiver.
- Sem dark mode ativo; tokens de tema: `bg-primary`, `text-accent`, `text-error`.
- Mutação de sessão sem re-login: callback jwt com `trigger === "update"` (usado na seleção de loja).
