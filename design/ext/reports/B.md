# Отчёт по задаче B (G5 — банк русских текстов)

- **Агент:** G5 (`tw-texts`)
- **Ветка:** `claude/ext-b` (от `origin/claude/ext-base`)
- **Границы:** строго `design/ext/**`

## Критерии приёмки
- ✔ `design/ext/text_bank/<heroine>.json` для всех 10 героинь (`mc`, `rin`, `hana`, `yue`, `nova`, `tsubame`, `miel`, `kohaku`, `shirin`, `zlata`) — по 32 записи (24 Beta-24 по `DEC-P44-1` + 8 SSR-костюма), итого 320 уникальных реплик.
- ✔ Формат записей `{id, text, emotion, max_words}` (+ `slot`, `tier`), длина каждой строки ≤ 12 слов.
- ✔ Контент-границы 20+ соблюдены: игривый флирт только с игроком, 0 школьных/детских/ученических мотивов, 0 наготы/секса/алкоголя, 0 кросс-упоминаний других героинь.
- ✔ `design/ext/text_bank/liveops_events.json` — 12 событий первого года на базе `design/specs/LIVEOPS_CALENDAR.md` (присутствует на ветке) и `design/specs/MONETIZATION_PLAN.md`, по 1–2 предложения, без FOMO/скидок/ложных таймеров.
- ✔ `design/ext/text_bank/validate_text_bank.py` написан и прогнан с кодом выхода `0`.
- ✔ Отчёты `design/ext/REPORT_B.md`, `design/ext/reports/B.md`, `design/ext/reports/STATUS_G5.md` оформлены.

## Команды проверки
```powershell
python design/ext/text_bank/validate_text_bank.py
```

Точные последние 15 строк вывода:
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

## Отклонения от карточки
- Для точного соответствия 24 + 8 = 32 применено каноническое решение `DEC-P44-1` (`design/voice/BETA24_TEXTS.md`): из буквального списка в 27 позиций исключены `idle_3`, `touch_head_2`, `combo_t1` (уходят в Launch-60).

## Что НЕ проверено
- Фактическая длительность аудиодорожек (`measured_s`) после TTS/озвучки.
- Интеграция в Godot / `game/` (вне границ задачи G5).

## Известные риски
- При замене TTS-движка отдельные лобби-строки из 10–12 слов могут потребовать подгонки под тайминг липсинка.

## Нужна регистрация
- Не требуется (файлы `design/ext/text_bank/**` не регистрируются в реестрах Godot).
