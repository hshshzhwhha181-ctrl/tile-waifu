# v10/meta — мета-ядро 0.10 (веха M1: Ф1, Ф5, Ф6, Ф7, SAVE_VER 8)

Ветка `v10-meta`. Всё в этой папке, горячие файлы 0.9 не тронуты: ниже — хуки для интегратора.

| Файл | Класс | Что |
|---|---|---|
| `meta.gd` | `V10Meta` | Единственный источник времени: `now_unix()`, `day_key()` (сутки с 04:00 по телефону, не откатываются ниже `last_key`), `cal_key()` (04:00 МСК), `clock_ok()` (часы назад > 1 ч), `grant_dated()` + `pending`, `tick()` → `bus().day_rolled(old, new)`, `fmt_when()` «чт 18:30», `fmt_msk()` «вт, 24 ноября, 04:00 МСК», флаги `--v10_now=`, `--v10_dayshift=` |
| `meta_tick.gd` | `V10MetaTick` | Нода-опрос: `tick()` раз в 30 с и на RESUMED/FOCUS_IN, отправка плана уведомлений |
| `bond.gd` | `V10Bond` | Единственный вход симпатии `gain(h, n, src)`: мягкий потолок 25/сут/героиня, касания 3/сут, жёсткие источники мимо потолка, строки «+3», «сегодня 22/25», «На сегодня она уже счастлива» |
| `notify.gd`, `notify_text.gd` | `V10Notify`, `V10NotifyText` | План уведомлений: согласие, категории (Возвращение выкл.), 1 на 72 ч, приоритет bday>comeback>salon>feed, тихие часы 22–10 → 10:00+0–40 мин, лог `user://v10_logs/notify.json` |
| `notify_panel.gd` | `V10NotifyPanel` | UI «Настройки → Уведомления»: согласие (кнопки равного веса), переключатели, «Следующее уведомление не раньше: …» |
| `entry_queue.gd` | `V10EntryQueue` | Не больше одной полноэкранной сцены за запуск; приоритет возврат > ДР игрока > ДР героини > фаза баннера > стиль стола > правила |
| `lint.gd` | `V10Lint` | Стоп-слова §2.7 (`BANNED`), исключения («однажды»), «бесплатн» только рядом с ценой. Спека кладёт в `v10/core/` — файл можно перенести, имя класса то же |
| `save_v8.gd` | `V10Save` | Подъём `SAVE_VER 7 → 8`: `migrate(S, now)`, `ensure(S)`, `register(key, defaults)`, `register_migrator(id, fn)` |
| `win_stack.gd` | `V10WinStack` | Реестр полос (≤2, салон 300 > мастерство 200 > пропуск 100; салон только в `path`) и тиков |
| `win_bar.gd` | `V10WinBar` | Общий виджет полосы: иконка, «3/4★» с бликом, звёзды влетают по одной, плашка «Можно восстановить!» |
| `win_panel.gd` | `V10WinPanel` | Блок под окном победы 0.9: полосы + тики + «Ещё уровень · 58» / «В салон» или «Домой»; «Скоро новая арка» серая |
| `more_level.gd` | `V10MoreLevel` | Логика следующего уровня + вайп 0,4 с |
| `afisha.gd`, `afisha_card.gd` | `V10Afisha`, `V10AfishaCard` | Афиша «Сегодня в чайной»: режим дня по дате (5-дневные перестановки, без повторов подряд), ×2 монет и ранга (не кристаллов), печать «Сыграно» |
| `shop_guard.gd` | `V10ShopGuard` | Предохранитель магазина: store-сборка без ₽-кнопок (на их месте серая «Скоро», тап — тост «Покупки откроются с выходом игры в RuStore»), test-сборка с плашкой «ТЕСТ» |
| `meta_ui.gd` | `V10MetaUI` | `trim()/refit()`: многоточие у подписей, заданных до входа в дерево (обход бага Godot 4.5) |
| `meta_selftest.gd` | `V10MetaSelftest` | Самотест всей дорожки |
| `meta_runner.tscn/.gd` | — | Запуск самотеста и скриншотов без main.gd |

## Запуск

