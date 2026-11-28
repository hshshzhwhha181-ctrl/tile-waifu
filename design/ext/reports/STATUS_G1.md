# STATUS G1 (`tw-core-audit`)

- **Обновлено:** 2026-11-28 17:20 MSK
- **Текущий прогресс:**
  - [x] **Brief A (`claude/ext-a`)** — ГОТОВО и запушено (`71c1712`): аудит ядра/оболочки, 10 воспроизведённых и исправленных багов, `CORE_AUDIT_SELFTEST 34/34 PASS`, 11/11 целевых сьютов + все Godot-сьюты `--fast` без регрессий; отчёты `design/ext/REPORT_A.md` и `design/ext/reports/A.md`.
  - [x] **P87 (`claude/ext-P87`)** — ГОТОВО (`TWUltRegistry`, `TWUltPolicy`, `TWUltSelftest`, `data/ult_catalogue.json`, `HANDOFF_CLAUDE.md`): `TWULT_SELFTEST 134/134`, `ULTS SELFTEST 1093/1093`, `ULT COVERAGE ids=58 covered=58`, `CORE_PURITY +0 new`, `HANDOFF_CLAUDE.md` без `662/682`, полный `--fast` 63/68 без регрессий Godot/линтеров; отчёт `design/ext/reports/P87.md`.
  - [ ] **Self-review (`design/ext/reports/SELF_REVIEW.md`)** — следующий шаг: независимый ревью-проход по обеим веткам (`claude/ext-a` и `claude/ext-P87`).
