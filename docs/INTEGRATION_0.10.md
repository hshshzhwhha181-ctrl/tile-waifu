# INTEGRATION_0.10 — карта интеграции модулей 0.10 в настоящую игру

Обновлено: 2026-11-24 (ветка `v10-integration`, `6f5ad0d` + этот документ; замеры §0 сделаны на `6f5ad0d`). Пишется для агентов, которые будут
вливать модули `game/scripts/v10/**` в настоящую игру: навигацию `main.gd`, сейв `g.gd`, хуки `play.gd`.

**Приоритет источников** (при расхождении побеждает верхний):
1. Красные линии HANDOFF §1 и решения владельца (HANDOFF, spec §11, «Решения» в HUD_V2).
2. `docs/UX_RULES.md` — всё, что игрок видит и слышит (вкладки, имена, кнопки, цены, звук). Чек-лист §10 обязателен
   для каждого шага: отчёт начинается строкой `UX_RULES: P0 N/N, P1 N/N`, любое «нет» в P0 — шаг не принят.
3. `docs/HUD_V2.md` — HUD v2 **заменяет** старый HUD (HANDOFF §18), это выше старых HUD-правок из README дорожек.
4. `docs/0.10-spec.md` — механика, данные, код (§2 контракт, §2.8 хуки, §3.1 горячие файлы).
5. `docs/MODES.md` (хаб «Столы», контракт режимов §7.1), `docs/LEGWEAR.md`, README модулей.

**Как пользоваться.** Шаги W1 → W2 → W3 → W4 идут строго по очереди, каждый — отдельный коммит/пуш в
`v10-integration` с полным прогоном проверок (§5). Раздел §2 — паспорт каждого модуля: что вызывать, где он
живёт в навигации, что менять в горячих файлах, с чем он конфликтует. Раздел §3 — сквозные решения, которые
нужно принять один раз (деньги, время, имена, HUD, музыка). Раздел §4 — шаги и приёмка.

---

## §0. Базовая линия (замер на `v10-integration` @ `6f5ad0d`, 2026-11-24, до любой интеграции)

Godot 4.5.1 (`/opt/tw-tools/godot`), каждый запуск через `flock /tmp/tw-godot.lock`, перед прогоном один раз
`--headless --path game --import` (0 ошибок).

### 0.1. Базовые самотесты (HANDOFF §2) и fuzz

| Проверка | Команда (`godot --headless --path game -- …`) | Результат | Время |
|---|---|---|---|
| selftest | `--selftest=1` | **SELFTEST 240/240** boards solved | 16 с |
| event | `--event_selftest=1` | **EVENT SELFTEST 84/84** | 6 с |
| league | `--league_selftest=1` | **LEAGUE SELFTEST 1131/1131** | 4 с |
| profile | `--profile_selftest=1` | **PROFILE SELFTEST 13/13** | 4 с |
| recovery | `--recovery_selftest=1` | **RECOVERY SELFTEST 42/42** | 4 с |
| ults | `--ults_selftest=1` | **ULTS SELFTEST 671/671** (в HANDOFF было 669 — проверок стало больше, все зелёные) | 3 с |
| letters | `--letters_selftest=1` | **LETTERS SELFTEST 2589/2589** | 4 с |
| summon | `--summon_selftest=1` | **флага нет в коде** (ни в одной ветке; `grep -rn summon_selftest` пусто). Игра просто открывает главную и висит — процесс снят по таймауту. Строка «summon_selftest 56/56» в HANDOFF §2 ошибочна (56/56 — это самотест V10Juice). Не включать в обязательный список, пока W3 не сделает `--gacha_selftest` частью `--v10_selftest` | — |
| fuzz | `--fuzz=3` | **FUZZ 144 games: rule errors 0, blocked takes 0** (cleared 59, lost 85) | 40 с |

Шум в логах, который был и до 0.10 (не ошибка): `ERROR: Condition "!actions.custom_samplers.has(...)"` из
`hero.gd:66` в headless-рендерере и `1 resources still in use at exit`.

### 0.2. Плейтест на экспортированном пакете

| Шаг | Команда | Результат | Время |
|---|---|---|---|
| экспорт пакета | `godot --headless --path game --export-pack Android x.pck` | rc 0, пакет 288 917 220 байт (≈289 МБ) | 57 с |
| плейтест «новый игрок» | `xvfb-run -a godot --main-pack x.pck --rendering-driver opengl3 --audio-driver Dummy --resolution 720x1280 -- --pt=fresh --shots=<dir>` | **PT OK 70 steps (236 s, touch misses 0)**, 70 снимков | 247 с |

Шаблоны экспорта 4.5.1 в контейнере изначально отсутствовали: поставлены из GitHub-релиза
`Godot_v4.5.1-stable_export_templates.tpz` в `~/.local/share/godot/export_templates/4.5.1.stable/`
(только `android_debug.apk`, `android_release.apk`, `android_source.zip`, `version.txt`). APK не собирался
(нет Android SDK, `dl.google.com` закрыт) — проверяется только `.pck`.

`V8Playtest._fresh()` привязан к старой навигации (тап по титулу, `V8ProfileCard`, вкладки `collection/shop/home`,
кнопки «Сесть за стол», «ИВЕНТ»). W1 и W4 обязаны обновить его шаги вместе с навигацией и вернуть PT OK.

### 0.3. Самотесты модулей (каждый своей сценой, README модуля)

| Модуль (§) | Результат | Время | Заметка |
|---|---|---|---|
| responsive (§2.1) | **LAYOUT_SELFTEST 172/172** | 7 с | xvfb 1536×2048 |
| economy (§2.2) | **ECON_SELFTEST 394/394** | 67 с |  |
| meta (§2.3) | **META_SELFTEST 133/133 (meta 23, bond 13, notify 20, entry 7, lint 7, save 13, winbar 12, more 8, afisha 18, shop 11, grep 1)** | 14 с | META_INFO: 20 файлов с `Time.*`, 11 с `G.add_aff` — список к W1 |
| levels (§2.4) | **LEVELS SELFTEST OK 1000 levels: certificate 1000/1000, auto-player 1000/1000, blind DFS 1000/1000, real board 143/143, assist 334/334, sawtooth 100/100** | 69 с |  |
| path (§2.5) | **PATH SELFTEST 111/111 (levels 30, peaks 12, legend 10, boosters 24, wind 7, jam 4, ui 24)** | 19 с | в логе `Lambda capture at index 0 was freed` — шум, не провал |
| salon (§2.6) | **SALON_SELFTEST 198/198** | 247 с |  |
| rituals (§2.7) | **RIT_SELFTEST 133/133** | 2 с |  |
| chat (§2.8) | **CHAT SELFTEST 133/133** | 1 с |  |
| phone (§2.9) | **PHONE SELFTEST 50/50** | 6 с | xvfb 720×1280 |
| gacha (§2.10) | **GACHA_SELFTEST 111/111** | 8 с |  |
| shop (§2.11) | **SHOP_SELFTEST 482/482** | 4 с |  |
| look (§2.12) | **LOOK_SELFTEST 709/709 OK** | 3 с |  |
| fonts (§2.13) | **FONTS SELFTEST: 276 ok, 0 failed (шрифты 690 432 байт)** | 2 с |  |
| profile2 (§2.14) | **PROFILE2_SELFTEST 112/112** | 3 с |  |
| hud2 (§2.16) | **HUD2 SELFTEST 854/854 OK** | 5 с |  |
| juice (§2.17) | **JUICE SELFTEST 56/56** | 5 с |  |
| audio (§2.18) | **V10AUDIO OK 339/339** | 22 с |  |
| auth (§2.19) | **AUTH_SELFTEST 102/102** | 8 с |  |
| clarity (§2.20) | **V10 CLARITY SELFTEST 3830/3830** | 2 с |  |
| tutorial (§2.21) | **V10TUT 3322/3382 — КРАСНЫЙ** (static 3311/3311 зелёный; 60 провалов в реальном прогоне). На исходной ветке `origin/v10-tutorial` (`01ca8d3`) тот же прогон: **3323/3383**, те же провалы — не регрессия слияния | 560 с | причина: §2.21 |
| tower (§2.22) | **TOWER_SELFTEST 192/192** | 55 с |  |
| mj-stage (§2.23) | **MJ_STAGE 125/125** | 26 с |  |
| mj-look (§2.24) | **MJ_LOOK 626/626** | 12 с | xvfb 720×1280 |
| mj-triples (§2.25) | **MJ_TRIPLES 2736/2736** | 15 с |  |
| mj-riichi (§2.26) | **MJ_RIICHI 97/97** | 330 с |  |
| mj-sanma (§2.27) | **MJ_SANMA 70/70** | 159 с |  |
| mj-koikoi (§2.28) | **MJ_KOIKOI 138/138** | 15 с |  |
| rig (§2.15) | самотеста нет | — | только `scenes/v10/rig_demo.tscn`; W3 добавляет смоук |

Итого: 26 из 27 самотестов модулей зелёные с первого прогона, **tutorial красный** (подробности — §2.21 и §6).
Все команды запускались из `game/` с `XDG_DATA_HOME` во временной папке (сейвы самотестов не трогают пользовательский).
Суммарное время последовательного прогона всех модулей ≈ 28 мин (самые долгие: tutorial, riichi, salon, sanma, levels).

---

## §1. Карта навигации 0.10 (UX_RULES §3.1–§3.2) и где живёт каждый модуль

**Идентификаторы вкладок** (оставляем старые id там, где экран тот же, чтобы не ломать `V8Playtest`, обучение,
`V10Music.SCREENS`, `V10Juice.TAB_STYLE`; меняются только подписи и центральная вкладка):

| # | Вкладка (подпись) | id вкладки | Корневой экран | Было в 0.9 |
|---|---|---|---|---|
| 1 | **Чайная** | `home` | `screens/home.gd`, перестроенный на `V10HudHome` | Чайная (14 элементов) |
| 2 | **Героини** | `collection` | `screens/collection.gd` → сегменты Наряды · Стиль · История | «Гардероб» |
| 3 | **Столы** | `tables` (новый) | `v10/core/tables_hub.gd` (новый файл W1) | «Партия» (звезда) + «Режимы» |
| 4 | **Желания** | `summon` | W1: старый `summon.gd`; W3: `V10WishScreen` | Желания |
| 5 | **Лавка** | `shop` | W1: старый `shop.gd` + `V10ShopGuard`; W3: `shop2_screen.gd` | Лавка |

Все 5 вкладок одной ширины, без звезды (UX §3.1, P0-2). Шестой вкладки нет: Профиль — тап по аватару,
Настройки — ⚙ в Профиле и в паузе партии. Глубина ≤ 2 перехода от корня вкладки (лист тоже считается).

**Размещение модулей** (цифра — число переходов от корня вкладки):

```
ЧАЙНАЯ (0)                         hud2 V10HudHome · rig (сцена) · audio «lobby»/тема партнёра · juice переходы
├─ Аватар ─► Профиль (1)            profile V10CardView «own»; look «Мой стиль» переезжает в Героини → Стиль
│     ├─ Оформить карточку (2)      profile V10CardEditor
│     └─ ⚙ Настройки (2)            meta V10NotifyPanel (Уведомления) · rituals «Мой день рождения» · auth «Аккаунт» ·
│                                   clarity «Фишки и словарь» · tutorial «Как играть» · fonts «О игре» (шрифты, лицензии) ·
│                                   mj-stage/mj-look строки «Звук и Картинка»
├─ Телефон (1) ─► письмо/чат/пост (2)   phone V10Phone (оверлей) поверх chat V10LocalTransport; rituals письмо недели,
│                                        вопрос о ДР игрока; gacha письмо «Новые правила желаний»
├─ Фонарь «Сегодня» ─► Афиша (1, лист) ─► экран строки (2)   meta V10AfishaCard; строки: партия дня, Задания дня,
│                                        режим дня ×2, неделя (tower), событие (v07), сезон (shop V10PassScreen)
├─ Фонарь «Салон» ─► v10salon (1) ─► лист задачи / v10scene (2)    salon
├─ Фонарь «Серия» ─► календарь серии (1, лист)                    rituals V10StreakSheet (+ V10StreakChip в фонаре)
├─ Табличка партнёра ─► её карточка в «Героинях» (вкладка)
├─ Утренний поднос (оверлей, не навигация)   rituals V10TrayView + gacha V10SevenPanel + shop абонемент (month_claim)
├─ Полноэкранные сцены входа (V10EntryQueue, 1 за запуск)  rituals возврат/ДР · look «Новый стиль стола» · gacha первая SSR
└─ ★ «Играть · N» ─► партия         path: старт текущего уровня Пути

ГЕРОИНИ (0) — карусель, сцена с ригом (rig), сегменты:
├─ Наряды ─► карточка наряда (1): Надеть · Примерить стиль · Созвездие ✦ · Мастерство   gacha V10OutfitGrowth, look V10KitStrip
├─ Стиль: Рамка · Фишки · Стол · Интерфейс · Стинг · Шрифт ─► выбор (1)   look V10StylePicker/V10TilePicker, mj-look материалы
├─ История: реплики, сцены, Альбом ─► фото (1)                            salon фото (S.v10_salon.photos → Альбом в 1.0)
└─ «Подарить» ─► лист подарков (1)

СТОЛЫ (0) — один вертикальный экран (MODES §6.1)
├─ Свиток Пути ─► полная карта v10path (1) ─► карточка уровня (2, лист)    levels + path
├─ ★ «Играть · N»
├─ «Сегодня»: Партия дня · Режим дня ×2 (тот же компонент, что Афиша)       meta
├─ Полка «Пасьянсы» ─► экран режима (1) ─► партия                           mj-triples (+ будущие classic/connect/cube/garden)
├─ Полка «За столом» ─► экран режима (1) ─► партия                          mj-riichi, mj-sanma, mj-koikoi
└─ Полка «Испытания и соперницы» ─► экран (1) ─► партия                     tower Пагода · Странствие; старые Блиц, Дуэли, Турнир
   (слияние двух полок UX §3.2 — правка MODES §6.1, интегратор W4 записывает её в UX_RULES §3.2 одной строкой)

ЖЕЛАНИЯ (0) ≤ 3 баннера     gacha V10WishScreen
├─ ⓘ Шансы ─► «Шансы и правила» (1)       gacha V10OddsScreen (провайдеры gacha/chest/tickets)
└─ Свеча ─► лист Свечи (1) ─► выбор SSR (2)   gacha V10SparkSheet

ЛАВКА (0) сегменты Витрина · Наряды · Пополнить      shop V10Shop2
├─ любая цена ─► лист подтверждения (1)   shop V10ShopFlow.confirm
├─ карточка пропуска ─► V10PassScreen (1)
└─ подвал: Шансы и правила · Мои покупки (V10Purchases) · Восстановить покупки (1)

ВНЕ ВКЛАДОК: заставка → auth V10AuthFlow.boot (вход/автовход) → shop V10AgeGate (год рождения) → Чайная.
ПАРТИЯ: hud2 V10HudMatch + V10ComboShowcase · mj-stage V10MjPresence · juice эффекты пар/Азарт · audio match/tense/fever ·
        look V10TileTheme/V10PairFx · mj-look материал и стол · clarity долгое нажатие · rituals Отдых/ДР-фишки · gacha мастерство.
ПОБЕДА: hud2 V10HudVictory (такт 1) · meta V10WinPanel + V10WinStack (такт 3, ≤ 2 полосы) · clarity «Почему так?» (за «ещё N ▸»).
```

