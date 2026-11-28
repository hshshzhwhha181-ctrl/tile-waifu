# Tile Waifu — ключевые решения по GDD v11 (ред. 2), 2026-11-27
Основание: 7 рецензий панели → `GDD_V11.md` (Прил. B — решение по каждому пункту, Прил. C — конфликты критиков). Вопросы к вам — `OPEN_QUESTIONS.md`.

**Гача и деньги**
1. Гарант: мягкий с 60-го желания (+5 п.п. за желание), жёсткий SSR на 80-м, 50/50 с catch-up, «Свеча» (выбор SSR) на 120-м. Любая SSR ≈41 желание, избранная ≈62, худший случай 120. Не нерф: желание 37–40 ₽ вместо ≈74,5; избранная ≈2 300–2 500 ₽.
2. Пакеты кратны 150 (79…2 990 ₽ = 300…12 000 кр); слов «выгоднее всего» нет.
3. Прямая продажа: SSR 1 490 ₽, S 599 ₽ (статика 359 ₽), звёзды 49–199 ₽; «одна витрина» (на баннере купить нельзя); цена и дата видны на баннере в день 1. Ранг «A» — это «Подарок» + 5 лепестков.
4. «Первый гость»: SSR гарантирована на 30-м желании; к D7 ≈30 желаний. За сезон: активный ≈160, лёгкий ≈64.
5. Защита: лимит трат 5 000 ₽/мес по умолчанию; платёж только после привязки (VK ID / Яндекс ID / почта); «История желаний»; хэш таблицы шансов.
6. Реклама только вне партии, ≤3 в сутки; «Без роликов» заменён «Пасьянс+» 399 ₽.

**Игра**
7. Наряд не влияет на игру нигде: порог ульты 8, заряд 0; модификаторы и тактики открывает симпатия (отличие от `HER §2`).
8. Скрытой энергии нет: удалены «15 наград», «XP ≤20», «240/300», потолок 300, «первая победа дня»; на экране победы 0 счётчиков.
9. Все 11 режимов остаются, но с приоритетами П1/П2/П3 и воротами выпуска (при срыве сроков уезжают рейтинговые Дуэли, Пагода, Дух).
10. Не более 2 новых систем в сутки; Стол+Рука с L26, но сразу для тех, кто заявил, что играет в риичи.
11. Стол риичи: хэш раздачи до начала, ИИ не видит стену, без подкрутки, разбор, тренажёры, статистика, двухшаговый ввод руки (фишка 46 px: 52 px не помещаются в 720).
12. Приключения: 6 тегов, синергии 2/3, 24 благословения, Вознесение 1–5, формула боя. Путь: 1000 уровней к релизу, арки по ★, подстройка предлагается, а не включается молча.

**Арт, UI, площадки**
13. Макет партии «board-first»: поле ≥92% ширины, плитка ≥64 px, героиня-полоса ≤28%, ульта — отдельное кольцо. Победа на обычном уровне ≤3 с.
14. «Нейтральный» тир — отдельный закрытый наряд; чип «Аниме / Спокойное» на S02; сборка для модерации по умолчанию «Нейтральный». Золотые композиты до заказа ригов.
15. Героиня входит в билд только после ворот (риг + Beta-24 JP + касания + кадры): цель 10, минимум 7. SSR-наряд — только с ригом, видео-ультой, ≥8 строками голоса.
16. Юр. минимум: полная дата рождения, «заявлено 18+», отдельный тумблер «Полный», Оферта + Политика + согласие на ПДн, удаление аккаунта, хостинг в РФ, письмо в RuStore за 30 дней, план Б (прямой APK).
17. Политика ИИ — арт, голос и музыка; слепой тест JP-голоса ≥70%, иначе живая актриса.

**Отклонено:** вырезание режимов из 1.0 (арт-критик); SSR 1 990–2 490 ₽ (юрист) и 990 ₽ (F2P); Стол с L12 для всех; «напарница» в Пути и дуэт-ульта (сила за симпатию в соло); значения правил JPML/EMA не вписаны — чужие правила не выдумываем.

