# v10/meta — мета-ядро 0.10 (веха M1: Ф1, Ф5, Ф6, Ф7, SAVE_VER 8)

Ветка `v10-meta`. Всё в этой папке, горячие файлы 0.9 не тронуты: ниже — хуки для интегратора.

| Файл | Класс | Что |
|---|---|---|
| `meta.gd` | `V10Meta` | Единственный источник времени: `now_unix()`, `day_key()` (сутки с 04:00 по телефону, не откатываются ниже `last_key`), `cal_key()` (04:00 МСК), `clock_ok()` (часы назад > 1 ч), `grant_dated()` + `pending`, `tick()` → `bus().day_rolled(old, new)`, `fmt_when()` «чт 18:30», `fmt_msk()` «вт, 24 ноября, 04:00 МСК», флаги `--v10_now=`, `--v10_dayshift=` |
| `meta_tick.gd` | `V10MetaTick` | Нода-опрос: `tick()` раз в 30 с и на RESUMED/FOCUS_IN, отправка плана уведомлений |
| `bond.gd` | `V10Bond` | Единственный вход симпатии `gain(h, n, src)`: мягкий потолок 25/сут/героиня, касания 3/сут, жёсткие источники мимо потолка, строки «+3» и серое «На сегодня она уже счастлива». Счётчика «сегодня 22/25» нет: UX_RULES §4.1 п.7 важнее спеки §2.4 (HANDOFF §12) |
| `notify.gd`, `notify_text.gd` | `V10Notify`, `V10NotifyText` | План уведомлений: согласие, категории (Возвращение выкл.), 1 на 72 ч, приоритет bday>comeback>salon>feed, тихие часы 22–10 → 10:00+0–40 мин, лог `user://v10_logs/notify.json` |
| `notify_panel.gd` | `V10NotifyPanel` | Группа «Уведомления» внутри листа Настроек (не окно поверх окна, UX §3.7): согласие (кнопки равного размера и вида, ux_role primary/secondary), строки-переключатели 80 px, «Следующее уведомление не раньше: …». Выключение согласия или категории снимает план |
| `entry_queue.gd` | `V10EntryQueue` | Не больше одной полноэкранной сцены за запуск; приоритет возврат > ДР игрока > ДР героини > фаза баннера > стиль стола > правила |
| `lint.gd` | `V10Lint` | Стоп-слова героини §2.7 (`BANNED`, «одна»/«цена»/«акци»/«купи» — по границе слова), «бесплатн» только рядом с ценой; `UI_BANNED` / `ui_check()` — жаргон UX §4.3 и «было» §4.2 для видимых строк (С-1). Спека кладёт в `v10/core/` — файл можно перенести, имя класса то же |
| `save_v8.gd` | `V10Save` | Подъём `SAVE_VER 7 → 8`: `migrate(S, now)`, `ensure(S)`, `register(key, defaults)`, `register_migrator(id, fn)` |
| `win_stack.gd` | `V10WinStack` | Реестр полос (≤2, салон 300 > мастерство 200 > пропуск 100; салон только в `path`, даже если зарегистрирован без `modes`) и тиков (одна строка: что не влезает по ширине, отбрасывается с конца) |
| `win_bar.gd` | `V10WinBar` | Общий виджет полосы — плашка M 80 px (HUD_V2 §2): иконка 48, «3/4★» gold.300, звёзды влетают по одной, плашка «Можно восстановить!» подпрыгивает дважды. По умолчанию не кнопка (`opts.tap`) |
| `win_panel.gd` | `V10WinPanel` | Блок окна победы (UX §3.4, HUD_V2 §8.3): полосы + тики + главная «Ещё уровень · 58» (≥ 440×104, нижняя треть) и вторичная текстом «В салон» / «В чайную». В конце арки — подпись «Все столы арки пройдены · новая уже в пути» и главная «В чайную» (без серой мёртвой кнопки). Повторный тап во время вайпа игнорируется |
| `more_level.gd` | `V10MoreLevel` | Логика следующего уровня + вайп 0,4 с (при `fx_level=min` — затемнение 120 мс) |
| `afisha.gd`, `afisha_card.gd` | `V10Afisha`, `V10AfishaCard` | Афиша «Сегодня в чайной»: режим дня по дате (5-дневные перестановки, без повторов подряд), ×2 монет и ранга (не кристаллов), печать «Сыграно». Карточка — содержимое листа фонаря «Сегодня» (одна главная «Играть» = первая несыгранная строка, «Понятно», когда всё сыграно) и блок «Сегодня» на Столах (`only: [daily, mode]`, без своей кнопки). Открытые строки + не больше одного закрытого тизера «Откроется: …» без замков (UX §6.4). `V10Afisha.GLOSSARY` — статьи для V10Glossary |
| `shop_guard.gd` | `V10ShopGuard` | Предохранитель магазина: store-сборка без ₽-кнопок (на их месте серая «Скоро», тап — тост «Покупки откроются с выходом игры в RuStore») и без подписи 0.9 «Тестовая версия: покупки бесплатные…», test-сборка с плашкой «ТЕСТ» (Overline 15) |
| `meta_ui.gd` | `V10MetaUI` | Токены UX §6.2 (единственные цветовые литералы дорожки; после влития v10-hud2 — ссылки на `V10DS`), шкала кеглей HUD_V2 §3 (32/22/18, Overline 15), `plate()` (плашка §2.2), `TextButton` (класс «Вторичная»), `role()` (`ux_role`), `enter()` («Вдох», при `fx_level=min` — проявление 120 мс), `trim()/refit()`, аудит-хелперы §10 «А»: `roles`, `font_sizes`, `texts`, `tappables`, `small_hits` |
| `meta_selftest.gd` | `V10MetaSelftest` | Самотест всей дорожки |
| `meta_runner.tscn/.gd` | — | Запуск самотеста и скриншотов без main.gd |