---

## §2. Паспорта модулей

Формат каждого паспорта: **API** (точки входа) · **Самотест** (команда и результат §0.3) · **Сейв** (ключи, которые
регистрирует) · **Хуки** (сигналы `V10Hooks`, spec §2.8) · **Навигация** (вкладка/экран/полка) · **Горячие файлы**
(файл → функция → что сделать) · **Конфликты** · **Шаг**. Пути в командах — от `game/`.

### 2.1. responsive (M0) — `v10/responsive/`
- **API:** `V10Layout.content_rect(vs)`, `safe_insets(vs)`, `bleed_rect(ctrl)`, `bleed_x(node)`, `cover_rect`, `contain_rect`,
  `is_wide/is_tall`; раннер `V10LayoutShots.start(main, args)`.
- **Самотест:** `xvfb-run -a godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 1536x2048 -- --layout_selftest=1 --save=user://layout_shots_save.json --save_wipe=1` → **LAYOUT_SELFTEST 172/172** (7 с).
- **Сейв:** нет. **Хуки:** нет.
- **Навигация:** инфраструктура всех экранов (колонка ≤ 720, вставки, «bleed»).
- **Горячие файлы:** **уже влит** в `main.gd` (`CR`, `safe_top/bottom`, `_build_navbar`, `_dev_args` → `V10LayoutShots`),
  `common.gd`, `home.gd`, `summon.gd`, `levels.gd`, `play.gd`, `v09/home/live.gd`, `v09/ult/cutin.gd` и др. (README).
  Новое: каждый новый экран W1–W4 добавлять строкой в `V10LayoutShots._screens()`; хаб «Столы», Салон, Телефон, Лавка 2,
  Желания v2, режимы mj-*.
- **Конфликты:** новый навбар W1 (`V10HudHome`/5 вкладок) должен сохранить правило «плашка на всю ширину, вкладки ≤ 820 по центру».
- **Шаг:** W1 (обновить вид навбара в раннере), далее каждый шаг дописывает свои экраны.

### 2.2. economy — `v10/economy/` (Ф2 часть, Л1–Л8 логика)
- **API:** фасад `V10Econ` (`from_legacy(S, now)`, `load_dict(d, provider, outfit_pool)`, `save_dict()`, `grant(d, src)`,
  `tick()`, `audit()`, `summon(bid, n)`, `pull_cost`); внутри `wallet: V10Wallet` (экземпляр: `add/spend/balance/premium/revoke`,
  валюты `crystal/moon/coin/wish/wax/petal`), `shop: V10Shop` (`offers/buy/reconcile/refund/month_claim`), `spend: V10Spend`,
  `pass_: V10Pass`, `clock: V10Clock`, `energy: V10Energy`; данные `V10Catalog`, шансы `V10Odds.disclosure`; платёжка
  `V10PaymentProvider`/`V10StubPay`.
- **Самотест:** `godot --headless --path . res://scripts/v10/economy/econ_selftest.tscn -- --econ_selftest=1 [--econ_mc=0.25]` → **ECON_SELFTEST 394/394** (67 с).
- **Сейв:** `S.econ` (один ключ, HMAC `seal`); `V10Save.register_migrator("econ", func(S, now): S.econ = V10Econ.from_legacy(S, now))`.
- **Хуки:** `app_resumed` → `econ.clock.resume(); econ.tick(); econ.shop.reconcile()`; `app_paused` → `G.save()`.
- **Навигация:** экрана нет; питает Желания, Лавку, лист «Что это · Откуда · На что» по тапу на валюту.
- **Горячие файлы:** `g.gd` → `var econ`, `_load_game()`/после `load_game()` — `V10Econ.load_dict(...)` + `owns`, `item_granted→give`,
  `tick()`, `reconcile()`; `save()` — `S.econ = econ.save_dict()` прямо перед сериализацией; `today()` — см. §3.2;
  35 прямых записей `S.gems/S.coins +=/-=` в 13 файлах (`g.gd`, `starter.gd`, `album.gd`, `ladder.gd`, `event_data.gd`, `combo.gd`,
  `play.gd`, `daily.gd`, `summon.gd`, `shop.gd`, `specials.gd`, `duel.gd`, `mode_play.gd`) → через фасад денег (§3.1).
- **Конфликты:** (1) две модели денег — см. §3.1; (2) свой движок круток `V10Gacha` (`S.econ.gacha`) дублирует `V10Gacha2`
  (gacha) — решение §3.1; (3) «Воск» (`wax`) есть в кошельке, spec §2.1 его запрещает; (4) сутки по МСК (`V10Clock.day_key`),
  а spec §2.5 — ежедневное 04:00 по телефону (`V10Meta.day_key`), календарное 04:00 МСК (`V10Meta.cal_key`); (5) цены:
  каталог 79 ₽ = 180 камня, абонемент +90/день против spec 1190 ₽ = 1090 и UX §5 — вопрос владельцу №1 README economy;
  (6) `V10Shop.offers().per_pull` пишет «за крутку» (запрещено UX §4.3) — поправить на «за желание»; (7) `econ_clock.gd`,
  `econ_pay_stub.gd` зовут `Time.*` (grep-самотест meta).
- **Шаг:** W1 (кошелёк, сейв, часы), W3 (магазин, пропуск, траты, единый источник цифр).

### 2.3. meta — `v10/meta/` (Ф1, Ф5, Ф6, Ф7, SAVE_VER 8)
- **API:** `V10Meta.now_unix()/day_key()/cal_key()/clock_ok()/tick()/bus().day_rolled/fmt_msk()`, `V10Bond.gain(h, n, src)`,
  `V10Save.register/register_migrator/migrate/ensure`, `V10EntryQueue.offer/done/run`, `V10WinStack.add_bar/add_tick`,
  `V10WinPanel.make(ctx, w)`, `V10MoreLevel`, `V10Afisha.set_provider/mark/mult/on_game_ended`, `V10AfishaCard.make(size)`,
  `V10ShopGuard.can_buy()/guard(screen)`, `V10Notify.request`, `V10NotifyPanel.make(w)`, `V10Lint.BANNED/check`.
- **Самотест:** `godot --headless --path . res://scripts/v10/meta/meta_runner.tscn -- --meta_selftest=1 --save=user://meta_runner.json --save_wipe=1` → **META_SELFTEST 133/133 (meta 23, bond 13, notify 20, entry 7, lint 7, save 13, winbar 12, more 8, afisha 18, shop 11, grep 1)** (14 с).
  После W1 включать `--meta_grep_strict=1`: сейчас вне `meta.gd` `Time.*` зовут 20 файлов (g.gd×2, letters.gd×2, starter.gd,
  recovery.gd, auth.gd, econ_clock.gd, econ_pay_stub.gd, riichi_data.gd, koikoi_save.gd, presence.gd, sanma_screen.gd×3,
  gacha clock.gd, tower_util.gd, rit_clock.gd, room_data.gd, event_data.gd, shop.gd …), а `G.add_aff` вне `bond.gd` —
  11 файлов (letters.gd, touch.gd, rit_bridge.gd, room.gd, event_play.gd×3, eggs.gd, play.gd×3, story_scene.gd, specials.gd,
  duel.gd×2, mode_play.gd×4). Полный список печатает строка `META_INFO`.
- **Сейв:** `S.v10_meta` (сутки, max_unix, days_seen, симпатия за день), `S.v10_afisha {day, played}`; `ver = 8`.
- **Хуки:** `app_resumed` (V10MetaTick ловит сам; хук нужен остальным), `home_built` → `V10EntryQueue.run()`,
  `win_screen(ctx)` → `V10WinPanel`, `game_ended(result)` → `V10Afisha.on_game_ended(result)`.
- **Навигация:** Чайная → фонарь «Сегодня» → Афиша (лист, 1); Столы → строка «Сегодня» (тот же компонент); Победа → полосы
  и «Ещё уровень · N»; Профиль → ⚙ → Уведомления (2).
- **Горячие файлы:** `project.godot [autoload]` — `V10MetaTick="*res://scripts/v10/meta/meta_tick.gd"` (не `V10Meta`: это class_name);
  `g.gd` — `SAVE_VER = 8`, `_migrate()` в конце `V10Save.migrate(S)`, `today()` → `V10Meta.day_key()`, `add_aff()` — сток только
  для `V10Bond`; все `G.add_aff` → `V10Bond.gain(h, n, src)`; `main.gd _notification` — RESUMED/PAUSED → `V10Hooks`;
  `main.gd settings()` → строка «Уведомления»; `home.gd build()` — `V10EntryQueue.run()`; `play.gd _victory()` — `V10Hooks.win_screen(wctx)`
  и `V10WinPanel` (кнопка `MoreLevel` для `--pt=fresh`); `daily.gd` — `V10Afisha.mark("daily")`; `shop.gd _buy()` первой строкой
  `if not V10ShopGuard.can_buy(): return`, `_build_body()/pass_popup()` → `V10ShopGuard.guard(self)`.
- **Конфликты:** у Афиши нет строк «Задания дня» (с «Забрать всё»), «Событие», «Неделя» (лига/турнир), «Сезон» — UX §3.2 их
  требует; добавить провайдерами `V10Afisha.set_provider(...)` в W1 (задания, событие, лига) и W3 (сезон). `lint.gd` лежит в
  `meta/`, spec кладёт в `core/` — имя класса то же, файл не переносить (меньше шума).
- **Шаг:** W1.

### 2.4. levels — `v10/levels/` (генератор 1000 уровней)
- **API:** `V10LevelGen.TOTAL`, `level(i)` (≈0,7 мс, данные узла), `build(i, -1, null, assist)` (доска + сертификат), `count()`,
  `is_peak(i)`; доска `V10LevelBoard` (= `V6SpecialBoard` с payload); `V10LevelSim` (боты).
- **Самотест:** `godot --headless --path . res://scripts/v10/levels/levels_selftest.tscn -- --levels_selftest=1 [--levels_n=200]` → **LEVELS SELFTEST OK 1000 levels: certificate 1000/1000, auto-player 1000/1000, blind DFS 1000/1000, real board 143/143, assist 334/334, sawtooth 100/100** (69 с).
- **Сейв:** нет своих; использует `S.unlocked`, `S.stars` (+ `S.v10_levels` у path). Данные `data/v10/levels/levels_bake.json` в пакете.
- **Хуки:** нет (вызовы из path/play).
- **Навигация:** через path (Столы → свиток → карта → карточка уровня).
- **Горячие файлы:** `g.gd _build_levels()` → уровни Пути из `V10LevelGen` (лениво по арке: 1000 × 0,7 мс ≈ 2–3 с на Android);
  `play.gd _make_board()` → `V10LevelBoard.new()` если `cfg.has("v10_id")`; `v06/special/specials.gd plan_for()` → `cfg.v10_plan` для
  Пути; `play.gd` награда — только первое прохождение (`reward.gems + per_star × ★`), не `+ stars*20` каждую победу;
  `V6SpecialBoard.unstick()` после фишки в лоток (дыра в старом коде).
- **Конфликты:** миграция `S.unlocked`/`S.stars` 48 → 1000 (предложение README: N-й старый → `round(N × 100 / 48)` арки 1);
  поле партии HUD v2 688×688 — раскладки > 9 рядов ужать (решение владельца 1 в HUD_V2); `G.LOCS[w]` есть только для 0–5.
  Расписание механик генератора расходится со spec (Туман 145, Фонарь-срок 185 отсутствуют).
- **Шаг:** W2.

### 2.5. path — `v10/path/` (П1–П3: карта, Пики/Легендарные, Огонёк пути)
- **API:** экран `path_map.gd` (`v10path`, args `{arc, won:{i, stars}}`); `V10PathState.on_win(i, stars, ms)/on_fail(i)/st()/next_level()`;
  `V10PathBoosters.apply_board(board, cfg)/on_win/on_fail/st()`; `V10PathJam.find(cfg, log)`; `V10PathDialogs.fail_window(...)/win_peak(...)`;
  `V10PathCard` (лист карточки уровня).
- **Самотест:** `XDG_DATA_HOME=/tmp/twx godot --headless --path . res://scripts/v10/path/path_demo.tscn -- --path_selftest=1` → **PATH SELFTEST 111/111 (levels 30, peaks 12, legend 10, boosters 24, wind 7, jam 4, ui 24)** (19 с).
- **Сейв:** `S.v10_levels`, `S.v10_boosters` (лениво) → `V10Save.register(...)`; косметика `laurel_arc1…10`, `frame_rising_1…10` →
  `V10ProfileCos`.
- **Хуки:** `pair_taken(info)` → лог снятых фишек для «места затора»; `game_ended(result)` → `on_win/on_fail`; `win_screen(ctx)`
  (кнопка «Ещё уровень» = `V10PathState` следующий узел).
- **Навигация:** Столы → свиток Пути (5 ближайших узлов) → `v10path` (1) → карточка уровня, лист (2) → партия.
  ★ «Играть · N» на Чайной и в Столах ведёт прямо в партию текущего уровня.
- **Горячие файлы:** `main.gd` — регистрация экрана `v10path` (через `V10Registry`); `play.gd build()` — `if args.has("v10_cfg"): cfg = args.v10_cfg`;
  после раздачи `V10PathBoosters.apply_board(board, cfg)` и `cfg.extra_hints`; `_on_clear()/_victory()` — `V10PathState.on_win`,
  кристаллы не начислять старой формулой; `_on_fail()` — `V10PathState.on_fail` + `V10PathJam.find` + `V10PathDialogs.fail_window`
  (на Пиках/Легендарных заменяет окно, платных кнопок нет); возврат `main.go("v10path", {won})`.
