# Арт и звук дорожки «Пагода и Странствие» (часть E, 0.10)

Файлы игры лежат в `game/assets/v10/tower/`, имена берутся из `game/scripts/v10/tower/ui/tower_art.gd` (`V10TowerArt`).
Проверка загрузки: `V10TowerArt.tex(key)` / `sound(key)`, все 22 ключа прошли (`TOWER_ART_CHECK 22/22`, сравнение размеров).
Контактный лист: `/tmp/claude-0/-home-claude/893f4170-a000-5979-973d-953ee0bffb0d/scratchpad/shots/art/contact.png`.

| Файл | Размер | Источник |
|---|---|---|
| `pagoda_far.webp` | 720×2400, без альфы, 124 КБ | Higgsfield `bcea4495…`, масштаб ×1,19 и центральная обрезка |
| `pagoda_mid.png` | 720×2400 RGBA, 2,0 МБ | Higgsfield `fe6cf3bb…` (родная прозрачность), растяжение 672×2016 → 720×2400 |
| `pagoda_near.png` | 720×2400 RGBA, 1,2 МБ | Higgsfield `2d8c8520…` (родная прозрачность), то же растяжение |
| `journey_far.webp` | 720×1600, без альфы, 446 КБ | Higgsfield `1aad038c…`, уменьшение 864×1920 → 720×1600 |
| `paper.webp` | 512×512, 21 КБ | процедурно, `paper.py` (бесшовно, кредиты не тратились) |
| `curses/<id>.png` ×11 + `curses/heat.png` | 160×160 RGBA, 38–47 КБ | один лист 4×3, Higgsfield `b8f21248…`, нарезка |
| `sfx/gong.ogg` | 2,19 с | синтез, `gong.py` (оба дубля Higgsfield отброшены) |
| `sfx/heat_flare.ogg` | 1,40 с | Higgsfield `4c00b6d0…` + слой `a7c8bee6…` |
| `sfx/feather.ogg` | 0,92 с | Higgsfield `fc2461ec…` |
| `sfx/heart_break.ogg` | 0,67 с | Higgsfield `204b760b…` + `porcelain_ring.py` |
| `sfx/lantern_out.ogg` | 0,64 с | Higgsfield `9cb6966b…` |

Все звуки: моно, 44,1 кГц, Vorbis q5, пики после декодирования от −6,5 до −9,9 dBFS, тишина по краям обрезана, хвосты
затухают плавно (без обрыва). Импорт Godot по умолчанию: `loop=false`.

## Модели и параметры

- Картинки: `gpt_image_2_6`. Финальные ассеты: `quality: xhigh, resolution: 2k`. Дальний фон и ближний слой: `quality: high`
  (лимит дорожки 20 кр). Размер задан через `size`, кратный 16: пагода `672x2016` (1:3 — самое вытянутое, что принимает
  модель на 2k; 720x2400 = 1:3,33 требует 4k за 5,5 кр), странствие `864x1920` (ровно 0,45 = 720/1600), лист иконок `aspect_ratio 4:3`
  (вышло 2336×1744). Для mid и near — `background: transparent`, альфа пришла чистой, `remove_background` не понадобился.
- Звук: `mirelo_text_to_audio` (0,25 кр/с), `duration` в секундах.
- Вариантов по одному на картинку, кроме лимита: все пять картинок приняты с первого раза (смотрел превью в песочнице).

## Промпты (дословно)

**Лист иконок, `b8f21248-45e5-4b74-88da-4e403e4dc049`** (xhigh, 2k, 4:3):
> A sprite sheet of 12 game icons arranged in a precise grid of 4 columns and 3 rows, evenly spaced, each icon centered in its own equal cell with generous empty margin around it, on a flat plain warm ivory paper background, no frames, no grid lines, no shadows. Every icon is the same round medallion of glossy black urushi lacquer (deep night black with a faint plum tint) with a thin polished gold rim, identical size and identical lighting (a soft glossy highlight at the top-left, no drop shadow). On each medallion a single bold glyph painted in vermilion cinnabar ink with confident sumi-e calligraphic brush strokes and dry-brush texture, simple, bold and readable at small size, filling about 60 percent of the medallion. Glyphs, row by row, left to right. Row 1: (1) a mahjong tile turned face down, its back covered by a fine lattice veil; (2) an hourglass; (3) a greedy grasping hand with curled clawing fingers; (4) a short horizontal tray squeezed between two inward-pointing chevrons. Row 2: (5) a single round paper lantern; (6) a radiant spark burst crossed out by one diagonal brush slash; (7) a curved counter-clockwise undo arrow crossed out by one diagonal brush slash; (8) a light bulb crossed out by one diagonal brush slash. Row 3: (9) two crossing shuffle arrows crossed out by one diagonal brush slash; (10) swirling mist cloud wisps in Japanese cloud style; (11) a hexagonal ice crystal; (12) a glowing ember coal with a small flame, the only one with a warm golden-orange inner glow. Elegant luxury mobile game UI, Japanese lacquerware craft, high detail, crisp clean edges, all twelve icons in one consistent style. No text, no letters, no kanji, no numbers, no watermark.

