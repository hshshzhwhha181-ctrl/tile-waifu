# AUDIO_BIBLE — звуковая библия Tile Waifu

Документ нужен, чтобы любой новый трек, стинг или звук звучал как часть одного саундтрека.
Эталон — 18 музыкальных треков ветки `v10-audio`. Владелец о них сказал: «все треки цепляют, подобраны идеально».
Картинная LoRA музыку не делает (HANDOFF §23). Поэтому стиль музыки держат три вещи:
1. **ДНК** из §2: инструменты, грув, гармония и продакшн, снятые с эталона в цифрах.
2. **Шаблон промпта** из §9: дословный каркас для `elevenlabs_music_v2_5`.
3. **Ворота стиля** из §10: скрипт `tools/audio/gate.py` сверяет кандидата с эталоном.

Связанные документы: UX_RULES §7 (звуковая идентичность), HUD_V2 §7.3 (звук витрины комбо), HEROINES §4–5 (красные линии, характеры),
README `game/scripts/v10/audio/README.md` в ветке `v10-audio` (код V10Music/V10SfxBank, пайплайн петель, лицензия).

---

## 0. Пять правил

1. **Каждый трек начинается с ядра:** гучжэн (или кото) + эрху + тёплое пиано/Rhodes + мягкие аналоговые пэды + бит. Без ядра трек не наш, каким бы красивым он ни был.
2. **Жанр вкладки — это «костюм» поверх ядра** (lo-fi, city-pop, EDM, trip-hop, battle-pop). Костюм меняем, ядро — нет.
3. **Пентатоника и мажорная надежда.** Даже напряжение и бой «стильные, никогда не страшные» (`never scary`, `never horror`).
4. **Петля без начала и конца:** `seamless loop, no intro, no fade-out, no ending` в каждом промпте петли. Только инструментал.
5. **Новый трек выходит только после ворот** (§10) и прослушивания критиком по чек-листу (§11).

---

## 1. Эталон: 18 одобренных треков

Файлы: `game/assets/v10/audio/music/*.ogg` в ветке `v10-audio`. Читать так: `git show v10-audio:game/assets/v10/audio/music/lobby.ogg > lobby.ogg`.
Дословные промпты и job id: `tools/audio/approved_music_prompts.json`. Метрики: `tools/audio/approved_metrics.json`.
Все треки сделаны в `elevenlabs_music_v2_5` с `force_instrumental: true`. Петли нарезаны `v10_loop.py` и выровнены на −16 LUFS.

Как читать таблицу:
- **BPM** и **тональность** записаны парой «в промпте / измерено».
- **Пента** — доля энергии хромы, которая попадает в лучшую пентатонику.
- **Центроид** — «яркость» трека в Гц.
- **Гарм.** — доля гармонической части. 1,0 значит «без ударных».
- **Ширина** — отношение side/mid.
- **Атаки/с** — плотность атак.
- **LRA≈** — разброс громкости по окнам 3 с, в LU.
- **CLAP** — косинус с центром остальных 17 треков (§10).
- **Теги** — три сильнейших тега по CLAP.

| id | экран | BPM | тональность | пента | центроид | гарм. | ширина | атаки/с | LRA≈ | CLAP | теги |
|---|---|---|---|---|---|---|---|---|---|---|---|
| `lobby` | титул/главная | 96/96 | D maj pent / Bb min (= Db maj) | 0,61 | 1369 | 0,83 | 0,41 | 4,0 | 1,2 | 0,89 | lofi, rhodes, anime |
| `path` | карта Пути | 104/103 | G maj pent / G maj | 0,73 | 1042 | 0,92 | 0,61 | 6,3 | 3,6 | 0,91 | anime, piano, chinese |
| `match_calm` | партия | 88/89 | A min pent / F maj | 0,66 | 807 | 0,76 | 0,14 | 3,3 | 3,2 | 0,74 | lofi, rhodes, jazz |
| `match_tense` | партия, лоток почти полон | 120/118 | E min / A min | 0,50 | 1619 | 0,77 | 0,27 | 8,0 | 1,5 | 0,81 | anime, edm, orch |
| `fever` | слой фивера | 128/129 | D maj / ? (r=0,47) | 0,47 | 2807 | 0,77 | 0,45 | 6,8 | 1,4 | 0,80 | edm, anime, pads |
| `summon` | призыв | 90/≈123* | F lydian / C maj (= F лид.) | 0,60 | 1271 | 0,90 | 0,79 | 5,1 | 3,8 | 0,79 | orch, pads, piano |
| `shop` | Лавка | 108/108 | C maj pent / C maj | 0,51 | 1356 | 0,78 | 0,32 | 4,0 | 2,0 | 0,89 | anime, lofi, rhodes |
| `salon` | Салон | 84/83 | Eb maj7 / C min (относит.) | 0,66 | 1044 | 0,86 | 0,17 | 3,4 | 1,4 | 0,78 | jazz, rhodes, lofi |
| `phone` | Телефон | 78/78 | F maj / F maj | 0,69 | 967 | 0,76 | 0,40 | 3,0 | 3,2 | 0,79 | lofi, rhodes, anime |
| `pagoda` | Пагода Луны | 82/81 | D dorian / D min | 0,51 | 1170 | 0,91 | 0,58 | 4,8 | 1,6 | 0,74 | anime, dizi, chinese |
| `duels` | Дуэли | 140/144 | C min / C min | 0,49 | 2896 | 0,80 | 0,55 | 4,6 | 2,4 | 0,81 | anime, edm, orch |
| `motif_mc` | Маджонг-тян | 122/123 | G maj / G maj | 0,46 | 1857 | 0,85 | 0,27 | 4,1 | 0,4 | 0,85 | anime, chinese, edm |
| `motif_rin` | Рин | 72/72 | A min pent / C maj (относит.) | 0,62 | 1104 | 0,89 | 0,70 | 5,1 | 5,0 | 0,78 | lofi, jazz, anime |
| `motif_hana` | Хана | 140/144 | E maj / E maj | 0,54 | 2270 | 0,76 | 0,40 | 4,7 | 0,9 | 0,77 | anime, chinese, edm |
| `motif_yue` | Юэ | 80/81 (3/4) | D min / D min | 0,66 | 967 | 0,96 | 0,58 | 2,7 | 0,8 | 0,72 | orch, guzheng, erhu |
| `motif_nova` | Нова | 118/118 | F# min / A min (r=0,33) | 0,47 | 2303 | 0,72 | 0,26 | 7,4 | 0,4 | 0,84 | anime, edm, pads |
| `sting_victory` | победа, 9,3 с | — | D maj / D maj | 0,72 | 3088 | 0,78 | 0,95 | 3,5 | 3,1 | 0,60 | guzheng, pipa, edm |
| `sting_defeat` | поражение, 7,6 с | — | — / E maj | 0,75 | 933 | 0,96 | 0,90 | 0,7 | 14,1 | 0,66 | piano, rhodes, jazz |

