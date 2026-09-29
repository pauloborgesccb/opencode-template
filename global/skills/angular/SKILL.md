---
name: Angular
description: Padrões para desenvolver em Angular moderno (v22+, signals, zoneless, standalone). Use ao criar ou alterar componentes, services, rotas ou forms em projeto Angular puro (não Ionic).
---

# Angular (v22+)

## Quando usar

Qualquer desenvolvimento em projeto Angular puro: componente novo, service, rota, form, refatoração. Para Ionic, use a skill ionic.

## Padrões obrigatórios

- **Standalone sempre**: componentes, directives e pipes standalone; NgModule só se o projeto legado exigir.
- **Signals para estado**: `signal()`, `computed()`, `linkedSignal()`. Inputs/outputs com `input()`, `output()` e `model()`, nunca decorators `@Input/@Output` em código novo.
- **Zoneless é o default** (v22): não dependa de Zone.js; mudanças de estado via signals.
- **Change detection**: OnPush é o default; não reative Eager (antigo Default) sem motivo.
- **Dados assíncronos**: `resource()` / `httpResource()` para fetch; evite subscribe manual em componente.
- **Forms**: Signal Forms (estáveis na v22) para forms novos; Reactive Forms só onde já existem.
- **DI**: `inject()` em vez de constructor injection em código novo.
- **Control flow**: `@if`, `@for` (com `track`), `@switch` e `@defer` no template; nunca `*ngIf/*ngFor` em código novo.

## Criar um componente

```bash
ng generate component features/<feature>/<nome> --style=scss
```

1. Organize por feature: `src/app/features/<feature>/` com componentes, service e rotas da feature juntos.
2. Componente de apresentação: só `input()`/`output()`, sem service injetado.
3. Componente de página: injeta service, orquestra signals, passa dados para os de apresentação.

## Criar um service de dados

```ts
@Injectable({ providedIn: 'root' })
export class ClienteService {
  private http = inject(HttpClient);
  clientes = httpResource<Cliente[]>(() => `${API}/clientes`);
}
```

## Rotas

Lazy por feature: `loadChildren: () => import('./features/x/x.routes')`. Guards funcionais (`CanActivateFn`), não classes.

## Comandos

```bash
ng serve          # dev
ng build          # produção
ng test           # unit (vitest ou karma conforme o projeto)
ng lint
```

## Evitar

- NgModules, decorators de I/O, `*ngIf/*ngFor`, subscribe em componente, `any`, Zone.js APIs.
- Ao tocar código legado, migre folha por folha (componentes de apresentação primeiro), não o projeto inteiro de uma vez.
