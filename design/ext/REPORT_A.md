# REPORT_A — Независимый аудит и усиление тестов ядра и оболочки (Brief A)

- **Агент:** G1 (`tw-core-audit`, Gemini 4 Neon)
- **Ветка:** `claude/ext-a` (от `origin/claude/ext-base` `b39a7c1`)
- **Дата:** 2026-11-28
- **Среда прогона:** Windows 11, Godot `4.5.1-stable` (`Godot_v4.5.1-stable_win64_console.exe`), Python 3.12, Node 24
- **Тестовый набор:** `game/tests/core_audit/core_audit_selftest.tscn` (`CORE_AUDIT_SELFTEST 34/34`, воспроизводил `9/34` до фиксов)

---

## 1. Список находок (BLOCKER / MAJOR / MINOR)

### MAJOR (исправлено в отдельных коммитах + покрыто тестами)

| ID | Уровень | Файл | Проблема | Статус / Коммит |
|---|---|---|---|---|
| **A-01** | MAJOR | `game/core/state/tw_migrate.gd:195` | **Нарушение детерминизма ядра (`randi()`):** `TWMigrate._new_profile()` генерировал `profile.id` через глобальный незасидированный `randi()`. Два вызова `TWMigrate.apply(v5_save, {"now": ...})` без коллбэка `ctx.new_profile` давали разные `profile.id` (`ed849128` vs `0f02898d`) и разные `state_hash()`. | **Исправлено** (`d8f1f56`): детерминированный `TWRng` (`ctx.rng` или `TWRng.make(now, 0x70726f66).next_u32()`). Голдены (передающие `ctx.new_profile`) не задеты. |
| **A-02** | MAJOR | `game/core/clock/tw_clock.gd:119-127`, `game/core/meta/save_v8.gd:61-89` | **Вечная заморозка дневного сброса + утечка системного времени:** (1) `TWClock._valid_key()` проверял только цифры `0..9`, пропуская невозможные даты (`9999-99-99`, `2026-13-01`, `2026-02-30`, `2025-02-29`), из-за чего `day_key()` навсегда зависал на `9999-99-99`. (2) `V10Save._latest_key()` допускал мусорные 10-символьные строки (`"zzzzzzzzzz"`, `"9999-99-99"`), т.к. `day_index()` на ошибке парсинга возвращал `0 <= day_index(best)+1` (спамя `ERROR: Invalid month value of: 99`). (3) `V10Save._latest_key()` вызывал `V10Meta.legacy_today()` в обход переданного `now`. | **Исправлено** (`d8f1f56`): строгая календарная проверка `YYYY-MM-DD` с учётом високосных лет в `TWClock._valid_key()`; `V10Save._latest_key(S, now)` использует явный `now` и фильтрует кандидаты через `TWClock._valid_key()`. |
| **A-03** | MAJOR | `game/core/state/tw_save.gd:120,160-171`, `game/core/state/tw_state.gd:165` | **Самоповреждение UTF-8 сейва и перезапись хорошего `.bak` мусором:** (1) `TWSave.write()` сравнивал `text.length()` (число символов) с `MAX_BYTES` вместо `text.to_utf8_buffer().size()` — кириллический JSON длиной 9M символов (~18 МБ > 16 МБ) успешно записывался, а при следующем чтении отклонялся `read_file()` как `toobig`. (2) При ротации `save.json -> save.bak.json` проверялся только синтаксис JSON (`read_file(path).ok`), а не валидность сейва: если `save.json` был испорчен до `{}` (валидный JSON без ключей), первый `flush()` после восстановления из `.bak` затирал хороший `.bak.json` пустым `{}` вместо переноса в `.corrupt.json`. | **Исправлено** (`d8f1f56`): проверка `text.to_utf8_buffer().size() > MAX_BYTES`; опциональный `validate: Callable` в `TWSave.write()`, проброшенный из `TWState.flush()`. |
| **A-04** | MAJOR | `game/core/rules/tw_board.gd:155-165` | **Загрязнение доски при повторной раздаче `TWBoard.deal()`:** метод `deal(cfg)` не обнулял массивы `face0, step0, gold0, ice0, secret0, shard0, kind, arg, mate` перед `_deal()`/`_specials()`. Повторный вызов `deal()` на доске со спецфишками оставлял до 51 «призрачных» флагов (в т.ч. `K_LOCK`/`K_CHAIN` от прошлой партии), ломая чистоту и решаемость. | **Исправлено** (`66e46a3`): полное обнуление массивов раздачи в начале `TWBoard.deal()`. |
| **A-05** | MAJOR | `game/core/rules/tw_board.gd:883-888` | **Потеря события `UNCHAIN` при взрыве бомбы:** `_pair_gone()` вызывал `_blast()` до проверки `arg[t] == pairs_done`. Взрыв рекурсивно увеличивал `pairs_done` на +1..+3, и при возврате во внешний `_pair_gone()` порог `pairs_done`, пройденный самой бомбой, уже проскакивался — событие `UNCHAIN` не выпускалось, хотя фишка становилась `takeable(t) == true` (визуальная цепь зависала на разблокированной фишке). | **Исправлено** (`66e46a3`): проверка и выпуск `UNCHAIN` для текущего `pairs_done` перенесены перед вызовом `_blast()`. |
| **A-06** | MAJOR | `game/shell/nav/tw_screens.gd:224-237,333-345` | **Утечка `_Nav` в `_pending`, стирание `history` при отказе `go_tab()` и утечка модалки из `exit()`:** (1) `go_tab()` создавал `_Nav.new(_pending)` до вызова `go()`, который создавал второй `_Nav` — первый навсегда застревал в `_pending` (20 утечек на 20 переключений вкладок). (2) `go_tab()` делал `history.clear()` до `_precheck()` — отказ по `locked` или `busy` оставлял старый экран, но уничтожал историю. (3) `go()` вызывал `modals.clear_all()` до `_unmount()`, поэтому модалка, открытая в `exit()` уходящего экрана, переживала переход. | **Исправлено** (`ee033e0`): `_Nav` создаётся только в ветках отказа `go_tab()`; сброс истории выполняется внутри `go()` через `opts.clear_history` только после `_precheck()` и `_instantiate()`; `_unmount()` вызывается перед `modals.clear_all()`. |
| **A-07** | MAJOR | `game/shell/nav/modal_stack.gd:124-157` | **Нарушение порядка сигналов при самозакрытии в `_build()`:** `ModalStack.open()` вызывал `modal._opened(opts)` до `opened.emit(modal)` и `changed.emit(...)`. Если `_build()` закрывал модалку синхронно, подписчики получали `["closed:self_close", "opened"]` и уже закрытую модалку как возвращаемое значение. | **Исправлено** (`ee033e0`): `life = OPEN` и сигналы `opened`/`changed` выпускаются до `_opened(opts)`; `open()` возвращает `null`, если модалка закрылась внутри `_build()`; добавлены гарды `is_instance_valid(modal)` перед `queue_free()`. |
| **A-08** | MAJOR | `game/shell/tw_bus.gd:23-168` | **Утечка сигналов `tree_exiting`, поломка multi-subscribe на одного Node-владельца, зомби freed-владельцы и гонка порядка `publish_all()`:** (1) `unsubscribe(tok)` не отключал `owner.tree_exiting`. (2) Повторный `subscribe(..., same_node)` в Godot 4 конфликтует при `connect(unsubscribe.bind(tok))` по базовому callable. (3) В Godot 4 `<Freed Object> != null` ложно, поэтому осиротевшие освобождённые `Node`-владельцы (не входившие в дерево) оставались в `_by_token` после `unsubscribe_owner()` и при доставке. (4) `publish_all([A, B])` на верхнем уровне выполнял вложенные события из обработчика `A` раньше `B` (`["A", "A_FOLLOW", "B"]`), в отличие от вложенного вызова (`["A", "B", "A_FOLLOW"]`). | **Исправлено** (`2488a8a`, `0de8031`): единая подписка `tree_exiting` с счётчиком на `owner_id`, отключаемая при обнулении; проверка освобождённого владельца через `owner_id != 0 and not is_instance_valid(owner)`; `publish_all()` ставит весь пакет в очередь до `_drain()` (строгий FIFO). |