\* `summon` — «зависающее» ожидание без ясной доли. Трекер долей ловит пульс тайко-«сердца», а не 90 BPM из промпта.
В `manifest.json` ветки записаны удвоенные и половинные темпы (fever 63,8, salon 166,7). В таблице они приведены к промпту.

**Что видно по замерам:**
- **Темп модель держит.** 15 из 16 петель попали в BPM промпта в пределах 3% (с учётом ×2 и ×½). Исключение — `summon` (см. сноску).
- **Тональность модель держит наполовину.** 12 из 17 треков совпали или ушли в параллельную/родственную тональность. `lobby`, `match_tense`, `fever` и `motif_nova` ушли в чужую, и владелец их всё равно одобрил.
  Вывод: тональность в промпте — подсказка. Новый трек не бракуем за тональность, если он пентатонный и мажорно-светлый по ощущению.
- **Пентатоника — ядро.** Пента ≥ 0,46 у всех; у спокойных и «дорожных» треков 0,6–0,75.
- **Бит обязателен.** Гармоническая доля 0,72–0,96, медиана 0,82. Ударные есть везде, кроме стинга поражения.
  Старые треки 0.7 без бита (0,97–0,98) воротами отсекаются (§10).
- **Узкая стереобаза.** У петель side/mid 0,14–0,79, медиана 0,41. Широко только у стингов (0,9–0,95).
  Прототипы 0.7 были шире 0,9, и CLAP отнёс их к «чужим».
- **Яркость задаёт жанр-костюм.** Тихие экраны (партия, Телефон, Салон, Юэ, Рин, Пагода) — центроид 800–1200 Гц.
  Поп-экраны (Лобби, Лавка, Путь) — 1000–1400. Энергия (фивер, Дуэли, Хана, Нова, МТ) — 1800–2900.
- **Ровная динамика.** У петель LRA≈ 0,4–5 LU, медиана 1,6. Это нужно для бесшовной петли и для того, чтобы трек не отвлекал.
  Пик-фактор 12–19 дБ: треки не пережаты.

---

## 2. Звуковая ДНК: «чайный дом + аниме-поп»

### 2.1. Ядро: есть в каждом треке, называется в каждом промпте
| Роль | Инструмент | Как звучит |
|---|---|---|
| Лид, щипок | **гучжэн** (`guzheng`); вместо него можно `koto` | мелодия, арпеджио, тремоло, глиссандо-подхват |
| Ответ, смычок | **эрху** (`erhu`) | контрмелодия и «вздох»; в бою — героический лид |
| Гармония | **тёплое пиано** (`warm piano`) или **Rhodes** | аккорды, мягкие септаккорды |
| Подложка | **мягкие аналоговые пэды** (`soft analog synth pads`) | «воздух» чайного дома |
| Ритм | **lo-fi бит** (`light lo-fi hip-hop drums`) — на спокойных экранах | щётки, шейкер, деревянный блок |
| Низ | мягкий круглый бас (`gentle bass`, `round sub bass`) | без перегруза; дисторшн-бас только в бою |

Фраза-якорь (в той или иной форме есть в 5 из 11 одобренных петель: path, match_tense, shop, phone, duels) — в новых **обязательна**:
`Same sonic identity as a teahouse anime-pop soundtrack (guzheng, erhu, warm piano, soft synths).`

### 2.2. Палитра акцентов: 1–3 штуки на трек под настроение
- **Восточные:** дицзы (`dizi bamboo flute`), сякухати-подобная флейта (`shakuhachi-like bamboo flute`), пипа (`pipa`), гуцинь (`guqin`), сямисэн (`shamisen accents`), тайко (`taiko accents / heartbeat / ensemble`), храмовые колокола (`deep temple bells`), колокольчики ветров (`wind chimes`).
- **Сказочные:** челеста, арфа-глиссандо, глокеншпиль, музыкальная шкатулка, «колокольчик-синт» (`bell-like synth`).
- **Поп и электроника:** пиццикато струнных, свинг, finger snaps, handclaps, трэп-хэты, суперсо с сайдчейном, дисторшн-синт-бас, медь-синт стабы (`brass-like synth stabs`), чиптюн (только Нова), саксофон-подобный синт (только Салон).
- **Хор** — только `wordless choir pads` / `choir-like synth pads (no words)`.

### 2.3. Запрещено
- Голос со словами, вокализ «а-а» на первом плане. Модель иногда добавляет вокал даже при `force_instrumental` — проверять (тег `OFF_vocal`, §10).
- Перегруженная гитара, метал, дабстеп-воббл, кантри-банджо, оркестровый хоррор, «эпичный трейлер» без восточного ядра.
- Узнаваемые чужие мелодии, в том числе «Happy Birthday», гимны и известные аниме-опенинги; имена артистов, «in the style of …».
- Звуки тела и придыхания (ASMR, поцелуи, стоны) — и в музыке, и в SFX (HEROINES §4, витрина 12+/16+).
- Шум, треск и «вау-эффекты», которые маскируют SFX партии. Винил допустим только тихим фоном (Телефон).
- Длинное вступление и затухание в петлях.

### 2.4. Грув и форма
- Темпы — от 72 до 144 BPM, четыре зоны: **72–84** (личное, тайна), **88–108** (основная игра, меню), **116–128** (энергия, мотивы), **140** half-time (бой).
- Размер 4/4. 3/4 — **только у Юэ** (её вальс и ульта «Последний вальс»).
- Энергия ровная по всей длине: `steady / consistent / constant energy`. Петля режется из середины генерации (`src_start` 1–29 с).
- Длина генерации: петли 60–90 с (в игру уходит 24–80 с), мотивы 30 с (в игру 12–24 с), стинги 8–10 с.

### 2.5. Гармония
- Мажорная или «минорная с надеждой» пентатоника: `<Key> major pentatonic` или `<Key> minor pentatonic leaning major`.
- Минор — для напряжения, Пагоды, Дуэлей и Юэ, всегда с оговоркой `hopeful edge`, `never scary`, `beautiful`.
- Джазовые септаккорды (maj7) — только у Салона. Лидийский лад — только у призыва («чудо вот-вот случится»).

---

## 3. Мотив «Пять ветров»

### 3.1. Что это
Пять нот — пять ветров: 東, 南, 西, 北 и «пятый ветер» — игрок, который сел за стол.
Мотив — звуковой логотип игры. Он звучит на загрузке, в лобби, в стингах и в первой ноте комбо. Каждая вкладка и каждая героиня держит его вариант.

