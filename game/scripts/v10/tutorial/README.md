# v10/tutorial — обучение под интерфейс 0.10 («Тишина и лак»)

Переписано с нуля (HANDOFF §16, §19): старые шаги 0.9 («левая колонка», «Режимы», «Гардероб», пузырь с портретом,
счётчик «3 / 12», энциклопедия подсказок, окно подтверждения пропуска) удалены вместе с иллюстрациями.
Новый модуль подчиняется UX_RULES (выше него только красные линии и решения владельца) и HUD_V2.

## 1. Что делает (и чего не делает)
- **Одна реплика героини + один спотлайт** (UX §2 п. 7, §3.5, HUD_V2 §9.2: «коучмарк-спотлайт с одной строкой Caveat, без карточки»).
  Реплика: Caveat 30, без пузыря и коробки, пишется пером 0,4 с, держится ≥ 4 с, гаснет 0,3 с (UX §6.3). Экранов текста нет.
- **Первая партия (L1)**: две направленные пары, «Осталось», правило открытой фишки, лоток; дальше — свободная игра.
  Первая пара < 10 с, первая реакция героини < 60 с (BENCHMARK MD-7).
- **Ступенчатое открытие** (UX §3.5): таблица ворот `V10Reveal` — кто, когда и что открывается; закрытое приглушено,
  тап даёт «Откроется после партии N». Модуль — единственный владелец этой таблицы (раньше её не было нигде в коде).
- **Не больше одной новой системы за вход в Чайную** (UX О-1). Вход = прибытие на Чайную (запуск или возврат с другого экрана).
- **Механики партии** (Помощь с L4, Приём, ×N, Азарт, Ставка ×2, тесный лоток): по одной реплике, не больше одной за партию,
  в зоне героини (HUD_V2 §8.1), никогда поверх поля во время хода и не во время T2/T3 витрины комбо.
- **«?» в шапке любого экрана** → лист «про этот экран»: заголовок + ≤ 3 строки с иконкой + «Показать в игре».
  **«Как играть»** — один лист со списком открытых тем (+ ≤ 1 тизер), темы открываются в том же листе (окно поверх окна запрещено).
- Героиня не продаёт: в Лавке реплик нет, о деньгах реплик нет. Лавка открывается тихо (UX §3.5).
- Чего модуль не делает: возраст/вход (v10-auth), выбор первой SSR (v10-gacha), палец «Вывеска — 3★» внутри Салона (v10-salon),
  утренний поднос (v10-rituals), первое письмо (v10-phone). Модуль подводит к ним спотлайтом с Чайной.

## 2. Файлы и классы (контракт)
| Файл | Класс | Роль |
|---|---|---|
| `tut_lines.gd` | `V10TutLines` | Все тексты: `INTROS`, `MATCH`, `HELP`, `HOW_TO`, `UI`, `RANK_GATES`; `t()`, `ui()`, `places(n)`, `match_line()`, `intro_line()`, `hero_name()`, `all_heroine_lines()`, `all_ui_strings()` |
| `tut_state.gd` | `V10TutState` | Сохранение `G.S.v10_tut` (v2), миграции, воронка |
| `tut_reveal.gd` | `V10Reveal` | Ворота UX §3.5: `is_open`, `locked_text`, `due_intros` |
| `tut_target.gd` | `V10TutTarget` | `tut_id` → прямоугольник на экране (мета, группы, провайдеры, запасные пути) |
| `coach.gd` + `spotlight.gdshader` | `V10Coach` | Оверлей: затемнение с окном, реплика Caveat, имя-надстрочник, кольцо касания, «Пропустить» |
| `tut_help.gd` | `V10TutHelp` | Листы «?» и «Как играть», тост «Откроется после партии N» |
| `tutorial.gd` | `V10Tutorial` | Оркестр: `attach(main)`, слежение за экранами, очередь вступлений, публичный API |
| `tut_match.gd` | `V10TutMatch` | Сценарий первой партии + реплики механик в любой партии |
| `tut_selftest.gd/.tscn` | `V10TutSelftest` | `--tut_selftest=1`, `--tut_shots=<dir>`, `--tut_bot=1` |
| `tut_demo.gd` | `V10TutDemo` | Хосты HUD v2 (Чайная/Партия/Победа) с тегами `tut_id` для скриншотов и геометрии |

