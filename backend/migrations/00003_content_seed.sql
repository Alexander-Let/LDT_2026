-- +goose Up
INSERT INTO content_bundles (version, payload) VALUES (1, $$
{
  "schema": 1,
  "tasks": [
    {
      "id": "budget_week",
      "topic": "budget",
      "title": "Карманные деньги",
      "situation": "Мама дала Финни 100 монет на неделю. Что Финни сделает в первый же день?",
      "choices": [
        {
          "id": "plan",
          "text": "Записать, на что нужны деньги, и отложить часть в копилку",
          "is_good": true,
          "explanation": "Молодец! Когда есть план, денег хватает на всё важное, а копилка растёт.",
          "effects": {"balance_delta": -20, "savings_delta": 20, "mood_delta": 10}
        },
        {
          "id": "spend_all",
          "text": "Сразу купить сладости на все 100 монет",
          "is_good": false,
          "explanation": "Сладости закончились за один день, и до конца недели монет не осталось. В следующий раз попробуй составить план!",
          "effects": {"balance_delta": -100, "savings_delta": 0, "mood_delta": -10}
        }
      ],
      "reward": 30
    },
    {
      "id": "budget_gift",
      "topic": "budget",
      "title": "Подарок другу",
      "situation": "У лучшего друга Финни скоро день рождения. Подарок стоит 50 монет, а у Финни есть 80.",
      "choices": [
        {
          "id": "buy_gift",
          "text": "Купить подарок заранее, а остаток распланировать",
          "is_good": true,
          "explanation": "Так держать! Подарок куплен вовремя, а оставшиеся монеты ещё поработают.",
          "effects": {"balance_delta": -50, "savings_delta": 0, "mood_delta": 10}
        },
        {
          "id": "buy_toy",
          "text": "Купить себе игрушку за 80 монет и забыть про подарок",
          "is_good": false,
          "explanation": "Игрушка радует недолго, а друг остался без подарка. Сначала — запланированные покупки!",
          "effects": {"balance_delta": -80, "savings_delta": 0, "mood_delta": -15}
        }
      ],
      "reward": 30
    },
    {
      "id": "saving_piggy",
      "topic": "saving",
      "title": "Копилка на мечту",
      "situation": "Финни мечтает о велосипеде за 500 монет. Каждую неделю у него остаются 30 свободных монет.",
      "choices": [
        {
          "id": "save_weekly",
          "text": "Класть 20 монет в копилку каждую неделю",
          "is_good": true,
          "explanation": "Отлично! Маленькие шаги каждую неделю приводят к большой цели.",
          "effects": {"balance_delta": -20, "savings_delta": 20, "mood_delta": 10}
        },
        {
          "id": "keep_pocket",
          "text": "Держать монеты в кармане — они и так пригодятся",
          "is_good": false,
          "explanation": "Монеты из кармана незаметно тратятся на мелочи, а цель всё дальше. Копилка надёжнее!",
          "effects": {"balance_delta": -30, "savings_delta": 0, "mood_delta": -5}
        }
      ],
      "reward": 30
    },
    {
      "id": "saving_prize",
      "topic": "saving",
      "title": "Неожиданный приз",
      "situation": "Финни выиграл 100 монет на школьном конкурсе. Как распорядиться призом?",
      "choices": [
        {
          "id": "split",
          "text": "Половину — в копилку на мечту, половину — на маленькую радость",
          "is_good": true,
          "explanation": "Здорово! И мечта стала ближе, и праздник получился.",
          "effects": {"balance_delta": 50, "savings_delta": 50, "mood_delta": 10}
        },
        {
          "id": "spend_day",
          "text": "Потратить всё за один день в игровом магазине",
          "is_good": false,
          "explanation": "Через день от приза ничего не осталось. Часть выигрыша в копилке работала бы на мечту!",
          "effects": {"balance_delta": 0, "savings_delta": 0, "mood_delta": -5}
        }
      ],
      "reward": 30
    },
    {
      "id": "payments_shop",
      "topic": "payments",
      "title": "Покупки в магазине",
      "situation": "У Финни 150 монет. Корм для питомца стоит 60 монет, а блестящая наклейка — 100 монет. На всё сразу не хватает.",
      "choices": [
        {
          "id": "food_first",
          "text": "Сначала купить корм — питомец не может ждать",
          "is_good": true,
          "explanation": "Верно! Сначала нужное, потом — хотелки. Питомец сыт, а на наклейку можно накопить.",
          "effects": {"balance_delta": -60, "savings_delta": 0, "mood_delta": 10}
        },
        {
          "id": "sticker_first",
          "text": "Купить наклейку, а корм — потом как-нибудь",
          "is_good": false,
          "explanation": "Наклейка красивая, но питомец остался голодным. Обязательные расходы всегда впереди!",
          "effects": {"balance_delta": -100, "savings_delta": 0, "mood_delta": -15}
        }
      ],
      "reward": 40
    },
    {
      "id": "payments_stranger",
      "topic": "payments",
      "title": "Странное сообщение",
      "situation": "В чате незнакомец пишет Финни: «Переведи мне 200 монет, а я верну тебе 300!»",
      "choices": [
        {
          "id": "refuse",
          "text": "Ничего не переводить и рассказать взрослым",
          "is_good": true,
          "explanation": "Правильно! Обещание «вернуть больше» — почти всегда обман. Про деньги и пароли говори со взрослыми.",
          "effects": {"balance_delta": 0, "savings_delta": 0, "mood_delta": 5}
        },
        {
          "id": "transfer",
          "text": "Перевести 200 монет — вдруг правда вернут?",
          "is_good": false,
          "explanation": "Незнакомец пропал вместе с монетами. Никогда не переводи деньги незнакомым людям!",
          "effects": {"balance_delta": -200, "savings_delta": 0, "mood_delta": -10}
        }
      ],
      "reward": 50
    }
  ],
  "shop_items": [
    {"id": "feed", "name": "Корм для Финни", "kind": "mandatory", "price": 60, "mood_delta": 5, "hunger_delta": 40},
    {"id": "vitamins", "name": "Витамины", "kind": "mandatory", "price": 40, "mood_delta": 5, "hunger_delta": 10},
    {"id": "shampoo", "name": "Шампунь для питомца", "kind": "mandatory", "price": 35, "mood_delta": 5, "hunger_delta": 0},
    {"id": "brush", "name": "Расчёска", "kind": "mandatory", "price": 25, "mood_delta": 5, "hunger_delta": 0},
    {"id": "ball", "name": "Мячик-попрыгунчик", "kind": "optional", "price": 80, "mood_delta": 20, "hunger_delta": 0},
    {"id": "bow", "name": "Нарядный бантик", "kind": "optional", "price": 50, "mood_delta": 10, "hunger_delta": 0},
    {"id": "stickers", "name": "Набор наклеек", "kind": "optional", "price": 30, "mood_delta": 8, "hunger_delta": 0},
    {"id": "glow_collar", "name": "Светящийся ошейник", "kind": "optional", "price": 120, "mood_delta": 25, "hunger_delta": 0}
  ],
  "goals": [
    {"id": "bike", "name": "Велосипед для Финни", "cost": 500, "emoji": "🚲"},
    {"id": "castle", "name": "Домик-замок", "cost": 900, "emoji": "🏰"},
    {"id": "microscope", "name": "Микроскоп", "cost": 350, "emoji": "🔬"}
  ],
  "glossary": [
    {"term": "Бюджет", "definition": "План, куда пойдут твои деньги: сколько потратить, а сколько отложить."},
    {"term": "Обязательные расходы", "definition": "Покупки, без которых нельзя: еда для питомца, уход, лекарства."},
    {"term": "Накопления", "definition": "Деньги, которые ты откладываешь в копилку на большую цель."},
    {"term": "Цель", "definition": "Большая покупка-мечта, на которую ты копишь."},
    {"term": "Доход", "definition": "Деньги, которые к тебе приходят: карманные деньги, подарки, награды за задания."}
  ]
}
$$
)
ON CONFLICT (version) DO NOTHING;

-- +goose Down
DELETE FROM content_bundles WHERE version = 1;