**Мажор (основной):** ступени **5 – 6 – 1′ – 2′ | 1′**, «соль-ля-до-ре-до».
Интервалы: +2, +3, +2, −2 полутона. Ритм в 4/4: три восьмые затактом, потом сильная доля — 2′ четвертью с точкой, 1′ половинной до конца такта.
Три быстрые ноты вверх, долгая нота наверху и мягкая «посадка». Это «порыв ветра и улыбка».

| Тональность | Ноты | Где |
|---|---|---|
| D | A B D′ E′ – D′ | лобби, фивер, победа |
| G | D E G A – G | Путь, МТ, день рождения |
| C | G A C′ D′ – C′ | Лавка, призыв (C = F лид.) |
| F | C D F G – F | Телефон, партия |
| E | B C# E F# – E | Хана |

**Минор (бой, тайна):** ступени **1 – ♭3 – 4 – 5 | 4**, «ля-до-ре-ми-ре».
Интервалы: +3, +2, +2, −2, ритм тот же. Звукоряд тот же пентатонный, поэтому мотив узнаётся.
Пример в D minor: D F G A – G.

**Ответ (эрху):** нисходящая фраза 2′ – 1′ – 6 – 5 («ре-до-ля-соль»). Это «ветер стихает».
Ответ звучит как вторая половина фразы и как основа стинга поражения.

### 3.2. Как просить мотив у модели (дословно)
`elevenlabs_music_v2_5` нот и аудио-референсов не принимает: у модели нет `medias`, только `prompt`, `duration`, `force_instrumental`, `lyrics`, `batch_size`.
Поэтому мотив задаётся словами. Строка ниже ставится в промпт **без изменений**:

```
Built on a short, instantly hummable five-note pentatonic hook (three quick rising notes and a long held note, sol-la-do-re-do), stated by <LEAD> and answered by <ANSWER>.
```
В миноре вместо `sol-la-do-re-do` пишется `la-do-re-mi-re`. По умолчанию `<LEAD>` = `guzheng`, `<ANSWER>` = `erhu`. В бою наоборот: лид `erhu`, ответ `guzheng`.

**Честно о точности:**
- В 18 одобренных треках общий мотив буквально не закреплён: каждый трек генерировался отдельно, без строки мотива. Единство в них держится на тембрах, пентатонике и груве.
- Мотив вводится этой библией на будущее. Модель воспроизводит его как «характер хука», а не до ноты.
- Проверить мотив по полному миксу автоматически не удаётся. Тест `pyin` по гармонической части микса не выделил мелодию ни в одном из 16 треков.
- Для буквальной идентичности есть отдельный ассет (§3.4).

### 3.3. Где и как звучит мотив
| Контекст | Вариант мотива |
|---|---|
| Загрузка, титул, трейлер | целиком, соло-гучжэн, потом ответ эрху (ассет `motif_five_winds`, §3.4) |
| Лобби / Чайная | целиком в хуке, 2–4 раза за петлю |
| Вкладки-меню | 1–2 раза за петлю, в инструменте вкладки (Путь — дицзы, Лавка — пипа) |
| Партия (`match_calm`) | только ритм «три восьмые + долгая» в арпеджио — мотив не отвлекает от доски |
| Напряжение / фивер | мотив в ускорении, тремоло гучжэна или хук эрху |
| Стинг победы | мотив вверх + тоника (`ends on a big resolved chord`) |
| Стинг поражения | ответ вниз 2′–1′–6–5 без разрешения (`soft hopeful unresolved chord`) |
| Комбо T1 / T2 / T3 (HUD_V2 §7.3) | T1 — первая нота мотива в тональности текущего трека; T2 — три ноты затакта; T3 — стинг 1,4 с: мотив целиком в тембре героини |
| Лейтмотив героини | мотив в её тембре + её собственное продолжение (§5) |

### 3.4. Ассет-логотип `motif_five_winds` (буквальная версия)
Чтобы мотив был **одинаковым до ноты** везде, где это важно (загрузка, T1/T2 комбо, тональные «колокольчики вкладок» UX §7.4):
1. Сгенерировать 4 дубля `elevenlabs_music_v2_5`, `duration` 6, промпт:
   `Solo guzheng plays a single short five-note pentatonic phrase in D major: A, B, D, E held, then D, three quick rising notes and a long held note, answered once by a soft erhu sigh falling E, D, B, A. Dry close recording, warm teahouse room, no other instruments, no drums. Ends with natural ring-out. Instrumental.`
2. По соло-клипу проверить ноты: `pyin` на соло работает (в отличие от микса). Взять дубль, где интервалы +2, +3, +2, −2.
3. Нарезать отдельные ноты для T1 и затакт для T2. Транспонировать питчем под тональность трека: ±3 полутона без артефактов.

---

## 4. Вкладки: настроение, темп, тональность

Правило соседства: у двух вкладок подряд в нижнем меню расходятся темп (≥ 8 BPM) **или** жанр-костюм. Кроссфейд в игре — 0,8 с (V10Music).
**Ни одна вкладка не делит трек с другой** (BENCHMARK MD-1).