### MINOR (исправлено или зафиксировано без правки вне скоупа)

| ID | Уровень | Файл | Проблема | Статус |
|---|---|---|---|---|
| **A-09** | MINOR | `game/shell/assets/tw_assets.gd:81-92` | `install_manifest()` в комментарии обещал `resolvers are kept`, но вызывал `_register_builtin()`, стирая все кастомные резолверы. | **Исправлено** (`d279409`): кастомные резолверы сохраняются и получают обновлённый `known = _by_path`; `reset()` очищает всё. |
| **A-10** | MINOR | `game/core/clock/tw_clock.gd:48-50` | `TWClock.Fake.advance_ms(ms)` при отрицательном `ms` откатывал монотонный счётчик `msec` назад (`-500`). | **Исправлено** (`d8f1f56`): `maxi(0, ms)`. |
| **A-11** | MINOR | `game/shell/assets/tw_assets.gd:257-258` | `_refuse()` перезаписывает meta `tw_placeholder` на синглтонах `_ph_tex` / `_ph_audio`, затирая диагностическую причину предыдущего отказа. | **Не исправлено** (dev-only диагностика, низкий риск; зафиксировано для справки). |
| **A-12** | MINOR | `tools/tw_test.py:767`, `tools/audio/lufs_gate.py:567`, `tools/qa/build_palette_ramps.py` | **Портативность на Windows (общие файлы не трогались по `PARALLEL.md` №2):** (1) `tw_test.py --clean-import` использует `git diff --name-only -- *.import` без рекурсивного globspec (на Windows возвращает 0 файлов). (2) `lufs_gate.py:567` вызывает Linux-команду `which ffmpeg` вместо `shutil.which("ffmpeg")` (`FileNotFoundError` на Windows). (3) `palette_ramps.json` хэширует `tokens.json` побайтно — на Windows с `core.autocrlf=true` CRLF даёт `PALETTE_RAMPS STALE`. | **Не исправлено** (вне скоупа Brief A / запрет правки `tools/tw_test.py` по `PARALLEL.md`; рекомендовано учесть агенту G3 в P96). |

