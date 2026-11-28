# FIX ROUND 1 — Отчёт `legal-age` (G4: P22 + P108)

- **Ветка:** `claude/ext-fix-legal-age` (от `origin/claude/integration`)
- **Агент:** `fix-g4-legal` (роль G4 Legal & Age Gate fixer)
- **Объём:** Закрыты **все 7 Confirmed MAJOR** и **все 7 MINOR** замечаний из `design/ext/FIX_ROUND1.md` (`## legal-age`); замечания `Refuted by second reviewer` не трогались.
- **Границы реестров:** `tools/tw_test.py`, `game/project.godot`, `game/export_presets.cfg`, `game/assets/`, `.github/workflows/qa.yml`, `design/ext/reports/STATUS.md`, `gh-pages` **не изменялись**. `TWState.SAVE_VER` остался `8`.

---

## 1. Сводка исправлений (7 MAJOR + 7 MINOR)

### Confirmed MAJOR (7/7 закрыты)

| # | Замечание | Исправление | Файлы |
|---|---|---|---|
| **M1** | `TWAge.revoke_age()` сбрасывал `BLOCKED_MINOR` и обходил 30-суточную блокировку; `clear_minor_block_by_support()` был неаутентифицированным публичным методом | `revoke_age()` отказывает (`DENY_MINOR_LOCKED`) при активной блокировке `is_minor_blocked()` и не трогает `blocked_until`; `submit_dob()` дополнительно проверяет `blocked_until > now` вне зависимости от `state`. `clear_minor_block_by_support(ticket_id, support_token)` работает fail-closed (`DENY_SUPPORT_UNCONFIGURED` / `DENY_SUPPORT_AUTH`) без настроенного `set_support_verifier(Callable)` и валидного токена. | `game/core/age/tw_age.gd` |
| **M2** | `TWSpendLimit.check_purchase()` по умолчанию имел `age=null, consent=null, required_offer_ver=""` и пропускал проверки | `check_purchase()` переведён в режим **fail-closed**: при `age == null` возвращает `DENY_AGE`, при `consent == null` или пустом `required_offer_ver` возвращает `DENY_CONSENT`, при `real_payments_enabled == false` возвращает `DENY_PAYMENTS_DISABLED`. | `game/core/age/tw_spend_limit.gd` |
| **M3** | Два несовместимых журнала согласий: `TWConsent` (`tw_consents`, `pdn`/`age_18`) vs `TWLegalConsent` (`legal_consents`, `pdn_consent`/`age_18_full_tier`) | Унифицировано в **единый журнал** на базе `TWConsent` (`STATE_KEY = "tw_consents"`): `TWLegalConsent` стал тонким shell-адаптером над `TWConsent` с общим `STATE_KEY`, единой нормализацией `TWConsent.normalize_kind()` (`pdn_consent -> pdn`, `age_18_full_tier -> age_18`), поддержкой `doc_hash` и односторонней миграцией старых записей `legal_consents` при сохранении `SAVE_VER = 8`. | `game/core/age/tw_consent.gd`, `game/shell/screens/legal/legal_consent.gd` |
| **M4** | Одна кнопка «Принять оферту» пакетом записывала ПДн + 18+ + `analytics=false` без открытия документов и без проверки `TWAge` | В `TWLegalScreen` и `TWLegalConsent` разделены явные акты согласия (152-ФЗ): (1) «Оферта и Политика» (`accept_offer_and_privacy`, требует открытия обоих документов, не включает ПДн и 18+), (2) отдельное «Согласие на ПДн» (`accept_pdn_consent`, требует открытия `pdn_consent`), (3) «Подтвердить 18+» (`accept_age_18`, требует открытия `age_18_full_tier` **и** подтверждённого взрослого `TWAge.is_adult()`), (4) отдельный переключатель аналитики (`set_analytics_consent`, без ложного `pdn_consent` хэша). Старый `accept_current_bundle` / `record_required_bundle` работает fail-closed без явных раздельных подтверждений и `TWAge`. | `game/shell/screens/legal/legal_screen.gd`, `game/shell/screens/legal/legal_consent.gd`, `game/core/age/tw_consent.gd` |
| **M5** | `data/legal/` вне `game/` и `.md` не попадают в экспорт `export_presets.cfg` | Создан `tools/sync_legal_bundle.py` (с `--check`), зеркалирующий `data/legal/manifest.json` и собирающий `game/data/legal/legal_bundle.json` (валидный RFC 8259 JSON с `\u0025`/`\u20bd`, полностью совместимый с `V10ContractSelftest` и автоматически экспортируемый Godot под `export_filter="all_resources"` без правки `export_presets.cfg`). `TWLegalData` разрешает `res://data/legal` первым и читает тексты из `legal_bundle.json` с проверкой SHA-256. | `tools/sync_legal_bundle.py`, `game/data/legal/manifest.json`, `game/data/legal/legal_bundle.json`, `game/shell/screens/legal/legal_data.gd` |
| **M6** | Противоречие между UI `age_gate.gd` («Год остаётся только на этом телефоне», «откровенные наряды») и шаблонами (полная дата / серверный хэш) | В `game/scripts/v10/shop/age_gate.gd:66` убраны противоречивые формулировки и добавлена ссылка на Политику конфиденциальности. В `01_offer.md`, `02_privacy.md`, `03_pdn_consent.md`, `12_age_18_full_tier.md` честно и согласованно описано: полная дата не сохраняется; в текущей клиентской сборке статус и 30-суточная блокировка хранятся локально, а серверная/хэш-синхронизация подключается до `real_payments_enabled = true`; временная зона журнала согласий приведена к МСК (UTC+3). | `game/scripts/v10/shop/age_gate.gd`, `data/legal/01_offer.md`, `02_privacy.md`, `03_pdn_consent.md`, `12_age_18_full_tier.md` |
| **M7** | `PullHistory.prune()` использовал сырой `clock.now()` (перевод часов вперёд стирает историю) и `record_pull()` принимал `ts` от вызывающего | `PullHistory` использует `clock.safe_now()` и сверяет дельту настенного времени с `clock.mono_msec()`: при откате часов назад (`not clock.clock_ok()`) или скачке вперёд (`> CLOCK_TOL`) `prune()` отказывается удалять записи (возвращает `0`), а `record_pull()` полностью игнорирует переданный вызывающим ключ `"ts"` и проставляет доверенное монотонное время. | `game/core/gacha/pull_history.gd` |

