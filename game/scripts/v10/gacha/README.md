# v10/gacha — Гача v2 (веха M4, спека Г1–Г8)

Ветка `v10-gacha` (от `gh-pages`, влита `v10-economy`). Только новые файлы в `game/scripts/v10/gacha/` и
`game/assets/v10/gacha/`; горячие файлы 0.9 не тронуты — всё подключается хуками ниже.
Раскрытие призыва — **тот же 3-ступенчатый фонарь 0.9**: `V10WishScreen` наследует `screens/summon.gd` и
переопределяет только баннер, оплату, слова и карточки (A/S/SSR, ✦, Лепестки), фонарь/карты/шоукейс не заменены.

## Файлы

| Файл | Класс | Что делает |
|---|---|---|
| `rates.gd` | `V10Rates` | **Единственные цифры шансов**: v2 (SSR 1,6 %, с 46-го +6 %, 60-е — SSR; S 13 %, S+ раз в 10) и v1 (0.9). `consolidated()` — точная марковская цепь (2,90 / 16,43 / 80,67 %), `item_odds()`, худший случай (120 ≈ 19 700 ₽, Свеча 200 ≈ 32 800 ₽), эталон ₽ за желание |
| `banners.gd` + `data/banners.json` | `V10Banners` | Ритм 3+3: фазы A «Новая луна» / B «Полнолуние» по 21 дню от 04:00 МСК, 9 фаз (27 недель) + запасная петля B; защита от отката часов (hw); «Цель желания»; список баннеров экрана (≤3) |
| `clock.gd` | `V10GClock` | Время лейна: `now_fn` → `V10Meta.now_unix` (хук), сутки МСК, `day_key` (04:00 телефона), «до пн, 14 декабря, 04:00 МСК» / отсчёт только в последние 48 ч |
| `gacha2.gd` | `V10Gacha2` | Правила: счётчики фаз (`pity/sr_pity/guar`, общие и переносимые) и `pity_std/s_pity_std`; `rates_ver` 1 до первой SSR; 50/50 + обещание; S баннера 50 %; «Первый гость» (120 кр, 50 желаний, SSR-наряд которого нет и не выбранный); Свеча (общий счётчик, +1 с любого желания, не сгорает, 200 → SSR постоянных или фазы); первая SSR на выбор + миграции; ✦/Лепестки; журнал `user://v10_logs/pulls.json` (90 дней, ≤2000) |
| `bank.gd` | `V10GachaBank` | Чем платим и что выдаём: сейчас ключи `G.S` (`gems/tickets/petals/moon/owned`), порядок билеты → кристаллы → Лунный камень, `split_text()` («Спишется: 3 билета → 1 050 кристаллов») |
| `stars.gd` | `V10Stars` | Созвездие ✦1–✦5 и Лепестки (A 10 / S 20 / SSR 60 сверх ✦5; не-наряды 25 кр + 2/6, SSR 20), звезда за 60 Лепестков, `unlocks` (ranked_safe) |
| `mastery.gd` | `V10Mastery` | Мастерство I–IV (300/1000/2500/5000, IV только SSR), ×2 при Отдыхе, копится в памяти, `flush` в конце партии, палитры |
| `seven.gd` | `V10Seven` | «Семь встреч»: 7 дней входа (не подряд), 10 билетов, провайдер утреннего подноса |
| `ui/wish_screen.gd` | `V10WishScreen` | Экран «Желания» v2 (наследник summon.gd): обложка журнала, свайп баннеров, рамка-панель, «Ещё N желаний до SSR», обещание словами, канделябр, «Загадать ×1/×10», «ⓘ Шансы»; в раскрытии — A/S/SSR, полёт ✦ на дубле, Лепестки, ханко «СБЫЛОСЬ/СВЕЧА/ТВОЯ», итог «Готово» главная |
| `ui/odds_screen.gd` | `V10OddsScreen` | «Шансы и правила»: Шансы (базовый/итоговый по редкости и по каждому предмету, баннер золотом) · Правила (+ худший случай) · История (90 дней, фильтр). Провайдеры: `gacha`, `chest` («без случайности»), `register()` для 1.0+ |
| `ui/first_pick_view.gd` | `V10FirstPickView` | Первая SSR: тёмный стол, 3 фишки «восточный ветер», карточки встают и «дышат», разворот, «Примерить стиль», «Выбрать её» → «Выбор окончательный» → ханко → шоукейс 0.9 → «Сделать партнёром?» |
| `ui/candelabra.gd` | `V10Candelabra` | Канделябр из 10 свечей кодом, зажигание по 20 желаний с нотами пентатоники, аккорд на 10-й |
| `ui/spark_sheet.gd` | `V10SparkSheet` | Лист выбора SSR за Свечу, подтверждение той же кнопкой |
| `ui/seven_panel.gd` | `V10SevenPanel` | Карточка «Семи встреч» для подноса: 7 фишек, печати, «Забрать всё» каскадом |
| `ui/outfit_growth.gd`, `ui/palette.gdshader` | `V10OutfitGrowth` | Для карточки наряда в «Героинях»: Созвездие ✦ + «Добавить звезду · 60 ❀», кольцо мастерства, палитры (шейдер перекраски с защитой кожи), церемония II–IV с гонгом |
| `ui/guest_scene.gd` | `V10GuestScene` | «Ты больше не гость» + рамка/титул «Свой за столом» (`fr_own`, `t_own` в V10ProfileCos) |
| `ui/ask_sheet.gd`, `ui/gui.gd` | `V10AskSheet`, `V10GUI` | Нижний лист-вопрос; кит «Тишина и лак» (токены, overline, лист с линией 1 px, тонкие полосы, пилюля редкости, ханко, каскад) |
| `gacha_selftest.gd` | `V10GachaSelftest` | `--gacha_selftest=1`: 111+ проверок (ниже) |
| `gacha_demo.tscn/.gd`, `ui/demo_host.gd` | `V10GachaDemo` | Отдельный запуск: самотест и скриншоты без main.gd и без сейва игрока |