- **Конфликты:** `V10PathState.grant()` ищет `V10Wallet` статикой с ключами глоссария — после вливания economy класс есть, но это
  экземпляр с ключами `crystal…`, `has_method("add")` на скрипте ложно → награды тихо пишутся в `S.gems` мимо кошелька
  (решение §3.1: пустить через фасад денег); `V10ProfileCos.unlock` в path, а у profile метод `grant` — сверить; имена арок
  (spec «Фестиваль фонарей» = арка 2, генератор — арка 3).
- **Шаг:** W2.

### 2.6. salon — `v10/salon/` (Р1–Р2)
- **API:** экраны `salon_screen.gd` (`v10salon`), `zone_scene.gd` (`v10scene`); `V10Salon.defaults()/ensure(S)/notify_stars(d)/hub_info()/next_goal()/lobby_texture()`;
  колбэки `grant_cb/bond_cb/letter_cb/day_cb/season_cb/level_cb`; `V10SalonHub.make(rect, cb)`; `V10SalonWinBar.build(ctx, w)/want_salon_button()`;
  `V10SalonPhoto`, `V10SalonHeroine.RIGS`.
- **Самотест:** `godot --headless --path . res://scripts/v10/salon/salon_runner.tscn -- --salon_selftest=1` → **SALON_SELFTEST 198/198** (247 с).
- **Сейв:** `V10Save.register("v10_salon", V10Salon.defaults())` (банк ★ = сумма лучших ★ − spent; миграция не нужна).
- **Хуки:** `game_ended` → `V10Salon.notify_stars(new_best − old_best)`; `app_resumed` → `card.refresh()`; `win_screen` → полоса (приоритет салона).
- **Навигация:** Чайная → фонарь «Салон» (появляется после L2, UX §3.5) → `v10salon` (1) → лист задачи / `v10scene` (2).
  Победа: полоса салона + вторая кнопка «В салон». Афиша: строка из `next_goal()`.
- **Горячие файлы:** `main.gd` — экраны `v10salon`, `v10scene` (через реестр); `home.gd` — фонарь «Салон» в `V10HudHome` (не карточка
  `V10SalonHub`: UX §3.2 заменил карточки фонарями; `V10SalonHub` можно оставить как содержимое листа-превью); фон лобби
  `V10Salon.lobby_texture()`; `play.gd _victory()` — через `V10WinStack.add_bar("salon", …)`; `level_cb` → `V10PathState`.
- **Конфликты:** токены «Тишина и лак» и кнопки — локальная копия `V10SalonUI` (заменить на `V10DS`/`V10Button` hud2); шрифт
  `V10SalonUI.font()` → `V10Fonts`; кнопка «Играть» ведёт в `levels` — заменить на старт уровня Пути; `grant_cb` по умолчанию
  пишет `S.gems` — в фасад денег; музыка салона: UX §7.1 «эрху, 76», трек audio `salon` — «city-pop/нео-соул» (§3.5).
- **Шаг:** W2.

### 2.7. rituals — `v10/rituals/` (Р3–Р7, Р10)
- **API:** фасад `V10Rituals.install()` (регистрирует сейв, провайдеры подноса, подписки на `game_ended/app_resumed`),
  `day_start()`, `entries()`, `on_game_ended(r)`, `deal_overlay(...)`, `on_pair(face, ov)`, `mastery_pairs(...)`; `V10Streak.view()/take_events()`;
  `V10Tray.register/should_show`; `V10Comeback.tier/rested/notify_plan`; `V10Bday.today_hero/window_hero`; `V10PlayerBday.claim_gift/delete/settings_text`;
  `V10RitBridge.set_sink(cb)`; UI `V10StreakChip`, `V10StreakSheet.open(main)`, `V10TrayView.open(...)`, `V10ComebackScene.play`,
  `V10LadderScreen.open`, `V10RestedBar`, `V10BdayCake`, `V10BdayGoalChip`, `V10PlayerBdayScreen/Scene`, `V10WeekLetterView`.
- **Самотест:** `godot --headless --path . res://scripts/v10/rituals/rituals_runner.tscn -- --rit=selftest --save=user://rit_runner.json --save_wipe=1` → **RIT_SELFTEST 133/133** (2 с).
- **Сейв:** `v10_streak`, `v10_comeback`, `v10_bday`, `v10_tray`, `v10_tele` (`V10RitSave`); в миграции 7→8 `S.streak = 0` (spec Р3).
- **Хуки:** `game_ended`, `app_resumed` (подписывается сам через `/root/V10Hooks`), `home_built` (чип серии, поднос, торт),
  `win_screen` (тик «Серия · N»), `game_started` + `pair_taken` (ДР-фишки, цель «24 пары её фишкой»).
- **Навигация:** Чайная → фонарь «Серия» (день 2) → календарь (1); поднос — оверлей нижней трети раз в день; сцены возврата/ДР —
  через `V10EntryQueue`; Телефон → Почта → письмо недели / вопрос о ДР (2); Профиль → ⚙ → «Мой день рождения» (2).
- **Горячие файлы:** `registry_list.gd` — `V10Rituals.install()`; `home.gd build()` — чип в фонаре «Серия», поднос, торт ДР;
  `play.gd` — `V10RestedBar` под кольцом Приёма, ДР-оверлей фишек на `game_started`; `v09/letters/letters.gd` — события `bday, week,
  ask_bday, while_away` и `backfill(n)` (letters.gd — горячий файл); `main.gd settings()` — строка ДР игрока.
- **Конфликты:** кит `V10RitUI` — своя копия токенов/кнопок (→ hud2); Caveat — из `v10-fonts` (уже влит, проверить подхват);
  `V10RitClock` — должен идти через `V10Meta` (уже форвардит, если класс есть); `rit_bridge` пишет `G.add_aff` в фолбэке (через Bond).
- **Шаг:** W2.

### 2.8. chat — `v10/chat/` (логика Р8–Р9)
- **API:** `V10Chat` (планировщик, `tick/on_event/view/choose/transcript/unread/stickers_for/typing_ms`), `V10ChatFeed`, `V10ChatLog`,
  транспорт `V10ChatTransport` / `V10LocalTransport.new(G.S.v10_phone.chat, "user://v10_logs/")`, `V10ChatValidate`.
- **Самотест:** `godot --headless --path . -s res://scripts/v10/chat/chat_selftest_cli.gd` → **CHAT SELFTEST 133/133** (1 с).
- **Сейв:** `S.v10_phone.chat` (`V10Chat.default_state()`), `S.v10_feed` (`V10ChatFeed.default_state()`); история — `user://v10_logs/chat_<h>.json`.
- **Хуки:** `game_ended` → `post_event(first_win | combo_record | rank_up)`; `app_resumed` и `day_rolled` → `tick(ctx)`.
- **Навигация:** только через phone (Телефон → Чаты/Лента).
- **Горячие файлы:** нет (всё через phone); после `G.load_game()`/восстановления/сброса пересоздавать транспорт (держит ссылку на словарь).
- **Конфликты:** стоп-слова подстрокой («сцена» ловится как «цена») — согласовать с `V10Lint`; пол игрока по умолчанию мужской
  (выбор «он/она» в `V10NamePicker`).
- **Шаг:** W2 (вместе с phone).

### 2.9. phone — `v10/phone/` (Р8–Р9 UI)
- **API:** `V10Phone.open(main, {tab|letter|hero})`, `badge()`, `event(...)`, `tick()`, `gain()`, `ensure()`, `default_state()`;
  `V10PhoneButton.make(main, rect)`; экран `phone_screen.gd`.
- **Самотест:** `xvfb-run -a godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 720x1280 res://scripts/v10/phone/phone_runner.tscn -- --save=user://phone_st.json --save_wipe=1 --phone_selftest=1` → **PHONE SELFTEST 50/50** (6 с) (нужен рендер).
- **Сейв:** `v10_phone` (`chat`, `name`, `named`, `tab`, `recent_st`, `intro`), `v10_feed`.
- **Хуки:** `home_built` → `refresh()` кнопки; `game_ended` → `V10Phone.event`; `app_resumed`/`day_rolled` → `V10Phone.tick()`.
- **Навигация:** Чайная → тихая иконка «Телефон» в статус-строке (после L5) → оверлей (1) → письмо/чат/пост (2). Заменяет кнопку «Письма».
- **Горячие файлы:** `home.gd` — `open_mail()` → `V10Phone.open(main, {"tab": "mail"})`, иконка — `phone_pressed` у `V10HudHome`;
  `v09/letters/letters.gd reply()` — `G.add_aff` → `V10Bond.gain(h, n, "letter_reply")`; музыка `V10Music.play_screen("phone")` в `phone_screen._build`.
- **Конфликты:** у `V10HudHome` своя кнопка «Телефон» с точкой — использовать её, `V10PhoneButton` не дублировать (число-бейдж
  UX §3.6 — только у Телефона); палитра `V10PhoneUI` — своя копия.
- **Шаг:** W2.

### 2.10. gacha — `v10/gacha/` (Г1–Г8)
- **API:** экран `ui/wish_screen.gd` (`V10WishScreen`, наследник `summon.gd`; `make_gacha().pull(banner, n)`), `ui/odds_screen.gd`
  (`V10OddsScreen`, args `{source, id, tab}`, `register()`), `V10Rates` (шансы), `V10Banners` (ритм 3+3), `V10Gacha2`, `V10GachaBank`,
  `V10Stars` (Созвездие/Лепестки), `V10Mastery`, `V10Seven`, `V10GClock.now_fn`; UI `V10FirstPickView`, `V10Candelabra`, `V10SparkSheet`,
  `V10SevenPanel`, `V10OutfitGrowth`, `V10GuestScene`.
- **Самотест:** `godot --headless --path . res://scripts/v10/gacha/gacha_demo.tscn -- --gacha_selftest=1 [--mc=0.3]` → **GACHA_SELFTEST 111/111** (8 с).
- **Сейв:** верхний уровень `tickets, petals, candles, pity_std, s_pity_std, rates_ver, ostars{}, targets{}, mastery{}, first_pick,
  first_pick_t, seven{days, claimed}`, `v10_gacha{mig, hw, guest_done, guest_seen, fp_letter}`; `newbie_left` 20 → 50 − (20 − old);
  журнал `user://v10_logs/pulls.json`.
- **Хуки:** `pair_taken` → `mastery.on_pair(...)`; `game_ended` → `mastery.flush(...)` (тосты/церемония II–IV, полоса мастерства
  в `V10WinStack`); `summon_built` (обучение/подсказки); `home_built` → `V10Seven.visit` (через поднос).
- **Навигация:** вкладка Желания (0) = `V10WishScreen`; ⓘ Шансы (1); Свеча → лист (1) → выбор SSR (2); первая SSR — полноэкранный
  поток после L3 (UX §3.5) через `V10EntryQueue`; Героини → карточка наряда → Созвездие/Мастерство (1).
- **Горячие файлы:** `main.gd` — `SCREENS["summon"]` → `wish_screen.gd`, `SCREENS["odds"]` → `odds_screen.gd`; `g.gd roll()/pull()` →
  прокси `V10WishScreen.make_gacha()`; `give()` при дубле больше не платит `DUP_GEMS`; удалить «Обмен 120» (`S.ex` → `petals` в миграции);
  `collection.gd` — `V10OutfitGrowth.constellation/mastery_ring/palettes` на карточке наряда.
- **Конфликты:** шансы v2 (SSR 1,6 %, итог 2,90 %) против `V10Econ/V10Gacha` (3 %, итог 3,85 %) и против цен каталога; два
  движка круток — выбрать `V10Gacha2` (§3.1); `V10Rates.REF_PACK_RUB` → `V10Sku.ref_rub_per_pull()` (класса `V10Sku` нет — создать
  в W3 из `V10Catalog`); экран шансов `V10OddsScreen` против `V10Odds` economy — один экран с провайдерами (spec §2.7).
- **Шаг:** W3.

### 2.11. shop — `v10/shop/` (Л1–Л8 UI)
- **API:** экран-адаптер `shop2_screen.gd` (`build(main, args)`, `args.tab` 0/1/2, `args.v10 = "pass" | "purchases"`); `V10ShopHub.model()`;
  `V10ShopModel` (`card/topup/ladder/vitrina/outfits/need/buy/defaults`); `V10ShopFlow.confirm/need/outfit/pause_ask`; `V10ShopSheet.layer`;
  `V10PassScreen`, `V10Purchases`, `V10AgeGate.make(st, now)`, `V10Age.is_set/bold_ok/min_age`, `V10Offers.can_popup/mark_shown`,
  `V10Ads`, `V10ShopPay`, `V10MonthDisc.make(model)`.
- **Самотест:** `godot --headless --path . res://scripts/v10/shop/shop_demo.tscn -- --shop_selftest=1` → **SHOP_SELFTEST 482/482** (4 с).
- **Сейв:** `V10Save.register("v10_shop", V10ShopModel.defaults())` (`gift/age/offers/ads/cool_asked/crystal_noask`); экономика — `S.econ`.
- **Хуки:** `win_screen` → `V10Offers.can_popup` (только после победы, с L8, не в сессию первой SSR, раз в сутки); `app_resumed` → `reconcile`.
- **Навигация:** вкладка Лавка (0) сегменты Витрина · Наряды · Пополнить; лист подтверждения (1); подвал: Шансы и правила · Мои покупки ·
  Восстановить (1); пропуск — карточка Витрины или строка «Сезон» Афиши (1–2); экран возраста — при загрузке (auth flow).
- **Горячие файлы:** `main.gd` — `SCREENS["shop"]` → `shop2_screen.gd`; после навбара полноэкранный `Control` → `V10ShopSheet.layer`;
  `_splash()` — `V10AgeGate` (если `not V10Age.is_set(S.v10_shop)`); `screens/shop.gd` и `_buy()` удалить (Ф7); `summon.no_gems` и
  `common.need_gems` → `V10ShopFlow.need(...)`; `export_presets.cfg` — пресеты `Android-test` (`custom_features="tw_test,rustore"`) и
  `Android-store` (`"tw_store,rustore"`), не исключать `*selftest*`/`shop_demo.*`.
