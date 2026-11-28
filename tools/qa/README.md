# tools/qa — QA tool-belt (см. `design/specs/UNIFIED_QA_PLAN.md`)

| Файл | Что | Запуск |
|---|---|---|
| `palette_audit.py` | аудит палитры PNG/WEBP/JPG: k-means → CIELAB → ΔE2000 до `design/specs/palette_ramps.json`, PASS/WARN/FAIL по профилю, JSON-отчёт, ratchet | `python3 tools/qa/palette_audit.py game/assets --exclude '/incoming/' --json out.json --quiet` |
| `skin_lint.py` | валидация `manifest.json` скина по `design/specs/skin_manifest.schema.json` + таблицам правил (30 кодов `SL-*`) | `python3 tools/qa/skin_lint.py tools/qa/fixtures/skins` (`--check-files`, `--release`) |
| `build_palette_ramps.py` | генерирует `design/specs/palette_ramps.json` из `game/shell/design/tokens.json` + предложенных рамп | `… --check` падает при рассинхроне |
| `build_skin_schema.py` | генерирует схему манифеста и `game/tests/fixtures/skins/ramps_min.json` | `… --check` |
| `make_skin_fixtures.py` | 3 образца манифестов (`valid`, `invalid_hex`, `missing_slot`) + копии для Godot-теста | |
| `colorlib.py` | sRGB/Lab/OKLab, ΔE2000, WCAG-контраст (только numpy) | библиотека |
| `run_qa_tools.py` | однострочный гейт `QA_TOOLS RESULT n/n OK` (его зовут `tw_test.py` и CI) | `python3 tools/qa/run_qa_tools.py` |
| `test_*.py` | unittest: цветовая математика (7 эталонных пар Sharma), палитра, линт, фаззинг | `python3 -m unittest discover -s tools/qa -p 'test_*.py'` |

Зависимости: `skin_lint` — только stdlib; `palette_audit` и тесты палитры — `numpy` + `Pillow` (без них эти тесты пропускаются). Godot-тест `skin_swap_soak` — `game/tests/skin_swap_soak/`, запуск `python3 tools/tw_test.py -s skin_soak`.