### 2.1 `V10TutState` (`tut_state.gd`)
```gdscript
const KEY := "v10_tut"; const VER := 2
static var test_store = null               # Dictionary-подмена для тестов (если не null — вместо G.S)
static func st() -> Dictionary             # ensure(G.S) и вернуть G.S[KEY] (каждый раз заново из G.S: загрузка подменяет S)
static func ensure(S: Dictionary) -> Dictionary   # идемпотентно; миграции ниже
static func seen(id: String) -> bool;  static func mark(id: String);  static func unmark(id: String)
static func hints_on() -> bool;  static func set_hints(on: bool)
static func first_match_done() -> bool;  static func set_first_match_done()   # + G.S.tut_done = true
static func skipped() -> bool;  static func skip()                            # skip: first_match_done + hints off
static func day_number() -> int            # 1 в первый игровой день; V10Meta.day_index(V10Meta.day_key()) - first_day + 1
static func funnel_mark(ev: String)        # один раз: st().funnel[ev] = секунды от t0 (локальная воронка, R19)
static func large() -> bool                # совместимость: clarity_state.gd:79 зовёт V10TutState.large()
static func save()                         # G.save() если есть
```
Данные: `{v:2, seen:{id:true}, first_match:false, skipped:false, hints:true, first_day:int(day_index), t0:int(unix),
funnel:{}, large:false, legacy:false, entries:int}`.
Миграции в `ensure`: (а) v1 старого модуля (`chapters`, `tips`, `tips_off`, `large`) → v2: `chapters.match1` → `first_match`,
`tips_off` → `hints=false`, `large` сохраняется; (б) игрок 0.9 (`G.S.tut_done` или `G.S.unlocked > 1`) → `first_match=true`,
`legacy=true`, все вступления, ворота которых уже открыты, помечаются `seen` (кроме `v10_welcome`, оно показывается один раз).
Ключи `G.S` только добавляются; `SAVE_VER` не трогаем (если появится `V10Save` — `V10Save.register(KEY, DEFAULTS)`).

### 2.2 `V10Reveal` (`tut_reveal.gd`) — таблица UX §3.5 + MODES §6.4
```gdscript
const GATES := { id: {"lvl": N} | {"day": N} | {"lvl": N, "or_day": D} | {"flag": "first_pick"} | {"rank": "Нефрит I"} | {} }
static func levels_done() -> int          # max(0, int(G.S.unlocked) - 1)  («после партии N» = levels_done() >= N)
static func is_open(id: String) -> bool   # неизвестный id -> true (не блокировать чужое)
static func locked_text(id: String) -> String   # «Откроется после партии 3» / «Откроется на 2-й день» / «Откроется на ступени «Нефрит I»»
static func force_open(id: String)        # для ворот по рангу: владелец режима зовёт, когда ранг достигнут
static func due_intros(screen_id: String) -> Array   # id из V10TutLines.INTROS: ворота открыты, не seen, экран подходит; по prio
```
| id | Открывается | id | Открывается |
|---|---|---|---|
| `tab.teahouse` | всегда | `match.help` | после партии 3 (на L1–L3 ряда помощи нет, UX P0-4) |
| `tab.tables` | после партии 1 | `path.boosters` | после партии 10 |
| `lantern.salon` | после партии 2 | `mode.blitz`, `afisha.mode_day` | после партии 12 |
| `tab.wishes` | после партии 3 | `victory.challenge` | после партии 15 |
| `tab.heroines` | после партии 3 и выбора первой SSR (`G.S.first_pick`), иначе после партии 4 | `tables.tourney` | после партии 16 |
| `phone` (Почта) | после партии 5 | `season` | после партии 20 или на 4-й день |
| `lantern.today` | после партии 6 | `mode.classic` 9, `mode.triples` 14, `mode.connect` 18, `mode.daily_task` 22, `mode.hand` 26, `mode.palm` 30, `mode.riichi` 34, `mode.cube` 40, `mode.koikoi` 45, `mode.dragon` 50 | после партии N |
| `tab.shop` | после партии 8 | `path.arcs` 49, `path.peaks` 58, `path.legend` 100 | после партии N |
| `lantern.streak`, `phone.chats`, `morning_tray` | 2-й день | `mode.garden`, `mode.journey` (Нефрит I), `mode.duels`, `mode.etudes` (Нефрит III), `mode.shift` (Жемчуг I), `mode.pagoda` (Золото I) | по рангу: `force_open` или `G.rank_name()`/`V10…` если есть |
| `phone.feed` | 3-й день | | |
«Валюты/₽ до L8 нет» и «24 ч без предложений после первой SSR» — у владельцев Лавки/Желаний; модуль это не дублирует.

