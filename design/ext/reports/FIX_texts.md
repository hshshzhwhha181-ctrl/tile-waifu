# Отчёт по фиксам `texts` (FIX ROUND 1 — G5 Russian Texts & Voice Bank)

- **Ветка:** `claude/ext-fix-texts` (от `origin/claude/integration`)
- **Агент:** `fix-g5-texts` (роль G5 Russian Texts & Voice Bank fixer)
- **Источник дефектов:** `design/ext/FIX_ROUND1.md` (`## texts` — 3 Confirmed MAJOR + 9 Confirmed MINOR; `Refuted` отсутствуют)

## Сводка закрытых дефектов

### Confirmed MAJOR (3/3 закрыты)

1. **MAJOR #1 — 0/240 строк Beta-24 совпадали с каноном `design/voice/BETA24_TEXTS.md`:**
   - Все 240 строк `tier: "beta24"` в `design/ext/text_bank/{mc,rin,hana,yue,nova,tsubame,miel,kohaku,shirin,zlata}.json` синхронизированы 1-в-1 с каноническими RU-субтитрами из `design/voice/BETA24_TEXTS.md` и `game/core/voice/voice_registry.json` (теперь **240/240** точных совпадений).
   - В каноническом источнике `tools/audio/voice_texts_beta24.py` точечно очищены только 4 RU-субтитра (JP и kana не менялись, оценка длительности и моры сохранены):
     - `nova_touch_spam_1`: `DDoS` → `дидос` (убрана латиница для RU TTS);
     - `miel_login_morning_1`, `miel_login_evening_1`: убран символ `~` в конце строк;
     - `rin_intro_summon_1`: убрано повторное «я» (13 → 12 слов, попадает в лимит `<=12`).
   - Пересобраны `design/voice/BETA24_TEXTS.md` и `game/core/voice/voice_registry.json` через `python tools/audio/voice_registry.py build`.

2. **MAJOR #2 — 80 SSR-строк без ключа `<skin_id>`, неверные `ssr_outfit_ref`, несовпадение тем и cue с `ULT_CATALOGUE.md` / `ult_catalogue.json`:**
   - В каждом из 10 файлов добавлено поле `ssr_skin_id`, исправлено `ssr_outfit_ref` в формате `<legacy_outfit> / <skin_id>` строго по `design/specs/ult_catalogue.json`:
     - `mc`: `o_dragon / mc_ssrp_dragonnight`
     - `rin`: `r_idol / rin_ssr_bunnytea` (было `r_agent`)
     - `hana`: `h_beach / hana_ssr_beach` (было `h_gala`)
     - `yue`: `y_duel / yue_ssr_scalearmor` (было `y_queen`)
     - `nova`: `n_diva / nova_ssrp_idolstage` (было `n_ssr`)
     - `zlata`: `zl_ember / zlata_ssr_firebird` (было `zl_base`)
     - `tsubame`: `tb_crimson / tsubame_ssr_ninjarose`
     - `miel`: `me_gala / miel_ssr_seaside`
     - `kohaku`: `ko_kyubi / kohaku_ssrp_moonfest`
     - `shirin`: `sh_sun / shirin_ssrp_oasislight`
   - Все 80 SSR-записей получили поле `skin_id` и канонические ID:
     - не-ультовые слоты: `<hero>.<skin_id>.<type>.<nn>` (`SKIN_HUD_SYSTEM.md:775`);
     - ультовые слоты: `<skin_id>_ult_cast_<N>` из `voice_cues[]` в `ult_catalogue.json` (`BATTLE_ULT_SPEC.md` §9.1–9.6), с точным совпадением текста с `voice[]` каталога для всех 6 релизных SSR/SSR+ (`mc`, `rin`, `hana`, `yue`, `nova`, `zlata`).
   - Переписаны сюжетно расходящиеся наборы: `hana` (пляж/подача вместо платья и каблуков), `rin` (кролик-чайница вместо агента/тысячи листьев), `yue` (чешуйчатый доспех и лунная глефа вместо бального платья и вальса), `nova` (сцена идола и дроп вместо форсажа/офлайн/root), `zlata` (Жар-птица `zl_ember` вместо клятвенного кокошника `zl_vow`), `mc` (`Нефрит и пламя!` вместо `Четыре ветра`), `miel` (морская карамель вместо сахарного бала), `kohaku` (лунный фестиваль вместо солнечного дождя `vow`), `shirin` (`Огни оазиса` вместо `Свет оазиса`).