## Запуск

```
# самотест (headless)
flock /tmp/tw-godot.lock /opt/tw-tools/godot --headless --path game res://scripts/v10/meta/meta_runner.tscn \
  -- --meta_selftest=1 --save=user://meta_runner.json --save_wipe=1 [--meta_grep_strict=1]
# скриншоты + проверка предохранителя на НАСТОЯЩЕМ экране Лавки (снимать в 720x1280 и 720x1600)
flock /tmp/tw-godot.lock xvfb-run -a /opt/tw-tools/godot --path game --rendering-driver opengl3 --audio-driver Dummy \
  --resolution 720x1280 res://scripts/v10/meta/meta_runner.tscn -- --meta_shots=<dir> --tag=720x1280 \
  --save=user://meta_runner.json --save_wipe=1 [--fx=min]
```
Самотест: `META_SELFTEST 189/189 (meta 23/23, bond 13/13, notify 25/25, entry 7/7, lint 31/31, save 13/13, winbar 22/22,
more 8/8, afisha 18/18, ux 17/17, shop 11/11, grep 1/1)`.

Скриншоты: `<tag>_win_path`, `_win_wipe`, `_win_end`, `_afisha`, `_afisha_stamp`, `_afisha_fresh`, `_afisha_tables`, `_notify`,
`_notify_on`, `_shop_test`, `_shop_store`, `_shop_store_gems`. На каждый экран дорожки печатается строка
`UX_AUDIT <экран> roles=… sizes=… small_hits=… taps=… words=… jargon=…` (пункты «А» чек-листа UX_RULES §10 до появления
`--ux_selftest`), затем `STORE_RUB_VISIBLE 0 TEST_NOTES 0`, `STORE_RUB_VISIBLE_GEMS 0`, `META_SHOTS ok`. Вне бюджета — ошибка
и код выхода 1. `--fx=min` снимает всё при `S.fx_level = "min"` (файлы с суффиксом `_min`).
Известное: процесс со скриншотами иногда падает уже ПОСЛЕ `META_SHOTS ok` (`malloc_consolidate(): invalid chunk size`,
код 134) при разборе загруженного `main.tscn` 0.9 — то же падение при выходе видят раннеры других веток; на снимки и
проверки не влияет, критерий успеха — строка `META_SHOTS ok`.
`--meta_grep_strict=1` включить после интеграции: тогда `Time.get_unix_time_from_system` / `get_date_string_from_system`
вне `meta.gd` и `G.add_aff(` вне `bond.gd` валят тест. Без флага они печатаются как `META_INFO to integrate …`.