| Экран | Трек | Костюм поверх ядра | BPM | Тональность | Акценты | Настроение (слова для промпта) |
|---|---|---|---|---|---|---|
| Титул / Главная | `lobby` ✔ | anime-pop, lo-fi hip-hop | 96 | D maj pent | bell-like synth, shaker | welcoming, hopeful, instantly hummable |
| Путь / Режимы | `path` ✔ | lo-fi марш | 104 | G maj pent | koto ostinato, dizi, pizzicato | curious, optimistic, progress |
| Партия | `match_calm` ✔ | chill anime lo-fi | 88 | A min pent → maj | Rhodes, brushed snare | relaxed focus, does not distract |
| Партия, лоток ≥ 70% | `match_tense` ✔ | stylish suspense | 120 | E min | taiko, clock plucks, string stabs | urgent but stylish, never scary |
| Фивер (слой) | `fever` ✔ | anime-pop EDM | 128 | D maj | supersaw, erhu hook | euphoric, triumphant, addictive |
| Желания (призыв) | `summon` ✔ | мистическое ожидание | 90 | F lydian | celesta, harp, taiko heartbeat, wordless choir | something wonderful about to be revealed |
| Лавка | `shop` ✔ | night-market swing | 108 | C maj pent | pizzicato, pipa, woodblock, finger snaps | cute, cozy, charming; в игре на −3 дБ (UX §7.1) |
| Салон | `salon` ✔ | neo-soul / city-pop | 84 | Eb maj7 | Rhodes, upright bass, sax-like synth | luxurious, refined, romantic |
| Телефон | `phone` ✔ | bedroom lo-fi | 78 | F maj | music box, celesta, vinyl | tender, intimate, a little flirty |
| Пагода | `pagoda` ✔ | trip-hop / тайна | 82 | D dorian | dizi, temple bells, dark pads | mysterious, majestic, dangerous but beautiful |
| Дуэли / лиги / турнир | `duels` ✔ | battle-pop | 140 half-time | C min | trap hats, pipa riffs, distorted bass | bold, confident, stylish |
| **Чайная** (MD-11) | тема партнёра «в салоне» — план | её мотив в lo-fi | её темп −15…−25% | её тональность | Rhodes, rain or morning dizi | cozy, close, unhurried |
| **Героини / гардероб** | план | бутик-chill | 70–76 | Bb maj pent | harp, soft strings, guzheng harmonics | boutique, intimate, elegant |
| **Коллекция** | план | ambient lo-fi | 74 | Ab maj pent | music box, koto | nostalgic, treasured memories |
| **Профиль** | вариант `lobby` (MD-1, если не хватит бюджета) | — | 96 | — | — | — |
| **Странствие** | план | open-air | 84 | A maj pent | shakuhachi-like flute, wind, light frame drum | spacious, wandering, wind over hills |
| **Партия, финал** (мало фишек) | план — слой | lo-fi + подъём | 88 (как `match_calm`) | как `match_calm` | rising guzheng runs, risers | almost there, sparkling anticipation |
| **Ханафуда / Кой-Кой** | тест §9.4 | lo-fi с хитрецой | 100 | A min pent → maj | koto, shamisen, woodblock | playful, sly, light gambling suspense |
| **Рейд-босс** | тест §9.4 | anime battle-pop + оркестр | 150 half-time | D min | taiko ensemble, choir pads, brass-like stabs | epic, heroic, dangerous yet beautiful, never horror |
| **День рождения героини** | тест §9.4 | festive anime-pop | темп мотива героини ±6 | тональность мотива | её тембр + music box, handclaps | joyful, warm, grown-up, not childish |

✔ — одобрено и лежит в `v10-audio`.
Расхождение с UX_RULES §7.1 (там Салон 76, Лавка 100, Пагода 60, Дуэли 120 и т.д.) решается **в пользу одобренных треков**: §7.1 писался до генерации. Предлагается обновить §7.1 по этой таблице.

**Слои партии** (база → напряжение → фивер → финал) — отдельные генерации одного темпа, переключаются в V10Music.
Если нужен слой строго в той же гармонии, генерировать его так: промпт базы плюс `same groove, same key, same tempo, add <слой>`.
Ещё вариант — `separate_stems` по базе (BENCHMARK MD-1).

---

## 5. Лейтмотивы героинь

### 5.1. Правила для каждой героини (основательницы и волны)
1. **Ядро плюс подпись.** Один восточный щипковый инструмент из ядра (гучжэн, кото, гуцинь или пипа) обязателен. К нему добавляется **тембровая подпись**, которой нет ни у одной другой героини (UX §7.2: «тембры не повторяются»).
2. **Своя зона темпа и тональности.** Не ближе 6 BPM к другой героине с той же тональностью. Реестр — таблица §5.2.
3. **Характер — словами из HEROINES §5.** Крючок, черта и цвет переводятся в 3–4 прилагательных: «cheerful, playful, mischievous».
4. **Взрослость.** В промпте `adult`, `elegant`, `refined`, `grown-up`. Нельзя `kawaii`-детскость без взрослой опоры, нельзя `schoolgirl`, `cute little`.
   Одобренный `motif_mc` содержит «kawaii». В новых промптах заменять на `playful, sparkling`.
5. **Сексуальность — только словами настроения** (`alluring`, `teasing charm`, `a little flirty`) и никогда звуками (§2.3).
6. **Формат мотива:** `duration` 30, `Loopable, no fade-out. Instrumental.` В игру уходит петля 12–24 с.
7. **Производные одной героини** (все через шаблон §9.3 с её подписью):
   - **мотив** 12–24 с;
   - **«в салоне»** — Чайная (MD-11): тот же инструмент, lo-fi, темп −15…−25%;
   - **стем Азарта** — фивер, если она партнёр (UX §7.3, A-редкость);
   - **стинг победы** 3–4 с в её теме;
   - **стинг комбо T3** 1,4 с;
   - **SSR-стинг** 4–6 с (не чаще раза в 600 с);
   - **день рождения** — 75 с, §9.4;
   - **представление SSR** — стинг перед раскрытием, а перед ним 400 мс тишины (UX §7).

### 5.2. Реестр основательниц (одобрено)
| Героиня | Подпись (одобрено в `motif_*`) | Темп | Тональность | Характер для промпта | Можно добавить (UX §7.2) |
|---|---|---|---|---|---|
| Маджонг-тян | гучжэн + глокеншпиль, synth plucks, handclaps | 122 | G maj | cheerful, playful, sparkly, mischievous, very catchy | пипа, колокольчики ветров |
| Рин | кото + сякухати-флейта, мягкое пиано, капли воды, колокольчик | 72 | A min pent (C maj) | calm, graceful, refined, a hint of teasing charm | гуцинь; наливаемый чай — как SFX, не в музыке |
| Хана | anime-pop rock, пипа и гучжэн рифы, свисток-синт, хлопки | 140 | E maj | upbeat, sunny, stadium energy | акустическая гитара, свисток эстафеты |
| Юэ | гуцинь + эрху, арфа, струнные, храмовый колокол, **вальс 3/4** | 80 | D min | regal, mysterious, noble, alluring, silvery night | челеста, лунный хор (`wordless`) |
| Нова | **чиптюн**-лид + synthwave-бас + кото, глитч-арпеджио | 118 | F# min (вышло A min) | cool, confident, playful, neon night city | гучжэн через биткраш |

Расхождение с UX §7.2: там МТ — пипа, Хана — гитара, Нова — гучжэн через биткраш.
Одобренный звук главнее, поэтому подпись берётся из колонки «одобрено». Инструменты UX можно добавлять, но не заменять ими подпись.

### 5.3. Слоты для новых героинь (UX §7.2, до выхода каждой)
| Героиня | Подпись | Ядро-щипок | Темп | Тональность | Не путать с |
|---|---|---|---|---|---|
| Злата | гусли, балалайка, хор «ой» (`wordless folk choir`) | гучжэн | 108 | A min pent | Лавка 108 C maj — тональность другая |
| Минамо | арфа, подводный пэд, капли | кото | 76 | Eb maj pent | Рин (кото): другие темп и лад |
| Кира | синт-оркестр, `cinematic synth strings` | пипа | 132 | B min | Дуэли: другая тональность и без трэп-хэтов |
| Веспер | орган, клавесин (`harpsichord`) | гуцинь | 92 | G min | Юэ: 4/4, не вальс |
| Сигрид | колокольчики, хор (`wordless choir`), фрейм-драм | гучжэн | 100 | F# maj pent | Ханафуда 100 A min — тональность другая |