3. **MAJOR #3 — `ev_s2_spring_ball` подавал платный набор `tw_bundle_season` (5 390 ₽) как приз за прохождение:**
   - В `design/ext/text_bank/liveops_events.json` (`ev_s2_spring_ball`) текст «Пройдите три сцены «Весеннего бала» и заберите сезонный «Набор Витрины» в Лавке.» заменён на: «Пройдите три сцены «Весеннего бала» за награды события; отдельно в Лавке доступен платный набор сезона «Витрина».»

### Confirmed MINOR (9/9 закрыты)

1. **MINOR #1 (`«Огни оазиса»`):** В `liveops_events.json` (`ev_s3_oasis_light`, `ev_s4_seaside_caramel`) и `shirin.json` переименовано «Свет(а) оазиса» → каноническое «Огни/Огней оазиса» (`SKIN_HUD_SYSTEM.md:825/870`, `ULT_CATALOGUE.md:78`).
2. **MINOR #2 (`ev_s1_dragonnight` vs `ev_s1_night_teahouse`):** Заголовок `ev_s1_dragonnight` изменён с «Чайный дом: Ночь дракона» на «Ночной дракон и Чайный парад» (чёткое отличие от мега-события «Ночь над чайным домом»), убрано «откройте витрину сезона» (до 57-го дня недоступна), также выправлено неканоническое «Императрица дракона» → «Ночной дракон» в `ev_s1_dragonnight` и `ev_y1_great_feast`.
3. **MINOR #3 (русский в `yue.json`):** Убраны «с тобой одним» (→ «лишь с тобой»), калька «Три четверти такта» и «последний вальс» при переписывании SSR-линии под `yue_ssr_scalearmor`.
4. **MINOR #4 (русский в `rin`/`mc`/`zlata`):** `rin_outfit_equip_1`, `rin_login_morning_1`, `mc_gift_normal_1` приведены к естественному канону `BETA24_TEXTS.md`; `rin.rin_ssr_bunnytea.idle.02` переписан без двусмысленности («В гостиной тихо, и я смотрю поверх очков лишь на тебя.»); `mc.mc_ssrp_dragonnight.equip.01` переписан без неуклюжей конструкции и `~`; `zlata.zlata_ssr_firebird.level_vow.01` переписан ясно и в теме `zl_ember`.
5. **MINOR #5 (`tsubame_touch_bold_1` и `tsubame` SSR `touch_2`):** `tsubame_touch_bold_1` синхронизирован с каноном («Только тебе я позволю читать моё присутствие.» — холодный профи, без благодарности, 2-е лицо); `tsubame.tsubame_ssr_ninjarose.touch.02` переписан в холодном профессиональном тоне и без привязки к телу/корсажу («Не трогай алый шарф. …Я не смутилась, просто соблюдай дистанцию.»).
6. **MINOR #6 (смягчение `kohaku` и `shirin`):** `shirin_touch_bold_1` синхронизирован с каноном («Наша с тобой линия судьбы очень длинная.»); `kohaku.kohaku_ssrp_moonfest.touch.02` и `.win.01` смягчены (убраны «до рассвета~» и «Погладь меня в награду»).
7. **MINOR #7 (латиница, `~`, `mc_tsumo_1`):** Удалены все латинские символы (`DDoS`, `root-доступ`, `Root-доступ`) и все символы `~`/`〜` во всех 320 строках `text_bank/*.json` и всех 240 RU-строках `BETA24_TEXTS.md` / `voice_registry.json`; `mc_tsumo_1` стал каноническим «Цумо!». В `validate_text_bank.py` добавлен запрет на `[A-Za-z]` и `[~〜]`.
8. **MINOR #8 (пуловые `max_words`):** Введены пуловые лимиты `max_words` (`3` для выкриков `combo_t2`/`combo_t3`/`ult_cast`/`ult_cast_a`/`ult_cast_b`/`riichi`/`ron`, `4` для `tsumo`, `12` для лобби/интро) во всех 10 JSON и в `validate_text_bank.py` с проверкой как слитного, так и раздельного (по дефису) подсчёта слов.
9. **MINOR #9 (расширение `FORBIDDEN_PATTERNS` и `FOMO_PATTERNS`):** Расширены стоп-списки в `validate_text_bank.py`: добавлены корни (в том числе не только от начала слова) `ученическ*`, `студент*`, `девчонк*`, `лице[йяюе]*`, `гимназ*`, `колледж*`, `малолетк*`, `раздев*`, `куда пялишься`, `пив*`, `водк*`, а в FOMO добавлены `не упусти*`, `только сегодня`, `только сейчас`, `осталось/осталась/остались`, `эксклюзив*`, `лимитирован*`, `распродаж*`, `выгоднее всего`, `исчезнет навсегда`, `больше не вернётся`, а также проверки кросс-упоминаний героинь, 2-го лица в `touch_bold`, синхронизации с `BETA24_TEXTS.md`/`ult_catalogue.json` и защиты от подачи платного набора как приза.