---

## 2. Property / Fuzz усиление (`game/tests/core_audit/core_audit_selftest.gd`)

1. **`TWBoard` (150 разнообразных засидированных досок × 8 форм × слоты 3..6 × все спецфишки):**
   - `150/150` сертификатов валидны (`verify_certificate() == {}`).
   - `150/150` досок полностью решаются `solver_move()` при включённых взрывах бомб.
   - `150/150` `export_replay() -> play_replay()` дают бит-в-бит совпадающий `state_hash()`.
   - `150/150` `snapshot() -> restore()` дают совпадающий `state_hash()`.
   - `30/30` повторных `deal()` на использованных досках чисты и сертификатно решаемы.
2. **`TWSave` + `TWMigrate` round-trip (150 случайных сейвов `ver = 0..8` с кириллическими никами, звёздами, грязными датами):**
   - `150/150` детерминированно мигрируют к `SAVE_VER = 8` (два запуска → один `state_hash()`).
   - `150/150` идемпотентны (`apply(apply(s)) == apply(s)`).
   - `150/150` проходят полный дисковый цикл `TWState.apply_state -> flush -> reload` с сохранением хэша и валидного календарного `v10_meta.last_key`.

---

## 3. Проверка и отсутствие регрессий

См. подробные команды и последние 15 строк реального вывода в `design/ext/reports/A.md`.
- `CORE_AUDIT_SELFTEST`: **`34/34` PASS** (до фиксов было `9/34`).
- Все 11 целевых сьютов и линтеров (`state`, `twboard`, `twparity`, `twnav`, `twmodal`, `twassets`, `core_purity`, `screen_has_spec`, `modal_only_via_stack`, `asset_id_only`, `ux_lint`): **`11/11` PASS**, 0 регрессий.
- Полный `python tools/tw_test.py --fast -j 2`: все **59/59** Godot-сьютов + `server_e2e` + 5 статических линтеров без единой регрессии (только 3 известных baseline-падения `letters`, `profile2`, `summon`, плюс 2 Windows-env особенности в нетронутых скриптах `qa_tools` / `audio_gate`, описанные в A-12).
