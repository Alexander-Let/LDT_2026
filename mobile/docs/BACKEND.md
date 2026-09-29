# Конспект контракта бэкенда (handoff)

Источник истины: `LDT_2026/backend/api/openapi.yaml`. Здесь — кратко, чтобы не лезть в него.

## Общее

- Base URL: `http://10.0.2.2:8080` (эмулятор → хост), переопределение клиентом:
  `--dart-define=API_BASE_URL=http://<LAN-IP>:8080`.
- Ошибки всегда: `{"error": {"code", "message"}}`.
  Коды: `invalid_request`, `unauthorized`, `not_found`, `version_conflict`, `internal`.
- `401` — токен неизвестен/истёк.
- Аутентификация: `Authorization: Bearer <device_token>` (ребёнок),
  `Bearer <parent_token>` (родитель).

## Эндпоинты

### Служебные
| Метод | Путь | Ответ |
|---|---|---|
| GET | `/healthz` | `{status: ok}` |
| GET | `/readyz` | 200 ok / 503 unavailable |

### Детские (device_token)
| Метод | Путь | Тело / Ответ |
|---|---|---|
| POST | `/v1/profiles` | `{device_token, display_name}` → 200 (уже был) / 201 `{profile_id, display_name, link_code, created_at}`. Идемпотентен по SHA-256(device_token) |
| GET | `/v1/profiles/me` | `{profile_id, display_name, link_code, state_version, updated_at}` |
| GET | `/v1/profiles/me/state` | `{state, state_version, updated_at}` |
| PUT | `/v1/profiles/me/state` | `{state, base_version}` → 200 `{state, state_version, ...}`; **409** `{error, current_version, current_state}` — клиент мержит и повторяет |
| GET | `/v1/profiles/me/bonuses` | `[{id, amount, reason, created_at}]` — неприменённые бонусы |
| POST | `/v1/profiles/me/bonuses/{id}/applied` | идемпотентно, возвращает 200 |

### Контент (device_token)
| Метод | Путь | Ответ |
|---|---|---|
| GET | `/v1/content/bundle` | `{version, published_at, payload}`; 404 если нет бандла |

### Родительские (parent_token)
| Метод | Путь | Тело / Ответ |
|---|---|---|
| POST | `/v1/parents/otp` | `{email, consent:true}` → 200 `{expires_at, dev_code?}` (dev_code только при APP_ENV=dev) |
| POST | `/v1/parents/session` | `{email, code}` → 201 `{parent_token, expires_at}` (токен живёт 30 дней) |
| POST | `/v1/parents/links` | `{link_code}` → 200 `{profile_id, display_name}` (код сравнивается без регистра, идемпотентно) |
| GET | `/v1/parents/children` | `[{profile_id, display_name, linked_at, state_version, updated_at}]` |
| GET | `/v1/parents/children/{profile_id}/summary` | `{profile_id, display_name, state, state_version, updated_at}` (чужой профиль → 404) |
| POST | `/v1/parents/children/{profile_id}/bonuses` | `{amount: 1..10000, reason}` → 201 Bonus |

## Схема игрового `state` (jsonb, серверу непрозрачен; владелец формата — клиент)

```json
{
  "schema": 1,
  "balance": 0,
  "savings": 0,
  "goal_id": "bike | null",
  "goal_saved": 0,
  "pet": {"name": "...", "color": "...", "accessory": "...", "stage": "baby", "mood": 0, "satiety": 0},
  "period": {"number": 1, "plan": {"mandatory": 0, "optional": 0, "savings": 0}, "fact": {}},
  "completed_tasks": ["task_id"],
  "purchases": [{"item_id", "name", "price", "kind", "at"}],
  "glossary_seen": [],
  "history": [{"at", "text"}],          // client-расширение
  "applied_bonuses": [1]                // client-расширение
}
```

Клиент волен расширять схему.

## Поведение клиента

- **409 version_conflict**: взять `current_state`, слить со своим (в приложении —
  серверное состояние как основа + локальные поля поверх с приоритетом),
  повторить PUT с `base_version = current_version`.
- **Офлайн**: всё работает локально; state помечается dirty и синхронизируется
  при появлении сети.
- **Бонусы**: GET → для каждого неприменённого id начислить amount на balance,
  записать в историю «Бонус от родителя: reason», затем POST applied.

## Контент-бандл payload v1

```json
{
  "schema": 1,
  "tasks": [{"id", "topic": "budget|saving|payments", "title", "situation",
             "choices": [{"id", "text", "is_good", "explanation",
                          "effects": {"balance_delta", "savings_delta", "mood_delta"}}],
             "reward"}],
  "shop_items": [{"id", "name", "kind": "mandatory|optional", "price", "mood_delta", "hunger_delta"}],
  "goals": [{"id", "name", "cost", "emoji"}],
  "glossary": [{"term", "definition"}]
}
```

Приложение стартует на встроенном бандле `assets/content/bundle.json` (копия v1 из
`backend/migrations/00003_content_seed.sql`), кэширует в SQLite и обновляет с
сервера, если `version` новее локальной.