---

## 6. Стинги

| Стинг | Длина | Конструкция | Промпт (ключевые слова) |
|---|---|---|---|
| `sting_victory` ✔ | 9,3 с | глиссандо гучжэна вверх → медь-синт фанфара + эрху → тайко + тарелка → колокольчики → разрешённый аккорд | `triumphant rising guzheng glissando… ends on a big satisfying resolved chord with natural ring-out` |
| `sting_defeat` ✔ | 7,6 с | нисходящий гучжэн → вздох эрху → тёплый аккорд пиано → колокольчик → неразрешённый «надеющийся» аккорд | `bittersweet but encouraging, not sad or dramatic, … soft hopeful unresolved chord` |
| Победа в теме партнёра (UX §7.3) | 3–4 с | её мотив вверх + тоника | §9.3 «стинг» с её подписью |
| Комбо T3 (HUD_V2 §7.3) | 1,4 с | мотив целиком в её тембре | модель даёт минимум 3 с: генерировать 4 с, взять 1,4 с с атаки, fade-out 120 мс |
| SSR-раскрытие героини | 4–6 с | 400 мс тишины → её мотив на арфе/челесте → её подпись → сияющий аккорд | §9.3 «стинг», `radiant, awe` |
| Ранг / сундук / рекорд | 2–4 с | SFX (`mirelo_text_to_audio`), не музыка — §7 | — |

Правила для всех стингов:
- стинг начинается с атаки, без тишины в файле (тишину делает код);
- конец — естественное затухание (`natural ring-out`), петли нет;
- музыка под стингом проседает до −30 дБ (V10Music). Под T3 — −6 дБ (HUD_V2 §7.3), под голос — −8 дБ;
- стинг поражения никогда не «провал» и не «тромбон-wah-wah».

---

## 7. SFX: палитра и звуковой логотип

**Звуковой логотип** — щелчок костяной (нефритовой) фишки о дерево и сукно (UX §7).
**Материалы салона:** дерево, нефрит, фарфор, лак, бумага-сёдзи, шёлк, колокольчики ветров, тайко.
Волшебство — только искры, колокольчики, хрусталь и тёплый свет. Без «лазеров», «бзз» и синтетических ошибок.

### 7.1. Одобренный банк (36 файлов, `mirelo_text_to_audio`)
| Семейство | id | Ключ промпта |
|---|---|---|
| Фишка | `tile_click` (+b, c), `tile_select`, `tile_deny`, `shuffle` | `polished jade mahjong tile tapped on a wooden table, short satisfying clack, close-up, no reverb tail` |
| Пары | `match_1` (+b), `match_2`, `match_3`, `combo_step`, `combo_finale` | `tiles clink, then a light bright guzheng pluck with soft sparkle` / `ascending bell and guzheng arpeggio` |
| Интерфейс | `btn_press` (+b), `btn_hover`, `tab_switch`, `page_turn`, `card_flip`, `notify` | `soft rounded pop with a warm wooden click and tiny bell overtone` / `silky swish, paper slide, tiny chime` |
| Награды | `reward_pop`, `coin_fly`, `gem_fly`, `star`, `chest_open`, `rank_up` | `coin clinks`, `glassy crystal tinkles`, `brass and bell fanfare with taiko hit` |
| Сила | `fever_ignite`, `fever_end`, `ult_ready`, `ult_cast`, `cutin_whoosh`, `booster`, `undo` | `fiery whoosh rising into a powerful taiko drum hit` / `silky cloth swish` |
| Гача | `lantern_rise`, `sr_reveal`, `ssr_reveal` | `paper lantern… wind chimes and ascending harp shimmer` / `choir-like angelic pad, cascading crystal bells and harp glissando` |
| Героиня | `heart` | `soft warm sparkly chime with a gentle heartbeat thump` |

### 7.2. Шаблон SFX (`mirelo_text_to_audio`)
```
<ACTION in one clause>: <MATERIAL from the salon palette> <ARTICULATION: click / clack / pluck / swish / chime>, <optional magic: soft sparkle | tiny bell overtone | crystal shimmer>, <SIZE: short | quick | big>, <FEEL: satisfying | gentle | premium | friendly not harsh>, clean, <no reverb tail | short shimmering tail>, mobile game UI sound
```
- `duration`: щелчки 1 с (в игру 0,12–0,4 с после `--maxlen`), награды 2 с, большие моменты 3–4 с.
- Ошибка — всегда `soft muted wooden knock`, никогда `buzz`.
- Шаги лестницы комбо — один id, питч в коде (V10SfxBank.combo).
- Новые механики MD-2 (лёд, замок, цепь, хлопушка, Туман, Фонарь-срок) делаются по тому же шаблону. Материалы: лёд → `porcelain and ice crystal`, замок → `brass latch`, цепь → `small jade chain links`, Туман → `airy silk breath and wind chime`.
- Звуки нарядов (LEGWEAR: шпоры, бубенцы судзу, монеты пайала, каблук по доскам) — те же правила. Ничего «резинового» и телесного (LEGWEAR §4.2: щелчок подвязки отменён).

---

## 8. Обработка и громкость

### 8.1. Цепочка (как сделаны одобренные треки — повторять без изменений)
1. **Генерация.** `elevenlabs_music_v2_5`, mp3 44,1 кГц, стерео. `force_instrumental: true`, `batch_size: 4` (4 дубля по цене пачки).
2. **Петля.** `python3 game/scripts/v10/audio/pipeline/v10_loop.py music in.mp3 out.ogg`
   - поиск пары точек по похожести 3 с (log-mel 40 полос + хрома + атаки), с предпочтением целых тактов;
   - подгонка конца до сэмпла по корреляции;
   - equal-power кроссфейд 0,35 с внутри файла.
3. **Громкость.** Интегральная −16 LUFS (pyloudnorm, K-взвешивание), чистое усиление без компрессии.
4. **Кодек.** Ogg Vorbis q5, 44,1 кГц стерео. В `.import` указать `loop=true`.
5. **Шов.** `seam_flux_pct ≤ 85` (у одобренных 9–80). Плюс лист швов `pipeline/seams_plot.py` глазами.
6. **Стинги:** `v10_loop.py music in.mp3 out.ogg --sting` — без петли, срез тишины в начале, −16 LUFS.
   **SFX:** `… sfx in.mp3 out.ogg [--maxlen 0.2]` — −14 LUFS, пик щелчков ≤ −1 dBFS.