- **Конфликты:** числа `V10ShopData` перенести в `V10Catalog`/`economy.json`; `window_days` у guest_149/newbie_499 (spec Л3 — гейты по
  уровню без дат); `traveler_199` не в `SKUS`; `pass_xp_per_pull` = 0 (Л5); цены каталога — вопрос владельцу; оферта — тост до 1.0;
  `V10ShopGuard` (meta, W1) и `V10ShopPay` (shop) — две проверки флейвора: в W3 оставить одну (`V10ShopPay`), guard — обёртка.
- **Шаг:** W1 (только `V10ShopGuard` на старой Лавке), W3 (Лавка 2 целиком, пресеты, возраст).

### 2.12. look — `v10/look/` (D1–D3, D5–D7; влиты fonts и profile)
- **API:** `V10Look.resolve/current/set_choice/migrate/tile_look/preview/end_preview/wave/notify/hub().look_changed`; `V10KitData`,
  `V10TileTheme.dress/apply_table/relight/anim_on`, `V10PairFx.burst`, `V10TilePicker.make`, `V10KitStrip.make`, `V10StylePicker.make`,
  `V10LookFonts.title/price_font`, `V10HudSkin.use/skinned/decorate/sync/sting/loading/menu_bg`, `V10SkinFx.press/open`, `V10SkinAssemble.play`,
  `V10PreviewBar.open`, `V10LookCos.kit_line`, `V10LookCard.payload/view/sim/validate`.
- **Самотест:** `godot --headless --path . res://scripts/v10/look/look_runner.tscn -- --look_selftest=1` → **LOOK_SELFTEST 709/709 OK** (3 с).
- **Сейв:** `look {frame, tile, table, hud}` (`"auto"`); `V10Look.migrate(G.S)` (`S.skin` → `look.tile`, `profile.frame` → `look.frame`);
  добавить `S.look` в код восстановления V8Recovery.
- **Хуки:** `pair_taken` → `V10PairFx.burst`; `game_started` → стол темы (`apply_table`).
- **Навигация:** Героини → сегмент «Стиль» (Рамка · Фишки · Стол · Интерфейс · Стинг · Шрифт) → выбор (1); Героини → карточка наряда →
  лента «Набор героини» (1); Желания → «Примерить стиль» (`V10PreviewBar`); «Новый стиль стола» — через `V10EntryQueue`.
- **Горячие файлы:** `g.gd skin_look()` → `V10Look.tile_look(S, {ranked, big_symbols})`; `tile.gd build()` → `V10TileTheme.dress(self)`;
  `v06/board/board_table.gd setup()` → `apply_table`; `collection.gd` — кит, сегмент Стиль, «Сделать партнёром» → `wave/notify/HudSkin.sync`;
  HUD-скин: одна строка `if V10HudSkin.skinned(): V10HudSkin.decorate(node, role)` в `jbutton.gd`, `rbox.gd`/`V10Plate`, `Common.popup`,
  `V10Header`, навбар, лоток; `cutin.gd _name_font()` → `V10LookFonts.title`; `main.gd _dev_args` — `--skin=zlata`.
- **Конфликты:** «Мой стиль» UX §3.2 переносит из Профиля в Героини → Стиль; `V10HudSkin.menu_bg` не включать, если на экране риг
  (1 риг + 1 видео); `V10Rank` пока нет (look делает R→A, SR→S сам) — W1 создаёт `V10Rank`; стинги — файлы audio.
- **Шаг:** W3.

### 2.13. fonts — `v10/fonts/` (D2)
- **API:** `V10Fonts.font(id, weight)`, `skin(skin, role, size)`, `skin_id`, `px`, `fit_title(text, skin, size, max_w)`, `coverage`, `credits()`, `licence_text(id)`, `deco`.
- **Самотест:** `godot --headless --path . res://scripts/v10/fonts/fonts_runner.tscn -- --fonts_selftest=1` → **FONTS SELFTEST: 276 ok, 0 failed (шрифты 690 432 байт)** (2 с).
- **Сейв:** `S.deco_fonts` (по умолчанию true).
- **Хуки:** нет.
- **Навигация:** инфраструктура; Профиль → ⚙ → «О игре · шрифты и лицензии» (2).
- **Горячие файлы:** `ui.gd UI.font()` — `nunito-sym.woff2` в конец `fallbacks` (₽ сейчас рисуется системным шрифтом!), заголовок
  SSR-партнёра через `V10Fonts.skin`; `v09/ult/cutin.gd _name_font()`; `export_presets.cfg include_filter` — `assets/v10/fonts/*/OFL.txt,
  assets/v10/fonts/licenses/*.txt` (иначе экран лицензий пуст в APK).
- **Конфликты:** роли шрифтов hud2 (`V10Type`: Display/UI/Numerals) — `UI.font` должен отдавать их же; Great Vibes вместо Marck Script (D2).
- **Шаг:** W1 (₽-фолбэк и `include_filter` — дёшево и нужно Лавке), W3 (шрифты SSR, лицензии).

### 2.14. profile — `v10/profile/` (D5–D6, реестр косметики §2.7)
- **API:** `V10ProfileCos` (`register/grant/unseen/mark_seen/seed_seen/ctx_from_save/sanitize`), `V10Feats.bump/best`, `V10CardPayload.mine/validate/sim`,
  `V10CardView.make(payload, rect, mode)`, `V10FrameView`, `V10CardEditor.open(overlay, S, cb, ex)`.
- **Самотест:** `godot --headless --path . res://scripts/v10/profile/profile2_selftest.tscn -- --profile2_selftest=1` → **PROFILE2_SELFTEST 112/112** (3 с).
- **Сейв:** `profile += {frame, title, badges, showcase, card_bg}`, `v10_cos_owned {}`, `v10_cos_seen {}`, `v10_feats {stats, done}`;
  в миграции один раз `V10ProfileCos.seed_seen(G.S, ctx_from_save(G.S))` (иначе ветеран получит десятки «новое»).
- **Хуки:** `game_ended` → `V10Feats.best/bump` (комбо, чистая рука, драконы, партия дня, дуэли), тост «новый титул».
- **Навигация:** Чайная → аватар → Профиль (1) → «Оформить карточку» (2); карточка соперника — лист из лиги/таблиц.
- **Горячие файлы:** `v08/profile/profile_screen.gd _identity()` → `V10CardView.make(... "own")`; `V8PlayerCard.open` → `"other"`;
  `population.gd` → `V10CardPayload.sim` (через `V10LookCard.sim` после look); `league.gd` строки → `"row"`.
- **Конфликты:** `V10LookCard` (look) оборачивает `V10CardPayload/V10CardView` — после W3 вызывать только `V10LookCard`; цвета рангов →
  `V10Rank.color`.
- **Шаг:** W3.

### 2.15. rig — `v10/rig/` (живая героиня v2, только Маджонг-тян `mc_gown`)
- **API:** `V10LiveRig` (`appear/gesture/react/look_at_global/talk/set_talking/set_mouth_level`, сигналы `tapped/gesture_started`,
  экспорты `handle_input/motion/auto_gestures/gesture_gap`); сцена `assets/v10/rig/mc_gown/rig.tscn`; демо `scenes/v10/rig_demo.tscn`.
- **Самотест:** нет (только демо `rig_demo.tscn` и замер `_process` 0,49 мс). Предложение W3: смоук «загрузить rig.tscn, 120 кадров,
  нет ошибок, ≤ 2 мс/кадр» в `V10Registry`.
- **Сейв:** нет.
- **Хуки:** нет (вызовы из home/heroines/salon/hud2).
- **Навигация:** Чайная (сцена), Героини (сцена), Салон (зона z1/z3), партия (сцена `V10HudMatch` — только МТ); ≤ 1 риг на экран.
- **Горячие файлы:** `v09/home/live.gd` — режим `"rig10"` (`handle_input = false`, касания `V9Touch` → `rig.react(zone, pos)`, голос →
  `set_talking`, `appear()` при выборе; `motion` от `fx_level`); `collection.gd` — сцена героини.
- **Конфликты:** риги Рин/Ханы — WIP-ветки `v10-rig-rin/hana` (не влиты, коммиты «stopped overnight»); `rig.tscn` ≈ 1 МБ текста —
  сохранить бинарным `.scn` до сборки; правило 1 риг + 1 видео (Г-4) против видеофона `v09/home/live.gd`.
- **Шаг:** W3.

### 2.16. hud2 — `v10/hud2/` (HUD v2 «Тишина и лак», заменяет старый HUD)
- **API:** токены `V10DS`, типографика `V10Type` (`settings/fit/quant/font/label`), плашки `V10Plate.make(S|M|L, w, …)`, кнопки
  `V10Button.make(play|cash|secondary|quiet)`, иконки `V10Icons.icon()`, шапка `V10Header.make(screen, title, on_back, on_help)` /
  `content_y(vs)`, Чайная `V10HudHome` (`configure`, сигналы `play_pressed/partner_pressed/phone_pressed/lantern_pressed(i)/tab_pressed(i)`,
  `compute(vs, insets)`), партия `V10HudMatch` (`configure/board_rect/tray_cell_rect/set_left/set_helper/show_combo/set_ult/say/start_banner/first_move`,
  сигналы `helper_pressed/pause_pressed/ult_pressed`), витрина `V10ComboShowcase` (`on_combo/fever_start/hold/release`, `input_paused`),
  победа `V10HudVictory` (`compute`, `next_pressed/home_pressed/more_pressed`), `V10Hud2Util`.
- **Самотест:** `godot --headless --path . res://scripts/v10/hud2/hud2_demo.tscn -- --hud2_selftest=1` → **HUD2 SELFTEST 854/854 OK** (5 с).
- **Сейв:** `S.hero_combo` («full | short | off») — добавить в дефолты.
- **Хуки:** нет своих; встраивается прямыми вызовами в `play.gd`/`home.gd`/`main.gd`.
- **Навигация:** все экраны: навбар 5 вкладок, Чайная, шапки подэкранов, партия, победа.
- **Горячие файлы (README hud2 «Миграция», строки по gh-pages `0510188`):**
  §0 общие точки — `ui.gd UI.label()` (обводка 0, тень только `on_art`, `V10Type.quant`), `UI.title()`, `UI.rbox()` → `V10Plate`,
  `v08/hud/art.gd nine("panel"/"ribbon")`, `jbutton.gd` (ужатие → `V10Type.fit`);
  §1 партия — `play.gd build()` (`V10HudMatch`, `V10ComboShowcase`), `_make_board()` (`tray_cell_rect`, `board_rect`), удалить из
  `_build_hud()` «домой», цель, кристаллы, портрет `V6HeroStage`, `tray_box`, полосу комбо; удалить `_build_bottom()`; `_on_match()`
  (`showcase.on_combo`, `hud2.set_ult`), `_cutin()` удалить, `_fever()` → `showcase.fever_start()`, `_intro()` → `start_banner`,
  `_process()` — заморозка таймеров при `_frozen`; рамка стола `board_table.gd:86–112` и огонь `combo.gd:248–430` выключить;
  победа `_victory()` → `V10HudVictory`;
  §2 Чайная — `home.gd build()`: удалить `_build_left()`, `_build_right()`, `_build_affection()`, `_say()`, затемнение пола; добавить `V10HudHome`;
  §3 шапки — `V8Header.make` → `V10Header.make` (`levels.gd`, `collection.gd`, `modes.gd`, `summon.gd`, `shop.gd`), статус-лента
  `main.gd _build_topbar()` на подэкранах убрать; §4 `main.gd` — `--hud2_selftest=1`.
- **Конфликты:** сцена героини в партии (`V10HudMatch`) против окна присутствия `V10MjPresence` (mj-stage) — §3.4; баннер комбо
  `V10Juice.combo_milestone` не подключать (его роль — витрина); у mj-stage, mj-triples, salon, rituals, gacha, phone свои
  копии токенов — заменить на `V10DS` (UX В-1); строки `main.gd` в README указаны по `0510188`, после responsive/clarity они сдвинулись —
  искать по именам функций.
- **Шаг:** W1 (§0 общие точки, навбар, Чайная `V10HudHome`, `V10Header`), W4 (партия, витрина, победа).

### 2.17. juice — `v10/juice/` (V10Juice)
- **API:** `V10Juice.warm()`, `cover(style, dur, center, tab_id)/reveal(dur)`, `TAB_STYLE`, `tile_match(mid, face, combo, gold)`,
  `fever_aura(parent, rect)/stop(h)`, `danger_beat`, `ult_ready`, `roll(lbl, a, b, t)`, `chest_open`, `chest_burst`, `fountain`, `crest_reveal`,
  `idle_sparkle`, `sheen`, `dissolve`, `heroine_entrance`, `calm()`.
- **Самотест:** `godot --headless --path . res://scripts/v10/juice/demo/juice_demo.tscn -- --juice_selftest=1` → **JUICE SELFTEST 56/56** (5 с).
- **Сейв:** `a11y_calm` (тумблер «Без тряски и вспышек»).
- **Хуки:** `pair_taken` → `tile_match` (или прямой вызов в `_on_match`).
- **Навигация:** все переходы вкладок; эффекты в партии, Желаниях, Лавке, наградах.
- **Горячие файлы:** `main.gd _ready()` — `V10Juice.warm.call_deferred()`; `main.go()` — твин `trans_mat` → `V10Juice.cover(...)`/`reveal(0.42)`,
  убрать `Sfx.play("whoosh")`; `play.gd _on_match()` — `tile_match` (снять дублирующие частицы `V6Fx.on_match`), `_fever()` — `fever_aura`
  (и выключить огонь рамки `V7Combo`), последний слот — `danger_beat`, ульта — `ult_ready`; `summon.gd _sequence` — `chest_burst` вместо
  белой `_flash()`; Лавка — `fountain/roll`.
- **Конфликты:** `TAB_STYLE` знает `levels`, не знает `tables` — добавить `"tables": "ink"`; `combo_milestone` не использовать (витрина hud2);
  `V6Fx.set_danger` красит весь экран — выключать при `V10MjPresence`/`danger_beat`; UX §3.1 требует переход «Тушь» 320 мс на всех
  вкладках — решить: стиль по вкладке (juice) или одна «Тушь» (UX). UX выше: **одна «Тушь» для вкладок**, фонарь/лепестки — только
  для входа в Желания/Салон/Профиль.
- **Шаг:** W4.