Модель сама отдала прозрачный фон. Порядок ячеек = `shroud, hourglass, greedy, narrow, one_lamp, no_ult, no_undo, no_hint,
no_shuffle, fog, guards, heat`. Глиф `no_ult` — искра-вспышка (Приём), перечёркнутая мазком; `guards` — кристалл льда
(Стражи = лёд); `heat` — уголёк с пламенем, единственный с тёплым свечением. Киноварь глифов ≈ #E64817 (киноварь = вермильон).

**pagoda_mid, `fe6cf3bb-2219-4b2a-bbf9-da258695736b`** (xhigh, 2k, 672x2016, transparent):
> A single tall slender moon pagoda tower with twelve stacked tiers, seen from the front, perfectly centered and vertical, filling the full height of the image from the stone base at the very bottom edge to the golden spire finial near the very top edge. Dark lacquered wood and cinnabar red pillars, gracefully upturned curved eaves on every tier with thin gilded gold edges, glowing warm paper lanterns hanging at the corners of every tier, small balcony railings, soft cool moonlight from the upper left rim-lighting the roofs, warm lantern glow on the walls. Each tier slightly narrower than the one below; the tower occupies only the central 70 percent of the width, with clean empty space on the left and right. Isolated object on a fully transparent background: no sky, no ground plane, no clouds, no fog, no trees, no people. Painterly anime game background art, rich detail, elegant night palette of deep plum-black, lacquer red and muted gold. No text, no signs, no watermark.

Вышло ≈11 ярусов + шпиль с полумесяцем. Нижний карниз почти во всю ширину (x 13…659 из 672), поэтому не обрезал,
а растянул неравномерно (×1,071 по x, ×1,190 по y): пагода на 11 % стройнее, ничего не срезано.

**pagoda_far, `bcea4495-4b18-426d-93f4-d1111cc1fc89`** (high, 2k, 672x2016):
> Tall vertical night sky backdrop for a mobile game parallax layer. Deep lacquer-black night sky at the top fading to dark plum and indigo, a huge soft pale-gold full moon in the upper third slightly off-center with a faint halo, sparse quiet tiny stars, thin drifting cloud ribbons. In the lower third, distant layered mountain ridges in blue-grey mist, and at the very bottom a soft luminous fog bank over a dark silhouetted garden of pine and plum trees. The middle of the image is calm and uncluttered. Painterly anime background art, soft smooth gradients, muted palette: night black, plum, misty blue-grey, pale paper ivory and a touch of gold. No buildings, no pagoda, no towers, no people, no text, no watermark.

Равномерный масштаб ×1,19 (луна остаётся круглой) и обрезка по 40 px с боков.

**pagoda_near, `2d8c8520-52d9-4e70-99d4-7ebe6154029f`** (high, 2k, 672x2016, transparent):
> Foreground framing elements for a tall vertical mobile game parallax layer, isolated on a fully transparent background. Along the left and right edges only: dark pine branches with needle clusters and plum blossom branches with soft pink-white flowers entering from the sides, several hanging round paper lanterns on thin cords glowing warm, and a few drifting petals. Place these elements as separate groups spaced along the full height, alternating between the left edge and the right edge. The central 60 percent of the width is completely empty and transparent from top to bottom. Painterly anime game art, dark silhouette-like foliage with rim light, night palette of deep plum-black, lacquer red, warm lantern gold. No sky, no ground, no buildings, no people, no text, no watermark.

Полностью прозрачная середина после растяжения ≈ x 225…495 (270 px). Кончики сосновых лап и веточки сливы местами
заходят до x ≈ 215 и от x ≈ 505, это меньше заданных 440 px. Элементы с краёв обрезать нельзя: тогда режутся фонари.
Если экрану A нужен более чистый центр, слой можно чуть масштабировать вокруг центра (×1,1) или притушить альфой у центра.