## Хуки для интегратора (M1)

1. **project.godot** `[autoload]` после V7Event: `V10MetaPoll="*res://scripts/v10/meta/meta_tick.gd"`.
   Имя автозагрузки НЕ `V10Meta` и НЕ `V10MetaTick`: это `class_name` статического класса и самого `meta_tick.gd`,
   Godot 4 не грузит класс, который прячет автозагрузку с тем же именем (у автозагрузок 0.9 `class_name` нет).
2. **g.gd**
   - `const SAVE_VER: = 8`; в `_migrate()` в конце: `V10Save.migrate(S)` (для ver < 8 делает подъём, для 8 — `ensure`).
     Экономика регистрирует свой шаг: `V10Save.register_migrator("econ", func(S, now): S.econ = V10Econ.from_legacy(S, now))`
     — до `load_game()` (в `registry_list.gd` или в `_ready` g.gd перед загрузкой).
   - `today()` → `return V10Meta.day_key()`. ВНИМАНИЕ: ветка `v10-economy` предлагает `today()` = день по Москве
     (`V10Clock`). По спеке §2.5 ежедневное — 04:00 по телефону (`V10Meta.day_key`), календарное — 04:00 МСК
     (`V10Meta.cal_key`). Экономике для баннеров/пропуска брать `cal_key`, для заданий — `day_key`. Решить при слиянии.
   - `add_aff()` оставить как сток для `V10Bond` (единственный вызов). Все остальные вызовы → `V10Bond.gain(h, n, src)`:
     `v09/home/touch.gd:180` → `"touch"`; `v09/letters/letters.gd:307` → `"letter_reply"`; `v07/room/room.gd:269` → `"gift"`;
     `v07/event/event_play.gd:201,203,277` → `"event_win"`; окно победы «+10 симпатии» в play.gd → `"level_win"`.
   - `Time.get_*_from_system` в letters.gd, starter.gd, population.gd, recovery.gd и др. → `V10Meta.now_unix()` / `day_key()`
     (полный список печатает самотест строкой `META_INFO`).
3. **main.gd** `_notification`: `NOTIFICATION_APPLICATION_RESUMED` → `V10Hooks.app_resumed` (V10MetaTick ловит его сам,
   хук нужен остальным модулям).
4. **home.gd** — после постройки главной: `V10EntryQueue.run()` (одна полноэкранная сцена). Карточки в правом слоте
   НЕТ (UX §3.3: на Чайной ≤ 7 тапаемых). Фонарь «Сегодня» (после L6, UX §3.5) открывает нижний лист (night.700, радиус 4,
   поля 24), его содержимое — `var c := V10AfishaCard.make(Vector2(W - 48, 0))`, высота `c.preferred_height()`.
   Сигналы: `row_pressed(id, tab)` → `daily`: `main.go("play", {"mode": "daily"})` (tab «Чтение руки» → режим hand, M6),
   `mode`: `modes._open(V10Afisha.mode_of_day())`, `salon`/`week` — экраны M2/M6; `locked(id, text)` →
   `main.toast(text, "lock")`; `close_pressed` → закрыть лист. Главная «Играть» листа шлёт `row_pressed` первой
   несыгранной строки. `V10Meta.bus().day_rolled.connect(func(_a, _b): c.refresh())` — без всплывающих окон; после
   партии `c.stamp(kind)` (печать «Сыграно»).
5. **Столы** (бывш. modes.gd «Режимы», UX §4.2) — блок «Сегодня» над главной «Играть · 58»:
   `V10AfishaCard.make(Vector2(W - 64, 0), {"only": ["daily", "mode"], "play": false, "header": false})` — две строки
   с `ux_role=secondary` (Партия дня, Режим дня, UX §3.4), своей кнопки нет.