### 2.18. audio — `v10/audio/` (V10Music, V10SfxBank)
- **API:** `V10Music.play_screen(id)/set_tension(fill)/fever(on)/sting("victory"|"defeat", resume)/motif(hero)/stop(fade)`, `SCREENS`;
  `V10SfxBank.play(id, opts)/match_tier/combo(n)/voice(hero, kind)/ids()`. Ставят себя под `/root` сами (без autoload).
- **Самотест:** `godot --headless --audio-driver Dummy --path . res://scripts/v10/audio/v10_audio_selftest.tscn` → **V10AUDIO OK 339/339** (22 с).
- **Сейв:** нет (флаги `S.music/S.sound/S.voice`).
- **Хуки:** нужен сигнал смены экрана — предложение: `V10Hooks.screen_shown(id, screen)` (эмитит `main.go()`), по нему
  `V10Music.play_screen(id)`; `game_started` → `play_screen("match")`; `game_ended` → `sting`.
- **Навигация:** музыка по вкладкам (UX §7.1), см. §3.5.
- **Горячие файлы:** таблица README audio: `main.gd` (старт, тумблер музыки), `home.gd`, `levels.gd`, `play.gd` (старт, тумблер, напряжение,
  фивер, победа, поражение, после окна), `summon.gd` (3 места + тишина перед раскрытием), `shop.gd`, `room.gd`, `collection.gd`,
  `letters_screen.gd`, `tourney_screen.gd`, `event_screen.gd`, `modes.gd`, `profile_screen.gd`; SFX через `V9Feel.press` и места `Sfx.play`.
- **Конфликты:** см. §3.5 (нет треков для Героинь/Странствия по UX, «салон» по характеру не совпадает); голоса героинь на русском не вошли
  (HANDOFF §15); стинг победы — в теме партнёра (UX §7.1), у audio общий `sting_victory`.
- **Шаг:** W4.

### 2.19. auth — `v10/auth/` (вход, автовход, аккаунт)
- **API:** `V10AuthFlow.boot(main) -> {login, …}`, `relogin(main)`, `open_account(main)`, `welcome(host, main)`, `skip_splash`, `title_music`;
  `V10Auth.ensure/defaults/sign_in_guest/player_id/flavor/now`; `V10LoginScreen`, `V10NickSheet`, `V10AccountSheet`, `V10EmailSheet`.
- **Самотест:** `godot --headless --path . res://scripts/v10/auth/auth_dev.tscn -- --auth_selftest=1 --save=user://auth_selftest_save.json --save_wipe=1` → **AUTH_SELFTEST 102/102** (8 с).
- **Сейв:** `V10Save.register("v10_auth", V10Auth.defaults())`; вне сейва `user://v10_session.json`, `v10_device.json`, `v10_auth_outbox.json`.
- **Хуки:** нет (вызывается из `_splash`); вызывает `V10AgeGate.ensure(host)`, если есть (у shop сейчас `make(...)`, не `ensure` — сверить).
- **Навигация:** вне вкладок: заставка → вход/автовход → (год рождения) → Чайная; Профиль → ⚙ → «Аккаунт» (2).
- **Горячие файлы:** `main.gd _splash()` — начало тайтла → `await V10AuthFlow.boot(self)` (старый тайтл «Играть» и `V8ProfileCard` уходят);
  ранний `return` для `--shots/--pt=/--profile_selftest` оставить; `settings()` — строка «Аккаунт»; `v08/devtools/playtest.gd _fresh()` —
  жать `Btn_guest`/`Btn_play` в `V10NickSheet` (сейчас ждёт «тап по титулу» и `V8ProfileCard`); `export_presets` — флейвор `rustore`.
- **Конфликты:** UX §3.5 «Запуск 1: год рождения, Вход/Гость, L1; ник генерируется сам; экрана карточки нет» — `V10NickSheet` спрашивает
  имя: сделать «имя по умолчанию + кубик», без обязательного шага; приветствие при автовходе «Вход выполнен: Скачано. Скачано.» (HANDOFF §16) —
  проверить строки `V10AuthText`; кнопки VK/Яндекс/Google — заглушки до SDK (1.0).
- **Шаг:** W4.

### 2.20. clarity — `v10/clarity/` (понятность, словарь)
- **API:** `V10Glossary` (`get_entry/label/tip/star_rule/stats_line/blocked_reason/fortune_title/fortune_chip/passive_note`), `V10GlossaryScreen.open(host, cat)`,
  `V10InfoCard`, `V10Breakdown` (`tap_reward/crystal_math/count_for`), `V10TileMarks.attach(t)`, `V10TileInfo.intercept(board, e)`, `V10Legend.open(host)`,
  `V10Clarity.attach_play/victory/settings_hook/open_settings`, `V10ClarityIcon.make`, `V10Sheet`.
- **Самотест:** `godot --headless --path . res://scripts/v10/clarity/clarity_selftest.tscn` → **V10 CLARITY SELFTEST 3830/3830** (2 с).
- **Сейв:** `S.v10_clarity` (лениво).
- **Хуки:** уже прямые строки `# v10-clarity hook` (влиты в этой ветке): `play.gd build()`, `_on_deny()`, `_show_fortune()`, `_v8_fortune_chip()`,
  `_track_set()`, `_victory()` (правило звёзд, статистика, `tap_reward`, `V10Clarity.victory`), `tray_board.gd setup()`/`_unhandled_input()`,
  `main.gd settings()`.
- **Навигация:** «?» в шапке каждого экрана → статья (UX §4.4); партия → долгое нажатие на фишку; победа → «Почему так?» за «ещё N ▸»;
  Профиль → ⚙ → «Фишки и словарь» (2).
- **Горячие файлы:** W4 — тексты и словарь под имена UX (§3.3); `V10Clarity.victory()` переезжает в такт 3 / лист «ещё N ▸» нового окна победы.
- **Конфликты:** **имена** — clarity переименовала «ульта» → «умение» (38 строк в 19 файлах), «лихорадка» → «Полнолуние» (17 строк в 10 файлах),
  ставку → «Ва-банк» (24 строки в 9 файлах); UX §4.2 требует «Приём», «Азарт», «Ставка ×2» (§3.3); экран победы clarity — 10 строк бонусов,
  UX P0-3 — ≤ 3 жетона, бонусы за «ещё N ▸».
- **Шаг:** W4.

### 2.21. tutorial — `v10/tutorial/` (написан под навигацию 0.9)
- **API:** `V10Tutorial.attach(main)`, `event(name)`, `tip_now(topic)`, `owns_first_match()`, `fill()`; `V10Help.open(main, topic)/help_button(...)`;
  `V10Coach`, `V10TutTarget`, `V10TutSteps`, `V10TutTips`, `V10TutState.ensure/DEFAULTS/large()`.
- **Самотест:** `godot --headless --path . res://scripts/v10/tutorial/test/tut_test.tscn -- --save=user://tut_test.json --save_wipe=1` (данные + реальный прогон;
  `--tut_static=1` — только данные) → **V10TUT 3322/3382, rc 1** (560 с): данные `static 3311/3311` зелёные, реальный прогон красный.
  Контрольный прогон на `origin/v10-tutorial` @ `01ca8d3` даёт **3323/3383** с теми же провалами — проблема была в ветке до слияния.
  Причина: `tut_test.go("play", {level:0})` → `V6Story.before_go()` показывает сюжетную сцену `intro` (сейв теста ставит `intro_done`,
  но не помечает сцену просмотренной, бот на неё не нажимает) → `main.busy` висит, экран остаётся `levels`
  → `go play levels`, `no softlock at m_wait`, и каскадом все главы (`m_*`, `h_*`, `s_*`, `v_*`), подсказки тем, «подарок — одно желание».
  Лечится в тесте одной строкой (в `boot()` пометить `V6Story.mark("intro")` или запускать с `--story_off`), но это файл чужого
  треда — делает тред переписывания обучения; в W1–W4 считать `tutorial: static only`.
- **Сейв:** `V10Save.register("v10_tut", V10TutState.DEFAULTS)` (`v, step, chapters, skipped, tips, tips_off, large, gifts`); `S.tut_done` из 0.9 → `chapters.match1`.
- **Хуки:** только `V10Tutorial.attach(self)` в `main._ready()` и гард `_intro()` в `play.gd`; в шапки — `V10Help.help_button`.
- **Навигация:** «Как играть» — Профиль → ⚙ (2) и «?» в шапках.
- **Горячие файлы:** `main.gd _ready()` последней строкой `V10Tutorial.attach(self)`; `play.gd _intro()` — `if tut and not V10Tutorial.owns_first_match()`;
  `main.gd settings()` — строка «Как играть» (закрыть окно настроек перед `V10Help.open`, П-6).
- **Конфликты:** **главы написаны под 0.9** («левая колонка», «Сесть за стол», «Режимы», «Гардероб», портрет 186×240) — переписать с нуля
  под UX/HUD v2 (HANDOFF §19 п. 2) — **это делает другой тред**. Интегратор только вешает хук и держит главы выключенными
  (`V10Tutorial.chapters_enabled = false` до переписывания; подсказки тем и «Как играть» можно оставить); реальный прогон `tut_test`
  уже красный (см. выше), а после W1 будет падать ещё и потому, что ищет свойства старых `home.gd/play.gd` — в `--v10_selftest=all` запускать с `--tut_static=1` и помечать
  `tutorial: static only`.
- **Шаг:** W4 (только хук).

### 2.22. tower — `v10/tower/` (R1–R3: V10Mods, Пагода Луны, Странствие) — только логика
- **API:** `V10Mods` (`heat/mult/resolve/offer_blessings/offer_curses/forced_curse/validate/max_valid_heat`), `V10Pagoda` (`DEFAULTS/st/is_open/new_run/
  floor_clear/end_run/cos_defs`), `V10Journey` (`DEFAULTS/is_open/week_info/start/finish/rewards_for/week_budget`), `V10TowerRules.for_run(run)`
  (`hook_cfg/slot_count/hook_start/hook_pair/apply_op/on_tray_changed/hook_overflow/tick/on_timeout/help_ok/help_off_text/paid_help/hook_clear/clock_text`),
  `V10TowerBoard` (таблицы), `V10TowerSim`, `V10TowerUtil`.
- **Самотест:** `godot --headless --path . res://scripts/v10/tower/tower_selftest.tscn -- --tower_selftest=1` → **TOWER_SELFTEST 192/192** (55 с).
- **Сейв:** `V10Save.register("v10_pagoda", V10Pagoda.DEFAULTS)`, `("v10_journey", V10Journey.DEFAULTS)`; миграция `climb_best/climb_miles` идемпотентна.
- **Хуки:** `game_started` (через `V10TowerRules.hook_cfg`), `pair_taken` (`hook_pair`), `game_ended`; сейв сразу после `hook_overflow/on_timeout/start/hook_clear`.
- **Навигация:** Столы → полка «Испытания и соперницы» → Пагода (1) / Странствие (1) → партия (2); Афиша — строка «Неделя».
- **Горячие файлы:** экранов **нет** — W4 пишет `v10/tower/pagoda_screen.gd` и `journey_screen.gd` (свиток проклятий, веер карт, пагода с
  параллаксом, кат-ин босса) + арт; `screens/modes.gd` плитка `climb` → Пагода, гейт `V10Pagoda.is_open()`; `play.gd`/`mode_play.gd` —
  10 точек таблицы README tower §3 (`_v6_setup`, `_slot_count`, `_make_board`, `_apply_perk`, `_on_match`, `_refresh`, `_on_fail`, `_process`,
  `_help_ok`, `_on_clear`); Пики ставят `S.v10_peak_first`.
- **Конфликты:** README tower: Странствие «только строка Афиши, без плитки», UX §3.2 — карточка на полке «Испытания» → по UX (карточка + строка);
  время: `V7EventData.now_unix()` локальное, модуль пересчитывает — при `V10Meta.now_unix` (UTC) поправить `now_utc`; `.gd.uid` создаёт `--import`.
- **Шаг:** W4.

### 2.23. mj-stage — `v10/mj/stage/` (героиня в любой партии, «режиссёр присутствия»)
- **API:** `V10MjPresence.new().attach(screen, hero, {board, avoid, charge_need, band, band_h})`, `sacred(rect)`, `on(event, data)`, `set_mode`,
  `apply_settings`, `input_on`, сигналы `portrait_tapped`, `finale_done`; `V10MjBarks.pick`, `V10MjStageLines.voice_path`, `V10MjStageSettings.st/build_rows`.
- **Самотест:** `godot --headless --audio-driver Dummy --path . res://scripts/v10/mj/stage/stage_selftest.tscn -- --mj_stage_selftest=1` → **MJ_STAGE 125/125** (26 с).
- **Сейв:** `v10_mj_stage {mode, inserts, voice}`.
- **Хуки:** события присутствия — из `pair_taken`/`game_started`/`game_ended` и прямые `presence.on(...)` в `_on_match`, `_refresh`, ульте.
- **Навигация:** внутри любой партии; Настройки → Звук и Картинка (3 строки), лист паузы.
- **Горячие файлы:** `play.gd` (через `V10Rules` или прямо): после `_build_hud()/_make_board()` — `attach` вместо `V6HeroStage`; `sacred` поля, лотка,
  ряда помощи; `on("pick"|"pair"|"combo"|"signature"|"last_pair"|"danger"|"wave"|"win"|"lose"|"ult")`; `v06/fx/v6fx.gd _on_tray` — не звать
  `set_danger`, если есть `V10MjPresence`; `main.gd` — флаг `--mj_stage_selftest=1`; шина `Voice` в `default_bus_layout`.
- **Конфликты:** окно присутствия против сцены героини `V10HudMatch` (§3.4); токены `V10MjStageData.TOK` → `V10DS`.
- **Шаг:** W4.

### 2.24. mj-look — `v10/mj/look/` (материалы фишек, столы героинь, ASMR, вибрация, музыка режимов)
- **API:** `V10MjTileMaterial.look_dict/dress/tile_state/st`, `V10MjTileView`, `V10MjStackCache`, `V10MjTables.theme_for/available`, `V10MjTableView.make/attach_front/
  set_sacred/set_parallax/light`, `V10MjAsmr.pick/place/pair/triple/ambient_for`, `V10MjHaptics.play`, `V10MjMusic.play(mode)`, `V10MjTrayFrame`.
