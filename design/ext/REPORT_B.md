# REPORT B — Банк русских текстов (G5, ветка `claude/ext-b`)

## 1. Что создано
Все файлы строго внутри `design/ext/**`:
- **10 файлов героинь** (`design/ext/text_bank/<heroine>.json` для `mc`, `rin`, `hana`, `yue`, `nova`, `tsubame`, `miel`, `kohaku`, `shirin`, `zlata`):
  - По **32 уникальные русские реплики** на героиню = **320 реплик** суммарно.
  - Состав: **24 строки Beta-24** (по каноническому решению `DEC-P44-1` из `design/voice/BETA24_TEXTS.md`: 27→24 — `login_morning`, `login_evening`, `intro_summon`, `outfit_equip`, `idle_1`, `idle_2`, `idle_warm`, `touch_head`, `touch_hand`, `touch_hair`, `touch_outfit`, `touch_spam`, `touch_bold`, `gift_normal`, `gift_liked`, `level_max_vow`, `combo_t2`, `combo_t3`, `clear`, `fail`, `ult_cast`, `riichi`, `ron`, `tsumo`) + **8 строк SSR-костюма** (`outfit_new`, `idle_2`, `touch_2`, `level_vow`, `ult_cast_a`, `ult_cast_b`, `equip`, `win`).
  - Формат каждой записи: `{id, slot, tier, text, emotion, max_words}`.
  - Все 10 героинь выдержаны в характере и каноне 20+ (`docs/HEROINES.md`, `docs/ROSTER_20.md`): игривый флирт адресован только игроку, без упоминания других героинь, без школьных/детских/ученических мотивов, без наготы/секса/алкоголя/указаний на части тела.
- **12 событий «лавки/баннеров» первого года**: `design/ext/text_bank/liveops_events.json` (название + описание в 1–2 предложения, без ложных таймеров, «успей» и скидок).
  - Источник: `design/specs/LIVEOPS_CALENDAR.md` (найден на ветке `claude/ext-b`) и `design/specs/MONETIZATION_PLAN.md`.
- **Скрипт-валидатор**: `design/ext/text_bank/validate_text_bank.py`.

## 2. Критерии приёмки
- ✔ 10 файлов героинь × 32 записи = 320 уникальных реплик (формат `{id, text, emotion, max_words}` + `slot`/`tier`).
- ✔ Длина каждой реплики ≤ 12 слов (наблюдаемый максимум: 12 слов; боевые выкрики `combo`, `ult_cast`, `riichi`, `ron`, `tsumo` — 1–4 слова).
- ✔ 12 событий первого года в `liveops_events.json` (по 1–2 предложения, уникальные названия и ID).
- ✔ Автоматическая проверка запрещённых корней (`школ*`, `учениц*`, `ученик*`, `лоли*`, `ребён*`, `ребен*`, `девоч*`, нагота/секс/алкоголь/«куда смотришь»/«коленки» + анти-FOMO в событиях): **0 нарушений**.
- ✔ Проверка второй формы обращения в `touch_bold` и отсутствия кросс-упоминаний других героинь: **0 нарушений**.
- ✔ Границы изменений строго `design/ext/**`; общие файлы, код `game/` и другие worktree не затронуты.

## 3. Команда проверки и точные последние 15 строк вывода

Команда:
```powershell
python design/ext/text_bank/validate_text_bank.py
```

Последние 15 строк вывода (`exit code 0`):
```text
  [OK] rin     : 32 lines (24 beta24 + 8 ssr), max_words=10
  [OK] hana    : 32 lines (24 beta24 + 8 ssr), max_words=11
  [OK] yue     : 32 lines (24 beta24 + 8 ssr), max_words=11
  [OK] nova    : 32 lines (24 beta24 + 8 ssr), max_words=10
  [OK] tsubame : 32 lines (24 beta24 + 8 ssr), max_words=10
  [OK] miel    : 32 lines (24 beta24 + 8 ssr), max_words=10
  [OK] kohaku  : 32 lines (24 beta24 + 8 ssr), max_words=10
  [OK] shirin  : 32 lines (24 beta24 + 8 ssr), max_words=12
  [OK] zlata   : 32 lines (24 beta24 + 8 ssr), max_words=11
Total heroines checked: 10 / 10
Total voice lines checked: 320 / 320 (unique=320)
Max words per voice line: 12 / 12
LiveOps Year-1 events checked: 12 / 12
Forbidden/FOMO violations: 0
RESULT: PASS (all 10 heroines x 32 lines + 12 liveops events valid)
```

## 4. Отклонения, что не проверено и риски
- **Уточнение по Beta-24 (`DEC-P44-1`):** буквальный список в брифе/GDD §8.4 насчитывает 27 позиций, а целевое число — 24 (+ 8 SSR = 32). Использовано каноническое решение `DEC-P44-1` из `design/voice/BETA24_TEXTS.md` (убраны `idle_3`, `touch_head_2`, `combo_t1`, оставлены 24 слота Beta-24 + 8 слотов SSR = ровно 32).
- **Не проверено:** фактическая длительность озвучки в секундах (`measured_s`) после TTS/актёрской записи; загрузка JSON в Godot (задача не затрагивает движок и `game/`).
- **Риски:** длинные лобби-реплики (10–12 слов) при медленном TTS могут звучать 2,5–3,8 с (вписывается в бюджет лобби 1,5–4 с из `BETA24_TEXTS.md`, но при необходимости короткого окна ≤1,2 с потребуют сокращения). Боевые реплики и выкрики уже укорочены до 1–4 слов.