Ассеты `game/assets/v10/gacha/` (gpt_image_2_6 high 2k, аудит анатомии пройден, job id в `art_jobs.tsv`):
`key_five_winds.webp` (салон «Пять ветров», 5 фонарей-ветров), `key_first_guest.webp` (Маджонг-тян у двери, подмигивает),
`guest_door.webp` (она же приглашает войти — сцена «Ты больше не гость»), `first_pick_table.webp` (стол и 3 фишки),
`key_new_moon.webp` / `key_full_moon.webp` (фоны фаз A/B), `banner_frame.png` (лаковая рамка с золотыми облаками, прозрачная).

## Запуск

```
# самотест (без окна)
flock /tmp/tw-godot.lock /opt/tw-tools/godot --headless --path game res://scripts/v10/gacha/gacha_demo.tscn -- --gacha_selftest=1 [--mc=0.3]
# скриншоты (нужен xvfb)
flock /tmp/tw-godot.lock xvfb-run -a /opt/tw-tools/godot --path game --rendering-driver opengl3 --audio-driver Dummy \
  --resolution 720x1280 res://scripts/v10/gacha/gacha_demo.tscn -- --shots=<dir> [--only=wish_phase,reveal,odds,…]
```
Сцены скриншотов: `wish_phase, wish_phase_b, wish_newbie, wish_std, reveal, real_pull, odds, spark, first, seven, growth, guest`.

## Данные сохранения (лениво, `ensure()` идемпотентен, SAVE_VER не трогается)
`tickets, petals, candles, pity_std, s_pity_std, rates_ver, ostars{}, targets{}, mastery{}, first_pick, first_pick_t, seven{days,claimed}`,
`v10_gacha {mig, hw, guest_done, guest_seen, fp_letter}`; `newbie_left` 20 → 50 − (20 − old). Существующие `pity, sr_pity, guar, pulls, owned` используются как есть.
Регистрация для `V10Save.register` — тот же список.

## Хуки для интегратора (горячие файлы правит только он)
- **H1 main.gd** `SCREENS["summon"]` → `res://scripts/v10/gacha/ui/wish_screen.gd`; `SCREENS["odds"]` → `ui/odds_screen.gd` (args `{source, id, tab}`).
  `dev_act` нового экрана понимает старые акты 0.9 и `v2_ssr10/v2_r10/v2_ssr1`, `odds`, `spark`, `first`, `b<i>`.
- **H2 g.gd** `G.roll/G.pull` → прокси: `V10WishScreen.make_gacha().pull(banner, n)`; `give` при дубле больше не платит `DUP_GEMS`
  (дубли идут в `V10Stars.on_dup` внутри `V10Gacha2`; `bank.give_fn` вызывает `G.give` только для нового).
  Кнопка «Обмен 120» (`S.ex`) удалена вместе со старым баннером (её поглощают Лепестки; перевод `ex → petals` — Ф2 кошелька).