- **Самотест:** `xvfb-run -a -s "-screen 0 1200x2600x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --resolution 720x1280 res://scripts/v10/mj/look/look_selftest.tscn -- --mj_look_selftest=1` → **MJ_LOOK 626/626** (12 с) (рендер нужен).
- **Сейв:** `v10_mj_look {material, hl_free, contrast, asmr, ambient, ver}`.
- **Хуки:** события присутствия → звук/вибрация (таблица README §5).
- **Навигация:** Героини → Стиль → Фишки/Стол (вместе с `V10TilePicker` look); фон экрана режима — стол партнёра; Настройки → Звук и Картинка.
- **Горячие файлы:** `main.gd` — флаг самотеста; в режимах — `V10MjTableView` под доской, `dress()` после `Tile.build()`.
- **Конфликты:** два каталога тем фишек/столов — `V10TileTheme` (look, 9 тем, 6 столов) и `V10MjTileMaterial/V10MjTables` (6 материалов, столы героинь):
  один пикер «Фишки и столы» в Героини → Стиль; материал = слой поверх темы (решить в W3/W4 и записать в README look).
- **Шаг:** W4 (материалы в пикере — W3, если успевает).

### 2.25. mj-triples — `v10/mj/triples/` (Тройки, 120 уровней)
- **API:** `V10MjTriplesInfo.INFO` (`shelf:"solitaire"`, `host:"hana"`, `gate:{level:14}`), `V10MjTriplesScreen.setup(main, {level, hero, presence, look, start_sheet, result_sheet})`,
  сигнал `finished(r)` (`r.action: next|retry|exit`), `V10MjTriplesSave.st/record/path_reward`, правила/генератор/доска.
- **Самотест:** `godot --headless --audio-driver Dummy --path . res://scripts/v10/mj/triples/triples_selftest.tscn -- --mj_triples_selftest=1` → **MJ_TRIPLES 2736/2736** (15 с).
- **Сейв:** `v10_mj_triples {level, stars, boosters_open, best, wins, plays}`.
- **Хуки:** `finished(result)` → интегратор: `V10Hooks.game_ended(result)`, награды ×0,5 Пути через фасад денег, `salon_stars` → `V10Salon.notify_stars`.
- **Навигация:** Столы → полка «Пасьянсы» → Тройки (1: «Играть · N», звёзды, «Как играть») → партия (2). Открытие после L14, реплика Ханы.
- **Горячие файлы:** только реестр экранов и хаб «Столы»; Приём — `V9UltCast/V9Cutin` перед `board.cast` в `_try_ult()` (свой файл).
- **Конфликты:** `TOK` → `V10DS`; музыка `mode_triples` отсутствует (MODES §6.5, З-1 «нет»); LUFS синтеза не мерили (З-4); `V10MjMech` не влит.
- **Шаг:** W4.

### 2.26. mj-riichi — `v10/mj/riichi/` («Стол на четверых»)
- **API:** `V10MjRiichiInfo.INFO` (`shelf:"table"`, `host:"mc"`, `gate:{level:34, daily_tasks:3}`), `V10MjRiichiScreen` (`build(main, args)`, args `format, hall, seats, seed,
  partner, rivals, presence, look, fx_min, horizontal, mute`; `finished(result)`), `V10MjRiichiDriver`, `V10MjRiichiStats.card()`.
- **Самотест:** `godot --headless --audio-driver Dummy --path . res://scripts/v10/mj/riichi/riichi_selftest.tscn -- --mj_riichi_selftest=1 [--games=N]` → **MJ_RIICHI 97/97** (330 с).
- **Сейв:** `v10_mj_riichi {ver, hall_progress, stats, last_seed, daily_one_hand, first_day, prefs}`.
- **Хуки:** `finished` → `game_ended`; `rp` → `G.add_rp(rp, "table")`; награды через фасад; потолок кристаллов — интегратор.
- **Навигация:** Столы → полка «За столом» → выбор зала (1) → стол (2); Афиша — «Одна раздача дня».
- **Горячие файлы:** `main.gd` — `SCREENS["riichi"]`, `PLAY_BACK["riichi"] = true`, флаг самотеста.
- **Конфликты:** гейт «3 задачи дня» требует дорожку `bridge` (не влита) — до неё фолбэк «2 партии в Учебном»; слово «риичи» допустимо только
  с пояснением (UX §4.3) — кнопка «Готов · риичи» с подписью при первом показе есть; 4 кегля в партии вместо 3 (P1).
- **Шаг:** W4.

### 2.27. mj-sanma — `v10/mj/sanma/` («Лунный стол на троих» + событие «Хозяйка против двоих»)
- **API:** `sanma_info.gd` `INFO` (`shelf:"table"`, `host:"yue"`, `gate {table_games: 3}`, `unlocked(n)`), `sanma_screen.gd` (`setup(main, {presence, partner, host, seed,
  event, hall, names})`, `sacred_rects()`, `finished(res)`), движок `V10MjSanmaRound extends V8Round`, `V10MjSanmaData.st()`.
- **Самотест:** `godot --headless --audio-driver Dummy --path . res://scripts/v10/mj/sanma/sanma_selftest.tscn -- --mj_sanma_selftest=1 [--games=200]` → **MJ_SANMA 70/70** (159 с).
- **Сейв:** `v10_mj_sanma {played, firsts, places, best_hand, best_score, kita_total, last_day, event, settings}`.
- **Хуки:** `finished` → `game_ended`, награды через фасад.
- **Навигация:** Столы → «За столом» → Лунный стол (1: «Играть · Восток», сегмент «Стол / Хозяйка против двоих») → стол (2). Открытие: 3 партии за столом на четверых.
- **Горячие файлы:** `main.gd` — экран и флаг самотеста; музыка — свой плеер `moon_table.ogg` → `V10MjMusic`.
- **Конфликты:** README ссылается на `V10MjRiichiData.st().played`, а в riichi ключи `hall_progress.games` — сверить счётчик; `Time.*` в `sanma_screen.gd`×3.
- **Шаг:** W4.

### 2.28. mj-koikoi — `v10/mj/koikoi/` (ханафуда)
- **API:** `V10MjKoikoiInfo.INFO` (`shelf:"table"`, `host:"rin"`, `gate:{level:45}`, `HOW`), `V10MjKoikoiScreen.setup(main, {hero, months, presence, music, seed})`, `finished(result)`,
  `V10MjKoikoiBook.pages`, `V10MjKoikoiSkins.album`, `V10MjKoikoiSave.st/record/rewards_for`.
- **Самотест:** `godot --headless --path . res://scripts/v10/mj/koikoi/koikoi_selftest.tscn -- --mj_koikoi_selftest=1 [--games=1000]` → **MJ_KOIKOI 138/138** (15 с).
- **Сейв:** `v10_mj_koikoi {wins, book, skins, best, beat, day_win, use_skins, games}`.
- **Хуки:** `finished` → `game_ended`, награды через фасад.
- **Навигация:** Столы → «За столом» → Коикои (1: «Играть», «6 / 12 месяцев», соперница) → партия (2). Открытие L45.
- **Горячие файлы:** `main.gd` — флаг самотеста; музыка — `music:false` + `V10Music`.
- **Конфликты:** экраны «Книги» и альбома скинов не сделаны (вторичные, глубина 2 — в W4 можно отложить); слово «ставка» в стоп-словах режима
  не конфликтует с «Ставка ×2» (в коикои его нет).
- **Шаг:** W4.

---

## §3. Сквозные решения (принимаются один раз, в шаге, указанном в скобках)

### 3.1. Деньги: одна модель (W1)
Сейчас в дереве **три** способа хранить валюту: (а) верхний уровень `G.S.gems/coins` 0.9 (35 записей в 13 файлах); (б) `V10Econ.wallet`
внутри `S.econ` (валюты `crystal/moon/coin/wish/wax/petal`, инвариант, долг после возврата, HMAC); (в) верхний уровень `S.tickets/petals/candles/moon`
(gacha `V10GachaBank`, rituals/salon/path фолбэки), как в spec Ф2. Плюс два движка круток (`V10Econ.gacha` и `V10Gacha2`).
**Решение для W1:**
1. Источник правды балансов — `G.econ.wallet` (нужен для ₽: возвраты, долг, аудит, печать). Глоссарий spec §2.1 → валюта кошелька:
   `gems→crystal`, `moon→moon`, `coins→coin`, `tickets→wish`, `petals→petal`. `wax` не используется (spec: Воска нет); `candles` — счётчик
   `V10Gacha2` (не валюта).
2. Новый статический фасад **`V10Money`** (`v10/core/money.gd`): `bal(key)`, `can(cost: Dictionary)`, `spend(cost, src) -> bool` (всё или ничего),
   `grant(d, src, from := Vector2(-1,-1))` (полёт в счётчик), `pull_split(n, each)`. Все модули (path `grant`, salon `grant_cb`, rituals `set_sink`,
   gacha `V10GachaBank`, tower/mj награды, shop) идут только через него. Имя не `V10Wallet` — это class_name экземпляра economy.
3. `G.S.gems/coins/tickets/petals/moon` остаются **зеркалами** (пишет только `V10Money` после каждой операции и `save()`), чтобы старый UI не
   падал; grep-самотест: `S.gems +=/-=` вне `money.gd` = 0 (W1 переводит 35 мест).
4. Крутки — `V10Gacha2` (spec Г1–Г8, UX-тексты); `V10Econ.gacha` не вызывается (остаётся в коде до чистки 1.0). Перенос в W3.
5. `V10Rank` (`v10/core/rank.gd`: `label/color/glow/hint/hero_rank/outfit_rank`, R→A, SR→S) создаётся в W1: его уже ждут look (`kit_data.gd`) и profile.

### 3.2. Время (W1)
Один источник — `V10Meta.now_unix()`, `day_key()` (ежедневное, 04:00 по телефону), `cal_key()` (календарное, 04:00 МСК), `clock_ok()`.
В W1 одной строкой в `registry_list.gd`: `V10GClock.now_fn = V10Meta.now_unix`; `V10Econ.clock` берёт `V10Meta.now_unix` (сутки экономики:
задания/подарок дня — `day_key`, баннеры/пропуск/неделя — `cal_key`); `g.gd today()` → `V10Meta.day_key()`; `V10RitClock`, `V10TowerUtil`,
`V10Auth.now`, phone `day_info` уже форвардят на `V10Meta`, если класс есть. Остальные 20 файлов с `Time.*` — по списку `META_INFO`,
затем `--meta_grep_strict=1` зелёный (W1 — g.gd, letters, starter, recovery, room_data, event_data, shop.gd; W2–W4 — модули своего шага).

### 3.3. Имена (W4, но правило действует с W1 для всех новых строк)
| В коде сейчас | UX_RULES §4.2 | Где |
|---|---|---|
| «Умение»/«умение» (clarity, раунд 2; 38 строк в 19 файлах: txt.gd, sfx.gd, play.gd `_skill_ready`, `V9_WAIT_LINES`, ult_cast.gd, ult_selftest.gd, main.gd, hero_stage.gd …) | **Приём** (подзаголовок при первом показе «особый ход героини») | всё видимое + `V10Glossary` + `ult_selftest` проверка подписи шкалы |
| «Полнолуние» (17 строк в 10 файлах), «Лихорадка» (5 строк в 4 файлах) | **Азарт** | combo.gd, specials.gd, txt.gd, glossary |
| «Ва-банк»/«ВА-БАНК!» (24 строки в 9 файлах), «риичи» у ставки | **Ставка ×2** (подпись «награда ×2, если закончишь без помощи») | play.gd, txt.gd, g.gd `YAKU.riichi.name`, photo.gd, sfx.gd |
| «Гардероб» (10 строк в 7 файлах) | Героини | main.gd `TABS`, txt.gd, tutorial |
| «Партия» (вкладка), «Режимы», «Сесть за стол», «Следующая партия» | Столы / Играть · N / Ещё уровень · N | main.gd, home.gd, modes.gd, play.gd |
| «Ивент» (4), «Поручения» (5), «Визиты», «Ульта/ульта» (39) | Событие / Задания дня / удалено / Приём | txt.gd, home.gd, v07, v09 |
| R / SR / SSR, «Ранг» у наряда | A / S / SSR, «Редкость» | `V10Rank` везде (W1 — вывод, W3 — Желания/Лавка) |
| «Свойство героини» (clarity), «Перк + стиль» | **Дар** (одна строка) | passive_run.gd, glossary |
Проверка — `V10Lint.UI_BANNED` по всем видимым строкам (С-1) — включается в `--v10_selftest=all` в W4 как жёсткий тест; до W4 — отчёт.

### 3.4. HUD: старый против v2 (W1, W4)
- W1: §9.1 HUD_V2 (три общие точки `ui.gd`, `art.gd`, `jbutton.gd`), навбар 5 равных вкладок, Чайная `V10HudHome`, шапки `V10Header`,
  статус-лента только на Чайной (аватар + ник + Телефон, без валют). Валюта — правая S-плашка шапки только там, где её тратят (Желания, Лавка).
- W4: партия `V10HudMatch` + `V10ComboShowcase`, победа `V10HudVictory` (P0-3, P0-4).
- **Сцена героини в партии:** `V10HudMatch` владеет раскладкой (5 элементов, поле 688×688, сцена над полем); `V10MjPresence` владеет
  поведением (бюджеты, святая зона, реплики, выходы, тёплый край). Интеграция: `V10MjPresence.attach(play, partner, {"band_rect": hud2.hero_rect(),
  "ring": hud2.ult_ring()})` — присутствие рисует в сцене hud2, кольцо Приёма одно (hud2). Дописать оба параметра в `presence.gd` (W4).
- Токены: `V10DS` (hud2) — единственный; локальные копии `V10MjStageData.TOK`, `V10MjTriplesLook`, `V10SalonUI`, `V10RitUI`, `V10GUI`, `V10PhoneUI` —
  алиасы на `V10DS` (UX В-1) в шаге модуля.