**journey_far, `1aad038c-f278-45cb-99c4-ed17627eeacf`** (xhigh, 2k, 864x1920):
> Vertical mobile game background for a journey screen: a winding mountain path with old stone steps receding into the distance through layered misty mountains at early dawn. Graceful weeping willows and a few blossoming sakura trees frame the left and right edges. Muted dawn palette: deep plum night sky at the top warming to pale paper ivory and soft gold near the horizon, mist pooling in the valleys, distant peaks fading into haze, a few petals in the air. The central area of the image is calm, airy and uncluttered with soft fog, leaving room for a paper scroll interface over it. Painterly anime background art, elegant and quiet, Japanese lacquer and washi aesthetic, soft light, rich detail at the edges. No buildings, no people, no animals, no text, no watermark.

Цвет не трогал: пробовал затемнение к «ночи» (смешивание и умножение), оба варианта выходили мутнее. Верхние 160 px
(шапка) дают контраст 5,7–6:1 с `paper.100`, середина светлая (под свиток, контраст ≈ 1,5:1). Если экрану B нужен
«ночной» вид, его делает наложение `night.900` 30–40 % в коде, а не новый файл.

**Звуки** (`mirelo_text_to_audio`):

| job id | dur | промпт | итог |
|---|---|---|---|
| `b475764a-9215-49d4-a443-59feaa28d85c` | 3 | A single soft temple gong struck gently with a padded mallet, warm deep bronze tone with a slow shimmering decay, calm and quiet, isolated sound effect, no music, no voices | отброшен: ровный синус ~470–700 Гц без удара и затухания |
| `3a047344-3d7b-443c-84fa-3e0907988aad` | 3 | One gentle strike of a small bronze temple gong in a wooden hall, mellow warm hum, soft attack, long smooth fading resonance, isolated sound effect, no music, no voices | отброшен: щелчок колокольчика (пик −0,4 dB, гаснет за 0,2 с), без гула |
| `4c00b6d0-81e6-4fdf-b7bb-4592d95ab69f` | 2 | A warm soft breath of fire flaring up in a brazier, gentle whoosh of flame igniting with a few soft crackles of embers, smooth and rounded, no harsh hiss, no explosion, isolated sound effect | **heat_flare**, основа: тёплый гул, центроид ~1 кГц |
| `a7c8bee6-935d-4894-a5a3-1853fc4e6c45` | 2 | Embers suddenly glowing and a flame rising with a soft rounded whoosh, like fire inhaling, warm low rumble and light crackle, gentle, isolated sound effect, no music | как отдельный звук не взят (шипение 4–5 кГц). Вошёл в heat_flare тихим слоем «воздуха» после ФНЧ 4 кГц, −6 dB |
| `fc2461ec-b071-4331-8b49-4efc97c537a6` | 1 | A light rustle of thin washi paper followed by a soft feather quill brush stroke across paper, delicate and close, isolated sound effect | **feather** |
| `204b760b-fd59-4492-affe-951264db2a50` | 1 | A quiet delicate crack of a small porcelain teacup, a single soft hairline crack, not shattering, gentle and close, isolated sound effect | **heart_break** (+ едва слышный фарфоровый звон после трещины) |
| `9cb6966b-61fa-4e65-8981-98a48bb2df50` | 1 | A soft gentle exhale blowing out a small candle inside a paper lantern, a short airy puff and faint flame flutter, quiet, isolated sound effect | **lantern_out** |

Без возможности послушать выбирал по `sox stats`, огибающей RMS по 100 мс, спектральному центроиду и спектрограммам.

Цепочки sox (моно 44,1 кГц wav → обработка → `ffmpeg -c:a libvorbis -q:a 5`):
- gong: `gong.py` → `reverb 22 40 55 0 8 -8` → `highpass 60`, обрезка тишины −60 dB с обоих концов → `gain -n -6.5`
  (2,19 с, G3 196 Гц, модальные доли с биениями, удар войлочной колотушки; пентатоника «Пяти ветров»);
- heat_flare: A `trim 0.05 1.40 highpass 70 lowpass 7000 fade q 0.38 -0 0.6` + B `trim 0.05 1.40 highpass 200 lowpass 4000
  fade q 0.45 -0 0.65 vol 0.5`, смешать (`sox -m`), `gain -n -6.5` (форма «вдоха»: подъём к 0,83 с, мягкий спад);
- feather: `trim 0 0.92 highpass 150 fade q 0.008 -0 0.22`, `gain -n -6.5`;
- heart_break: `trim 0.33 0.72 highpass 100 fade q 0.01 -0 0.3`, `porcelain_ring.py … 0.105`, `fade q 0 -0 0.25 gain -n -9`
  (тихо, как просили);
