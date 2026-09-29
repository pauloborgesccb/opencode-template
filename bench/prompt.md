Crie um sistema de controle de despesas pessoais com backend e frontend separados.

## Estrutura
- `backend/`: API em NestJS com banco SQLite (TypeORM). Porta 4001.
- `frontend/`: Next.js (App Router) consumindo a API. Porta 4000.
- Sem autenticação. Sem Docker. Node puro.

## Backend (NestJS + SQLite)
Entidades:
- Category: id, name (único, obrigatório)
- Expense: id, description (obrigatório), amount (decimal > 0), date (ISO), categoryId (FK obrigatória)

Endpoints:
- POST /categories: cria categoria. Nome duplicado retorna 409.
- GET /categories: lista todas.
- POST /expenses: cria despesa. amount <= 0 ou date inválida retorna 400; categoryId inexistente retorna 404.
- GET /expenses?categoryId=&month=YYYY-MM: lista com filtros opcionais combináveis.
- DELETE /expenses/:id: remove; inexistente retorna 404.
- GET /summary?month=YYYY-MM: retorna total geral do mês e total por categoria, ordenado do maior para o menor.

Requisitos:
- DTOs com class-validator em todos os POSTs.
- Arquivo de banco: backend/dev.sqlite (synchronize ligado, sem migrations).
- Script `npm run seed` que insere 3 categorias e 8 despesas em meses variados (inclua despesas em 2026-09).
- CORS liberado para http://localhost:4000.

## Frontend (Next.js)
Três áreas em uma única página:
1. Formulário de nova despesa (descrição, valor, data, select de categoria carregado da API), com exibição da mensagem de erro da API quando houver.
2. Lista de despesas com filtro por categoria e por mês, e botão de excluir em cada linha.
3. Card de resumo do mês selecionado: total geral e total por categoria.
A lista e o resumo devem atualizar após criar ou excluir sem recarregar a página.
Estilo mínimo (CSS puro ou Tailwind), sem biblioteca de componentes.

## Critérios de aceite (serão executados)
1. `cd backend && npm install && npm run seed && npm run start:dev` sobe sem erro.
2. `cd frontend && npm install && npm run dev` sobe sem erro.
3. `curl -X POST localhost:4001/expenses -H 'Content-Type: application/json' -d '{"description":"x","amount":-5,"date":"2026-09-01","categoryId":1}'` retorna 400.
4. `curl -X POST localhost:4001/expenses -H 'Content-Type: application/json' -d '{"description":"x","amount":10,"date":"2026-09-01","categoryId":999}'` retorna 404.
5. `curl 'localhost:4001/summary?month=2026-09'` retorna JSON com totalGeral e array por categoria ordenado.
6. Criar despesa pela interface atualiza lista e resumo sem reload.

Entregue tudo funcionando. Não pergunte nada, tome as decisões e execute.