```
# самотест (headless)
flock /tmp/tw-godot.lock /opt/tw-tools/godot --headless --path game res://scripts/v10/meta/meta_runner.tscn \
  -- --meta_selftest=1 --save=user://meta_runner.json --save_wipe=1 [--meta_grep_strict=1]
# скриншоты + проверка предохранителя на НАСТОЯЩЕМ экране Лавки
flock /tmp/tw-godot.lock xvfb-run -a /opt/tw-tools/godot --path game --rendering-driver opengl3 --audio-driver Dummy \
  --resolution 720x1280 res://scripts/v10/meta/meta_runner.tscn -- --meta_shots=<dir> --tag=720x1280 \
  --save=user://meta_runner.json --save_wipe=1
```
`--meta_grep_strict=1` включить после интеграции: тогда `Time.get_unix_time_from_system` / `get_date_string_from_system`
вне `meta.gd` и `G.add_aff(` вне `bond.gd` валят тест. Без флага они печатаются как `META_INFO to integrate …`.

## Хуки для интегратора (M1)

1. **project.godot** `[autoload]` после V7Event: `V10MetaTick="*res://scripts/v10/meta/meta_tick.gd"`.
   Имя автозагрузки НЕ `V10Meta` (это `class_name` статического класса, конфликт имён).
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
4. **home.gd** — после постройки главной: `V10EntryQueue.run()` (одна полноэкранная сцена); правый слот:
   `var c := V10AfishaCard.make(Vector2(CARD_W, 0))` (высота `c.preferred_height()` ≈ 300 px), сигналы
   `row_pressed(id, tab)` → `daily`: `main.go("play", {"mode": "daily"})` (tab «Чтение руки» → режим hand, M6),
   `mode`: `modes._open(row.mode)`, `salon`/`week` — экраны M2/M6; `locked(id, text)` → `main.toast(text, "lock")`.
   `V10Meta.bus().day_rolled.connect(func(_a, _b): card.refresh())` — без всплывающих окон.
5. **modes.gd** сверху: широкая `V10AfishaCard.make(Vector2(W - 32, 0))`.
6. **play.gd** (окно победы Пути, `_victory`) — после `v8_res_close`:
   ```
   var wctx := {"mode": "path" if mode == "" else mode, "level": lvl, "first": first, "stars": stars,
     "was_done": <были ли звёзды у lvl ДО этой победы>, "count": V10LevelGen.count(), "salon_open": <M2>,
     "on_more": func(n): main.go("play", {"level": n, "partner": partner}, false)}
   V10Hooks.win_screen(wctx)
   var wp := V10WinPanel.make(wctx, pw); root.add_child(wp); wp.position = <под плашкой>; wp.play(_v9_yaku_at + 0.4)
   ```
   В режиме `path` панель заменяет кнопки «Дальше / Желания» (`victory_next_btn` → `wp.more_btn` для плейтеста),
   в остальных — только полосы (`buttons` false). `wp.denied` → `main.toast(hint, "lock")`, `wp.home` → `main.go("home")`.
   `V10Hooks.game_ended(result)` → `V10Afisha.on_game_ended(result)`; ×2 монет/ранга: `V10Afisha.mult(mode, "coins")`
   и `mult(mode, "rank")` там, где начисляются монеты и очки ранга (кристаллы не умножаются).
   `--pt=fresh`: шаг «победа → Ещё уровень → новая партия» нажимает `MoreLevel` (имя ноды).
7. **daily.gd** — день входа засчитывается по любой вкладке партии дня: `V10Afisha.mark("daily")` при завершении.
8. **shop.gd** — первая строка `_buy()`: `if not V10ShopGuard.can_buy(): return`; в конце `_build_body()` и
   `pass_popup()`: `V10ShopGuard.guard(self)`. **export_presets.cfg**: два пресета — `Android-store`
   (`custom_features="tw_store"`) и `Android-test` (`custom_features="tw_test"`). Без тега релизная сборка считается
   store (безопасно), запуск из редактора/debug — test.
9. **Настройки** (main.gd `settings()`): строка «Уведомления» → `Common.popup(main, "Уведомления", h)` с
   `V10NotifyPanel.make(w)` внутри.
10. Модули M2–M4 регистрируют полосы/тики: `V10WinStack.add_bar("salon", V10WinStack.PRIO_SALON, builder, {"modes": ["path"]})`,
    провайдеры афиши `V10Afisha.set_provider("salon"|"week"|"hand"|"weekend_rule", cb)`, датированные начисления
    `V10Meta.on("streak", cb)` + `V10Meta.grant_dated("streak", data)`, уведомления `V10Notify.request(cat, earliest, hero)`,
    полноэкранные сцены `V10EntryQueue.offer(kind, key, show)` + `done(kind, key)`.
