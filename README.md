# Питомец Финни — backend

Серверная часть прототипа «Питомец Финни» — мобильного приложения по финансовой
грамотности для детей 7–11 лет (кейс ДЕПФИН г. Москвы, ЛЦТ 2026).

Бэкенд — опциональный сервис в local-first архитектуре: игровой цикл полностью
работает офлайн на устройстве, сервер отвечает за синхронизацию профиля, доставку
учебного контента и родительскую сводку.

## Стек

- Go 1.27, gin, pgx, goose, PostgreSQL 16
- Конфигурация — только через переменные окружения (см. `backend/.env.example`)
- Контракт API — OpenAPI 3: [`backend/api/openapi.yaml`](backend/api/openapi.yaml)

## Архитектура

Один Go-модуль, одна база PostgreSQL, четыре HTTP-процесса плюс шлюз:

```
                 ┌────────────┐
                 │  gateway   │ :8080 — единственный наружу (reverse proxy, stdlib)
                 └─────┬──────┘
       /v1/parents/   │   /v1/content/      остальное (/v1/profiles*, /healthz, /readyz)
              ┌───────┴───────────┬─────────────────────────┐
              ▼                   ▼                         ▼
         parents :8083      content :8082             profiles :8081
         /v1/parents/*      /v1/content/bundle        /v1/profiles*, state, бонусы
              └───────────────────┴─────────────────────────┘
                                  ▼
                       PostgreSQL 16 (общая база, миграции goose — сервис migrate)
```

- Каждый доменный сервис — отдельный бинарник из `cmd/` (`profiles`, `content`,
  `parents`, `gateway`), собранный из одного Dockerfile; все хендлеры живут
  в `internal/http`, роуты по доменам собирают `NewProfilesRouter`,
  `NewContentRouter`, `NewParentsRouter` (монолитный `NewRouter` сохранён
  для локальной разработки через `cmd/server`).
- Порты 8081–8083 доступны только внутри сети compose; снаружи — только
  gateway на 8080. Адреса апстримов gateway задаются env `PROFILES_URL`,
  `CONTENT_URL`, `PARENTS_URL` (по умолчанию `http://localhost:8081`–`8083`).
- Каждый сервис отвечает `/healthz`; `/readyz` проверяет пинг БД. Gateway
  проксирует оба пути на profiles.

## Быстрый запуск

Требуется Docker с Compose.

```bash
docker compose up --build
```