### 3.5. Музыка по вкладкам (W4, UX §7.1)
| Вкладка / экран | `V10Music` | Замечание |
|---|---|---|
| Чайная | `motif(partner)` в «салонной» аранжировке, иначе `play_screen("home")` (= `lobby`) | UX: тема партнёра (MD-11); полная при симпатии ≥ 6 |
| Героини | `motif(выбранная)`, фон `play_screen("collection")` (= `salon`) | UX: арфа, струнные, 68 — отдельного трека нет (новый трек — задача polish) |
| Столы / Путь | `play_screen("path")` | ок |
| Партия | `match` → `set_tension` → `fever` (Азарт) → `sting` | UX: стем Азарта = инструмент партнёра — пока общий `fever` |
| Желания | `play_screen("summon")`, `stop(0.4)` перед SSR | ок |
| Лавка | `play_screen("shop")` −3 дБ | проверить −3 дБ |
| Салон | `play_screen("salon")` | UX: эрху 76, трек — city-pop (несовпадение характера, отметить в отчёте W4) |
| Телефон | `play_screen("phone")` | ок |
| Пагода | `play_screen("pagoda")` | ок |
| Странствие | `play_screen("pagoda")` (временно) | UX: сякухати, ветер, 84 — трека нет |
| Дуэли, турнир, лига | `play_screen("duels")` | ок |
| Режимы mj-* | `V10MjMusic.play(mode)` / свои петли (`koikoi_loop`, `moon_table`, `riichi*`) через шину Music | `mode_triples` и др. из MODES §6.5 — нет |
Кроссфейд вкладок 0,4 с (UX) — `V10Music` по умолчанию 0,8 с: передать `fade = 0.4`.

### 3.6. Числа (W3, решение владельца)
Расходятся три источника: каталог `V10Catalog` (79 ₽ = 180 камня; абонемент 300 + 90/день; SSR 3 %), `V10Rates` gacha (SSR 1,6 %, итог 2,90 %; эталон
1190 ₽ = 1090), spec §2.2/Л4 (1190 ₽ = 1090, ≈ 164 ₽ за желание; абонемент +30/день). В W3 сделать `V10Sku` (единственное место с ₽) и `V10Rates`
(единственное место с шансами) поверх **одного** каталога; по умолчанию — **spec** (UX ссылается на spec-цифры, gacha уже по spec), каталог economy
подогнать, вопрос №1 README economy записать владельцу в отчёт. `--contract_selftest=1` (spec §2.2) — в W3.

### 3.7. Сейв: SAVE_VER 7 → 8 (W1, ровно один раз)
- `g.gd`: `const SAVE_VER: = 8`; в конце `_migrate()` — `V10Save.migrate(S)` (для ver < 8 — подъём: `v10_meta`, `v10_afisha`, мигратор economy
  `S.econ`, `ex → petals`, `free10 → tickets += 10`, `S.streak = 0`, `V10ProfileCos.seed_seen`, `V10Look.migrate`, gacha `newbie_left`; для 8 — `ensure`).
- Регистрация дефолтов (все в `registry_list.gd`, порядок не важен; поздние шаги дописывают ключи **без** нового подъёма):
  W1 `v10_meta, v10_afisha, econ, v10_shop, v10_cos_owned, v10_cos_seen, v10_feats, v10_auth, v10_tut, v10_clarity, look, hero_combo, a11y_calm`;
  W2 `v10_levels, v10_boosters, v10_salon, v10_streak, v10_comeback, v10_bday, v10_tray, v10_tele, v10_phone, v10_feed`;
  W3 `tickets, petals, candles, pity_std, s_pity_std, rates_ver, ostars, targets, mastery, first_pick, first_pick_t, seven, v10_gacha, deco_fonts`;
  W4 `v10_pagoda, v10_journey, v10_mj_stage, v10_mj_look, v10_mj_triples, v10_mj_riichi, v10_mj_sanma, v10_mj_koikoi`.
  (Ключи W2–W4 можно зарегистрировать уже в W1 — `ensure` идемпотентен, — а модули подключить позже.)
- `recovery_selftest` (`v08/recovery/recovery_selftest.gd`): фикстура сейва 0.9 (ver 7) → загрузка → `ver == 8`, все старые ключи на месте,
  все зарегистрированные ключи есть, второй `migrate` ничего не добавляет (отчёт `added == []`), повреждённые значения новых ключей чинятся
  (`V10MjTileMaterial.st()` и т. п.), `S.econ.seal` верный, `.bak`-восстановление на ver 8. Плюс `--v10_save_selftest=1` (spec §2.6).
- Журналы (`ledger`, `pulls`, чаты, уведомления) — только `user://v10_logs/*.json`.

### 3.8. Ядро `v10/core/` (W1, новые файлы)
- `hooks.gd` — autoload **`V10Hooks`** (`project.godot [autoload]` после `V7Event`): сигналы spec §2.8 `pair_taken(info)`, `game_started(cfg)`,
  `game_ended(result)`, `win_screen(ctx)`, `home_built(home)`, `summon_built(sc)`, `app_resumed`, `app_paused` + расширение
  `screen_shown(id, screen)` (для музыки, обучения, переходов); методы `emit_*`. Точки эмита (один раз, W1):
  `play.gd build()` после `_make_board()` → `game_started`; `play.gd _on_match()` → `pair_taken({mid, combo, gold, shard, face, mode, partner})`;
  `play.gd _on_clear()` (победа) и `_on_fail()`/`_v8_record_loss()` (поражение) → `game_ended(result)` по схеме MODES §7.1 `{mode, win, score, stars,
  time_s, pairs, hero, seed, level, rewards}`; `play.gd _victory()` → `win_screen(ctx)`; `mode_play.gd`/`event_play.gd`/`daily.gd` — `game_ended`;
  `home.gd build()` → `home_built(self)`; `summon.gd build()` → `summon_built(self)`; `main.gd _notification` → `NOTIFICATION_APPLICATION_RESUMED/PAUSED`;
  `main.gd go()` после `build` → `screen_shown(id, screen)`.
- `registry.gd` — `class_name V10Registry` (статический): `module(id, {selftest:{scene, args, fast_args, needs_render, marker}, save:{key: defaults},
  screens:{id: path}, home_slot, migrator})`, `screens()`, `selftests()`, `depth_graph()` (для П-5).
  `main.gd`: `const SCREENS` → `var SCREENS` + `SCREENS.merge(V10Registry.screens())` в `_ready()` (const-словарь в GDScript неизменяем).
- `registry_list.gd` — по одной строке на модуль (единственный общий файл).
- `--v10_selftest=all|fast|<id,id>` (`main.gd _dev_args` → `V10RegistryRunner`): запускает **каждую** сцену самотеста отдельным дочерним
  процессом `OS.execute(OS.get_executable_path(), ["--headless" (если не needs_render), "--path", res_root, scene, "--", args…])` без `flock`
  (родитель уже под ним), читает маркер (`ECON_SELFTEST`, `META_SELFTEST`, `MJ_RIICHI`… — колонка «маркер» в §0.3), печатает
  `V10_SELFTEST ok/total` и строку на модуль, код выхода = число красных модулей. `needs_render` (phone, mj_look, responsive) без DISPLAY
  помечаются `skipped (no display)`; запускать под `xvfb-run`. `fast` — урезанные аргументы (riichi `--games=20`, sanma `--games=20`,
  koikoi `--games=100`, gacha `--mc=0.1`, econ `--econ_mc=0.1`, levels `--levels_n=200`).
- `money.gd` (`V10Money`, §3.1), `rank.gd` (`V10Rank`), `tables_hub.gd` (хаб «Столы»), `nav.gd` (новый навбар, если не внутри `V10HudHome`).

---

## §4. Шаги интеграции W1 → W4

Общее для каждого шага: работать в `v10-integration`; горячие файлы — короткими вызовами; в конце шага — §5 «Проверки», отчёт с
`UX_RULES: P0 N/N, P1 N/N`, скриншоты новых экранов (720×1280 и 1080×2400), коммит на английском, `git push origin v10-integration`.
`SAVE_VER` поднимается только в W1.

### W1. Контракт + M0 + M1: фундамент, кошелёк/ранги/мета, навигация 5 вкладок, плашки HUD v2
**Состав:**
1. Ядро §3.8: `V10Hooks` (autoload) + все точки эмита; `V10Registry` + `registry_list.gd` (строки всех 28 модулей — с самотестами и
   ключами сейва, экраны — только тех, что подключаются в W1); `--v10_selftest=all|fast`.
2. Сейв §3.7: `SAVE_VER 8`, `V10Save.migrate` в `_migrate()`, мигратор economy, `ex/free10/streak`, `seed_seen`, `V10Look.migrate`,
   новые проверки в `recovery_selftest`.
3. Деньги §3.1: `V10Money`, `G.econ` (`load_dict`, `save_dict` в `save()`, `reconcile/tick` на загрузке и `app_resumed`), перевод 35 прямых
   записей `S.gems/S.coins`; `V10Rank` и вывод A/S/SSR в старых экранах (summon, collection, shop, профиль, cutin; `G.rar_color` → `V10Rank.color`).
4. Мета §3.2: autoload `V10MetaTick`, `today()` → `V10Meta.day_key()`, `G.add_aff` → `V10Bond.gain` (11 файлов), `Time.*` вне meta — в файлах W1;
   `V10EntryQueue.run()` на Чайной; Афиша с провайдерами «Задания дня» (+ «Забрать всё»), «Событие», «Неделя», режим дня ×2 (`V10Afisha.mult`
   на монеты и ранг); `V10WinPanel`/`V10WinStack` + «Ещё уровень · N» в окне победы Пути (старое окно 0.9 пока остаётся, панель снизу);
   `V10ShopGuard` на старой Лавке; Настройки → Уведомления.
5. Навигация (UX §3.1–§3.3, HUD_V2 §8.2, §8.6, §9.1, §9.4): `TABS` = Чайная · Героини · Столы · Желания · Лавка (id `home, collection, tables,
   summon, shop`), 5 равных вкладок без звезды; Чайная на `V10HudHome` (аватар+ник, Телефон, 3 фонаря Сегодня/Салон/Серия — Салон и Серия
   скрыты до W2 по §3.5, табличка партнёра, одна «Играть · N»), удалены левая колонка, «Режимы», «Сесть за стол», «Лига», «Ивент», «−20%»,
   валюты, «ещё 3 сегодня»; хаб «Столы» `tables_hub.gd` (каркас: свиток Пути → старый `levels`, «Играть · N», строка «Сегодня», полки со старыми
   режимами из `modes.gd` по одному тизеру); шапки `V10Header`; статус-лента и валюты только где тратят; §9.1 HUD_V2 (`UI.label/title/rbox`,
   `art.gd`, `jbutton.gd`); `UI.font` + `nunito-sym` (₽); `--hud2_selftest=1` в main.
6. `V8Playtest._fresh()` и `go_tab()` под новую навигацию (вкладка `tables`, «Играть · N» вместо «Сесть за стол», без «ИВЕНТ» на главной),
   шаг «победа → Ещё уровень → новая партия» (`MoreLevel`).

**Приёмка W1:**
- [ ] Все базовые самотесты §0.1 зелёные с теми же числами (или больше): selftest 240/240, event 84/84, league 1131/1131, profile 13/13,
      recovery ≥ 42 + новые проверки миграции (все зелёные), ults 671/671, letters 2589/2589; `--fuzz=3` — rule errors 0, blocked takes 0.
- [ ] `--v10_selftest=all` под xvfb печатает `V10_SELFTEST ok/total` и строку на каждый из 28 модулей; все модули с самотестом — не ниже §0.3
      (tutorial — `static only`).
- [ ] `--meta_selftest=1 --meta_grep_strict=1`: 0 `G.add_aff` вне `bond.gd`; `Time.*` — только файлы W2–W4 из списка §2.3 (перечислить в отчёте).
- [ ] grep: `S.gems\s*[-+]=` / `S.coins\s*[-+]=` вне `v10/core/money.gd` = 0; `--econ_selftest=1` и `econ.audit()` после fuzz пустой.
- [ ] Сейв 0.9 (фикстура) → 0.10: `ver == 8`, ключи из §3.7 W1 на месте, повторная загрузка ничего не меняет, `econ.seal` валиден.
- [ ] Экспорт пакета + `--pt=fresh` на пакете → `PT OK`, шаг «Ещё уровень» пройден, скриншоты Чайной, Столов, Героинь, Желаний, Лавки.
- [ ] UX P0-1 (Чайная: ≤ 7 тапаемых без навбара, 3 фонаря, одна «Играть»), P0-2 (5 равных вкладок, новые имена) — «да»; П-1, П-2, П-3, П-5 (граф
      `V10Registry.depth_graph()` ≤ 2), П-6, С-2 (до L8 нет «₽»), С-7 (на Чайной нет цен и валют) — «да».
- [ ] `--hud2_selftest=1` зелёный; `--layout_selftest=1` на 1536×2048 и `--layout_shots` 720×1280/1080×2400 без `LAYOUT WARN` на новых экранах.
- [ ] В store-сборке (`--feature tw_store` или без тега в экспорте) на старой Лавке 0 видимых ₽-кнопок (`--meta_selftest` блок shop).

### W2. M2 + M3: Путь до 1000/Салон, ритуалы, Телефон/чаты
**Состав:**
1. levels + path: `G._build_levels()` → `V10LevelGen` (лениво по арке), `V10LevelBoard`, `v10_plan`, миграция `S.unlocked/S.stars` 48 → 1000 (по README levels,
   без потери звёзд; записать формулу в recovery_selftest), награды Пути только первое прохождение через `V10Money`; экран `v10path` в реестре;
   свиток Пути в хабе «Столы» = 5 узлов `V10PathMap`; «Играть · N» = `V10PathState` текущий; бустеры/Огонёк, подстройка после 2 провалов,
   окно провала Пиков/Легендарных, «место затора» (лог снятий из `pair_taken`).
2. salon: экраны `v10salon`, `v10scene`; фонарь «Салон» после L2 (§3.5, одна обязательная подсказка-палец); полоса салона и «В салон» в `V10WinStack`;
   `notify_stars` на `game_ended`; фон лобби; колбэки `grant_cb → V10Money`, `bond_cb → V10Bond`, `letter_cb → V9Letters.queue`, `level_cb → V10PathState`.
3. rituals: `V10Rituals.install()`; фонарь «Серия» (день 2) с `V10StreakChip` → `V10StreakSheet`; утренний поднос (`V10TrayView`) на Чайной; сцены возврата/ДР
   через `V10EntryQueue`; `V10RestedBar` в партии; ДР-фишки (`deal_overlay`) не в рейтинге; события писем в `letters.gd`; «Мой день рождения» в Настройках.
4. chat + phone: `V10Save.register("v10_phone"/"v10_feed")`, транспорт-одиночка (пересоздание после load/restore), Телефон из иконки статус-строки
   (после L5) вместо «Писем», события `first_win/combo_record/rank_up/comeback/outfit`, `letters.gd reply()` → `V10Bond`.