### 8.2. Цели громкости
| Класс | Цель в файле | Пик | В игре |
|---|---|---|---|
| Музыка (петли, мотивы) | −16 LUFS ±0,5 | рекомендуется ≤ −1 dBTP | шина `Music`. Под голосом −8 дБ, под T3 −6 дБ, под фивером база −22 дБ, под стингом −30 дБ |
| Стинги | −16 LUFS | ≤ −1 dBTP | поверх приглушённой петли |
| SFX | −14 LUFS (щелчки ниже из-за потолка пика) | ≤ −1 dBFS | `db`/`vdb` в BANK. Нажатия −20…−26, награды −15…−18, большие моменты −8…−13 (пик 100 мс, K-взвеш.) |
| Голос | −14 LUFS (UX §7.4) или как реплики героини 0.7 | ≤ −1 dBTP | музыка под репликой −8 дБ |

**Что найдено замером (исправить в polish, без регенерации):**
- У `path` (−0,6 dBFS), `motif_rin` (−0,9) и `phone` (−1,3) сэмпловый пик выше −1.
- После декодера Vorbis и ресемплинга на телефоне это может дать клип.
- Решение: в `v10_loop.py` после нормализации добавить мягкий лимитер на −1 dBTP только при превышении (`alimiter=limit=0.89:attack=5:release=50`) или опустить усиление на разницу.
- Целевые LUFS это почти не меняет.

**Расхождения документов:**
- UX §7.4 требует «пики SFX −6 dBFS», а банк сделан с потолком −1 dBFS и выравниванием в коде.
- Действует решение ветки `v10-audio`: громкость SFX задаётся в игре (`db` в BANK). Пик −6 dBFS — это ориентир *в миксе игры*, а не в файле.

### 8.3. Эквализация и спектр
- Одобренные треки **не эквализировались**. Микс генератора — часть стиля.
- Новый трек тоже не правим EQ. Если баланс полос вне коридора эталона, берём другой дубль или регенерируем.
- Коридор эталона для петель — энергия полосы относительно всего спектра, дБ, мин / медиана / макс:

| Полоса | мин | медиана | макс |
|---|---|---|---|
| < 60 Гц | −46 | −9 | −4 |
| 60–250 Гц | −9 | −3 | −2 |
| 250 Гц – 2 кГц | −11 | −5 | −1 |
| 2–6 кГц | −26 | −18 | −12 |
| > 6 кГц | −42 | −28 | −17 |

- Допустимая правка — только «мобильная»: HPF 30 Гц 12 дБ/окт (динамики телефона ниже 100 Гц не играют, а саб съедает запас по пику) и наклон не больше ±2 дБ.
- Резкость: центроид петли 750–3100 Гц. Ярче — уши устают за сессию, темнее — трек «тонет» на динамике телефона.
- Одноразовая цепочка ffmpeg, если пайплайна нет под рукой:
  `ffmpeg -i in.mp3 -af "highpass=f=30,loudnorm=I=-16:TP=-1:LRA=7:linear=true" -c:a libvorbis -q:a 5 out.ogg`
  Петля этим не режется, поэтому для петель — только `v10_loop.py`.

---

## 9. Шаблоны промптов `elevenlabs_music_v2_5`

### 9.1. Параметры
```json
{"model": "elevenlabs_music_v2_5", "duration": 75, "force_instrumental": true, "batch_size": 4, "prompt": "<ШАБЛОН>"}
```
- `duration`: петля вкладки 75 (лобби/Чайная 90), мотив 30, стинг 8–10, логотип 6.
- `batch_size: 4` — 4 дубля за раз, из них ворота (§10) и критик выбирают один.
- Цена по `estimate_audio_cost` на 2026-11-24: **43,6 кр** за 75 с × 4 дубля.
- Длина промпта 600–1100 символов. Длиннее не нужно: модель теряет хвостовые требования (`no fade-out`).

### 9.2. Мастер-шаблон петли (дословно; `<…>` — слоты)
```
<PURPOSE> music for a premium anime mahjong game set in the Five Winds teahouse, a magical East-Asian world: <SCENE>. <MOOD>. Lead melody on <LEAD>, <ANSWER> countermelody, warm <KEYS> chords, soft analog synth pads, <DRUMS>, <BASS>, <ACCENTS>. Built on a short, instantly hummable five-note pentatonic hook (three quick rising notes and a long held note, <MOTIF_SYLLABLES>), stated by <LEAD_SHORT> and answered by <ANSWER>. <COSTUME> fusion with traditional Chinese instruments, <BPM> BPM<FEEL>, <KEY>. Same sonic identity as a teahouse anime-pop soundtrack (guzheng, erhu, warm piano, soft synths). <ENERGY> energy throughout, seamless loop: no intro, no fade-in, no fade-out, no ending, starts directly on the groove. Instrumental only.
```

**Словарь слотов** (брать из таблиц §4–5 и HEROINES; не придумывать новые инструменты вне §2.2):

| Слот | Что писать | Примеры |
|---|---|---|
| `<PURPOSE>` | экран или событие | `Main lobby theme`, `Calm puzzle gameplay`, `Raid boss battle`, `Heroine birthday celebration` |
| `<SCENE>` | 1 предложение — место и действие в мире «Пяти ветров» | `walking along a lantern-lit mountain path` |
| `<MOOD>` | 3–5 прилагательных + страховка | `Joyful, warm, festive, grown-up, not childish` / `…, never scary` / `…, never horror` |
| `<LEAD>` | щипок ядра + удвоение | `bright guzheng doubled by bell-like synth`, `plucky koto and guzheng`; в бою `a soaring heroic erhu` |
| `<LEAD_SHORT>` | одно слово | `guzheng` / `erhu` |
| `<ANSWER>` | смычок ядра | `erhu`; в бою `guzheng` |
| `<KEYS>` | пиано-семейство | `piano` / `Rhodes piano` |
| `<DRUMS>` | бит по зоне темпа §2.4 | `light lo-fi hip-hop drums with shaker` · `soft lo-fi drums with brushed snare` · `driving 120 BPM beat with tight hi-hats and taiko accents` · `128 BPM four-on-the-floor kick` · `massive taiko ensemble with punchy hybrid drums and trap hi-hats` |
| `<BASS>` | | `gentle bass` · `round sub bass` · `warm upright-style bass` · `pulsing synth bass` · `distorted synth bass` (только бой) |
| `<ACCENTS>` | 1–3 из §2.2 | `pizzicato strings, woodblock, finger snaps` |
| `<MOTIF_SYLLABLES>` | мажор / минор | `sol-la-do-re-do` / `la-do-re-mi-re` |
| `<COSTUME>` | жанр-костюм | `Anime-pop`, `Chill anime lo-fi`, `Anime battle-pop`, `Neo-soul and city-pop`, `Anime-pop EDM` |
| `<BPM>` / `<FEEL>` | зона §2.4; `<FEEL>` = `` или ` half-time feel` | `96`, `150 half-time feel` |
| `<KEY>` | пентатоника | `D major pentatonic`, `A minor pentatonic leaning major`, `D minor` |
| `<ENERGY>` | | `Steady` · `Constant high` (бой; тогда хвост `starts directly at full energy`, плюс `no build-up`) |

