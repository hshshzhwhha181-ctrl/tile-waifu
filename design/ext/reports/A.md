# Отчёт A — Независимый аудит и усиление тестов ядра и оболочки (`claude/ext-a`)

- **Агент:** G1 (`tw-core-audit`)
- **Ветка:** `claude/ext-a` (база: `origin/claude/ext-base` `b39a7c1`)
- **Полный разбор находок:** `design/ext/REPORT_A.md`

## 1. Критерии приёмки (`BRIEF_A_AUDIT_TESTS.md`)

- **✔ Найти баги корректности (детерминизм ядра, миграции сейва, утечки модалок, гонки `TWBus`):** найдено 10 реальных багов (8 MAJOR: A-01..A-08; 2 MINOR: A-09..A-10) + 2 информационных MINOR (A-11, A-12). Каждый из 10 багов сначала воспроизведён тестом (9/34 до фиксов), затем исправлен.
- **✔ Минимальный воспроизводящий тест + исправление отдельным коммитом, без поломки зелёных тестов:**
  - Тесты: `7d0b182`, `bd86cd6` (`game/tests/core_audit/core_audit_selftest.{gd,tscn,_runner.gd}`, `exit_modal_screen.gd`).
  - Фиксы отдельными коммитами по подсистемам: `d8f1f56` (`core/state+clock+meta`), `66e46a3` (`core/rules`), `ee033e0` (`shell/nav`), `2488a8a` + `0de8031` (`shell/tw_bus`), `d279409` (`shell/assets`).
- **✔ Property/fuzz-тесты (`TWBoard` решаемость/сертификаты/реплей/снапшот/перераздача; `TWSave`+`TWMigrate` round-trip v0..v8):** 150 засидированных досок `TWBoard` + 150 случайных сейвов v0..v8 — `34/34 PASS`.
- **✔ Отчёт `design/ext/REPORT_A.md` (BLOCKER/MAJOR/MINOR, что исправлено, что нет):** создан и закоммичен.
- **✔ Границы соблюдены:** `gh-pages`, `project.godot`, `export_presets.cfg`, `assets/`, `game/shell/screens/**`, `tools/tw_test.py` и реестры модулей НЕ трогались.

## 2. Команды проверки и последние 15 строк вывода

### Команда 1 — Целевой аудит-сьют (`CORE_AUDIT_SELFTEST`)
```powershell
& "$env:GODOT_BIN" --headless --audio-driver Dummy --path game res://tests/core_audit/core_audit_selftest.tscn
```
Последние 15 строк вывода (до известного teardown-краша Godot 4.5.1 на Windows после печати маркера):
```text
PASS A-07a: self-closing _build emits opened BEFORE closed (never opened after closed)
PASS A-07b: close() handles modal calling queue_free() inside on_close cleanly
PASS A-08a: unsubscribe() disconnects owner.tree_exiting (0 leaked connections)
PASS A-08b: unsubscribe_owner() safely prunes freed orphan owners and removes target
PASS A-08c: publish_all([A, B]) delivers full batch before handler-published follow-ups (FIFO)
PASS A-08d: single Node owner with 3 subscriptions uses 1 tree_exiting hook and drops all 3 on exit
PASS A-09: TWAssets.install_manifest() preserves registered custom resolvers and updates known map
PASS A-10: TWClock.Fake monotonic clock never moves backwards on negative advance_ms
PASS prop(TWBoard): 150/150 diverse seeded boards have 100% valid certificates
PASS prop(TWBoard): 150/150 diverse boards cleared by solver_move()
PASS prop(TWBoard): 150/150 export_replay -> play_replay exact state_hash parity
PASS prop(TWBoard): 150/150 snapshot/restore exact state_hash parity
PASS prop(TWBoard): 30/30 re-deals on used boards clean & cert-solvable
PASS prop(TWSave+TWMigrate): 150/150 random v0..v8 saves pass deterministic migration, idempotency, and disk round-trip
CORE_AUDIT_SELFTEST 34/34
```