---

## RED → GREEN доказательства

### 1. RED (до правок данных и валидатора)

Добавлен регрессионный набор `design/ext/text_bank/test_text_bank.py` (13 тестов: 3 MAJOR + 9 MINOR + валидатор) и запущен до внесения исправлений:

```powershell
python -m unittest discover -s design/ext/text_bank -p "test_*.py" -v
```

Реальный вывод (RED — **12/13 падений**, упали все 3 MAJOR и все 9 MINOR):

```text
test_major1_beta24_matches_canon_240_of_240 ... FAIL
test_major2_ssr_skin_id_schema_refs_and_ult_cues ... FAIL
test_major3_spring_ball_does_not_present_paid_bundle_as_prize ... FAIL
test_minor1_shirin_outfit_named_ogni_oazisa ... FAIL
test_minor2_s1_events_distinct_titles_and_no_vitrina_sezona ... FAIL
test_minor3_yue_natural_russian ... FAIL
test_minor4_rin_mc_zlata_natural_russian ... FAIL
test_minor5_tsubame_cold_pro_and_no_body_garment_touch ... FAIL
test_minor6_kohaku_and_shirin_softened ... FAIL
test_minor7_no_latin_no_tilde_and_mc_tsumo_clean ... FAIL
test_minor8_pool_specific_max_words ... FAIL
test_minor9_expanded_forbidden_and_fomo_patterns ... FAIL
test_validator_passes ... ok

Ran 13 tests in 0.038s
FAILED (failures=12)
```

Ключевые фрагменты RED-диагностики до правок:
- `MAJOR 1`: `AssertionError: 0 != 240 : Only 0/240 Beta-24 RU strings match BETA24_TEXTS.md`
- `MAJOR 2`: `First list contains 202 additional elements. First extra element 0: "mc: ssr_skin_id=None != 'mc_ssrp_dragonnight'"`
- `MAJOR 3`: `Regex matched: 'заберите сезонный «набор' ... ev_s2_spring_ball presents paid bundle as a prize`
- `MINOR 1`: `Regex matched: 'Свет оазиса' ... liveops_events.json still uses 'Свет оазиса'`
- `MINOR 3`: `yue.json still contains awkward phrase 'с тобой одним'`
- `MINOR 4`: `rin.json still contains awkward phrase 'удивительно важно'`
- `MINOR 5`: `tsubame touch_bold still talks about thanks: 'когда благодаришь так тихо, даже шарф не скрывает румянец.'`
- `MINOR 6`: `'до рассвета' unexpectedly found in 'погладишь все девять хвостов? тогда останусь с тобой до рассвета~'`
- `MINOR 7`: `'партия окончена' unexpectedly found in 'цумо! партия окончена~'`
- `MINOR 8`: `AssertionError: 1 not greater than 1 : max_words must be pool-specific, not uniform 12`
- `MINOR 9`: `FORBIDDEN_PATTERNS failed to catch 'ученическая форма'`

### 2. GREEN (после всех исправлений)

#### 2.1 Регрессионный набор `test_text_bank.py` + `validate_text_bank.py` + `voice_registry.py`

```powershell
python -m unittest discover -s design/ext/text_bank -p "test_*.py" -v
python design/ext/text_bank/validate_text_bank.py
python tools/audio/voice_registry.py check
```

Реальный вывод (GREEN, `exit code 0`):

