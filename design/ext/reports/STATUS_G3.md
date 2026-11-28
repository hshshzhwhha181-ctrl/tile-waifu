# Статус агента G3 (`tw-data-ci`)

Последнее обновление: 2026-11-28

| Задача | Ветка | Статус | Отчёт | Примечания |
|---|---|---|---|---|
| P93 | `claude/ext-P93` | ✔ готово, запушено | `design/ext/reports/P93.md` | `data/skins.json` (64 скина), `data/shop.json` v2, `tools/design_lint.py` (`51/51 OK`, selftest `9/9 OK`), `tools/test_design_lint.py` (`11/11 OK`); нужна регистрация в `tools/tw_test.py` и `.github/workflows/qa.yml` |
| P96 | `claude/ext-P96` | в очереди (следующая) | — | рендерящий CI (`docker/qa-render/`, `docs/qa/THRESHOLDS.md`, `.github/workflows/qa-render.yml`, патчи для `tw_test.py` в отчёт) |