### 2.3 `V10TutTarget` (`tut_target.gd`)
```gdscript
static func provide(id: String, fn: Callable)    # fn() -> Rect2 | {rect: Rect2, radius: float} | null
static func unprovide(id: String)
static func find(root: Node, id: String) -> Dictionary   # {ok: bool, rect: Rect2 (px вьюпорта), radius: float, node: Node|null}
static func rect_of(n: Node) -> Rect2           # Control: get_global_transform_with_canvas()*Rect2(0,size); Node2D: мета tut_size или провайдер
```
Порядок поиска: провайдер → узел с `get_meta("tut_id") == id` (обход дерева от `root`, видимый, в дереве; кэш weakref) →
группа `"tut:" + id` → `FALLBACKS[id]` (пути по свойствам `main`/`main.screen`, см. §6). Невидимое/нулевое → `ok=false`.
`radius`: мета `tut_radius`, иначе пилюля для кнопки «Игра» (`h/2`), 4 для плашек, круг для дисков.

### 2.4 `V10Coach` (`coach.gd`, Control на CanvasLayer 92 «V10TutLayer», process_mode ALWAYS)
```gdscript
signal finished(result: String)          # "target" | "tap" | "timeout" | "skip" | "lost"
static func layer(host: Node) -> CanvasLayer
func show_step(spec: Dictionary) -> void
# spec: {line, speaker(hero id), portrait: bool, target: String(tut_id) | rect: Rect2, radius,
#        mode: "tap"|"do"|"wait"|"ring", dim: 0.72 (хабы) | 0.45 (партия), place: "auto"|"above"|"below"|"hero",
#        anchor: Rect2 (для place "hero" — зона реплики у плеча), avoid: [Rect2] (face_rect+48 и т. п.),
#        hold: 4.0, timeout: 8.0, skippable: bool, root: Node (где искать target)}
func complete(result := "target")        # оркестр зовёт, когда действие игрока выполнено
func is_showing() -> bool
func current_rect() -> Rect2             # окно спотлайта (для тестов/бота)
```
- Затемнение: `ColorRect` + `spotlight.gdshader` (униформы: `dim_color` = V10DS.NIGHT_900 с альфой `dim`, `hole` Rect2 в px,
  `radius`, `soft` 10 px, `rim_color` V10DS.GOLD_500, `rim_w` 1.5). Окно следует за целью (сглаживание), один «вдох» при появлении
  (1.12→1.0, 240 мс QUINT_OUT). Бесконечной пульсации нет (бюджет хаба: одна анимация — «дыхание» главной кнопки).
- Реплика: `V10Type.label(text, "hand", 30, V10DS.PAPER_100, true)` (Caveat 600, тень по HUD_V2 §3), ширина ≤ 560 (партия ≤ 472),
  ≤ 2 строк, по левому краю. Над ней надстрочник — имя героини капсом (`"overline"` 15, `V10DS.GOLD_500`).
  Портрет-круг 56 (`res://assets/v08/emotions/<id>_happy.webp`) — только если героини нет на экране (нет цели `home.hero`/`match.hero`).
- Размещение: блок текста выше или ниже окна (зазор 24), целиком в безопасной колонке (`V10Layout.safe_insets`, поля 32 хаб / 24 рабочий),
  не пересекает окно (+16) и `avoid`; `place:"hero"` — в `anchor` (зона у плеча в партии, HUD_V2 §8.1: x 232–520, y ≈ 912).
- Режимы: `tap` — затемнение, любой тап закрывает (тап в окне проходит в игру и тоже закрывает); `do` — тапы проходят только
  в окне (`_has_point` = false внутри окна), закрывает `complete()` или тап в окно; `wait` — без затемнения и без блокировки
  (`mouse_filter = IGNORE`), тонкая обводка цели, реплика гаснет сама после `hold`; `ring` — без текста, кольцо касания на цели.
- Кольцо касания (только `do`/`ring`): `V10DS.GOLD_300`, 2 px, сжимается r+28 → r+6, 900 мс, повтор раз в 1,6 с, пока ждём действие.
- «Пропустить» (только `skippable`): тихая подпись UI 18 `PAPER_500` справа сверху в безопасной зоне, хит ≥ 80;
  первый тап → «Точно пропустить?» (`PAPER_100`) на 3 с, второй → `finished("skip")`. Окна подтверждения нет.