```text
test_major1_beta24_matches_canon_240_of_240 ... ok
test_major2_ssr_skin_id_schema_refs_and_ult_cues ... ok
test_major3_spring_ball_does_not_present_paid_bundle_as_prize ... ok
test_minor1_shirin_outfit_named_ogni_oazisa ... ok
test_minor2_s1_events_distinct_titles_and_no_vitrina_sezona ... ok
test_minor3_yue_natural_russian ... ok
test_minor4_rin_mc_zlata_natural_russian ... ok
test_minor5_tsubame_cold_pro_and_no_body_garment_touch ... ok
test_minor6_kohaku_and_shirin_softened ... ok
test_minor7_no_latin_no_tilde_and_mc_tsumo_clean ... ok
test_minor8_pool_specific_max_words ... ok
test_minor9_expanded_forbidden_and_fomo_patterns ... ok
test_validator_passes ... ok

----------------------------------------------------------------------
Ran 13 tests in 0.190s

OK
=== Tile Waifu G5 Text Bank Validation ===
  [OK] mc      : 32 lines (24 beta24 + 8 ssr [mc_ssrp_dragonnight]), max_words=11
  [OK] rin     : 32 lines (24 beta24 + 8 ssr [rin_ssr_bunnytea]), max_words=12
  [OK] hana    : 32 lines (24 beta24 + 8 ssr [hana_ssr_beach]), max_words=11
  [OK] yue     : 32 lines (24 beta24 + 8 ssr [yue_ssr_scalearmor]), max_words=11
  [OK] nova    : 32 lines (24 beta24 + 8 ssr [nova_ssrp_idolstage]), max_words=11
  [OK] tsubame : 32 lines (24 beta24 + 8 ssr [tsubame_ssr_ninjarose]), max_words=11
  [OK] miel    : 32 lines (24 beta24 + 8 ssr [miel_ssr_seaside]), max_words=10
  [OK] kohaku  : 32 lines (24 beta24 + 8 ssr [kohaku_ssrp_moonfest]), max_words=10
  [OK] shirin  : 32 lines (24 beta24 + 8 ssr [shirin_ssrp_oasislight]), max_words=10
  [OK] zlata   : 32 lines (24 beta24 + 8 ssr [zlata_ssr_firebird]), max_words=10
Total heroines checked: 10 / 10
Total voice lines checked: 320 / 320 (beta24_canon_match=240/240)
Max words per voice line (hyphen-split): 12 / 12
LiveOps Year-1 events checked: 12 / 12
Validation violations: 0
RESULT: PASS (all 10 heroines x 32 lines + 12 liveops events valid)
VOICE_FILES 0/240 0.0%
VOICE_REGISTRY 3159/3159
```

#### 2.2 Дизайн-линтер `tools/design_lint.py`

```powershell
python tools/design_lint.py
```

Реальный вывод (`exit code 0`):

```text
DESIGN_LINT RESULT 51/51 OK
```

#### 2.3 Godot-селфтест `voice_registry` (через `godot_lock.ps1`)

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\ADMIN\.gemini\antigravity\brain\978de0bc-31e6-471b-88e3-aed00f14f758\scratch\godot_lock.ps1" -WorkDir "C:\Users\ADMIN\.gemini\antigravity\scratch\tw-texts" -Command "python tools/tw_test.py -s voice_registry"
```

Реальный вывод (`exit code 0`):

```text
[tw_test] 1 suite(s), mode=full, jobs=4, godot=C:\Users\ADMIN\.gemini\antigravity\scratch\tw-tools\godot\Godot_v4.5.1-stable_win64_console.exe
  [ 1/1] voice_registry PASS    3162/3162      7.8s  

suite        status   ok/total       secs  verdict     marker / reason
--------------------------------------------------------------------------------------------------------------
voice_registry pass     3162/3162       7.8  ok          VOICE_REGISTRY 3162/3162

[tw_test] 1/1 pass, 0 skipped, known-fail none, improved none, wall 8s (j=4)
[tw_test] no regression vs baseline
```

После прогона Godot все правки `.import` откачены через `git checkout -- ':(glob)**/*.import'`.

---

## Изменённые файлы
- `design/ext/text_bank/{mc,rin,hana,yue,nova,tsubame,miel,kohaku,shirin,zlata}.json`
- `design/ext/text_bank/liveops_events.json`
- `design/ext/text_bank/validate_text_bank.py`
- `design/ext/text_bank/test_text_bank.py` (новый)
- `tools/audio/voice_texts_beta24.py` (4 RU-субтитра: убраны `DDoS`, `~`×2 и 13-е слово; JP/kana без изменений)
- `design/voice/BETA24_TEXTS.md` (пересобран `voice_registry.py build`)
- `game/core/voice/voice_registry.json` (пересобран `voice_registry.py build`)
- `design/ext/reports/FIX_texts.md` (этот отчёт)

## Нужна регистрация
- При желании включить `design/ext/text_bank/validate_text_bank.py` и `design/ext/text_bank/test_text_bank.py` в общие пайплайны (`tools/tw_test.py` и/или `.github/workflows/qa.yml`) — требуется отдельная регистрация в общих реестрах (на этой ветке общие реестры не изменялись).