Поднимаются шесть сервисов: `db` (PostgreSQL), `migrate` (миграции goose),
`profiles`, `content`, `parents` и `gateway` (единая точка входа на порту
8080). Проверка:

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
go run ./cmd/server    # монолит на :8080 со всеми доменами
```

Доменные сервисы без Docker запускаются по одному (каждому — свой порт через
`HTTP_ADDR`, например `HTTP_ADDR=:8081 go run ./cmd/profiles`), gateway —
`go run ./cmd/gateway`.

Тесты не требуют базы данных. Интеграционный тест store пропускается,
пока не задан `DATABASE_URL` (`go test -short` тоже его пропускает).

## Аутентификация и приватность

Персональные данные ребёнка не собираются. Два контура доступа:

- **Ребёнок** — `Authorization: Bearer <device_token>`. Клиент один раз
  генерирует случайную строку; на сервере хранится только её SHA-256-хэш.
  К одному профилю можно привязать несколько устройств: на новом устройстве
  ребёнок вводит `link_code` через `POST /v1/profiles/attach`, и новый
  токен открывает тот же профиль (таблица `profile_devices`).
- **Родитель** — `Authorization: Bearer <parent_token>`. Вход по одноразовому
  6-значному коду (OTP): `POST /v1/parents/otp` → `POST /v1/parents/session`.
  Токен сессии живёт 30 дней, в базе — только хэш. Единственные ПДн в системе —
  email родителя; согласие на обработку фиксируется (`consent: true`).

**Отправки email в прототипе нет**: OTP пишется в лог сервера (slog), а при
`APP_ENV=dev` дополнительно возвращается в поле `dev_code` ответа
`POST /v1/parents/otp`. В `prod` поле `dev_code` отсутствует.

Ошибки возвращаются в едином формате:

```json
{"error": {"code": "invalid_request", "message": "..."}}
```

Коды: `invalid_request` (400), `unauthorized` (401), `not_found` (404),
`version_conflict` (409), `internal` (500).

## API

| Метод | Путь | Доступ | Описание |
|---|---|---|---|
| GET | `/healthz` | — | живость процесса |
| GET | `/readyz` | — | готовность (пинг БД) |
| POST | `/v1/profiles` | открыт | создать профиль (идемпотентно: 200 если токен уже есть, 201 если создан) |
| POST | `/v1/profiles/attach` | открыт | привязать устройство к профилю по `link_code` (идемпотентно; восстановление на другом устройстве) |
| GET | `/v1/profiles/me` | ребёнок | профиль: имя, link_code, версия состояния |
| GET | `/v1/profiles/me/state` | ребёнок | игровое состояние `{state, state_version, updated_at}` |
| PUT | `/v1/profiles/me/state` | ребёнок | сохранить состояние; 409 + `current_version`/`current_state` при конфликте версий |
| GET | `/v1/profiles/me/bonuses` | ребёнок | неприменённые бонусы от родителя |
| POST | `/v1/profiles/me/bonuses/{id}/applied` | ребёнок | отметить бонус применённым (идемпотентно) |
| GET | `/v1/content/bundle` | ребёнок | последний бандл контента `{version, published_at, payload}` |
| POST | `/v1/parents/otp` | открыт | запросить одноразовый код (`consent: true` обязателен) |
| POST | `/v1/parents/session` | открыт | обменять код на `parent_token` (TTL 30 дней) |
| POST | `/v1/parents/links` | родитель | привязать ребёнка по `link_code` (идемпотентно) |
| GET | `/v1/parents/children` | родитель | список привязанных детей |
| GET | `/v1/parents/children/{profile_id}/summary` | родитель | сводка прогресса (только для привязанных, иначе 404) |
| POST | `/v1/parents/children/{profile_id}/bonuses` | родитель | начислить бонус (`amount` 1..100, `reason` ≤ 200) |

### Сценарий целиком (curl)

```bash
BASE=http://localhost:8080

# 1. Ребёнок: создание профиля (идемпотентно — повтор вернёт тот же профиль с 200)
curl -X POST $BASE/v1/profiles -H 'Content-Type: application/json' \
  -d '{"device_token":"my-secret-device-token-0123456789","display_name":"Финни"}'
# => {"profile_id":"...","display_name":"Финни","link_code":"K7M2QN","created_at":"..."}

# 2. Ребёнок: профиль и состояние
curl $BASE/v1/profiles/me -H 'Authorization: Bearer my-secret-device-token-0123456789'
curl $BASE/v1/profiles/me/state -H 'Authorization: Bearer my-secret-device-token-0123456789'

# 3. Ребёнок: сохранение состояния (base_version из GET; при расхождении — 409)
curl -X PUT $BASE/v1/profiles/me/state \
  -H 'Authorization: Bearer my-secret-device-token-0123456789' \
  -H 'Content-Type: application/json' \
  -d '{"state":{"balance":120,"savings":30,"mood":80},"base_version":0}'

# 4. Ребёнок: учебный контент (клиент сам сравнивает version)
curl $BASE/v1/content/bundle -H 'Authorization: Bearer my-secret-device-token-0123456789'

# 5. Родитель: запрос кода (в dev код вернётся в dev_code, иначе смотрите лог сервера)
curl -X POST $BASE/v1/parents/otp -H 'Content-Type: application/json' \
  -d '{"email":"mama@example.com","consent":true}'
# => {"expires_at":"...","dev_code":"123456"}

# 6. Родитель: обмен кода на токен сессии
curl -X POST $BASE/v1/parents/session -H 'Content-Type: application/json' \
  -d '{"email":"mama@example.com","code":"123456"}'
# => {"parent_token":"...","expires_at":"..."}

# 7. Родитель: привязка ребёнка по link_code из шага 1
curl -X POST $BASE/v1/parents/links \
  -H 'Authorization: Bearer <parent_token>' -H 'Content-Type: application/json' \
  -d '{"link_code":"K7M2QN"}'

# 8. Родитель: список детей и сводка прогресса
curl $BASE/v1/parents/children -H 'Authorization: Bearer <parent_token>'
curl $BASE/v1/parents/children/<profile_id>/summary -H 'Authorization: Bearer <parent_token>'