## OWNER VISUAL REFERENCES (2026-11-28, from the owner himself — binding as the visual bar)
Files: `design/refs/owner_ui/12..15.webp` (UI mock-ups) and `design/refs/owner_pinup/4..11.webp` (heroine boldness bar). Same files are committed in the repo under `design/refs/` on branch `claude/refs`.
1. Heroine art tier **Full is the RuStore default** (see design/ART_TIER_FULL.md on claude/p50b): stockings/thigh-highs with garter/ribbon bands, high slits, plunging necklines, leaning/hip-tilt/over-shoulder poses, winks. Hard lines: adults only, no nudity/explicit acts, no school coding, no text on art. The owner said of the first P50 composites: "style became similar, but why no intimate poses and more revealing costumes?"
2. UI mock-ups 12..15 (match HUD, Tea House home, combo x10 screen, win card "Стол чист") are what he wants the screens to FEEL like: huge glamorous heroine at the SIDE of the board (match: pyramid board left ~55% width, 7-slot tray below it, heroine full body on the right ~40%, gold "x10" combo numeral, slim top bar "1-2 · Осталось 18" with pause + progress); Tea House: portrait avatar + name top-left, 3 lantern chips (Сегодня / Салон / Серия), big heroine leaning on the mahjong table, script greeting line, pink pill CTA "Играть · 1-4", heroine name plate with heart, 5-tab bottom nav (Чайная, Героини, Столы, Желания, Лавка) with gold line icons; win card: heroine reaching toward camera over the table, serif title "Стол чист", 2 of 3 stars, pink CTA "Ещё уровень · 5", text link "В чайную →".
3. CONFLICT to resolve in code, not by asking: GDD v11 says heroine strip <=28% of height ('Минимум' medallion). The mock-ups show the heroine taking the full right column. Decision: TWPresence has three modes — **Полный** (side-by-side as in mock-ups, DEFAULT for Full art tier on tall phones), **Стандарт** (strip <=28%), **Минимум** (medallion 160 px). Board must stay >= 50% of screen width in Полный; a toggle in settings. Tray = 7 slots (as in the mock-up) unless Q-tray says otherwise.
4. Mock-up art is concept only (generated, has baked UI text/flaws); real screens are built from separate heroine cut-outs, TWTokens widgets and real text. Do not ship the mock-up pixels.
5. More owner references `design/refs/owner_pinup/16..20.webp`: Hana beach (yellow tie bikini + sheer shirt, kneeling on towel, wink), MC bunny-style leotard (cheongsam-heart cutout, sheer pantyhose, heels, casino), Nova rooftop (striped thigh-highs, crop top, holo mini skirt, chunky sneakers, stretch pose), a green-haired braided heroine with glasses in a black bunny-tailcoat with pantyhose (tea service, leaning), Yue as a scale-armour battle outfit (dragon-scale bodice, thigh-high scale stockings, moon glaive). These are valid Full-tier SEASONAL/ALT outfits (swimwear, bunny, idol, battle). Rule: Full tier allows swimwear/bunny/sheer hosiery for the RuStore build; Yandex SFW/Neutral tier uses closed outfits.

## OWNER DECISION 2026-11-28 (binding): 17+/18+ only, Yandex Games dropped, maximum fan-service within the Full tier
- No Yandex Games build. No SFW/Neutral dual-build constraint anywhere (LoRA datasets, prompts, outfits, naming). The Neutral tier is a low-priority optional moderation fallback only (P3), not a design driver.
- Art direction = maximum erotic-glamour fan-service for an adult audience: stockings/thigh-highs/garters, plunging necklines, sheer fabrics, swimwear, bunny suits, negligee/robe-dresses, high slits, tight bodysuits, seductive and intimate poses (reclining, kneeling, leaning, squatting, arching, over-the-shoulder, teasing glances, wet/flushed skin, close-ups). Many heroines (roster growth), many outfits per heroine (target >= 6 each: base, evening, swim, bunny/maid, sleepwear/robe, battle/idol, seasonal), animated (idle breathing, blink, hair/cloth/soft-body secondary motion, win/touch reactions).
- HARD lines that stay (they are platform/store/legal limits and my own limit, not style choices): every character is clearly an adult (adult face, adult proportions, 20+ canon); NO nudity (no exposed nipples or genitals, nothing explicit/pornographic), no sexual acts or fluids, no school/minor coding, no text/logos on art. Content rating target: 17+/18+ "suggestive", i.e. what mainstream gacha (Brown Dust 2, Azur Lane, Nikke) ships.

