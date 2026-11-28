# SELF_REVIEW — Независимый ревью-проход агента G1 (`tw-core-audit`)

- **Агент:** G1 (`tw-core-audit`)
- **Проверенные ветки:**
  - `claude/ext-a` (финальный коммит `051a7bd`, от `origin/claude/ext-base` `b39a7c1`)
  - `claude/ext-P87` (финальный коммит кода `b400e64`, от `origin/claude/ext-base` `b39a7c1`)
- **Дата:** 2026-11-28

---

## 1. Проверка соблюдения жёстких правил (`MASTER_PROMPT.md §2`, `PARALLEL.md`)

| Проверка | Статус | Подтверждение |
|---|---|---|
| Изолированный worktree (`../tw-core-audit`), основной клон не затронут | **✔** | `git -C tile-waifu branch --show-current` → `claude/ext-base`, `git status --short` пуст. |
| Запрещённые и общие файлы не тронуты (`tools/tw_test.py`, `project.godot`, `export_presets.cfg`, `game/assets/`, `game/shell/screens/`, `STATUS.md`, пути G2–G6) | **✔** | Автопроверка всех изменённых путей обеих веток → `FORBIDDEN_TOUCHED: NONE (0)`. |
| Пересечение файлов между `claude/ext-a` и `claude/ext-P87` | **✔** | Единственный общий файл — `design/ext/reports/STATUS_G1.md` (собственный статус G1); 0 пересечений по коду и данным. |
| Чистота ядра `game/core/**` (`CORE_PURITY`) | **✔** | `PASS (565 violations, baseline 565, +0 new)` на обеих ветках. |
| Рэтчеты и статлинтеры (`ux_lint`, `asset_id_only`, `screen_has_spec`, `modal_only_via_stack`, `no_direct_levels`) | **✔** | 100% PASS, 0 нарушений, 0 новых литералов `res://assets`. |
| Нет PR, merge в `claude/integration`, force-push, правок `gh-pages` | **✔** | Только обычные `git push` в `origin/claude/ext-a` и `origin/claude/ext-P87`. |

---

## 2. Находки независимого ревью-прохода и исправления

В ходе построчного аудита `git diff origin/claude/ext-base..claude/ext-a` и `git diff origin/claude/ext-base..claude/ext-P87` найдены **6 реальных проблем/краевых рисков**, все исправлены, покрыты воспроизводящими тестами и запушены в соответствующие ветки:

| ID | Ветка | Файл | Суть находки | Исправление и тест |
|---|---|---|---|---|
| **SR-01** | `claude/ext-a` | `game/core/meta/save_v8.gd` | В `_latest_key()` индекс `best_idx` обновлялся внутри цикла кандидатов. Цепочка из 4 ступенчатых дат (`today+1`, `+2`, `+3`, `+4` в `daily_day`/`tasks.day`/`pet.day`/`login.last`) могла протолкнуть `v10_meta.last_key` на **4 дня вперёд**, нарушая инвариант «никогда дальше завтра». | Зафиксирована константа `max_idx = V10Meta.day_index(best) + 1` до цикла; добавлен тест `A-02d` в `core_audit_selftest.gd` (коммит `051a7bd`). |
| **SR-02** | `claude/ext-a` | `game/shell/tw_bus.gd` | В `subscribe()` проверка `owner != null` перед `owner.get_instance_id()` заменена на идиоматичную для Godot 4 `is_instance_valid(owner)`. | Правка в `subscribe()` (коммит `051a7bd`). |
| **SR-03** | `claude/ext-P87` | `game/core/ult/ult_registry.gd` | `entry(id)`, `legacy_entry(id)`, `catalogue()`, `tiers()` возвращали живые ссылки на внутренние мутабельные словари из `JSON.parse_string()`: случайная мутация вызывающим кодом (например, `u.vfx.append(...)`) портила глобальный реестр для всей игры. | Возврат `.duplicate(true)` в `entry()`, `legacy_entry()`, `catalogue()`, `tiers()` и копия входного `doc` в `install_catalogue()`; добавлен тест иммутабельности в `TWUltSelftest` (коммит `b400e64`). |
| **SR-04** | `claude/ext-P87` | `game/core/ult/ult_registry.gd` | `install_catalogue()` молча добавлял дублирующийся `id` в `_order` и перезаписывал `_by_id[uid]`; `schema_errors()` пропускал отрицательные `atk_pct_star0`/`atk_pct_per_star`. | Введён `_duplicate_ids` (пробрасывается в `coverage_report().duplicate_ids`), дубли не добавляются в `_order`, отрицательные `atk_pct` отклоняются; добавлен негативный тест в `TWUltSelftest` (коммит `b400e64`). |
| **SR-05** | `claude/ext-P87` | `game/core/ult/ult_policy.gd` | При передаче `NAN` в `last_full_age_s` ветки `first_per_fight` (`NAN >= 0.0 == false` → `"full"`) и `favorite` (`NAN >= 20.0 == false` → `"assist"`) вели себя противоречиво. | Нормализация `if is_nan(last_full_age_s): last_full_age_s = 0.0` (консервативный кулдаун `"assist"` в обоих режимах); добавлен тест в `TWUltSelftest` (коммит `b400e64`). |
| **SR-06** | `claude/ext-P87` | `game/core/ult/ult_registry.gd` | `ensure_save(S)` не удалял пустые/нестроковые ключи из `S.ult_seen` (например, `""`), хотя `record_seen`/`seen_count` их игнорируют. | Добавлена очистка нестроковых и пустых ключей в `ensure_save(S)`; расширен тест `AT-U12` в `TWUltSelftest` (коммит `b400e64`). |

