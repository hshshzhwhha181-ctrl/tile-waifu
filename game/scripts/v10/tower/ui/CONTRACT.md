# Tower UI 0.10 — контракт между частями (дорожка 6 «Пагода и Странствие»)

Ветка `claude/project-thread-nspkdp` = `v10-tower` + свежий `gh-pages` + `v10-hud2` + `v10-juice` (только новые файлы).
Логика (pagoda.gd, journey.gd, mods*.gd, tower_rules.gd, tower_board.gd, tower_util.gd, sim.gd) уже есть и покрыта
`TOWER_SELFTEST 192/192`. Здесь делаем экраны, партию в режимах, арт и звук. Горячие файлы 0.9 (g.gd, main.gd, play.gd,
mode_play.gd, modes.gd, home.gd, ui.gd, jbutton.gd, tray_board.gd, project.godot) **не трогать**: хуки пишем в README.

## Обязательные документы (читать перед работой)
- `docs/UX_RULES.md` — §3.4 (Пагода/Странствие: главное «Подняться» / «Начать забег», второстепенное «Правила», тихое «?»),
  §3.7 бюджет экрана (рабочий экран: ≤ 10 тапаемых, ≤ 60 слов, ≤ 2 валюты, ≤ 4 кегля, ≤ 2 полосы, 1 лист), §4 имена
  (Приём вместо «ульта», Азарт, «героиня» в UI), §6 дизайн-система, §6.7 движение, §7.1 музыка, §10 чек-лист.
- `docs/HUD_V2.md` — плашки V10Plate S/M/L, 3 роли шрифтов, шапка V10Header, кнопки V10Button (play/cash/secondary/quiet).
- `docs/0.10-spec.md` §9 R1–R3 — что видит игрок.
- `game/scripts/v10/tower/README.md` — API логики и хуки интеграции (§3 таблица точек партии, §8 сохранения).
- `game/scripts/v10/hud2/README.md`, `game/scripts/v10/juice/README.md` — готовые компоненты.

## Общие правила кода
- GDScript 4.5, табы. Цвета только из `V10DS` и `V10TowerUI` (никаких hex-литералов в своих файлах).
- Текст через `V10Type` (`V10TowerUI.label`), не мельче 18 px (Overline 15 — только капс-надстрочник). Каждую строку из
  данных движка пропускать через `V10TowerUI.ui_text()` (Ульта → Приём, богиня → героиня).
- Роли: `V10TowerUI.role(node, "primary"|"secondary"|"tertiary")`. Ровно 1 primary на экране/листе (в партии 0).
- Нажатия: `V10TowerUI.tap(node)`; недоступное — серое с подписью «Откроется: …» или причиной, мёртвых кнопок нет.
- Хит-зоны ≥ 80 px. Окно поверх окна запрещено; лист — только поверх экрана.
- Время только датой с МСК («до пн, 30 ноября, 04:00 МСК»), отсчёт — только в последние 48 ч (`week_info().countdown`).
- В Пагоде и Странствии **нет цен, ₽, Лунного камня и платной помощи**. Строки без «%», «₽».
- Соперницы-героини всегда с подписью «соперницы-героини (ИИ)»; строки ИИ-игроков таблицы без метки (решение владельца).
- `fx_level`: `V10TowerUI.fx()`; при `min` движение = проявление 120 мс, информация остаётся.
- Godot всегда через `flock /tmp/tw-godot.lock /opt/tw-tools/godot …`. Новые `class_name` → `--headless --path game --import`.
- Скриншоты — только под `xvfb-run -a … --rendering-driver opengl3 --audio-driver Dummy --resolution 720x1280`
  (и 720x1600 для 9:20). Сохранять в `/tmp/claude-0/-home-claude/893f4170-a000-5979-973d-953ee0bffb0d/scratchpad/shots/<часть>/`.
- Не коммитить и не пушить — это делает ведущий. Чужие файлы не править: нужна правка — опиши её в отчёте.

## Части и владельцы файлов
| Часть | Файлы (только свои) |
|---|---|
| Ведущий | `ui/tower_ui.gd` (V10TowerUI), `ui/tower_art.gd` (V10TowerArt), `ui/CONTRACT.md`, логика и её тексты, README |
| A. Экран Пагоды | `pagoda_screen.gd`, `ui/curse_scroll.gd` (V10CurseScroll), `ui/pagoda_view.gd` (параллакс), `ui/demo_pagoda.gd/.tscn` |
| B. Экран Странствия | `journey_screen.gd`, `ui/journey_scroll.gd` (V10JourneyScroll), `ui/demo_journey.gd/.tscn` |
| C. Веер и окна | `ui/card_fan.gd` (V10TowerFan), `ui/tower_sheets.gd` (V10TowerSheets), `ui/demo_fan.gd/.tscn` |
| D. Партия | `tower_play.gd`, `ui/tower_hud.gd` (V10TowerHud), `ui/boss_cutin.gd` (V10BossCutin), `ui/demo_play.gd/.tscn` |
| E. Арт и звук | `game/assets/v10/tower/**`, `tools/art/tower/**` (промпты, job id), строки в `tools/art/jobs.tsv` не трогать — список в отчёт |
| F. Сборка (после A–E) | `ui/tower_harness.gd/.tscn` (демо-main), `ui/tower_ui_selftest.gd`, плейтест `--tower_pt` |