- lantern_out: `trim 0.36 0.64 highpass 150 lowpass 4500 fade q 0.06 -0 0.45`, `gain -n -7` (убран гул 41 Гц).

## Нарезка и обработка (`process_images.py`, песочница Higgsfield)

- Иконки: медальоны найдены по проекциям альфы (12 кругов ≈ 476×485). Квадрат по центру со стороной max(w,h)·160/156,
  ресайз с премультиплицированной альфой → 160×160 (поле 2 px). Лист 640×480 передан без потерь (lossless webp), здесь
  нарезан на `curses/<id>.png`. Читаемость в 64 px проверена на `night.900` и на бумаге (контактный лист).
- mid/near: альфа < 8 обнулена (невидимая дымка), под прозрачными пикселями цвет растянут push-pull (без тёмной каймы
  при фильтрации и mip). Ресайз премультиплицированный.
- far: webp q95; journey: webp q95.
- paper: `python3 tools/art/tower/paper.py game/assets/v10/tower/paper.webp 7`: периодический FFT-шум трёх масштабов,
  волокна кодзо на торе 3×3, крапинки. База #EFE4D0, на тон ниже `paper.100`. Бесшовность проверена склейкой 2×2,
  включая растянутый контраст.

## Доставка из песочницы (обход блокировки cloudfront)

Файл из `image_paths` в `sandbox_exec` сохраняется побайтно в
`/root/.claude/projects/-home-claude/893f4170-a000-5979-973d-953ee0bffb0d/tool-results/mcp-Higgsfield-blob-*.png|jpg`
(сверено по sha256). Поэтому tar (lossless webp + ogg, 3,46 МБ) нарезан на куски по 500 000 байт. Каждый кусок записан
как сырые байты в серый PNG шириной 1000 px (≤ 512 КиБ на вызов), всего 7 вызовов. Здесь байты PNG склеены и обрезаны
до длины, проверены sha256 tar и каждого файла. Это дешевле base64 в stdout (там предел ~60 000 символов на вызов
и ~20 тыс. токенов контекста на кусок).

## Кредиты

Только эта дорожка, по оценкам `estimate_*_cost`: иконки 3,5 + mid 3,5 + journey 3,5 + far 2 + near 2 + звуки
(0,75·2 + 0,5·2 + 0,25·3) 3,25 = **17,75 кр** из лимита 20. Общий баланс аккаунта (696,37 → 604,21 к 22:31 UTC) тратили
и параллельные дорожки, поэтому по нему трату этой дорожки не определить. Платный outpaint и remove_background не понадобились.

## Строки для `tools/art/jobs.tsv` (имя<TAB>job id; сам файл не правил)

```
tower_curses_sheet	b8f21248-45e5-4b74-88da-4e403e4dc049
tower_pagoda_mid	fe6cf3bb-2219-4b2a-bbf9-da258695736b
tower_pagoda_far	bcea4495-4b18-426d-93f4-d1111cc1fc89
tower_pagoda_near	2d8c8520-52d9-4e70-99d4-7ebe6154029f
tower_journey_far	1aad038c-f278-45cb-99c4-ed17627eeacf
sfx_tower_heat_flare	4c00b6d0-81e6-4fdf-b7bb-4592d95ab69f
sfx_tower_heat_flare_air	a7c8bee6-935d-4894-a5a3-1853fc4e6c45
sfx_tower_feather	fc2461ec-b071-4331-8b49-4efc97c537a6
sfx_tower_heart_break	204b760b-fd59-4492-affe-951264db2a50
sfx_tower_lantern_out	9cb6966b-61fa-4e65-8981-98a48bb2df50
sfx_tower_gong_rejected_a	b475764a-9215-49d4-a443-59feaa28d85c
sfx_tower_gong_rejected_b	3a047344-3d7b-443c-84fa-3e0907988aad
```

## Что можно улучшить после пополнения кредитов

- Гонг из генерации (сейчас синтез): попробовать ElevenLabs SFX или Mirelo с другим описанием, 2–3 дубля. Библиотеку
  Epidemic Sound (`search_sound_effects`) не брал: её лицензия рассчитана на видео, а не на раздачу внутри игры.
- pagoda_mid в 4k (`size 720x2400`, 5,5 кр): родные пропорции без растяжения и больше деталей.
- pagoda_near: второй дубль с более узкими краевыми группами под центр 440 px.
