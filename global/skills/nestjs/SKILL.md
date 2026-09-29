---
name: NestJS (padrão santander-solar-api)
description: Arquitetura do projeto santander-solar-api (NestJS 11, TypeORM, PostgreSQL, Liquibase, módulos em português). Use APENAS ao trabalhar no santander-solar-api ou em projeto que declaradamente siga esse padrão; em outros projetos NestJS, siga as convenções locais do projeto.
---

# NestJS (arquitetura santander-solar-api)

## Quando usar

Desenvolvimento em API NestJS: módulo novo, endpoint, entity, DTO, validação, fila, cron, cache.

## Stack de referência

NestJS 11 + TypeORM 0.3 + PostgreSQL, migrations via **Liquibase** (SQL puro, NÃO TypeORM migrations), class-validator + Swagger, JWT/Passport, RabbitMQ (amqplib manual), Redis (ioredis), pnpm, Node 20.

## Estrutura

Módulos por domínio de negócio, nomes em **português**, um por pasta direto em `src/` (sem `src/modules/`):

```
src/<dominio>/
├── <dominio>.module.ts
├── controllers/<dominio>.controller.ts
├── services/<dominio>.service.ts
├── entidades/<nome>.entity.ts        # "entidades", não "entities"
├── dto/                              # com index.ts barrel
└── enums/
```

Módulo de referência para copiar o padrão: `src/empresa/`.

## Criar um módulo/endpoint novo (checklist)

1. Criar a pasta com as subpastas canônicas acima.
2. **Entity**: `@Entity('tb_<nome>')`, colunas com `name: 'snake_case'` e `type` explícitos, propriedades camelCase, timestamps `@CreateDateColumn`/`@UpdateDateColumn` com `type: 'timestamptz'`.
3. **DTO**: class-validator com mensagens **em português** (`@IsNotEmpty({ message: 'CNPJ é obrigatório.' })`), `@Transform` para normalizar antes de validar (tirar máscara, uppercase), `@ApiProperty` com description + example em todo campo. Barrel em `dto/index.ts`.
4. **Service**: validação de negócio acumulando erros e lançando de uma vez:
   `throw new BadRequestException(new ErrorResponseDto(titulo, mensagem, erros))`.
   CRUD simples pode estender `BaseService` de `src/common/services/base.service.ts`.
5. **Controller**: `@ApiTags` + `@Controller('<dominio>')`, `@ApiOperation/@ApiResponse` em toda rota, retorno = ResponseDto.
6. **Auth**: padrão vigente é
   `@UseGuards(AuthGuard('jwt'), RolesGuard)` + `@Roles([PerfilUsuario.ADMIN])` + `@UsuarioAutenticado() usuario: UsuarioComContexto`.
   (O decorator composto `@Auth()` existe mas não é o padrão em uso.)
7. **Module**: `TypeOrmModule.forFeature([...])`, `forwardRef()` para dependência circular, exportar service. Registrar em `AppModule.forRoot()` (`src/app.module.ts`).
8. **Migration**: `npm run migrate:create <nome>` gera SQL em `src/migrations/changes/` e já registra no changelog. A app aplica no boot com `MIGRATION_ENABLE=true`. Dados iniciais também são migrations SQL (não há seed).

## Erros (formato padronizado)

Resposta de erro sempre `{ titulo, mensagem, erros[] }` (`ErrorResponseDto`); filter global já converte erros do class-validator. Não crie outro formato.

## Filas RabbitMQ (implementação própria, 4 camadas)

Para evento novo: valor no enum `RabbitMQEvent` + tipo em `RabbitMQEventData` (`src/rabbitmq/events/`) → entrada no registry (`registry/`) → método no handler (`handlers/`). Publicar com `rabbitMQService.publish()`. Não usar @nestjs/microservices.

## Cache e Cron

- Cache: decorator `@Cacheable({ ttl, keyPrefix, includeParams })`, chaves em `cache-keys.enum.ts`, flag `REDis_ENABLED`.
- Cron: `@nestjs/schedule` só com `ENABLE_CRON=true`; execução única em multi-pod via `LeaderService` (`ENABLE_LEADER`).

## Comandos

```bash
docker-compose -f docker/docker-compose.yml up -d  # postgres, rabbit, redis, signoz
npm run start:dev
npm run build && npm run lint && npm run test
npm run migrate:create <nome>
```

## Pontos de atenção (inconsistências conhecidas)

- README cita `migrate:up/check/stats`: esses scripts NÃO existem; migration aplica no boot.
- `npm run cli` aponta para `src/commands/` que não existe.
- Não há `.spec.ts` em `src/` (só um e2e); código novo com teste unitário é melhoria bem-vinda, seguindo jest já configurado.
- PDF via Puppeteer + Handlebars (`PdfService`), Excel via exceljs (`ExcelService`); templates `.hbs` copiados para dist pelo nest-cli.json.
- Storage de arquivos é filesystem local (`STORAGE_PATH`), não S3.
- Swagger em `/docs` protegido por basic auth (`SWAGGER_USER`/`SWAGGER_PASS`).
