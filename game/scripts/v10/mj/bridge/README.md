# Мост к столу (`v10/mj/bridge`)

Два коротких обучающих режима-перехода от пасьянсов к ричи-столу (`docs/MODES.md §4.5`, §6.2, §6.4):
- **`bridge_daily` («Задача дня»)** — ежедневная задача «Какую фишку сбросить?» из 365 проверенных раздач (`daily_discard_2027.json`), веер-календарь месяца, шаринг без спойлеров; 3 решённые задачи открывают «Стол на четверых» (`riichi_open`).
- **`bridge_hand` («Собери руку»)** — 60 уровней пирамиды ричи-фишек с нежадной автосборкой в 4 набора и пару, 3 «Сбросами» на край стола и требованием к ценности комбинации с L20 (`×2…×4`).

## Состав модуля
- `bridge_info.gd` (`V10MjBridgeInfo`) — карточки `INFO` (`bridge_daily`), `INFO_HAND` (`bridge_hand`), `CARDS`, `HOW_DAILY`, `HOW_HAND`, `STARS_HOW`, `GLOSSARY`.
- `bridge_tiles.gd` (`V10MjBridgeTiles`), `bridge_tile.gd` (`V10MjBridgeTile`) — 34 вида фишек ричи, шантэн/укэирэ-помощники, квадраты шаринга.
- `bridge_daily.gd` (`V10MjBridgeDaily`), `bridge_daily_screen.gd` (`V10MjBridgeDailyScreen`) — анализ сбросов, объяснения Маджонг-тян, веер месяца и экран «Задачи дня».
- `bridge_hand.gd` (`V10MjBridgeHand`), `bridge_levels.gd` (`V10MjBridgeLevels`), `bridge_hand_screen.gd` (`V10MjBridgeHandScreen`) — нежадная автосборка (проверка `completable`), 60 уровней и экран «Собери руку».
- `bridge_screen.gd` (`V10MjBridgeScreen`) — единый маршрутизатор `setup`/`build` + `finished(result)`.
- `bridge_save.gd` (`V10MjBridgeSave`), `bridge_look.gd` (`V10MjBridgeLook`), `bridge_icon.gd` (`V10MjBridgeIcon`), `bridge_presence.gd` (`V10MjBridgePresence`).
- `bridge_demo.tscn`, `bridge_selftest.tscn` (`--mj_bridge_selftest=1`).

## Проверка
```powershell
& $godot --headless --path game res://scripts/v10/mj/bridge/bridge_selftest.tscn -- --mj_bridge_selftest=1
```