5. `Time.*` и `G.add_aff` в файлах W2 → meta (`rit_clock`, phone, salon_selftest…).

**Приёмка W2:**
- [ ] Всё из «Приёмки W1» (база §0.1, fuzz, `--v10_selftest=all`, `PT OK` на пакете) — без регресса.
- [ ] `--levels_selftest=1` ≥ §0.3, `--path_selftest=1` ≥ §0.3, `--salon_selftest=1`, `--rit=selftest`, chat, `--phone_selftest=1` — не ниже §0.3.
- [ ] Миграция прогресса: фикстура 0.9 с пройденными 48 уровнями → на карте открыт уровень по формуле, звёзды перенесены, банк Салона = сумма ★
      (интро «У тебя уже N★…»), повторная загрузка — без изменений (recovery_selftest).
- [ ] `--pt=fresh` (пакет) проходит: L1 → Чайная → «Играть · 2» → победа → «Ещё уровень» → L3; фонарь «Салон» появляется после L2, тап → Салон → бирка →
      «Восстановить» при наличии ★; Телефон появляется после L5 (если плейтест доходит — иначе dev-флаг `--unlock=6`), скриншоты Салона, карты Пути,
      карточки уровня, Телефона, календаря серии, подноса.
- [ ] Окно победы Пути: ≤ 2 полосы (салон > мастерство > пропуск), «Ещё уровень · N» открывает правильный индекс, в не-path режимах полосы салона нет.
- [ ] За один вход — одна полноэкранная сцена (`V10EntryQueue`, О-1); на Чайной ≤ 7 тапаемых и ≤ 1 точки (П-3, §3.6); Телефон — единственное число-бейдж.
- [ ] Симпатия: только `V10Bond.gain` (grep-strict зелёный для файлов W2), потолок 25/сут работает в чатах/ленте/касаниях.

### W3. M4 + M5: Желания v2, Лавка 2 (Android-test/Android-store), лицо героинь (look/fonts/profile), живой риг
**Состав:**
1. gacha: `SCREENS["summon"]` → `V10WishScreen`, `SCREENS["odds"]` → `V10OddsScreen` (провайдеры gacha/chest/tickets — один экран шансов),
   `G.roll/pull` → `V10Gacha2`, дубли → `V10Stars`, «Обмен» удалён; первая SSR на выбор после L3 (UX §3.5 поток: Желания → выбор → «Сделать партнёром?»
   → вкладка Героини); «Первый гость», «Семь встреч» (поднос), Свеча; мастерство (`pair_taken`/`game_ended`, полоса в `V10WinStack`);
   письмо «Новые правила желаний» через очередь входа; 24 ч без предложений после первой SSR (`offer_quiet`).
2. Числа §3.6: `V10Sku` + `V10Rates` поверх одного каталога; `--contract_selftest=1`.
3. shop: `SCREENS["shop"]` → `shop2_screen.gd`, `V10ShopSheet.layer`, удалить `screens/shop.gd` и `_buy()`; «Не хватает» → `V10ShopFlow.need`;
   попап после победы (`V10Offers`); реклама-заглушка только в тест-сборке; абонемент → поднос + `V10MonthDisc`; пропуск сезона + строка «Сезон» Афиши;
   **пресеты** `export_presets.cfg`: `Android-test` (`custom_features="tw_test,rustore"`) и `Android-store` (`"tw_store,rustore"`), оба с
   `exclude_filter=""`, `include_filter` для OFL/лицензий; пресет `Android` оставить равным `Android-test` (на него ссылается HANDOFF §2) или
   обновить команды HANDOFF §2 в том же коммите; `V10AgeGate` в `_splash()` (до W4 — перед старым тайтлом).
4. look + fonts + profile: `g.gd skin_look()` → `V10Look.tile_look`, `tile.gd`/`board_table.gd` хуки тем, `V10PairFx` на `pair_taken`; Героини → сегменты
   Наряды · Стиль · История, кит-лента, «Мой стиль» из Профиля → Стиль; HUD-скин (каркас, Злата скрыта, `--skin=zlata`), «Новый стиль стола» через
   очередь входа; шрифты SSR (`UI.font`, `cutin.gd`), экран «О игре · шрифты и лицензии»; Профиль 2.0 (`V10LookCard`/`V10CardView`, редактор,
   `population.gd`, `league.gd`), выдачи косметики (`V10ProfileCos.grant`) из Лавки/пропуска/«Первого гостя».
5. Живой риг: `v09/home/live.gd` режим `rig10` для МТ в Чайной и в Героинях (≤ 1 риг на экран, `motion` от `fx_level`), `rig.tscn` → бинарный `.scn`;
   смоук-самотест рига в реестре.

**Приёмка W3:**
- [ ] Всё из приёмки W1–W2 без регресса; `--gacha_selftest`, `--shop_selftest`, `--look_selftest`, `--fonts_selftest`, `--profile2_selftest`, `--econ_selftest` ≥ §0.3;
      `--contract_selftest=1` зелёный (ни одной «₽»/«%» вне `V10Sku`/`V10Rates`).
- [ ] Экспорт обоих пресетов (`--export-pack Android-test` и `Android-store`) и `--pt=fresh` на **каждом** → `PT OK`; в store-пакете 0 видимых ₽-кнопок
      (С-2), в test — плашка «ТЕСТ»; `include_filter` положил `OFL.txt` (экран лицензий не пуст).
- [ ] Желания: ≤ 3 баннера, «SSR — не позже 60-го желания» одной строкой, «ⓘ Шансы» у каждой случайной покупки (С-5), «Готово» главная в итоге ×10 (P0-5, P0-6).
- [ ] Лавка: сегменты Витрина · Наряды · Пополнить, «= N желаний» и «≈ N ₽ за желание» под каждой ценой (С-3), «Касса» без rose.500 (С-4), лист
      подтверждения §5.3, ни одного «₽» до L8 (С-2) (P0-7).
- [ ] Первая SSR: поток после L3 одним полноэкранным сценарием, без предложений 24 ч (О-3); «Сделать партнёром?» → вкладка Героини.
- [ ] Героини: на экране ≤ 1 риг и ≤ 1 видео (Г-4), лицо свободно от UI (Г-1), «Мой стиль» доступен за ≤ 2 перехода (П-5).
- [ ] Сейв: ключи W3 зарегистрированы, `ex → petals`, `newbie_left` по формуле, `S.look` в V8Recovery — recovery_selftest зелёный.

### W4. M6 + хаб «Столы» + звук + сок + вход + понятность + победа
**Состав:**
1. Хаб «Столы» полностью (MODES §6.1): корешок, свиток Пути, «Играть · N», «Сегодня» (Партия дня · Режим дня ×2), полки «Пасьянсы» (Тройки),
   «За столом» (Стол на четверых, Лунный стол, Коикои), «Испытания и соперницы» (Пагода, Странствие, Блиц, Дуэли, Турнир) — по одному тизеру на полку,
   гейты MODES §6.4 через `V10EntryQueue` (одна система за вход); экраны режимов (1 переход) по контракту MODES §7.1; результаты `finished(result)` →
   `V10Hooks.game_ended` + `V10Money.grant` (потолок кристаллов 400/сут spec §2.3) + `G.add_rp`.
2. tower: экраны `pagoda_screen.gd`, `journey_screen.gd` (+ арт), `V10TowerRules` в `play.gd`/`mode_play.gd` (10 точек), сейв после потерь/попыток,
   косметика в `V10ProfileCos`, строка «Неделя» Афиши.
3. Партия HUD v2 (P0-4): `V10HudMatch` + `V10ComboShowcase` (README hud2 §1), `V10MjPresence` в сцене hud2 (§3.4), mj-look стол/материал, Азарт =
   `V10Juice.fever_aura` (огонь рамки V7Combo выключен), рамка стола выключена, «Ставка ×2» до первого хода, звук — в паузе.
4. Победа (P0-3): такт 1 `V10HudVictory` (поза `win`, «Стол чист», звёзды; критерии — по тапу на звезду), такт 2 — ≤ 3 жетона наград и одна «новость»,
   такт 3 — ≤ 2 полос (`V10WinStack`); ранг, лига, комбинации, альбом, разбор clarity — в «ещё N ▸»; кнопки «Ещё уровень · N» и «В чайную/В салон»
   на постоянных местах, остальное в «⋯»; «#20 из 20» убран.
5. audio: `V10Music` по таблице §3.5 через `V10Hooks.screen_shown`, кроссфейд 0,4 с, `set_tension/fever/sting`, SFX через `V9Feel` → `V10SfxBank`.
6. juice: `V10Juice.warm()`, переходы вкладок («Тушь» по UX §3.1), эффекты пар, фонтаны наград, `chest_burst` вместо белой вспышки в Желаниях.
7. auth: `_splash()` → `V10AuthFlow.boot` (+ `V10AgeGate`), «Аккаунт» в Настройках, `V8Playtest._fresh()` жмёт «Играть как гость».
8. clarity под UX: словарь и все видимые строки — «Приём», «Азарт», «Ставка ×2», «Дар», «Героини», «Столы», «Событие», «Задания дня» (§3.3);
   `ult_selftest` проверяет «Приём»; `V10Lint.UI_BANNED` — жёсткий тест в `--v10_selftest`.
9. tutorial: только хук (`V10Tutorial.attach`, гард `_intro()`, «Как играть», «?» в шапках), главы выключены до переписывания другим тредом.

**Приёмка W4:**
- [ ] Всё из приёмки W1–W3 без регресса; `--tower_selftest`, `--mj_stage_selftest`, `--mj_look_selftest` (xvfb), `--mj_triples_selftest`, `--mj_riichi_selftest`,
      `--mj_sanma_selftest`, `--mj_koikoi_selftest`, `--juice_selftest`, audio, `--auth_selftest`, clarity — ≥ §0.3 (clarity/ults — с обновлёнными именами).
- [ ] `--pt=fresh` (пакет): вход «Гость» → L1 → Чайная → Столы → (dev-разблокировка) Тройки, Стол на четверых, Коикои, Пагода — по одной партии с
      `finished` и начислением; скриншоты хаба, экранов режимов, партии HUD v2 (T1/T2 витрины), победы (3 такта).
- [ ] P0 UX_RULES §9 1–10 — все «да» (P0-3 победа, P0-4 шапка партии, P0-8 режимы растворены в Столах, P0-9 событие, P0-10 кат-ин); чек-лист §10 P0 полностью «да».
- [ ] Хаб «Столы»: тапаемых ≤ 7 (свиток, Играть, Сегодня, 3 полки), слов ≤ 25, на полке ≤ 1 тизер; глубина до любой партии ≤ 2 (П-5).
- [ ] С-1: `V10Lint.UI_BANNED` по всем видимым строкам = 0 (нет «умение», «Полнолуние», «Ва-банк», «ульта», «Гардероб», «Ивент», «Поручения», «SR»).
- [ ] Партия: ≤ 5 постоянных узлов HUD (`--hud2_selftest`), святая зона пуста при включённом вводе (`sacred_hits() == 0`), 1 риг и 0 видео, FPS-замер ≥ 55
      (или отметить, что устройства нет).
- [ ] Музыка: у каждой вкладки свой трек, кроссфейд 0,4 с (З-1, ручная проверка по логу `V10Music`), нет двух музык одновременно.
- [ ] Белых вспышек нет (В-7), `fx_level=min` — информация на месте, `a11y_calm` выключает тряску.
- [ ] Обучение: `V10Tutorial.attach` стоит, главы выключены, `tut_test --tut_static=1` зелёный; в отчёте — ссылка на тред переписывания.

---

## §5. Проверки после каждого шага (одинаковые для W1–W4)

```bash
cd /home/claude/tile-waifu
G=/opt/tw-tools/godot; L="flock /tmp/tw-godot.lock"
$L $G --headless --path game --import
for f in selftest event_selftest league_selftest profile_selftest recovery_selftest ults_selftest letters_selftest; do
  $L $G --headless --path game -- --$f=1; done            # числа §0.1, ни одного регресса
$L $G --headless --path game -- --fuzz=3                  # rule errors 0, blocked takes 0
$L xvfb-run -a $G --path game --rendering-driver opengl3 --audio-driver Dummy --resolution 720x1280 -- --v10_selftest=all   # с W1
$L $G --headless --path game --export-pack Android /tmp/x.pck
$L xvfb-run -a $G --main-pack /tmp/x.pck --rendering-driver opengl3 --audio-driver Dummy --resolution 720x1280 -- --pt=fresh --shots=<dir>   # PT OK
```
Экспорт без Android SDK работает (шаблоны 4.5.1 в `~/.local/share/godot/export_templates/4.5.1.stable/`, только `android_*.apk`, `android_source.zip`,
`version.txt`); APK не собирать (нет SDK, dl.google.com закрыт). Отчёт шага: числа против §0, `UX_RULES: P0 N/N, P1 N/N`, список «нет» с исправлением,
скриншоты, что отложено.

---

## §6. Открытые вопросы и блокеры

1. **Цены и шансы** (§3.6) — решение владельца; до решения W3 берёт spec-цифры.
2. `--summon_selftest` из HANDOFF §2 не существует — поправить HANDOFF при следующем обновлении (W1), заменить на `--gacha_selftest` в `--v10_selftest`.
3. Тред переписывания обучения (HANDOFF §19 п. 2) — W4 вешает только хук.
4. Риги Рин/Ханы — WIP-ветки не влиты; в партии/Чайной у них арт наряда.
5. Треки Героинь и Странствия по UX §7.1 отсутствуют; голоса героинь на русском — отложены (HANDOFF §15).
6. Дорожки MODES `classic`, `connect`, `cube`, `bridge`, `garden`, `raid`, `mechanics` не влиты (у `classic`/`connect` WIP-ветки) — полки «Пасьянсы»
   показывают только Тройки (+ старые Этюды/Блиц/Сад из `modes.gd`), гейт стола «3 задачи дня» — фолбэк.
7. Правка UX_RULES §3.2 (слияние полок «Испытания» и «Соперницы», MODES §6.1) — утвердить в W4.
8. **Блокер-базлайн: `tut_test` красный (3322/3382)** уже на ветке `v10-tutorial` — сюжетная сцена `intro` блокирует первый матч бота
   (§2.21). Приёмка W1–W4 по обучению — только `--tut_static=1` (3311/3311) + хук `attach`; реальный прогон чинит тред обучения.