6. **play.gd** (окно победы Пути, `_victory`) — после `v8_res_close`:
   ```
   var wctx := {"mode": "path" if mode == "" else mode, "level": lvl, "first": first, "stars": stars,
     "was_done": <были ли звёзды у lvl ДО этой победы>, "count": V10LevelGen.count(), "salon_open": <M2>,
     "on_more": func(n): main.go("play", {"level": n, "partner": partner}, false)}
   V10Hooks.win_screen(wctx)
   var wp := V10WinPanel.make(wctx, 672.0); root.add_child(wp)
   wp.position = Vector2((W - 672.0) * 0.5, H - B - 24.0 - wp.height()); wp.play(_v9_yaku_at + 0.4)
   ```
   Панель прижата к низу: главная «Ещё уровень» ≈ y 1064–1168, вторичная ≈ 1176–1256 при 720×1280 (HUD_V2 §8.3);
   лишняя высота 9:20 уходит вверх, героине. В режиме `path` панель заменяет кнопки «Дальше / Желания»
   (`victory_next_btn` → `wp.more_btn` для плейтеста), в остальных — только полосы (`buttons` false).
   `wp.home` → `main.go("home")`, `wp.salon` → экран салона (M2). `wp.denied` больше не шлётся (конец арки — подпись
   и главная «В чайную»), подключать можно для старых вызовов.
   `V10Hooks.game_ended(result)` → `V10Afisha.on_game_ended(result)`; ×2 монет/ранга: `V10Afisha.mult(mode, "coins")`
   и `mult(mode, "rank")` там, где начисляются монеты и очки ранга (кристаллы не умножаются).
   `--pt=fresh`: шаг «победа → Ещё уровень → новая партия» нажимает `MoreLevel` (имя ноды).
7. **daily.gd** — день входа засчитывается по любой вкладке партии дня: `V10Afisha.mark("daily")` при завершении.
8. **shop.gd** — первая строка `_buy()`: `if not V10ShopGuard.can_buy(): return`; в конце `_build_body()` и
   `pass_popup()`: `V10ShopGuard.guard(self)` (он же прячет подпись 0.9 «Тестовая версия: покупки бесплатные…» в
   store-сборке). То же для всех окон с ₽ вне shop.gd: `V8Starter.popup` (starter.gd) — `V10ShopGuard.guard(<окно>)`
   после постройки и `can_buy()` в начале покупки; ₽ в `txt.gd` — строки этих окон (самотест печатает список
   `META_INFO ₽ outside screens/shop.gd`). **export_presets.cfg**: два пресета — `Android-store`
   (`custom_features="tw_store"`) и `Android-test` (`custom_features="tw_test"`). Без тега релизная сборка считается
   store (безопасно), запуск из редактора/debug — test.
9. **Настройки** (main.gd `settings()`): группа «УВЕДОМЛЕНИЯ» (Overline 15, gold.500) ВНУТРИ того же листа настроек:
   `var np := V10NotifyPanel.make(w); sheet_body.add_child(np)` (высота `np.preferred_height()`, сигнал `changed` →
   пересчитать высоту листа). Не открывать её отдельным `Common.popup` поверх настроек (UX §3.7, П-6).
10. Модули M2–M4 регистрируют полосы/тики: `V10WinStack.add_bar("salon", V10WinStack.PRIO_SALON, builder, {"modes": ["path"]})`,
    провайдеры афиши `V10Afisha.set_provider("salon"|"week"|"hand"|"weekend_rule", cb)`, датированные начисления
    `V10Meta.on("streak", cb)` + `V10Meta.grant_dated("streak", data)`, уведомления `V10Notify.request(cat, earliest, hero)`,
    полноэкранные сцены `V10EntryQueue.offer(kind, key, show)` + `done(kind, key)`.
11. **V10Glossary** (ветка v10-clarity): `for e in V10Afisha.GLOSSARY: V10Glossary.add(e)` (или как регистрирует
    clarity) — статьи «Сегодня в чайной», «Партия дня», «Режим дня ×2» (П-4); «?» листа Афиши открывает `day.today`.
12. **V10DS** (ветка v10-hud2): константы `V10MetaUI.NIGHT_*/PAPER_*/GOLD_*/ROSE_*/JADE_*/CINNABAR` и `FS_*` указать на
    `V10DS` (одна правка в `meta_ui.gd`). Главные кнопки дорожки (`MoreLevel`, `HomeBtn`, `Play`, `Close`) сейчас
    `JButton "gold"` 0.9 (розовая пилюля с сакурой по углам) — после влития hud2 сделать их классом «Игра»
    (rose.500, Playfair 32, без сакуры, UX §6.5, В-4/В-9); «Разрешить»/«Не сейчас» — одинаковые «Вторичные».