## OWNER PRIORITY 2026-11-28: HEROINES ARE THE MAIN BET (binding)
Audience = gacha whales who want to collect and pull goddesses; the heroines must be in one unmistakable, irresistible style (BD2 / Azur Lane / Nikke level erotic-glamour fan-service; hard lines unchanged: adults, no nudity/explicit acts, no text). Consequences for planning:
1. Heroine presentation outranks everything except the money/odds correctness: splash art per SSR outfit (2 hero poses), live idle (breath, blink, hair/cloth secondary motion) for every owned outfit, touch/affection reactions, summon reveal with the heroine's pose, home/Tea House showcase with the heroine large (Полный mode), costume gacha (7 outfits per heroine), voice lines.
2. Roadmap moves: rigs P41-P43 and the summon reveal (video pilot P57) get pulled forward behind the vertical slice; the vertical-slice gate (P38) must include a "heroine showcase" screen with a live-animated heroine.
3. One style across ALL heroines is a gate: face-matrix (45 pairs distinguishable), same rendering (glossy-warm lacquer, rim light, saturated), same line weight; LoRA v3 is trained on the curated Full-tier set to guarantee it for fillers/animation frames; gpt_image_2_6 + elements stays the identity engine for key art.
4. OWNER CONFIRMED (2026-11-28): the first two live-animated showcases in the vertical slice are MC (warm) and Yue (statuesque). Rigs P41-P43 start with these two (mc_gown exists; yue_base is built after P50 style approval).

## 2026-11-28 (вечер) — отзыв владельца по листам Full-tier (БИНДИНГ)
Стиль одобрен («стиль супер, секси-секси»). Проблемы: (1) анатомия: лишние руки, неестественные позы, слишком большие бёдра; (2) вид сзади: корпус развёрнут, а бёдра/ноги/попка остаются «спереди» — разрыв скручивания; (3) мало поз с акцентом на попку (в одежде, по красным линиям), позы однообразны; (4) нужно ещё горячее: ноги, грудь, попка, вызывающие позы — при идеальной анатомии и гармонии. Примеры: design/refs/owner_feedback/26–30. Решение: бейк-офф моделей/рецептов на сложных позах, новая библиотека поз, строгий многоуровневый критик-гейт, перегенерация всех наборов (art4).

## 2026-11-28 — пропорции (владелец, БИНДИНГ)
Все героини казались слишком высокими, ноги длиннее туловища. Решение: пах на 45–48% высоты, ноги ≤ плечо–пах + голова, головность 6.5–7.0 (пол снижен с 6.75; взрослое лицо и зрелая фигура обязательны, юный вид = брак). Файл: design/art_v6/PROPORTIONS_OWNER_BINDING.md. Слова «long legs/elongating/statuesque» запрещены в промптах.

## 2026-11-28 (вечер): бриф владельца «скины и HUD для SSR+, ульты на каждую героиню и наряд, длинный донатный план, единая палитра» и что из него получилось
Статус: **проект спецификаций, не продакшен-код.** Нарядный план собран и отревьюен тремя ролями (монетизация-кит, Godot-инженер, комплаенс RuStore/РФ), правки внесены, решения владельца собраны в `OPEN_QUESTIONS.md` (раздел «Вопросы по ревью спецификаций», Q-R01…Q-R16). Безопасные значения по умолчанию уже записаны в документах и действуют, пока вы не ответили.

