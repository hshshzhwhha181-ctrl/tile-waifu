# STATUS G2 (`tw-battle`)

Обновлено: 2026-11-28

| ID | Ветка | Статус | Краткий итог |
|---|---|---|---|
| P73 | `claude/ext-P73` | **DONE** | `data/battle/balance.json` (+ зеркало), `battle_sim.py` v2 (вариант A + W15), `battle_sim_report.txt` (8/8 gates PASS), правки `BATTLE_ULT_SPEC.md`, SHA `0078a41`. |
| P76 | `claude/ext-P76` | **DONE** | `data/battle/roles.json`, `data/battle/heroes_battle.json` (+ зеркала), 5 ролей, 3+1 ауры, 1+4 отряд, 10 героинь, SHA `9f2929f`. |
| P78 | `claude/ext-P78` | **DONE** | `data/battle/progress.json` (+ зеркало), `TWBattleData`, `TWBattleProgress`, `BATTLE_PROGRESS_SELFTEST 61/61 OK` (AT-B03, AT-B11, W15), SHA `bd93338`. |
| P74 | `claude/ext-P74` | **DONE** | `TWBattleEvents`, `TWBattleMath`, `TWBattle`, `BATTLE_INT_ONLY` в `lint_core_purity.py` (`13/13 PASS`, +0 new), `BATTLE_CORE_SELFTEST 29/29 OK`, SHA `1654194`. |
| P75 | `claude/ext-P75` | **DONE** | `TWBattleBot`, `TWBattleSelftest`, `game/tests/battle/battle_selftest.tscn` → `BATTLE_SELFTEST 18/18 OK` (AT-B07 1.99%, AT-B08 1.76%/2.76%, AT-B09 94.25%/27.52p/46.16%, AT-B16 20/20), `CONTRACT 35/35`, linters PASS. |
| P77 | `claude/ext-P77` | NEXT | `tools/gen_stages.py`, `data/battle/stages.json`, 60 этапов 100% сертификация с `suit_weights`, AT-B10. |
