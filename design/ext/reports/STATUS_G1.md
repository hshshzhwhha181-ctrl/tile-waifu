# STATUS G1 (`tw-core-audit`)

- **Обновлено:** 2026-11-28 17:30 MSK
- **Статус очереди G1:** **ЗАВЕРШЕНО (3/3)**
  - [x] **Brief A (`claude/ext-a`, `051a7bd`)** — ГОТОВО и запушено: аудит ядра/оболочки, 11 воспроизведённых и исправленных багов (включая `SR-01`/`SR-02` из self-review), `CORE_AUDIT_SELFTEST 35/35 PASS`, `tw_test.py` без регрессий; отчёты `design/ext/REPORT_A.md`, `design/ext/reports/A.md`.
  - [x] **P87 (`claude/ext-P87`, `b400e64`)** — ГОТОВО и запушено: `TWUltRegistry`, `TWUltPolicy`, `TWUltSelftest`, `data/ult_catalogue.json` (+ `game/core/ult/data/ult_catalogue.json`), `HANDOFF_CLAUDE.md` без `662/682`, `TWULT_SELFTEST 137/137`, `ULTS SELFTEST 1096/1096`, `ULT COVERAGE ids=58 covered=58`, `CORE_PURITY +0 new`; отчёт `design/ext/reports/P87.md`.
  - [x] **Self-review (`design/ext/reports/SELF_REVIEW.md`)** — ГОТОВО и запушено: найден и исправлен ряд краевых дефектов (`SR-01..SR-06`), проверены нулевые пересечения файлов и нулевые правки запрещённых путей.
