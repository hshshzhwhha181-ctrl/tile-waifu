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

## 2026-11-28 (P50b): Art tier Full is the RuStore default; hard lines unchanged
- Heroine art direction for every batch (H0 to H4) is **tier Full**, spec in `design/ART_TIER_FULL.md`. It replaces the Standard (Yandex-intersection) rules of `lora-v2/SPEC_V2.md` section 2, `docs/HEROINES.md` section 4 and `docs/LEGWEAR.md` 1.1 for art. No Standard / Neutral tier exists in the art packages any more (git history of P59 keeps the old H2 neutral tier).
- Why the P50 golden composites were tame: they followed the Yandex-intersection policy (no stockings or garter, slits to mid-thigh, no swimwear / bunny, closed poses, muted `v4c` tail). The owner's earlier allowances for RuStore (stockings, garters, swimsuits, deep slits and necklines, flirty poses) were never used. Not a model limit.
- Hard lines, unchanged and enforced by `tools/art/validate_batches.py`: every character clearly adult (adult face, 7 to 7.5 heads, 20+); no nudity (no exposed nipples or genitals); no explicit sex acts or fluids; no school or minor coding; no text, logos or watermark in art; camera not under the skirt.
- Tools: `tools/art/full_tier_wardrobe.py` (10 heroines x 7 outfits x 3 poses), `tools/art/build_art_batches.py` (H0, H1, H2 wardrobe, H3, H4 rebuilt as Full; tail `v5f`), validator with a tier-aware word list (costume words allowed in `"tier": "full"` files only). Budget effect: H2 200 -> 350 cr, plan nominal 2562 -> 2712 cr, ceiling 3074 -> 3254 cr (`design/ART_BATCHES.md`); the owner confirms the numbers.
- First Full frames (15 MC / Yue / Nova golden composites, 1 Hana pin-up, 6 probes): `design/golden_full/`, nothing registered or approved.
