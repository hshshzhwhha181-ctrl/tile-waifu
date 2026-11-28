# STATUS G6 (`tw-tail`)

- **Завершено:**
  - `P26` (`claude/ext-P26`, коммит `e053e21`): soak-тест утечек модалок (`game/shell/tests/modal_soak.gd`, `.tscn`), `MODAL_SOAK_SELFTEST 24/24` (11.08s), 7/7 сьютов `tw_test.py` зелёные. Отчёт: `design/ext/reports/P26.md`.
  - `P106` (`claude/ext-P106`): чистое ядро `game/core/analytics/` (`ANALYTICS_SELFTEST 24/24`, `CORE_PURITY +0`, `UX_LINT 0`), приёмник `server/src/events.mjs` (`4/4` Node tests + `server/e2e_test.mjs` `60/60 E2E_OK`), дашборды `tools/dashboards/` DB-01…DB-10 (`DASHBOARDS_SELFTEST 5/5 PASS`, DB-10 строго обезличен). Отчёт: `design/ext/reports/P106.md`.
- **Следующая задача:**
  - `P92` (`claude/ext-P92`): Аудит/фикс `tools/assets/export_filter.py` (исключение `skins_dl/**`, включение `pack_pub.pub`, проверка ключа подписи + самотест).