### 9.3. Короткие шаблоны
**Мотив героини** (30 с):
```
Character theme for <NAME>, <AGE-NEUTRAL ROLE: e.g. a calm graceful tea-ceremony mistress>, an elegant adult heroine of the Five Winds teahouse: <3–4 TRAIT ADJECTIVES>. <SIGNATURE INSTRUMENTS> with <CORE PLUCK: guzheng | koto | guqin | pipa>, <1–2 ACCENTS>, <DRUMS>, built on a short five-note pentatonic hook (three quick rising notes and a long held note, <MOTIF_SYLLABLES>), very catchy short hook, <BPM> BPM<, 3/4 waltz feel — только Юэ>, <KEY>. Same teahouse anime-pop sonic identity. Loopable, no intro, no fade-out. Instrumental.
```

**Стинг** (8–10 с):
```
Short <victory fanfare | gentle defeat | radiant SSR reveal | heroine signature> jingle for an anime mahjong game set in the Five Winds teahouse, <N> seconds: <SHAPE: rising guzheng glissando… / soft descending guzheng phrase…>, <CORE+SIGNATURE>, <ACCENTS>, <MOOD: joyful anime-pop | bittersweet but encouraging, not sad or dramatic>, five-note pentatonic hook <rising | falling>, <KEY>, ends on <a big satisfying resolved chord | a soft hopeful unresolved chord> with natural ring-out. Instrumental.
```

**Слой партии** (той же генерацией нельзя, поэтому максимально тот же промпт):
```
<полный промпт базового слоя без изменений> Layer variant: same groove, same key, same tempo, same instruments, now <with rising guzheng runs and risers, sparkling anticipation | with taiko accents and staccato erhu ostinato, urgent but stylish>.
```

### 9.4. Три тестовых примера (Ханафуда, рейд-босс, день рождения)
Промпты собраны строго по мастер-шаблону §9.2. Лежат в `tools/audio/test_requests.json` и `scratchpad/av/music_tests/requests.json`.

> **Статус: НЕ СГЕНЕРИРОВАНЫ.** Вызов `generate_audio_batch` в этой сессии запретила авто-проверка разрешений: трата кредитов требует явного «да» владельца.
> Цена — 3 × 43,6 = **≈131 кр** (баланс на момент записи 1814,82). Ворота §10 для них готовы и проверены на эталоне.
> Значит, «протестирован» пока только инструмент отбора. Сами промпты пройдут проверку после одобренного прогона.

**A. Ханафуда / Кой-Кой** — 100 BPM, A min pent → maj, мотив `sol-la-do-re-do`:
```
Hanafuda flower-card mini-game (Koi-Koi) music for a premium anime mahjong game set in the Five Winds teahouse, a magical East-Asian world: two elegant adult players turn painted flower cards of the twelve months under paper lanterns, deciding whether to push their luck. Playful, sly and charming with light gambling suspense, seasonal and flowery, never dark. Lead melody on plucky koto and guzheng, erhu countermelody, warm piano chords, soft analog synth pads, light lo-fi hip-hop drums with brushed snare, woodblock and finger snaps, round upright-style bass, shamisen accents and pizzicato strings. Built on a short, instantly hummable five-note pentatonic hook (three quick rising notes and a long held note, sol-la-do-re-do), stated by guzheng and answered by erhu. Anime-pop fusion with traditional East-Asian instruments, 100 BPM, A minor pentatonic leaning major. Same sonic identity as a teahouse anime-pop soundtrack (guzheng, erhu, warm piano, soft synths). Steady energy throughout, seamless loop: no intro, no fade-in, no fade-out, no ending, starts directly on the groove. Instrumental only.
```

**B. Рейд-босс** — 150 half-time, D minor, мотив `la-do-re-mi-re`, лид эрху:
```
Raid boss battle music for a premium anime mahjong game set in the Five Winds teahouse, a magical East-Asian world: all the heroines join forces against a colossal storm-dragon spirit above the Moon Pagoda. Epic, heroic and urgent, powerful but stylish anime battle energy, dangerous yet beautiful, never horror. Lead melody on a soaring heroic erhu, fast guzheng tremolo countermelody, driving piano ostinato, soft analog synth pads, massive taiko ensemble with punchy hybrid drums and trap hi-hats, distorted synth bass, swelling strings, brass-like synth stabs and wordless choir pads. Built on a short, instantly hummable five-note pentatonic hook (three quick rising notes and a long held note, la-do-re-mi-re), stated by erhu and answered by guzheng. Anime battle-pop fusion with traditional Chinese instruments, 150 BPM half-time feel, D minor. Same sonic identity as a teahouse anime-pop soundtrack (guzheng, erhu, warm piano, soft synths). Constant high intensity, seamless loop: no intro, no build-up, no fade-out, no ending, starts directly at full energy. Instrumental only.
```

**C. День рождения героини** (пример — Маджонг-тян) — 116 BPM, G maj pent, её подпись + music box:
```
Heroine birthday celebration music for a premium anime mahjong game set in the Five Winds teahouse, a magical East-Asian world: a cozy surprise party for Mahjong-chan, the cheerful jade-and-sakura hostess, with cake, paper lanterns and confetti. Joyful, warm, sweet and festive, a little mischievous, celebratory and grown-up, not childish. Lead melody on bouncy guzheng doubled by glockenspiel, erhu countermelody, warm piano chords, soft analog synth pads, light bouncy pop drums with handclaps and shaker, gentle bass, playful pipa plucks, wind chimes and music-box sparkles. Built on a short, instantly hummable five-note pentatonic hook (three quick rising notes and a long held note, sol-la-do-re-do), stated by guzheng and answered by erhu. Anime-pop fusion with traditional Chinese instruments, 116 BPM, G major pentatonic. Same sonic identity as a teahouse anime-pop soundtrack (guzheng, erhu, warm piano, soft synths). Steady energy throughout, seamless loop: no intro, no fade-in, no fade-out, no ending, starts directly on the groove. Instrumental only.
```
Для другой героини меняются: имя и роль, подпись (§5.2), темп (её мотив ±6) и тональность (её мотив).