*(Примечание: также во время реализации P87 была поймана и закрыта тонкая ловушка Godot 4 — вызов `TWUltRegistry.reload()` перехватывается движком как встроенный `Script.reload(false)` и стирает все `static var`, включая `_legacy_sources`; метод переименован в `reload_catalogue()` с регрессионным тестом сохранения `_legacy_sources`.)*

---

## 3. Команды перепроверки после исправлений и последние 15 строк вывода

### 3.1 `claude/ext-a` (`051a7bd`)
```powershell
& $env:GODOT_BIN --headless --audio-driver Dummy --path game res://tests/core_audit/core_audit_selftest.tscn
python tools/tw_test.py -s state,meta,twnav,twmodal,twboard,twassets,core_purity,ux_lint,asset_id_only -j 2 --fast
```
Последние 15 строк вывода:
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

### 3.2 `claude/ext-P87` (`b400e64`)
```powershell
& $env:GODOT_BIN --headless --audio-driver Dummy --path game res://tests/ult/ult_selftest.tscn
python tools/tw_test.py -s ults,ult_rin,wave1,state,core_purity,ux_lint,asset_id_only -j 2 --fast
```
Последние 15 строк вывода:
```text
ULT COVERAGE ids=58 covered=58
TWULT_SELFTEST 137/137
suite        status   ok/total       secs  verdict     marker / reason
--------------------------------------------------------------------------------------------------------------
ults         pass     1096/1096      13.7  improved    ULTS SELFTEST 1096/1096
ult_rin      pass     22/22          19.0  ok          ULT SELFTEST rin 22/22
wave1        pass     221/221         7.3  ok          WAVE1_SELFTEST 221/221
state        pass     182/182        37.4  ok          STATE_SELFTEST 182/182
core_purity  pass     6/6             0.6  ok          CORE_PURITY RESULT: PASS (565 violations, baseline 565, +0 new)
ux_lint      pass     -               2.3  ok          UX_LINT RESULT: OK (0 violations)
asset_id_only pass     13/13           1.0  ok          ASSET_ID_ONLY SELFTEST 13/13 PASS

[tw_test] 7/7 pass, 0 skipped, known-fail none, improved ['ults'], wall 51s (j=2); logs: C:\Users\ADMIN\AppData\Local\Temp\tw_test_logs
[tw_test] no regression vs baseline
SR87_RC=0
```

---

## 4. Итоговый вердикт G1

- **Готово к приёмке Claude:** обе ветки (`claude/ext-a`, `claude/ext-P87`) чистые, независимые, без конфликтов друг с другом и с ветками G2–G6, все критерии подтверждены реальными прогонами Godot 4.5.1.
- **Остающиеся на стороне интегратора (Claude) действия:** см. разделы `## Нужна регистрация` в `design/ext/reports/A.md` и `design/ext/reports/P87.md` (строки `CATALOG` в `tools/tw_test.py`, `ULT COVERAGE` в `verify_selftests.sh`, вызов `TWUltRegistry.register_legacy_source("wave1", ...)` при старте оболочки и `TWUltRegistry.ensure_save(S)` в `TWMigrate`/модуле `battle`).
- **Что не проверялось:** запуск `qa_tools` и `audio_gate` в Linux-окружении (на Windows-хосте они падают из-за CRLF в `tokens.json` и вызова Unix-команды `which ffmpeg`).
