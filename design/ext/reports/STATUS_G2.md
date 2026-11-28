# STATUS G2 (`tw-battle`)

Обновлено: 2026-11-28

| ID | Ветка | Статус | Краткий итог |
|---|---|---|---|
| P73 | `claude/ext-P73` | **DONE** | `data/battle/balance.json` (+ зеркало), `battle_sim.py` v2 (вариант A + W15), `battle_sim_report.txt` (8/8 gates PASS), правки `BATTLE_ULT_SPEC.md`, SHA `0078a41`. |
| P76 | `claude/ext-P76` | **DONE** | `data/battle/roles.json`, `data/battle/heroes_battle.json` (+ зеркала), 5 ролей, 3+1 ауры, 1+4 отряд, 10 героинь, SHA `9f2929f`. |
| P78 | `claude/ext-P78` | **DONE** | `data/battle/progress.json` (+ зеркало), `TWBattleData`, `TWBattleProgress`, `game/tests/battle/progress_selftest.tscn` → `BATTLE_PROGRESS_SELFTEST 61/61 OK` (AT-B03, AT-B11 100k, W15 catch-up, flags true/false), `CONTRACT_SELFTEST 35/35`, linters PASS. |
| P74 | `claude/ext-P74` | NEXT | `game/core/modes/battle/` (`TWBattle`, `TWBattleMath`, события, integer bp, `ULT_AIM`) + правило `CORE_PURITY` в `tools/lint_core_purity.py`. |
| P75 | `claude/ext-P75` | PENDING | `battle_bot.gd`, `battle_selftest.gd`, сцены в `game/tests/battle/`, AT-B07..B09. |
| P77 | `claude/ext-P77` | PENDING | `tools/gen_stages.py`, `data/battle/stages.json`, 60 этапов 100% сертификация с `suit_weights`, AT-B10. |