### MINOR (7/7 закрыты)

| # | Замечание | Исправление | Файлы |
|---|---|---|---|
| **m1** | Лимит 512 записей выбрасывал первичные согласия и повторял `seq=513` | Добавлен персистентный монотонный счётчик `next_seq` (строго уникальные `seq` после 512). Ротация `_rotate_to_cap()` никогда не удаляет первичные (founding) согласия по обязательным видам и последнюю запись каждого вида — вытесняются только старые перекрытые записи (например, переключения аналитики). | `game/core/age/tw_consent.gd` |
| **m2** | `record_purchase` не имел идемпотентности по `order_id`, а `pop_front` ломался на неотсортированных `t` | `record_purchase` отклоняет пустой `order_id` (`DENY_ORDER_ID`), при повторном `order_id` возвращает `{"ok": true, "code": "DUPLICATE", "duplicate": true}` без повторного суммирования и без ложной аварийной паузы. Очистка старше 366 дней переписана на фильтрацию по всем элементам (устойчива к любому порядку `t`); все расчёты переведены на `clock.safe_now()`. | `game/core/age/tw_spend_limit.gd` |
| **m3** | `PullHistory.record_pull` дописывал вымышленные `150 gems` / `gift` при пропущенных полях | Убраны вымышленные дефолты (`cost_cur = ""`, `cost_amt = 0`, `rarity = ""`, `family = ""`); в `export_text()` при отсутствии цены выводится `—`. | `game/core/gacha/pull_history.gd` |
| **m4** | Разные форматы экспорта UTC vs МСК и возможность подделать `ts` переводом часов назад | Единый экспорт через `TWConsent.export_text()` в формате `YYYY-MM-DD HH:MM МСК`; `ts = maxi(clock.safe_now(), box["last_ts"])` запрещает запись задним числом в обоих адаптерах. | `game/core/age/tw_consent.gd`, `game/shell/screens/legal/legal_consent.gd` |
| **m5** | `validate_bundle()` не вызывался в runtime; отсутствовала проверка `..` в поле `file` | Добавлена строгая проверка `TWLegalData.is_safe_rel_filename()` (запрещает `..`, `/`, `\`, `:`, ведущую точку) в `read_doc_text()` и `validate_bundle()`. `load_bundle()` и `TWLegalScreen.enter()` запускают `validate_bundle()`; при невалидном/подменённом пакете `TWLegalScreen` блокирует отображение документов и запись согласий. | `game/shell/screens/legal/legal_data.gd`, `game/shell/screens/legal/legal_screen.gd` |
| **m6** | Нерезервный домен `example.ru`, неподтверждённое утверждение о самозанятых в RuStore, нечитаемый `real_payments_enabled` и отсутствие блокировки незаполненных `[ЗАПОЛНИТЬ` | Все адреса `*@example.ru` заменены на RFC 2606 резервный `.invalid` (`*@tilewaifu.invalid`). В `11_seller_details.md` утверждение о самозанятых в RuStore помечено `[ЮР: уточнить актуальные правила RuStore по допустимости самозанятых для монетизации]`. В `TWLegalData` добавлены `real_payments_enabled()`, `has_unfilled_placeholders()`, `can_enable_real_payments()`; `validate_bundle()` отклоняет `real_payments_enabled=true` при наличии `[ЗАПОЛНИТЬ`. | `data/legal/01_offer.md`, `02_privacy.md`, `03_pdn_consent.md`, `05_refund_rules.md`, `10_ai_policy.md`, `11_seller_details.md`, `13_beta_rules.md`, `game/shell/screens/legal/legal_data.gd`, `game/core/age/tw_spend_limit.gd` |
| **m7** | Док 12 §1.3 («откровенный контент уровней B2/B3»), полуночный край МСК для Владивостока, принятие 1900 (126 лет), неверифицированный `link_account` | В `12_age_18_full_tier.md` §1.3 убрано противоречие про «откровенный контент уровней B2/B3». В `TWAge` добавлен `date_of_tz()` с учётом `clock.tz_bias_min()` (пользователь во Владивостоке UTC+10 в 00:30 в свой 18-й день рождения корректно проходит как 18+), введён `MAX_AGE = 120` (1900-01-01 отклонён с `DENY_DOB_RANGE`), а `link_account(provider, uid, verification_token)` проверяет формат и работает fail-closed без `set_link_verifier(Callable)` + валидного токена (`DENY_LINK_UNCONFIGURED` / `DENY_LINK_UNVERIFIED`). | `data/legal/12_age_18_full_tier.md`, `game/core/age/tw_age.gd` |

---

## 2. Подтверждение RED → GREEN (реальные команды и выводы)

### 2.1. Core P22 (`twage`: M1, M2, M7, m1, m2, m3, m4, m7)

Команда запуска (через `godot_lock.ps1`):
```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\ADMIN\.gemini\antigravity\brain\978de0bc-31e6-471b-88e3-aed00f14f758\scratch\godot_lock.ps1" -WorkDir "C:\Users\ADMIN\.gemini\antigravity\scratch\tw-legal" -Command "& `$env:GODOT_BIN --headless --path game --quit-after 180 res://tests/age/age_selftest.tscn"
```

**BEFORE (RED — 18 регрессионных проверок упали до исправлений):**
```text
TWAGE FAIL: [M1] revoke_age() does NOT unlock active BLOCKED_MINOR
TWAGE FAIL: [M1] submit_dob after revoke_age() during lock still returns DENY_MINOR_LOCKED
TWAGE FAIL: [M1] unauthenticated clear_minor_block_by_support() fails closed and keeps BLOCKED_MINOR
TWAGE FAIL: [M2] check_purchase(499) with null age/consent fails closed
TWAGE FAIL: [M2] check_purchase(499, age) with null consent fails closed
TWAGE FAIL: [M2] check_purchase(499, age, consent, '') with empty offer_ver fails closed
TWAGE FAIL: [M7] record_pull ignores caller-supplied ts and stamps clock time
TWAGE FAIL: [M7] forward phone clock jump (>365d) does NOT wipe PullHistory
TWAGE FAIL: [m1] founding required consents survive >512 analytics toggles
TWAGE FAIL: [m1] consent seq stays unique and monotonically increasing past 512 (last=513)
TWAGE FAIL: [m2] duplicate record_purchase(ord_idem_1) is idempotent (spent=6000)
TWAGE FAIL: [m2] out-of-order entry >366d old is pruned without dropping newer entry
TWAGE FAIL: [m3] omitted cost does NOT fabricate 150 gems (got 150 gems)
TWAGE FAIL: [m3] omitted rarity does NOT fabricate 'gift' (got 'gift')
TWAGE FAIL: [m4] consent ts cannot be backdated when phone clock moves backward
TWAGE FAIL: [m7] Vladivostok user at 00:30 local on 18th birthday is accepted (not hard-blocked for 30d)
TWAGE FAIL: [m7] 1900-01-01 (age 126 > MAX_AGE) rejected with DENY_DOB_RANGE
TWAGE FAIL: [m7] unverified link_account without verifier/token fails closed
TWAGE_SELFTEST 131/149 FAILED
```

**AFTER (GREEN — все проверки пройдены):**
```text
TWAGE_SELFTEST 156/156 OK
```

### 2.2. Legal P108, Packaging, UI & Docs (`twlegal`: M3, M4, M5, M6, m4, m5, m6, m7)

Команда запуска (через `godot_lock.ps1`):
```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\ADMIN\.gemini\antigravity\brain\978de0bc-31e6-471b-88e3-aed00f14f758\scratch\godot_lock.ps1" -WorkDir "C:\Users\ADMIN\.gemini\antigravity\scratch\tw-legal" -Command "& `$env:GODOT_BIN --headless --path game --quit-after 180 res://tests/legal/legal_selftest.tscn"
```

**BEFORE (RED — 21 регрессионная проверка упала до исправлений):**
```text
TWLEGAL FAIL: [M3] TWLegalConsent.STATE_KEY == TWConsent.STATE_KEY (got 'legal_consents' vs 'tw_consents')
TWLEGAL FAIL: [M4] accept_current_bundle without opened docs & TWAge records 0 entries (got 5)
TWLEGAL FAIL: [M4] accept_single_doc('age_18_full_tier') without verified adult TWAge fails closed
TWLEGAL FAIL: [M5] res://data/legal/manifest.json exists inside game/ project
TWLEGAL FAIL: [M5] res://data/legal/legal_bundle.json exists inside game/ project
TWLEGAL FAIL: [M5] manifest.json and legal_bundle.json are Godot-recognized exportable resources
TWLEGAL FAIL: [M5] TWLegalData.resolve_dir() resolves to res://data/legal (got 'C:/Users/ADMIN/.gemini/antigravity/scratch/tw-legal/data/legal')
TWLEGAL FAIL: [M6] age_gate.gd no longer makes contradictory local-only claim
TWLEGAL FAIL: [M6] age_gate.gd no longer contradicts legal docs on explicit/revealing wording
TWLEGAL FAIL: [M6] 02_privacy.md timestamp zone matches unified MSK journal export
TWLEGAL FAIL: [M6] 12_age_18_full_tier.md truthfully notes local storage vs P1 server rollout
TWLEGAL FAIL: [m4] TWLegalConsent.export_text() uses unified MSK format with 'МСК' label
TWLEGAL FAIL: [m4] TWLegalConsent refuses to backdate ts when phone clock moves backward
TWLEGAL FAIL: [m5] read_doc_text rejects '..' path traversal filename
TWLEGAL FAIL: [m5] validate_bundle flags '..' path traversal (...)
TWLEGAL FAIL: [m5] TWLegalScreen refuses to open tampered doc when validate_bundle() fails
TWLEGAL FAIL: [m5] TWLegalScreen refuses to record consent on tampered bundle
TWLEGAL FAIL: [m6] zero occurrences of non-reserved domain example.ru in legal docs
TWLEGAL FAIL: [m6] 11_seller_details.md marks RuStore self-employed status with [ЮР]/уточнить instead of unverified fact
TWLEGAL FAIL: [m6] TWLegalData reads real_payments_enabled and exposes can_enable_real_payments() placeholder gate
TWLEGAL FAIL: [m7] 12_age_18_full_tier.md §1.3 removes contradictory 'откровенный контент уровней B2/B3' wording
TWLEGAL_SELFTEST 115/136 FAILED
```

**AFTER (GREEN — все проверки пройдены):**
```text
TWLEGAL_SELFTEST 145/145 OK
```

---

## 3. Итоговый прогон сьютов и линтеров

### 3.1. `tools/tw_test.py` (13 затронутых сьютов через `godot_lock.ps1`)
```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\ADMIN\.gemini\antigravity\brain\978de0bc-31e6-471b-88e3-aed00f14f758\scratch\godot_lock.ps1" -WorkDir "C:\Users\ADMIN\.gemini\antigravity\scratch\tw-legal" -Command "python tools/tw_test.py --fast -s twage,twlegal,contract,state,registry,twnav,twmodal,shop,core_purity,ux_lint,asset_id_only,modal_only_via_stack,screen_has_spec --no-baseline -j 2"
```
Результат:
```text
suite        status   ok/total       secs  verdict     marker / reason
--------------------------------------------------------------------------------------------------------------
twage        pass     156/156        11.1  new         not in baseline
twlegal      pass     145/145        11.4  new         not in baseline
contract     pass     35/35          32.5  ok          CONTRACT_SELFTEST 35/35
state        pass     182/182        50.9  ok          STATE_SELFTEST 182/182
registry     pass     264/264         9.5  ok          REGISTRY_SELFTEST 264/264
twnav        pass     132/132        12.5  ok          TWNAV_SELFTEST 132/132
twmodal      pass     83/83          12.5  ok          TWMODAL_SELFTEST 83/83
shop         pass     682/682        11.9  ok          SHOP_SELFTEST 682/682
core_purity  pass     13/13           1.1  improved    CORE_PURITY RESULT: PASS (546 violations, baseline 546, +0 new)
ux_lint      pass     -               3.7  ok          UX_LINT RESULT: OK (0 violations)
asset_id_only pass     13/13           1.7  ok          ASSET_ID_ONLY SELFTEST 13/13 PASS
modal_only_via_stack pass     14/14           1.7  ok          MODAL_ONLY_VIA_STACK SELFTEST 14/14 PASS
screen_has_spec pass     7/7             0.6  ok          SCREEN_HAS_SPEC SELFTEST 7/7 PASS

[tw_test] 13/13 pass, 0 skipped, known-fail none, improved ['core_purity'], wall 81s (j=2)
```

### 3.2. Статические проверки и синхронизация пакета
- `python tools/sync_legal_bundle.py --check` → `LEGAL_BUNDLE CHECK: OK (13 docs synced to game/data/legal/)`
- `python tools/lint_core_purity.py --selftest --check` → `CORE_PURITY RESULT: PASS (546 violations, baseline 546, +0 new)`
- `python tools/lint_asset_id_only.py --selftest --check` → `ASSET_ID_ONLY RESULT: PASS (shell 0 violations; ... 0 ratchet breaches)`
- `python tools/lint_modal_only_via_stack.py --selftest --check` → `MODAL_ONLY_VIA_STACK RESULT: PASS (shell 0 violations; ... 0 ratchet breaches)`
- `python tools/lint_screen_has_spec.py --selftest --check` → `SCREEN_HAS_SPEC RESULT: PASS (0 violations)`
- `python tools/lint_tokens.py --files` → **0 нарушений** в `game/shell/screens/legal/` (4 существующих shell-нарушения относятся к нетронутым `tw_assets.gd` и `result_modal.gd`).
- `python .agents/skills/tw-godot-qa/scripts/ux_lint.py` → `UX_LINT RESULT: OK (0 violations)` (включая прямой скан всех 13 изменённых `.gd`).

---

## 4. Нужна регистрация

Общие файлы (`game/export_presets.cfg`, `tools/tw_test.py`, `.github/workflows/qa.yml`, `tools/baseline.json`) в этой ветке не редактировались. При интеграции:

1. **Экспорт Android APK (`game/export_presets.cfg`):**
   - Runtime-пакет `game/data/legal/manifest.json` и `game/data/legal/legal_bundle.json` уже является стандартным Godot `JSON`-ресурсом и **автоматически упаковывается** под `export_filter="all_resources"` без правки `game/export_presets.cfg`.
   - Если в будущем потребуется также напрямую упаковывать сырые `.md`-файлы, добавить `data/legal/*.md` в `include_filter` пресетов `preset.0`, `preset.1`, `preset.2` в `game/export_presets.cfg`.
2. **CI-проверка синхронизации (`.github/workflows/qa.yml`):**
   - Добавить шаг `python tools/sync_legal_bundle.py --check`, чтобы любое редактирование `data/legal/*.md` без обновления `game/data/legal/` роняло CI.
3. **Baseline тестов (`tools/baseline.json` / `tools/tw_test.py`):**
   - Обновить baseline для уже зарегистрированных сьютов `twage` (`156/156`) и `twlegal` (`145/145`).
4. **Интеграция с `TWPay` / сервером (PM04–PM08):**
   - При инициализации `TWAge` в shell/auth подключить `age.set_support_verifier(...)` (проверка подписанного тикета поддержки) и `age.set_link_verifier(...)` (проверка OAuth/OTP подтверждения VK/Яндекс/email).
   - В платёжном шлюзе вызывать `spend_limit.check_purchase(rub, age, consent, legal_data.offer_version(), bool(legal_data.can_enable_real_payments()["ok"]))`.