- **H3 время**: в M1 `V10GClock.now_fn = V10Meta.now_unix` (одна строка в регистре). Grep-самотест `Time.*` не сработает: системные часы только в `clock.gd` как запасной путь.
- **H4 мастерство**: `V10Hooks.pair_taken(info)` → `mastery.on_pair(G.S.outfit[partner], rested, 1)`;
  `V10Hooks.game_ended` → `ups = mastery.flush(G.S, func(o): return V10Gacha2.rar10(G.ITEM[o].rar))`; I → `main.toast(V10OutfitGrowth.toast_text(o, 1))`,
  II–IV → `V10OutfitGrowth.mastery_up(main.overlay, o, lv, func(): main.go("collection", {"item": o}))`; полоса в `V10WinStack` (приоритет 2) — `V10Mastery.progress`.
- **H5 Героини (collection.gd)** карточка наряда: `V10OutfitGrowth.constellation(gacha, item, rect, rebuild)`, `mastery_ring`, `palettes(item, rect, func(i): V10Mastery.set_palette(...))`;
  картинка наряда — `material = V10OutfitGrowth.palette_material(V10Mastery.palette(G.S, id))` (uniform `palette_idx` в card_art — задача D-лейна).
- **H6 Утренний поднос (V10Tray)**: при входе `V10Seven.visit(G.S, V10GClock.day_key())`; провайдер `V10Seven.tray_items(G.S, give)` или карточка `V10SevenPanel.make(...)`;
  `give(r)`: tickets/gems/coins → `G.S[...] +=`, item → `G.give`, cos → `V10GuestScene.grant_cos(G.S, id)` (`cb_evening`).
- **H7 Профиль**: рамка/титул «Свой за столом» — `fr_own`, `t_own` (уже в V10ProfileCos); до слияния профиля пишутся в `S.v10_cos_owned`.
- **H8 Анонс правил**: письмо Маджонг-тян «Новые правила желаний» через очередь входа, текст из `V10Rates.summary_lines()` и `worst_lines()`; `rates_ver=1` у старых сейвов до первой SSR (уже в коде).
  Если `S.v10_gacha.fp_letter` — письмо «Все три SSR уже твои: 10 билетов» (миграция первой SSR).
- **H9 Предложения**: витрина/попап Лавки обязаны проверять `gacha.offer_quiet()` (24 ч после первой SSR — ни одного полноэкранного предложения).
- **H10 Цены**: `V10Rates.REF_PACK_RUB/REF_PACK_MOON` → заменить на `V10Sku.ref_rub_per_pull()` когда появится (спека §2.2). **Расхождение**: каталог `v10-economy`
  считает базу 79 ₽ = 180 камня (≈ 66 ₽ за желание) и старые шансы 3 %; лейн реализует спеку 0.10 (1190 ₽ = 1090, 1,6 %/2,9 %). Решить в M4 одним источником.
- **H11 registry_list.gd**: `--gacha_selftest=1` → `V10GachaSelftest.run()`; дефолты сейва — список выше.

## Самотест `--gacha_selftest=1`
Шансы v2/v1 аналитически; Монте-Карло 300 000 (SSR 2,91±0,1, S 16,4±0,3, ≤60 без SSR, S+ раз в 10); путь `pull()` (свеча за каждое желание,
std-счётчик отдельно); сумма шансов 100±0,01 на каждом баннере и каждый предмет пула в списке; новичок: 1000×50 — SSR всегда и не выбранная,
×10 = 1200, баннер скрыт после 50, миграция 12 → 42, билеты не берутся; v1 до первой SSR; фаза B даёт цель (10 000), SSR баннера ≤120,
2/3 SSR — баннер; фазы 26 недель без дыр, по 21 дню, A/B чередуются, 04:00 МСК, запасная петля, откат часов, отсчёт только ≤48 ч;
Свеча (200 → выбор, только SSR, ровно 200, не сгорает, с билетов, дубль → ✦); первая SSR (без трат, один раз, 24 ч тишины, миграции);
Семь встреч; Созвездие и Лепестки; мастерство; лайнт видимых строк `ui/` на жаргон UX_RULES §4.3.
