# Сад 2.0 (`v10/mj/garden`)

Бесконечный дзен-маджонг волнами с лотком на 6 (перелив 3 фишек домой без поражения), «Ночным столом» и силуэтом Юэ за сукном на рекорде недели (`docs/MODES.md §4.9`, полка «Пасьянсы», ведущая Юэ, врата — ранг Нефрит I).

## Состав модуля
- `garden_info.gd` (`V10MjGardenInfo`) — карточка режима `INFO`, `HOW`, `MORE`, врата Нефрит I.
- `garden_rules.gd` (`V10MjGardenRules`) — безголовые правила волн, лотка 6 с переливом 3 домой, множитель серии ×1…×5, JSON-сохранение стола посреди волны.
- `garden_gen.gd` (`V10MjGardenGen`) — генератор волн (24–40 фишек) с сертификатом старых и новых фишек без перелива.
- `garden_board.gd` (`V10MjGardenBoard`) — стол на `Tile` + `V10MjTileMaterial`, анимации полёта, перелива и прихода волны с очередью ранних тапов (блок ≤ 0,3 с).
- `garden_look.gd` (`V10MjGardenLook`), `garden_icon.gd` (`V10MjGardenIcon`) — токены `V10DS`, дневной и «Ночной стол» (тёплая лампа, дождь).
- `garden_sound.gd` (`V10MjGardenSound`) — ASMR-дерево, дождь/ручей/бамбук, пентатонические колокольчики (ночью музыка выключена).
- `garden_presence.gd` (`V10MjGardenPresence`), `garden_silhouette.gd` (`V10MjGardenSilhouette`) — выход по пояс на волне в пределах полосы и силуэт за полупрозрачным сукном на рекорде недели.
- `garden_save.gd` (`V10MjGardenSave`), `garden_card.gd` (`V10MjGardenCard`), `garden_screen.gd` (`V10MjGardenScreen`).
- `garden_demo.tscn`, `garden_selftest.tscn` (`--mj_garden_selftest=1`).

## Проверка
```powershell
& $godot --headless --path game res://scripts/v10/mj/garden/garden_selftest.tscn -- --mj_garden_selftest=1
```