**Бриф (4 пункта).**
1. Скины и HUD-темы для нарядов SSR и выше: смена доски, меню, Стола риичи, результатов, боя, Желаний и Лавки под наряд.
2. Ульта у каждой героини и у каждого наряда, кинематограф уровня топ-гач, с красными линиями (взрослые, без наготы, без школьного кода, без текста в арте, камера не под подол).
3. Долгий донатный план на 12 месяцев в рублях под RuStore 17+/18+: каталог, цены, дорожки, календарь лайв-опса, честная гача.
4. Единая палитра: всё из рамп героинь и тем, никаких внепалитровых цветов.

**Ветки и файлы (всё на GitHub, сборная ветка `claude/spec-all` = integration + четыре спек-ветки, только docs/tools).**
- `claude/spec-skin`: `design/specs/SKIN_HUD_SYSTEM.md` (тиры, SkinPack, слоты, поверхности, анимация, конвейер, каталог 58 скинов, линт, пакеты P60–P72), `design/specs/PALETTE_LOCK.md` (рампы, 8 тем, аудит, RFC).
- `claude/spec-battle`: `design/specs/BATTLE_ULT_SPEC.md` (слой боя, прокачка, ульты, пакеты P73–P89), `ULT_CATALOGUE.md` + `ult_catalogue.json` (58 id = 58 скинов), `sim/battle_sim.py` и отчёт.
- `claude/spec-money`: `design/specs/MONETIZATION_PLAN.md` (каталог SKU, гача, дорожки, комплаенс, пакеты PM01–PM26), `LIVEOPS_CALENDAR.md` (12 месяцев), `sim/*` (расчёты экономики и LTV).
- `claude/spec-qa`: `design/specs/UNIFIED_QA_PLAN.md`, `tools/qa/*` (palette_audit, skin_lint, схема манифеста, фазз), `game/tests/skin_swap_soak/*`, CI-шаг.
- Бэклог: `backlog.json`/`BACKLOG.md` дополнены 53 пакетами P60–P112 (генератор `_gen_backlog.py`, данные `_bl_data4.py`); ревью — `spec_review_whale.md`, `spec_review_tech.md`, `spec_review_compliance.md`.

