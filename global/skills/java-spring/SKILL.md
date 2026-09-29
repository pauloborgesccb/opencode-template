---
name: Java Spring (arquitetura lyra, Spring moderno)
description: Arquitetura do projeto lyra (hexagonal por usecase, fatias verticais, Liquibase), modernizada para Spring Boot 4+. Use APENAS ao trabalhar no lyra ou em projeto Java/Spring que declaradamente siga esse padrão; em outros projetos Spring, siga as convenções locais.
---

# Java + Spring Boot (arquitetura lyra, versão moderna)

## Quando usar

Desenvolvimento em backend Java/Spring: endpoint novo, usecase, entidade, migration, teste.

## Stack alvo (código novo)

Spring Boot 4.x (Java 21+), Maven, JPA/Hibernate + PostgreSQL/PostGIS, **Liquibase**, MapStruct só no legado, Lombok, springdoc-openapi (não Springfox), OAuth2 Resource Server + JWT (Keycloak), JUnit 5 + Mockito.

No lyra real a base é Boot 2.2/Java 11; siga a ARQUITETURA dele, mas em código novo use os recursos modernos: `record` para Input/Output, `SecurityFilterChain` (não WebSecurityConfigurerAdapter), springdoc.

## Arquitetura: hexagonal em fatias verticais por feature

```
vega/monitoramento/
├── domain/
│   ├── entity/                          # entidades JPA
│   ├── usecase/<feature>/<acao>/        # Usecase + Input + Output co-localizados
│   └── interfaces/dataprovider/<feature>/  # portas de persistência
├── adapter/
│   ├── controller/<feature>/            # interface XController + XControllerImpl
│   └── gateway/repository/<feature>/    # XDataProviderImpl + XRepository (JPA)
└── application/configuration/           # security, swagger, exception handlers
```

Pacotes camelCase, domínio em português (`rastreabilidade`, `contratoOriginacao`).

## Criar um endpoint novo (fatia completa)

1. **Interface do controller** (`adapter/controller/<feature>/XController.java`): TODAS as anotações web ficam aqui: `@RequestMapping`, mapping HTTP, `@PreAuthorize("hasAnyRole('...')")`, anotações OpenAPI.
2. **Impl** (`XControllerImpl.java`): `@Controller @AllArgsConstructor @Slf4j`, injeta usecases, usuário via `sessionUtils.getUserKeycloak()`, retorna `ResponseEntity`.
3. **Input/Output** (`domain/usecase/<feature>/<acao>/`): `record` em código novo (no legado, Lombok `@Data @Builder`).
4. **Usecase** (`<Verbo><Substantivo>Usecase.java`): `@Component @AllArgsConstructor @Slf4j`, método `executar(...)`, `@Transactional(rollbackFor = Exception.class)`, depende SÓ de interfaces `*DataProvider`. Verbos do padrão: Buscar, Inserir, Cadastrar, Atualizar, Excluir, Validar, Listar, Processar, Gerar.
5. **Porta** (`domain/interfaces/dataprovider/<feature>/XDataProvider.java`).
6. **Adaptador** (`adapter/gateway/repository/<feature>/XDataProviderImpl.java` + `XRepository extends JpaRepository`).
7. **Entidade** (`domain/entity/`): `@Entity @Table(name="snake_case", schema = Constantes.SCHEMA_X)`, id por SEQUENCE.
8. **Migration**: SQL em `db/changelog/sqls/initialversion/YYYYMMDD-descricao-kebab.sql` + changeset no `db.changelog-master.yaml` (id `lyra-bd-<data>-<descricao>`, author = dev).
9. **Teste**: `src/test/.../unitarios/<feature>/...UsecaseTest.java`: `@ExtendWith(MockitoExtension.class)`, `@Mock` nas portas, `@InjectMocks` no usecase, `@DisplayName` em português.

## Validação e erros

- Padrão dominante: validação imperativa DENTRO do usecase, lançando `ValidationException("chave_i18n")` (mensagens são chaves resolvidas contra `messages_pt_BR.properties`).
- Bean Validation (`@Valid`) é minoritária; use nos DTOs de entrada quando fizer sentido, mas a regra de negócio fica no usecase.
- NUNCA repetir o antipadrão legado de try/catch no controller devolvendo `ResponseEntity.status(500).body("[ERRO_...]")`.

## Segurança (ponto crítico)

A proteção efetiva é POR MÉTODO via `@PreAuthorize` na interface do controller. O WebSecurity tem `permitAll()` amplo: **endpoint novo sem `@PreAuthorize` fica público**. Nunca crie rota sem ele. Multi-tenant: filtro por empresa (`idEmpresasFiltro` do `UserKeycloak`) é passado explicitamente ao usecase.

## Comandos

```bash
./mvnw spring-boot:run -Dspring-boot.run.profiles=dev,local,no-liquibase  # local sem migrar
./mvnw clean package -DskipTests
./mvnw test                              # JUnit 5 + JaCoCo
./mvnw test -Dtest=XUsecaseTest          # um teste
```

Porta 9000, contextPath `/monitoramento-vega`. Profiles: dev, local, homolog, staging, prod, no-liquibase.

## Pontos de atenção

- Após criar entidade, rode `mvn generate-sources` (QueryDSL gera as classes `Q*`).
- MapStruct (`service/mapper/`) e pacotes `controllers/`, `service/`, `dto/`, `payload/` são LEGADO: não crie código novo neles; usecase novo mapeia entidade→Output manualmente.
- Cobertura de teste é concentrada em usecases: todo usecase novo nasce com teste.
- Migrando para Spring Boot 4: javax → jakarta, Springfox → springdoc, WebSecurityConfigurerAdapter → SecurityFilterChain bean.