- Цель пропала (`find` не нашёл 1,5 с) → `do` превращается в `wait`; через `hold` → `finished("lost")`. Обучение никогда не запирает.
- `fx_level=min` (`V10Juice.level()`/`G.fx_level()`): все появления 120 мс, без «вдоха» и кольца касания (вместо него статичная обводка).
- Цвета только из `V10DS`, обводка текста 0, кегли из шкалы (30 hand, 15 overline, 18/22 UI). Звук: `V10SfxBank.play("notify", {"db": -10})` при реплике.

### 2.5 `V10TutHelp` (`tut_help.gd`)
```gdscript
static func open(host: Node, topic: String) -> Control       # лист «?»: H1 Display 44 + ≤ 3 плашки M (иконка + строка) + кнопки
static func open_how_to(host: Node) -> Control               # «Как играть»: строки-темы (только открытые + ≤ 1 тизер «Откроется: …»),
                                                             # строка «Подсказки героини» с переключателем, «Первая партия»
static func close_all(host: Node)
static func locked_toast(host: Node, at: Rect2, text: String) -> void   # плашка S над `at`, 1,6 с, без звука-ошибки «бззз»
static func topic_for_screen(screen_id: String) -> String    # home→teahouse, levels→tables, summon→wishes, collection→heroines, …
```
Лист: подложка `NIGHT_900` α 0.6 (тап — закрыть), поверхность `NIGHT_700`, радиус 4 сверху, «Шёлк» 220 мс снизу. Главное —
«Понятно» (`V10Button.make("play", …)`, ux_role primary), вторичное — «Показать в игре» (если вступление уже видено), тихое — «Словарь»
(`V10GlossaryScreen.open`, лист при этом закрывается — окно поверх окна запрещено). Открытие второго листа заменяет первый.

### 2.6 `V10Tutorial` (`tutorial.gd`)
```gdscript
static var inst: V10Tutorial
static func attach(main: Node) -> V10Tutorial    # единственный обязательный хук; повторный вызов безопасен
static func main_node() -> Node                  # main, к которому подключён (для V10TutTarget.FALLBACKS)
static func owns_first_match() -> bool           # true, если модуль подключён (старый палец 0.9 не нужен)
static func is_open(id: String) -> bool          # = V10Reveal.is_open
static func locked_tap(id: String, at) -> void   # at: Control | Rect2 → тост «Откроется после партии N»
static func help(screen_id := "") -> void        # «?» текущего экрана
static func how_to() -> void                     # «Как играть»
static func say(line: String, target_id := "", opts := {}) -> void   # общий коуч для других дорожек (тот же вид)
static func event(name: String, data := {}) -> void   # "first_pick", "partner_set", "rank_up", "salon_done", …
static func replay(intro_id: String) -> void     # unmark + показать при следующем входе на свой экран
static func skip_all() -> void
static func busy() -> bool                       # коуч на экране
```
Слежение за экраном: сигнал `main.screen_root.child_entered_tree` (+ кадр задержки), страховка — таймер 0,25 с по `main.screen_id`
(не каждый кадр). Пока `main.busy` или идёт переход/сцена `V6Story` — ничего не показывает.
Вход в Чайную: `entries += 1`; берётся первое `due_intros("home")` с `system=true`, если в этом входе ещё не было системы.
На других экранах — первое `due_intros(screen_id)` (первый визит). В партии — `V10TutMatch`.
Если `V10EntryQueue.shown_this_launch()` не пуст в этот же момент — вступление ждёт следующего входа (не две полноэкранные вещи сразу).