**Решения, принятые по ревью (с числами).**
1. **Сила от нарядов в бою: НЕТ в релизе 1.0** (вариант A = `DECISIONS` №7 остаётся в силе). `outfit_stats_enabled=false`, `bond_stats_enabled=false`, платных ускорителей силы нет, борд «Мощь» с наградами не вводится, остаётся «Мастерство». Вариант B (до +28% ATK, потолок ≤10% по комплаенсу) включается только вашим решением и заключением юриста (Q-R01).
2. **Каталог и цены не менялись:** S 599 ₽ (статика 359), SSR 1 490 ₽, SSR+ 2 490 ₽ [гипотеза], ★ 49/79/119/199 ₽, дорожка Премиум 899 ₽ / Люкс +1 091 ₽; лепестки SSR+ 3 600 (дубль 300). Потолок каталога за 12 месяцев ≈128 353 ₽ без желаний. Мера по умолчанию: заглавный SSR S2/S4 открывается для прямой покупки с дня 57 (Q-R03).
3. **Окна прямой продажи:** «Эвергрин-Бутик» (всё, чего нет на активном баннере) открыт с дня 1; S и SSR баннера — с дня 29; SSR+ — с дня 57. «Каталог запуска одним платежом 18 128 ₽» признан недоступным в первые 28 дней; в модели LTV добавлена чувствительность (M1 153→99 тыс. ₽ при 35% сдвига на M2–M3).
4. **Гача не менялась:** мягкий гарант с 60-го, жёсткий на 80-м, 50/50, Свеча на 120-м, избранная ≈61,8 желания в среднем, худший случай 120 (≈4 490 ₽ при 37,4 ₽/желание). Главный экономический риск R-M01: активный F2P получает ≈165 желаний за сезон, это вдвое-втрое щедрее эталонов; рекомендация ≈105–120 (Q-R02), до ответа числа в бету не публикуются.
5. **Юнит-экономика честно плохая:** чистый LTV365 ≈143 ₽ в среднем сценарии (низкий 61, высокий 282), то есть окупается только CPI ≤143 ₽; критерий выхода из P2: D30 платящих ≥2,5% и ARPPU D30 ≥900 ₽, иначе платная реклама не масштабируется.
6. **Рубли в закрытой бете P1 включаются только после входных ворот** (юрлицо и договор RuStore Pay, 54-ФЗ, уведомление РКН, Оферта/Политика/согласие, письмо в RuStore ≥30 дней, песочница пройдена); до этого флаг `real_payments_enabled=false`.
7. **Красные линии усилены (8–13):** нет просвета и облегания мокрой/тонкой ткани (кропы +40%, детектор наготы как стоп-гейт), камера по классу подола (мини-юбка: не ниже бедра, ≤5°; код ракурса `L` отменяется), пропорции **≥7,0 головы** (было 6,75) и правило сочетаний «юных» признаков, лицо в кадре на всех статичных кадрах, словарный гейт на реплики, одна сборка для модерации и игроков (подмены кадров «нейтральным комплектом» нет). Одновременно сняты перегибы: амплитуды мягкой анимации подняты (грудь 4/8/12 px вместо 2,5/5/7), запрет «любых двух героинь в кадре» сужен до «нет романтики/касаний героиня–героиня».
8. **Технические решения:** текстуры героинь в ETC2/ASTC 4×4 (базовый риг 29–31 МБ → ≈8–10 МБ), «ASTC 6×6» в Godot 4.5 нет; видео единого формата Theora 540×960, постоянных видео-петель в Лобби нет (параллакс + шейдер вместо них); клипы и ульт-риги — JSON, `.res/.tres` в паках запрещены; версионированные пути паков и ключ подписи `.pub`; ядро боя целочисленное; сохранения только модульными версиями (`SAVE_VER` остаётся 8); экранный проход ульты ≤1; Android-плагин для памяти и термо-сигналов; рендерящие тесты через xvfb, а не `--headless`.
9. **Первые две живые витрины (подтверждено вами ранее):** MC (`mc_ssrp_dragonnight`, пилот P66) и Юэ (`yue_ssr_scalearmor`, P99). SSR+ скин ≈238 ч и ≈955 кр с запасом, SSR ≈119 ч и ≈458 кр, S ≈46 ч и ≈151 кр; запуск S1 (28 скинов без базовых) ≈1 849 ч и 5 352 кр номинал.

**Что НЕ построено (честно).** Ни одного скина, ульты, экрана или платёжного кода: только документы, инструменты `tools/qa` (линт манифеста, аудит палитры по файлам, схема, 77 проверок) и тест-заглушка `skin_swap_soak` на заглушке `TWSkinHostStub`. Нет `TWSkinHost`, `TWPalette`, `TWWardrobe`, паков, CDN, боевого ядра, платёжного провайдера, серверного кошелька, детектора наготы, рендерящего CI-образа. Бюджеты памяти — оценки без замера на устройстве; симулятор боя не пересчитан под вариант A; сим экономики не пересчитан под Q-R02/Q-R04.

**Проверка сборной ветки `claude/spec-all` (bc95e8b, 2026-11-28).** `tools/qa`: 77/77 (72 unittest + 5 проверок синхронизации; в т.ч. 4 новых теста `ReviewFixes`). Быстрый набор репозитория `tools/tw_test.py --fast` (Godot 4.5.1, -j 3, 252 с): 65/68 pass, три известных падения из baseline (`letters` 4330/4355, `profile2`, `summon` 45/56), `no regression vs baseline`, `qa_tools` новый и зелёный. Эти тесты проверяют существующий код игры и инструменты QA; спецификации (Markdown) ими не проверяются. Конфликт при слиянии был один (`tools/tw_test.py`, обе правки сохранены).
Корректировка (тот же день): головность 6.75–7.0, пол 6.75 НЕ снижен (риск apparent-age по ревью комплаенса, Q-R09); «короче ноги» достигается правилом линии паха ≤48%. Спеки требуют ≥7.0 — нужно решение владельца (Q-R09): принято временно 6.75 + правило сочетаний «юных» признаков (макс. 1) + apparent age ≥24.
