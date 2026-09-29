---
name: FastAPI
description: Padrões para desenvolver APIs em FastAPI (Pydantic v2, async, APIRouter, SQLAlchemy 2). Use ao criar ou alterar endpoints, models, schemas ou dependências em projeto FastAPI/Python.
---

# FastAPI

## Quando usar

Qualquer desenvolvimento em projeto FastAPI: endpoint novo, model, schema, dependência, autenticação, testes.

## Estrutura padrão (por domínio)

```
app/
├── main.py              # create_app, include_router, lifespan
├── core/                # config (pydantic-settings), security, db engine
├── <dominio>/
│   ├── router.py        # APIRouter do domínio
│   ├── schemas.py       # Pydantic v2 (entrada/saída)
│   ├── models.py        # SQLAlchemy 2 (Mapped/mapped_column)
│   ├── service.py       # regra de negócio
│   └── deps.py          # dependências do domínio
└── tests/
```

## Padrões obrigatórios

- **Pydantic v2**: `model_config = ConfigDict(from_attributes=True)`; schemas separados: `XCreate`, `XUpdate`, `XOut`. Nunca expor model ORM direto.
- **SQLAlchemy 2 estilo novo**: `Mapped[tipo]` + `mapped_column()`, sessão async (`AsyncSession`) se o projeto for async.
- **Rotas async** por padrão; sync somente para lib bloqueante sem alternativa.
- **DI com `Depends`**: sessão de banco, usuário autenticado e paginação entram por dependência, nunca instanciados na rota.
- **Router por domínio**: `APIRouter(prefix="/clientes", tags=["clientes"])`, incluído no main.
- **Erros**: `HTTPException` com status correto (400 validação de negócio, 404 não encontrado, 409 conflito); handler global para exceções de domínio via `@app.exception_handler`.
- **response_model sempre** (ou tipo de retorno anotado) para contrato e docs corretos.

## Criar um endpoint

```python
@router.post("/", response_model=ClienteOut, status_code=201)
async def criar(dados: ClienteCreate, db: AsyncSession = Depends(get_db)):
    return await service.criar_cliente(db, dados)
```

1. Schema em `schemas.py`, regra em `service.py`, rota fina no `router.py`.
2. Migration com Alembic: `alembic revision --autogenerate -m "..."` e revisar o gerado antes de aplicar.

## Comandos

```bash
uvicorn app.main:app --reload    # dev (ou fastapi dev app/main.py)
pytest                            # testes (httpx.AsyncClient + ASGITransport)
alembic upgrade head              # migrations
ruff check . && ruff format .     # lint/format
```

## Evitar

- Regra de negócio dentro da rota; query direta na rota.
- Schemas Pydantic v1 (`class Config`, `orm_mode`): use ConfigDict.
- Retornar dict solto quando existe schema; `except Exception` genérico engolindo erro.