## Экраны (контракт вызова)
Экран = `Control` со скриптом и методом `build(m, args: Dictionary)` (как все экраны 0.9: `main.go(id, args)` делает
`screen.set_script(SCREENS[id]); screen.call("build", main, args)`). `m` — main: `m.go(id, args)`, `m.back()`, `m.toast(text, icon)`.
Интегратор добавит в `main.SCREENS`: `"pagoda": pagoda_screen.gd`, `"journey": journey_screen.gd`, `"tower_play": tower_play.gd`
и в `PLAY_BACK`/`NO_HISTORY`: `"tower_play"`. Плитка `climb` в «Столах» ведёт на `main.go("pagoda")`.

- `main.go("pagoda", {})` — хаб Пагоды. Запуск этажа: `main.go("tower_play", {"mode": "pagoda", "run": run})`.
- `main.go("journey", {})` — хаб Странствия. Запуск доски: `main.go("tower_play", {"mode": "journey", "run": run})`,
  тренировка: `{"mode": "practice", "run": practice_run}` (забег тренировки живёт в args, не в сейве).
- После партии tower_play возвращает на хаб: `main.go("pagoda", {"result": end_res})` / `main.go("journey", {"result": fin})`
  — хаб показывает итог (окна C) поверх себя одним листом, если `args.result` есть.

## API части C (используют A, B, D)
```gdscript
# ui/card_fan.gd
class_name V10TowerFan extends Control
signal picked(id: String)
signal skipped
static func open(parent: Control, cards: Array, opts: = {}) -> V10TowerFan
#   cards: dicts из V10Mods.bless_card(id, run) / V10Mods.curse_card(id, lvl, mode)
#   opts: {title: String, can_skip: bool, skip_text: String, run: Dictionary (бейдж «уже ×N»), mode: "pagoda"|"journey"}
#   Веер из-под стола, тап поднимает (вдох 1,06), второй тап или «Взять» подтверждает, свайп вниз — «показать стол».

# ui/tower_sheets.gd — окна поверх партии/хаба; каждое само вызывает логику выбора и в конце on_done.call(dict)
class_name V10TowerSheets extends RefCounted
static func floor_clear(parent: Control, run: Dictionary, res: Dictionary, on_done: Callable) -> Control
#   res = V10Pagoda.floor_clear(run, …). Такт 1: «Этаж N пройден», ≤ 3 жетона награды, сундук Стража, веха, подношение,
#   рекорд. Если res.forced — «Пагода разгорается» (карта проклятия, звук heat_flare). Такт 2: веер res.offer →
#   V10Pagoda.pick_blessing. Кнопки: «Выше · этаж N+1» (primary) → on_done({action: "next"}), «В Пагоду» (secondary) →
#   on_done({action: "leave"}) (забег сохранён).
static func board_clear(parent: Control, run: Dictionary, res: Dictionary, on_done: Callable) -> Control
#   res = V10Journey.board_clear(run, …). Счёт доски с прокаткой, итог, сердца. Веер благословений (res.offer) →
#   V10Journey.pick_blessing; затем необязательный выбор 1 из 2 проклятий (res.curse_offer, «очки ×1,15», можно
#   «Без проклятия») → V10Journey.take_curse. on_done({action: "next"}) или, если res.done, on_done({action: "finish"}).
static func pagoda_end(parent: Control, end_res: Dictionary, new_cos: Array, on_done: Callable) -> Control
#   end_res = V10Pagoda.end_run(run). «12 этажей × 2,2 = 2 640», рекорд по Жару, косметика (new_cos — id из COS).
#   «Новое восхождение» (primary) → on_done({action: "again"}), «К Пагоде» → on_done({action: "hub"}).
static func journey_end(parent: Control, fin: Dictionary, on_done: Callable) -> Control
#   fin = V10Journey.finish(run). Счёт, ступень (печать Бронза/Серебро/Золото), награда недели (выдана один раз),
#   попытки. «Готово» (primary) → on_done({action: "hub"}).
static func heat_flare(parent: Control, card: Dictionary) -> void   # вспышка «вспыхнул Жар» без белого
```
Награды выдаёт **тот, кто открыл окно**, до показа: `V10TowerUI.grant(res.reward, "pagoda")`, затем `V10TowerUI.save_now()`.

## API части D для A и B
`tower_play.gd` extends `res://scripts/screens/play.gd`, режимы `pagoda`, `journey`, `practice` через `V10TowerRules`
(таблица README §3). HUD режима — `V10TowerHud` (фонари/сердца, «Жар 12», часы). Кат-ин босса — `V10BossCutin.play(parent, hero, trick) -> Signal`.

## API части A/B для F
Каждый экран и компонент — свой демо-раннер `ui/demo_*.tscn` с флагами `-- --shots=<dir>` (снимки всех состояний) и
`--selftest=1` (печатает `<PART>_SELFTEST ok/total`, код выхода 0 при успехе). F соберёт их в общий `--tower_ui_selftest`.
