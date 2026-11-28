# STATUS G6 (`tw-tail`)

- **Завершено (вся очередь G6 выполнена):**
  1. `P26` (`claude/ext-P26`, коммит `e053e21`): soak-тест утечек модалок (`game/shell/tests/modal_soak.gd`, `.tscn`), `MODAL_SOAK_SELFTEST 24/24` (11.08s, 61 экран × 10 архетипов модалок, регрессия 0.12.1), 7/7 сьютов `tw_test.py` зелёные. Отчёт: `design/ext/reports/P26.md`.
  2. `P106` (`claude/ext-P106`, коммит `b590aa4`): чистое ядро `game/core/analytics/` (`ANALYTICS_SELFTEST 24/24`, `CORE_PURITY +0`, `UX_LINT 0`), приёмник `server/src/events.mjs` (`4/4` Node tests + `server/e2e_test.mjs` `60/60 E2E_OK`), дашборды `tools/dashboards/` DB-01…DB-10 (`DASHBOARDS_SELFTEST 5/5 PASS`, DB-10 строго обезличен). Отчёт: `design/ext/reports/P106.md`.
  3. `P92` (`claude/ext-P92`): аудит/фикс `tools/assets/export_filter.py` + `tools/assets/test_export_filter.py` (`EXPORT_FILTER SELFTEST 14/14 PASS`, CLI `5/5 OK`, аудит `skins_dl/**`, `shell/skin/pack_pub.pub`, APK/PCK инспектор). Общие файлы `export_presets.cfg`, `tools/tw_test.py`, `.github/workflows/qa.yml` не тронуты; правки вынесены в `design/ext/reports/P92.md` → `## Нужна регистрация`.
- **Ожидание:** все задачи G6 запушены; перехожу в ожидание команд `@coordinator`.