# 9. Родитель: бонус ребёнку
curl -X POST $BASE/v1/parents/children/<profile_id>/bonuses \
  -H 'Authorization: Bearer <parent_token>' -H 'Content-Type: application/json' \
  -d '{"amount":100,"reason":"За отличную неделю"}'

# 10. Ребёнок: видит бонус и подтверждает начисление
curl $BASE/v1/profiles/me/bonuses -H 'Authorization: Bearer my-secret-device-token-0123456789'
curl -X POST $BASE/v1/profiles/me/bonuses/<id>/applied \
  -H 'Authorization: Bearer my-secret-device-token-0123456789'

# 11. Ребёнок на НОВОМ устройстве: привязка по link_code из шага 1
curl -X POST $BASE/v1/profiles/attach -H 'Content-Type: application/json' \
  -d '{"device_token":"another-device-token-0123456789","link_code":"K7M2QN"}'
# => {"profile_id":"...","display_name":"Финни","link_code":"K7M2QN","has_state":true}
# Дальше новый токен работает с тем же профилем:
curl $BASE/v1/profiles/me/state -H 'Authorization: Bearer another-device-token-0123456789'
```

## Контракт контента (payload бандла, schema=1)

Согласован с клиентом, сидится миграцией `00003_content_seed.sql`:

```json
{"schema": 1,
 "tasks": [{"id","topic":"budget|saving|payments","title","situation",
            "choices":[{"id","text","is_good":bool,"explanation",
                        "effects":{"balance_delta":int,"savings_delta":int,"mood_delta":int}}],
            "reward":int}],
 "shop_items": [{"id","name","kind":"mandatory|optional","price":int,"mood_delta":int,"hunger_delta":int}],
 "goals": [{"id","name","cost":int,"emoji"}],
 "glossary": [{"term","definition"}]}
```

Сид версии 1: 6 заданий (по 2 на тему), 8 позиций магазина (4 обязательные +
4 необязательные), 3 цели, 5 терминов глоссария — всё на русском.

### Бандл v2 (schema=2)

Миграция `00004_content_v2.sql` добавляет бандл `version = 2` с полным игровым
контентом по спецификации (`Context/Infa.md`): `economy` (обязательные расходы
60 монет/период, правила СР с максимумом 50/период и блокировками переходов
стадий, бонусы отката +10/+50, лимит родительского бонуса 100), `professions`
(8 профессий с зарплатами, курсами, собеседованиями и мини-играми),
`shop_items` (22 товара), `goals` (3 цели), `tasks` (задания A1–G2 по периодам),
`hitrik_scenes`, `events` (случайные события периодов 2–5), `archetypes`
(5 архетипов с перками), `glossary` (16 терминов), `periods` (5 периодов с
репликами питомца). `GET /v1/content/bundle` возвращает последнюю версию,
поэтому после миграции отдаётся v2.

Лимит родительского бонуса по спецификации — не более 100 монет за раз:
`POST /v1/parents/children/{profile_id}/bonuses` принимает `amount` 1..100.

## Структура репозитория

```
├── backend/
│   ├── cmd/
│   │   ├── server/      # монолитный HTTP-сервис (локальная разработка)
│   │   ├── migrate/     # применение миграций goose
│   │   ├── profiles/    # сервис детских профилей (:8081)
│   │   ├── content/     # сервис учебного контента (:8082)
│   │   ├── parents/     # сервис родительского раздела (:8083)
│   │   └── gateway/     # reverse proxy, единая точка входа (:8080)
│   ├── api/             # спецификация OpenAPI 3
│   ├── internal/
│   │   ├── config/      # конфигурация из env
│   │   ├── http/        # роутеры (монолит + по доменам), middleware, хендлеры
│   │   └── store/       # доступ к PostgreSQL (pgx)
│   ├── migrations/      # SQL-миграции (встраиваются в бинарник)
│   ├── Dockerfile       # один образ на все сервисы (command-override в compose)
│   └── .env.example
├── docker-compose.yml   # db + migrate + profiles + content + parents + gateway
└── docs/                # документация (структура данных, матрица ТЗ, тест-кейсы)
```