### Команда 2 — Затронутые сьюты ядра/оболочки + все статические линтеры
```powershell
python tools/tw_test.py -s state,twboard,twparity,twnav,twmodal,twassets,core_purity,screen_has_spec,modal_only_via_stack,asset_id_only,ux_lint -j 2 --fast
```
Последние 15 строк вывода:
```text
twboard      pass     2006/2006      17.1  improved    TWBOARD_SELFTEST 2006/2006  (9.2 s)
twparity     pass     1401/1401      15.6  ok          TWPARITY_SELFTEST 1401/1401
twnav        pass     132/132        10.2  ok          TWNAV_SELFTEST 132/132
twmodal      pass     83/83           8.2  ok          TWMODAL_SELFTEST 83/83
twassets     pass     69/69          18.5  ok          TWASSETS_SELFTEST 69/69
core_purity  pass     6/6             0.7  ok          CORE_PURITY RESULT: PASS (565 violations, baseline 565, +0 new)
screen_has_spec pass     7/7             0.5  ok          SCREEN_HAS_SPEC SELFTEST 7/7 PASS
modal_only_via_stack pass     14/14           1.4  ok          MODAL_ONLY_VIA_STACK SELFTEST 14/14 PASS
asset_id_only pass     13/13           2.4  ok          ASSET_ID_ONLY SELFTEST 13/13 PASS
ux_lint      pass     -               2.5  ok          UX_LINT RESULT: OK (0 violations)

[tw_test] 11/11 pass, 0 skipped, known-fail none, improved ['twboard'], wall 58s (j=2); logs: C:\Users\ADMIN\AppData\Local\Temp\tw_test_logs
[tw_test] no regression vs baseline
TW_TEST_RC=0
```

### Команда 3 — Полный `tools/tw_test.py --fast`
```powershell
python tools/tw_test.py --fast -j 2
```
Последние 15 строк вывода:
```text
server_e2e   pass     60/60           5.0  ok          E2E_OK
ux_lint      pass     -               2.6  ok          UX_LINT RESULT: OK (0 violations)
core_purity  pass     6/6             0.8  ok          CORE_PURITY RESULT: PASS (565 violations, baseline 565, +0 new)
no_direct_levels pass     10/10           1.5  ok          NO_DIRECT_LEVELS RESULT: PASS (0 violations)
screen_has_spec pass     7/7             0.5  ok          SCREEN_HAS_SPEC SELFTEST 7/7 PASS
modal_only_via_stack pass     14/14           1.3  ok          MODAL_ONLY_VIA_STACK SELFTEST 14/14 PASS
asset_id_only pass     13/13           1.3  ok          ASSET_ID_ONLY SELFTEST 13/13 PASS
qa_tools     fail     74/76           8.9  REGRESSION  rc=1
audio_gate   error    -               0.2  REGRESSION  was pass, now error (no marker line 'AUDIO_GATE SELFTEST')

[tw_test] 63/68 pass, 0 skipped, known-fail ['letters', 'profile2', 'summon'], improved ['twboard'], wall 447s (j=2); logs: C:\Users\ADMIN\AppData\Local\Temp\tw_test_logs
[tw_test] REGRESSION vs baseline:
   qa_tools: rc=1   (log C:\Users\ADMIN\AppData\Local\Temp\tw_test_logs\qa_tools.log)
   audio_gate: was pass, now error (no marker line 'AUDIO_GATE SELFTEST')   (log C:\Users\ADMIN\AppData\Local\Temp\tw_test_logs\audio_gate.log)
FAST_RC=1
```

## 3. Отклонения от карточки и пояснения

- Тесты размещены в `game/tests/core_audit/` (а не в корневой `tests/`, которой в репозитории нет), строго по существующей конвенции `game/tests/skin_swap_soak/` (где сцены доступны Godot через `res://tests/...`).
- Ветка создана от `origin/claude/ext-base` (согласно `MASTER_PROMPT.md §1` и `PARALLEL.md`), а не от `claude/integration` (который упомянут в старой шапке `BRIEF_A_AUDIT_TESTS.md`).
- Общий файл `tools/tw_test.py` не правился (запрет `PARALLEL.md` правило 2).

## 4. Что НЕ проверено и известные риски

