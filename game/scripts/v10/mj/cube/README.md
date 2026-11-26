# Куб (`v10/mj/cube`)

Вращаемая 3D-фигура из фишек-кубиков с реликвией основательницы в сердцевине (`docs/MODES.md §4.4`, полка «Пасьянсы», ведущая Нова, врата — уровень 40).

## Состав модуля
- `cube_info.gd` (`V10MjCubeInfo`) — карточка режима `INFO`, `HOW`, `RULE`, `STARS_HOW`.
- `cube_shapes.gd` (`V10MjCubeShapes`) — 40 фигур (5 глав × 8 уровней, чётное число клеток ≤ 125, сердцевина под реликвию).
- `cube_rules.gd` (`V10MjCubeRules`) — правило свободы в 3D (две открытые соседние грани на разных осях + прямая видимость по оси), «Мотив ×2», отмена, подсказка, перемешивание.
- `cube_gen.gd` (`V10MjCubeGen`) — обратная укладка с сертификатом `lv.order` и подписью героини `with_signature`.
- `cube_atlas.gd` (`V10MjCubeAtlas`), `cube_tile.gdshader`, `cube_relic.gd` (`V10MjCubeRelic`), `cube_view.gd` (`V10MjCubeView`) — один `MultiMeshInstance3D` без теней в `SubViewport` 720×720, аналитический выбор лучом `pick()`, 5 мешей реликвий.
- `cube_style.gd` (`V10MjCubeStyle`), `cube_icon.gd` (`V10MjCubeIcon`) — токены `V10DS` («Тишина и лак») и монолинейные иконки.
- `cube_sound.gd` (`V10MjCubeSound`) — деревянный шорох вращения, «ток-ток» пары со Шрёдер-реверберацией, кото реликвии (≤ −6 dBFS).
- `ults_cube.gd` (`V10MjCubeUlts`), `cube_presence.gd` (`V10MjCubePresence`), `cube_save.gd` (`V10MjCubeSave`), `cube_screen.gd` (`V10MjCubeScreen`).
- `cube_demo.tscn`, `cube_selftest.tscn` (`--mj_cube_selftest=1`).

## Проверка
```powershell
& $godot --headless --path game res://scripts/v10/mj/cube/cube_selftest.tscn -- --mj_cube_selftest=1
```
