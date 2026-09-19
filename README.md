# Питомец Финни — backend

Серверная часть прототипа «Питомец Финни» — мобильного приложения по финансовой
грамотности для детей 7–11 лет (кейс ДЕПФИН г. Москвы, ЛЦТ 2026).

Бэкенд — опциональный сервис в local-first архитектуре: игровой цикл полностью
работает офлайн на устройстве, сервер отвечает за синхронизацию профиля, доставку
учебного контента и родительскую сводку.

## Стек

- Go 1.27, gin, pgx, goose, PostgreSQL 16
- Конфигурация — только через переменные окружения (см. `backend/.env.example`)
- Контракт API — OpenAPI 3 (`backend/api/openapi.yaml`, в работе)

## Быстрый запуск

Требуется Docker с Compose.

```bash
docker compose up --build
```

Поднимаются три сервиса: `db` (PostgreSQL), `migrate` (миграции goose) и
`server` (HTTP API на порту 8080). Проверка:

```bash
curl http://localhost:8080/healthz   # {"status":"ok"}
curl http://localhost:8080/readyz    # проверка соединения с БД
```

Остановка: `docker compose down`. Сброс данных: `docker compose down -v`.

## Локальная разработка без Docker

```bash
cd backend
cp .env.example .env   # и заполнить DATABASE_URL своим PostgreSQL
go test ./...
go run ./cmd/migrate
go run ./cmd/server
```

## Структура репозитория

```
├── backend/
│   ├── cmd/
│   │   ├── server/      # HTTP-сервис
│   │   └── migrate/     # применение миграций goose
│   ├── api/             # спецификация OpenAPI 3
│   ├── internal/
│   │   ├── config/      # конфигурация из env
│   │   ├── http/        # роутеры, middleware, healthcheck
│   │   └── store/       # доступ к PostgreSQL (pgx)
│   ├── migrations/      # SQL-миграции (встраиваются в бинарник)
│   ├── Dockerfile
│   └── .env.example
├── docker-compose.yml   # postgres + migrate + server, запуск одной командой
└── docs/                # документация (структура данных, матрица ТЗ, тест-кейсы)
```