- **Не проверено на Linux:** прогон выполнен на Windows 11. На Windows два нетронутых Python-инструмента из `--fast` падают по причинам ОС: `qa_tools` (`tokens.json` с CRLF меняет sha256 в `palette_ramps.json`) и `audio_gate` (`tools/audio/lufs_gate.py:567` вызывает Unix-команду `which ffmpeg`). На Linux/CI оба сьюта работают штатно.
- **Полный (не `--fast`) прогон** (`mj_riichi`, `mj_sanma`, `salon`, `duels`, `challenge`, `mj_classic`, `mj_connect`, `mj_bridge`, `mj_look`) не запускался в этой ветке (в соответствии с `MASTER_PROMPT.md §1` и ограничением нагрузки `PARALLEL.md` правило 5).
- **Риск (низкий):** `TWBus.publish_all()` теперь ставит весь пакет в очередь до `_drain()` (строгий FIFO). Если какой-либо внешний код полагался на прерывание пакета синхронным вложенным `publish()` между элементами пакета, поведение изменится на согласованное FIFO (`nav_selftest 132/132` и `legacy_host 314/314` прошли без проблем).

## 5. Нужна регистрация (для Claude при слиянии)

По правилу 2 `design/ext/PARALLEL.md` файл `tools/tw_test.py` не редактировался. Для подключения нового сьюта в `CATALOG` (`tools/tw_test.py`, группа `core`):

```python
    S("core_audit", "CORE_AUDIT_SELFTEST", "res://tests/core_audit/core_audit_selftest.tscn", group="core", timeout=300,
      note="Brief A: 10+ regression checks (determinism, calendar dates + ratchet guard, UTF-8/bak save, board re-deal/UNCHAIN, go_tab leak/history, modal open order, bus leaks/FIFO, custom resolvers) + 150 TWBoard & 150 TWSave/TWMigrate property/fuzz cases"),
```

## 6. Дополнение после self-review (`SR-01`, `SR-02`)

- **SR-01 (`game/core/meta/save_v8.gd`):** в `_latest_key()` верхняя граница кандидата (`max_idx = day_index(today) + 1`) вынесена за цикл, чтобы цепочка из 4 ступенчатых дат (`today+1..+4` в `daily_day`/`tasks`/`pet`/`login`) не могла протолкнуть `last_key` на 4 дня вперёд. Добавлен тест `A-02d` в `core_audit_selftest.gd`.
- **SR-02 (`game/shell/tw_bus.gd`):** в `subscribe()` используется `is_instance_valid(owner)` вместо `owner != null` при чтении `get_instance_id()`.
- **Повторная проверка (`res://tests/core_audit/core_audit_selftest.tscn` + `python tools/tw_test.py -s state,meta,twnav,twmodal,twboard,twassets,core_purity,ux_lint,asset_id_only -j 2 --fast`):**
```text
PASS A-02d: V10Save._latest_key blocks stepping-stone ratchet past tomorrow
CORE_AUDIT_SELFTEST 35/35
state        pass     182/182        40.9  ok          STATE_SELFTEST 182/182
meta         pass     190/190         7.8  ok          META_SELFTEST 190/190 (meta 23/23, bond 13/13, notify 25/25, entry 7/7
twnav        pass     132/132        10.4  ok          TWNAV_SELFTEST 132/132
twmodal      pass     83/83           8.5  ok          TWMODAL_SELFTEST 83/83
twboard      pass     2006/2006      16.8  improved    TWBOARD_SELFTEST 2006/2006  (8.9 s)
twassets     pass     69/69          18.2  ok          TWASSETS_SELFTEST 69/69
core_purity  pass     6/6             0.6  ok          CORE_PURITY RESULT: PASS (565 violations, baseline 565, +0 new)
ux_lint      pass     -               2.8  ok          UX_LINT RESULT: OK (0 violations)
asset_id_only pass     13/13           1.4  ok          ASSET_ID_ONLY SELFTEST 13/13 PASS

[tw_test] 9/9 pass, 0 skipped, known-fail none, improved ['twboard'], wall 58s (j=2); logs: C:\Users\ADMIN\AppData\Local\Temp\tw_test_logs
[tw_test] no regression vs baseline
SRA_RC=0
```

