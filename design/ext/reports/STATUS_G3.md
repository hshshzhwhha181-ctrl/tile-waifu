# Статус агента G3 (`tw-data-ci`)

Последнее обновление: 2026-11-28

| Задача | Ветка | Статус | Отчёт | Примечания |
|---|---|---|---|---|
| P93 | `claude/ext-P93` | ✔ готово, запушено | `design/ext/reports/P93.md` | `data/skins.json` (64 скина), `data/shop.json` v2, `tools/design_lint.py` (`51/51 OK`, selftest `9/9 OK`), `tools/test_design_lint.py` (`11/11 OK`); нужна регистрация в `tools/tw_test.py` и `.github/workflows/qa.yml` |
| P96 | `claude/ext-P96` | ✔ готово, запушено | `design/ext/reports/P96.md` | `docker/qa-render/` (xvfb + Mesa llvmpipe + Godot 4.5.1 + fonts), `docs/qa/THRESHOLDS.md` (Date X = `2026-12-12`), `.github/workflows/qa-render.yml`, `tools/qa/check_pending_gate.py` + `8/8` unit tests, `skin_swap_soak` (`2412/2412 OK` в OpenGL3 с `PIXEL_CHECK PASS`, `live_tex=8/8`, `AT-S22`, OKLab; `2407/2407` headless); diff для `tools/tw_test.py` в отчёте |

Очередь G3 полностью выполнена (2/2 задачи).
