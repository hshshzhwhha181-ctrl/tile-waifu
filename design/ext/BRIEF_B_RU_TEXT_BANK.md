# Бриф B — банк русских текстов (для внешней модели)
Игра: гача-маджонг-пасьянс + риичи, 10 взрослых героинь (20+), сборка RuStore 18+. Источники канона: `docs/HEROINES.md`, `docs/ROSTER_20.md`, `design/voice/` (если есть), GDD §озвучка (строки `equip, idle, touch, ult_cast, level_vow, outfit_new`).
Задача: написать тексты, которые потом озвучат/вставят в игру.
1. Для каждой из 10 героинь: 24 реплики (Beta-24: login×2, intro_summon, outfit_equip, idle×3, idle_warm, touch head×2 / hand / hair / outfit / spam / bold, gift×2, level_max_vow, combo_t1–t3, clear, fail, ult_cast, riichi, ron, tsumo) в её голосе (характер из docs/HEROINES.md). Игривый флирт, без пошлости с наготой/сексом, без упоминания школы/возраста младше 20. Длина 0,4–1,2 с (до ~12 слов).
2. Для каждой героини ещё +8 строк для SSR-костюма: outfit_new, idle_2, touch_2, level_vow, ult_cast_a, ult_cast_b, equip, win.
3. Описания 12 событий «лавки/баннеров» (название, 1–2 строки) для первого года (см. `design/specs/LIVEOPS_CALENDAR.md` на ветке `claude/spec-money`).
4. Формат: `design/ext/text_bank/<heroine>.json` ({id, text, emotion, max_words}) + `design/ext/REPORT_B.md`. Проверка скриптом: длины, запрещённые слова (список: школ*, ученица, лоли, ребён*), уникальность реплик.
Границы: ветка `claude/ext-b` от `claude/integration`; только `design/ext/**`.
