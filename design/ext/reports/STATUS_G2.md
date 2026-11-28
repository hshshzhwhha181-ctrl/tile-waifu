# STATUS G2 (`tw-battle`)

Обновлено: 2026-11-28

| ID | Ветка | Статус | Краткий итог |
|---|---|---|---|
| P73 | `claude/ext-P73` | **DONE** | `data/battle/balance.json` (+ зеркало), `battle_sim.py` v2 (вариант A + W15), `battle_sim_report.txt` (8/8 gates PASS), правки `BATTLE_ULT_SPEC.md`, SHA `0078a41`. |
| P76 | `claude/ext-P76` | **DONE** | `data/battle/roles.json`, `data/battle/heroes_battle.json` (+ зеркала в `game/core/modes/battle/data/`): 5 ролей, 3+1 ауры, 1+4 отряд, 10 героинь, 100% сверка с `balance.json` и `ult_catalogue.json`. |
| P78 | `claude/ext-P78` | NEXT | `game/core/modes/battle/progress.gd`, `data/battle/progress.json`, сцена/тест в `game/tests/battle/`, AT-B03/B11, флаги `outfit_stats_enabled`/`bond_stats_enabled` true/false. |
| P74 | `claude/ext-P74` | PENDING | `game/core/modes/battle/` (`TWBattle`, `TWBattleMath`, события, integer bp, `ULT_AIM`) + правило `CORE_PURITY` в `tools/lint_core_purity.py`. |
| P75 | `claude/ext-P75` | PENDING | `battle_bot.gd`, `battle_selftest.gd`, сцены в `game/tests/battle/`, AT-B07..B09. |
| P77 | `claude/ext-P77` | PENDING | `tools/gen_stages.py`, `data/battle/stages.json`, 60 этапов 100% сертификация с `suit_weights`, AT-B10. |