### 2.7 `V10TutMatch` (`tut_match.gd`)
Подключается, когда `screen_id == "play"` и у экрана есть `board` (TrayBoard). Сигналы доски: `matched(mid, combo, gold, shard)`,
`tray_changed`, `failed`, `cleared`; опрос раз в 0,2 с: `skill_ready`, `_v6_danger`, `fever_until`, видимость `riichi_btn`/`match.stake`.
HUD v2 (когда подключат): `hud.helper_pressed`, `hud.ult_pressed`, `hud.hero_face_global()` для `avoid`.
**L1** (`lvl == 0`, `mode == ""`, первая партия не пройдена, подсказки включены), после стартового баннера (≈1,4 с):
1. `m_a` (do, dim 0.45, кольцо) — фишка A = `board.best_move()`; провайдеры `match.tile_a/tile_b` (B — свободная пара A).
2. `m_b` (do) — до `matched`. Воронка `first_pair`.
3. `m_left` (tap) — строка «Осталось».
4. `m_free` (wait) — правило открытой фишки, мягкое кольцо на следующем ходе.
5. `m_tray` (tap) — после второй пары; `{n}` = размер лотка (`board.SLOTS`/`board.slots`).
6. Свободная игра: 20 с без хода → `ring` на `best_move()` без текста (≤ 3 раз за L1).
7. Первый тесный лоток → `m_danger` (wait). Кольцо Приёма полное → `m_ult` (do, цель `match.hero`), воронка `first_ult`.
8. Победа → `first_match_done`, воронка `l1_win`; на экране победы `v_stars` (wait), затем `v_home` (do, `win.home`).
9. Поражение → `m_fail` (wait).
«Пропустить» есть на шагах 1–5 (skippable) → `V10TutState.skip()`.
**Любая партия**: по одной реплике механики (если не видена, не больше одной за партию, не на L1, кроме `m_danger`/`m_ult`):
`match_help` (ворота `match.help`, после баннера), `match_combo` (первое комбо ≥ 2, с L2), `match_fever` (Азарт), `match_stake` (видна кнопка).
Говорит партнёр партии (`screen.partner`), на L1 — Маджонг-тян. Реплики — только в зоне героини, `avoid` = её лицо + 48.

## 3. Список `tut_id` для интегратора
Интегратор навешивает `node.set_meta("tut_id", "<id>")` на узлы новых экранов (договорённость с тредом интеграции):
| tut_id | Узел |
|---|---|
| `nav.teahouse` `nav.heroines` `nav.tables` `nav.wishes` `nav.shop` | ячейки вкладок навбара (`V10HudHome.tab_ls[i]`-ячейка 144 px) |
| `home.hero` | героиня на Чайной (кадр рига/арта) |
| `home.play` | ★ «Играть · N» (`V10HudHome.play_b`) |
| `home.phone` | Телефон (`phone_b`) |
| `home.partner` | табличка партнёра (`partner`) |
| `lantern.today` `lantern.salon` `lantern.streak` | фонари (`lantern_tr[0..2]`) |
| `tables.play` | ★ «Играть · N» на Столах |
| `tables.tourney` | строка/карточка «Турнир недели» на полке «Соперницы» |
| `tables.mode.<key>` | карточка режима на полке (`classic`, `triples`, `connect`, `daily_task`, `hand`, `riichi`, `cube`, `koikoi`, `dragon`, `palm`, `garden`, `journey`, `duels`, `etudes`, `shift`, `pagoda`) |
| `level.boosters` | ряд бустеров на карточке уровня |
| `match.board` `match.tray` `match.hero` `match.pause` `match.status` `match.help` `match.hint` `match.stake` `match.combo` | поле, лоток, героиня с кольцом Приёма, пауза, строка «1-2 · Осталось N», ряд помощи целиком, диск «Подсказка», «Ставка ×2», цифра комбо |
| `win.stars` `win.rewards` `win.next` `win.home` | звёзды, жетоны наград, «Ещё уровень · N», «В чайную» |
| `fail.retry` | «Ещё раз» |
Пока теги не навешаны, работают запасные пути на текущий код 0.9 (`main.tab_nodes`, `home.play_btn`, `play.tray_box`, `play.tiles_lbl`,
`play.btn_hint`, `play.portrait`, `play.riichi_btn`, `play.victory_next_btn`, `play.fail_retry_btn`) и на члены `V10HudHome`/`V10HudMatch`/`V10HudVictory`.

## 4. Хуки в горячие файлы (делает интегратор)
См. раздел «Хуки» в конце файла (заполняется при сдаче ветки, с проверенным патчем).

## 5. Проверка
```
cd game
flock /tmp/tw-godot.lock /opt/tw-tools/godot --headless --path . res://scripts/v10/tutorial/tut_selftest.tscn -- --tut_selftest=1
xvfb-run -a -s "-screen 0 1700x2700x24" /opt/tw-tools/godot --path . res://scripts/v10/tutorial/tut_selftest.tscn \
  --rendering-driver opengl3 --audio-driver Dummy --resolution 720x1280 -- --tut_shots=/abs/dir [--insets=48,24]
flock /tmp/tw-godot.lock xvfb-run -a /opt/tw-tools/godot --path . res://scripts/v10/tutorial/tut_selftest.tscn \
  --rendering-driver opengl3 --audio-driver Dummy --resolution 720x1280 -- --tut_bot=1
```