**Как прогнать** (после согласия владельца):
1. `generate_audio_batch` с `requests` из `tools/audio/test_requests.json`, затем `jobs_wait`.
2. Скачать 12 mp3 → `v10_loop.py music` → ogg в `scratchpad/av/music_tests/`.
3. `python3 -I tools/audio/gate.py <эталон> loop:100:koikoi_a.ogg … loop:150:raid_a.ogg … loop:116:bday_a.ogg …`.
4. Из прошедших оставить по одному лучшему на тему (критик по §11). Не прошедшие удалить.

---

## 10. Ворота стиля (ухо-прокси)

`tools/audio/` (Python, CPU, ~40 с на трек):
- `analyze.py` — LUFS, пик, LRA≈, BPM (librosa), тональность (Крумхансль по CQT-хроме гармонической части), доля пентатоники, центроид, полосы, гармоническая доля, ширина, атаки/с.
- `style_check.py` — **CLAP** (`laion/larger_clap_general`) даёт эмбеддинг трека по окнам 10 с.
  - косинус с центром эталона и с ближайшим эталонным треком;
  - zero-shot теги: инструменты ядра и «чужие» жанры (`OFF_*`: рок, метал, кантри, вокал, дабстеп, хоррор, классика);
  - `identity` = средний тег ядра (guzheng, erhu, chinese, anime, pads) минус средний `OFF_*`.
  - Чекпойнт `laion/larger_clap_music` на HF сломан (logit_scale ≈ 0, все косинусы ≈ 0) — не использовать. Нужен `transformers<5`.
- `gate.py` — пороги и вердикт PASS/FAIL. Запуск: `gate.py <папка эталона> kind:bpm:file …`.
  `kind` = `loop` | `ambient` | `motif` | `sting`. У `ambient` несовпадение BPM — только предупреждение.

**Пороги** (петли и мотивы; для стингов — только CLAP-центр ≥ 0,55, identity и пентатоника):
| Метрика | Порог | Эталон (min…max) | Прототипы 0.7 |
|---|---|---|---|
| CLAP косинус с центром | ≥ 0,70 | 0,72…0,91 | 0,36…0,67 |
| CLAP косинус с ближайшим | ≥ 0,76 | 0,76…0,92 | 0,56…0,76 |
| `OFF_*` в топ-3 тегов | нет | нет | 5 из 6 |
| identity | ≥ 0,05 | 0,055…0,186 | 0,03…0,12 |
| BPM | ±4% от промпта (×2, ×½, ×1,5) | 15/16 | — |
| Гармоническая доля | 0,70…0,97 | 0,72…0,96 | 0,98 (нет бита) |
| Ширина side/mid | ≤ 0,85 | 0,14…0,79 | 0,90…1,25 |
| Центроид | 750…3100 Гц | 807…2896 | 1111…1613 |
| Пентатоника | ≥ 0,45 | 0,46…0,75 | 0,63…0,73 |
| LUFS / пик | −16 ±0,5 / ≤ −0,5 dBFS | (предупреждение) | |

**Проверка самих ворот:**
- **Эталон, leave-one-out** (каждый трек против остальных 17): **18/18 PASS**. `summon` проходит как `ambient`; как `loop` он падал бы по BPM.
- **Контроль — 6 старых треков 0.7** (`game/assets/music/*.ogg`, `v07/daynight/*.ogg`): **0/6 PASS**. Причины: CLAP 0,36–0,67, нет бита, широкое стерео, хоррор и кантри в тегах.
- Метрика различает «наш» и «не наш» звук с запасом. Пограничный случай один: `v07_menu_morning` — ближайший 0,759 при пороге 0,76.

**Чего ворота не ловят** (это работа критика, §11):
- точный мотив;
- красоту и «цепляет ли» хук;
- щелчки и артефакты генерации;
- вокал на 2–3 секунды;
- характер героини.

---

## 11. Чек-лист нового трека

**До генерации:**
- [ ] Экран или героиня есть в §4 / §5. Если нет — сначала строка в таблице: темп, тональность, костюм, подпись. Соседи не совпадают.
- [ ] Промпт собран по §9.2 / §9.3. Ядро (гучжэн/кото + эрху + пиано/Rhodes + пэды) и строка-якорь `Same sonic identity…` на месте.
- [ ] Строка мотива на месте: мажор `sol-la-do-re-do` или минор `la-do-re-mi-re`.
- [ ] Для петли: `seamless loop, no intro, no fade-in, no fade-out, no ending`. Для стинга: `natural ring-out`.
- [ ] Нет запретов §2.3: слов, вокала, имён артистов, чужих мелодий, `kawaii`/`schoolgirl`, хоррора.
- [ ] `force_instrumental: true`, `batch_size: 4`, нужная `duration`. Цена — `estimate_audio_cost`.

**После генерации (каждый дубль):**
- [ ] `v10_loop.py` → ogg −16 LUFS. Для петли `seam_flux_pct ≤ 85` и лист швов глазами.
- [ ] Пик ≤ −1 dBTP (иначе лимитер, §8.2).
- [ ] `gate.py` → PASS.
- [ ] Критик в наушниках и на динамике телефона:
  - [ ] ядро слышно в первые 10 с;
  - [ ] хук запоминается после 2 прослушиваний;
  - [ ] нет вокала, слов и «оханий»;
  - [ ] нет клипа, щелчков и «плывущего» темпа;
  - [ ] на шве не меняется ни такт, ни громкость;
  - [ ] не страшно и не грустно «в провал»;
  - [ ] трек не спорит с SFX партии: щелчок фишки слышен поверх музыки на −20 дБ.
- [ ] Переход с соседних вкладок (кроссфейд 0,8 с) не режет ухо: прогнать в `v10_audio_demo.tscn`.
- [ ] Для героини: тембровая подпись не повторяет чужую, характер узнаётся без картинки.

**Оформление:**
- [ ] Файл, `.import` с `loop=true`, `build_manifest.py` (job id обязателен — это доказательство происхождения), самотест `V10AUDIO OK`.
- [ ] Промпт и job id → `tools/audio/approved_music_prompts.json`. Строка в таблице §1 (замер `analyze.py`).
- [ ] Одобренный трек кладётся в папку эталона. Ворота сами подтягивают новый центр стиля.
- [ ] Строка в UX §7.1/§7.2, если появился новый экран или новая героиня.

---

## 12. Открытые вопросы владельцу
1. Обновить UX_RULES §7.1 (темпы вкладок) и §7.2 (подписи героинь) по одобренным трекам (§4, §5.2 здесь)? Предлагается «да».
2. Разрешить прогон 3 тестовых треков §9.4 (≈131 кр) и ассета-логотипа `motif_five_winds` §3.4 (≈4 кр)?
3. Добавить в `v10_loop.py` лимитер −1 dBTP при превышении (касается `path`, `motif_rin`, `phone`)?
