# STATUS G6 (`tw-tail`)

- **Завершено:**
  - `P26` (`claude/ext-P26`): soak-тест утечек модалок (`game/shell/tests/modal_soak.gd`, `game/shell/tests/modal_soak.tscn`), `MODAL_SOAK_SELFTEST 24/24` (11.08s, 61 экран × 10 архетипов модалок, регрессия 0.12.1, Android back, watchdog, 2400 random ops, 0 leaked nodes), 7/7 релевантных сьютов `tw_test.py` зелёные. Отчёт: `design/ext/reports/P26.md`.
- **Следующая задача:**
  - `P106` (`claude/ext-P106`): Аналитика и дашборды (`game/core/analytics/`, `game/tests/analytics/`, `server/src/events.mjs`, `tools/dashboards/`).
- **В очереди далее:**
  - `P92` (`claude/ext-P92`): Аудит/фикс `tools/assets/export_filter.py`.
