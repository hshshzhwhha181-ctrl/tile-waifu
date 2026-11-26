# hudfx SFX — источники и обработка

Все исходники: Higgsfield `mirelo_text_to_audio` (FAL, 0,25 кр/с), mp3 44,1 кГц моно, 2026-11-24. Job id — также в `tools/art/jobs.tsv` (`sfx_<name>`).
Формат файлов: Ogg Vorbis q5, моно, 44,1 кГц. Пик после декодирования ≤ −6 dBFS (peak-нормализация −6,3 dBFS по UX_RULES §7.4, перекодировано libvorbis q5, высота pluck не менялась; пики — в peaks.json). Тишина в начале < 10 мс (порог −50 dB). Короткий хвост fade-out.
Громкость выровнена по «пику 100 мс, K-взвеш.» (как в AUDIO_BIBLE §8.2): L100 = −12 ±0,3. Исключения: `silk_close` на 1,5 LU тише (так задано: «мягче»).
`odometer_tick` упирается в потолок пика: L100 −22 при пике −1,3 dBFS (щелчок, «ниже из-за потолка пика»). Тихий уровень в игре задаёт `db` в коде.

## Файлы

| Файл | Длина | Пик, dBFS | Job id (исходник) | Промпт (дословно) | Обработка |
|---|---|---|---|---|---|
| `pluck.ogg` | 1,35 с | −2,1 | `15556102-5f7c-48dd-8650-7f9e825a5b70` (2 с) | One single guzheng string plucked once and left to ring: a clean clear pitched note with warm round tone and natural decay, solo, only one note, no melody, no other instruments, close-up studio recording, mobile game UI sound | Тело ноты пересинтезировано: 13 гармоник с амплитудами, снятыми с дубля (окно 30–500 мс), наклон −1,2 дБ/гармонику, T60 основного тона 1,3 с, верхние гаснут быстрее; поверх — настоящий щипок дубля (30 мс, ВЧ > 1,5 кГц). Нота C4. Почему: оба дубля содержат вторую ноту (≈ 430 Гц) или биения ±9 Гц, чистой одиночной ноты нет |
| `ring_ready.ogg` | 0,8 с | −3,6 | `e386ba1d-be43-4dde-8e56-51021e0a4115` (2 с) | Small brass singing bowl struck once with a soft felt mallet: warm pure sustained resonant tone with gentle ringing, soft, premium, clean, mobile game UI sound | 0–0,8 с, полоса 150 Гц–3,2 кГц, мягкая атака 0→1 за 340 мс («вдох»), затухание 260 мс. Тон G (196 Гц, гармоники 393/589/980) |
| `lantern_ignite.ogg` | 0,6 с | −1,3 | `1e4c0cf9-bde5-4256-8478-f54c647abd41` (1 с) + `e386ba1d-…` | (ветер, см. `wind_whoosh`) + (чаша, см. `ring_ready`) | «Ууф»: шум дубля ветра, полоса скользит 260→820→380 Гц, атака 35 мс, спад τ 120 мс. Стеклянный звон: чаша на 2 октавы выше (×4, с антиалиасингом), удар 2 мс, τ 130 мс, вход на 85 мс, −7,5 дБ |
| `lantern_exhale.ogg` | 0,4 с | −2,6 | `1e4c0cf9-…` | Gentle warm wind gust carrying flower petals: soft airy whoosh rising and falling with a light petal rustle, smooth, quiet, friendly not harsh, clean, no reverb tail, mobile game UI sound | Воздушный «пых» без дыхания человека: полоса 1,7→0,85 кГц, НЧ-срез 6 кГц, атака 45 мс, спад к 0,4 с, лёгкое трепетание пламени 15 Гц в хвосте |
| `silk_open.ogg` | 0,3 с | −2,9 | `b766e019-ac92-42a1-becf-69dfe0189be8` (2 с) | Two soft silk fabric swishes with a pause between them: smooth silky cloth swish, light and airy, gentle, quiet, premium, clean, no reverb tail, mobile game UI sound | Первый взмах дубля (0–0,34 с), полоса 1,7→3 кГц (вверх — «открытие»), НЧ-срез 6,5 кГц, атака 110 мс |
| `silk_close.ogg` | 0,25 с | −2,1 | `b766e019-…` (тот же дубль) | — | Второй взмах дубля (1,08–1,40 с), полоса 2,2→1,4 кГц (вниз — «закрытие»), НЧ-срез 5,5 кГц, атака 75 мс, −1,5 LU |
| `wind_whoosh.ogg` | 0,7 с | −2,8 | `1e4c0cf9-…` + `b766e019-…` | (см. `lantern_exhale`) | Порыв: полоса 520→1250→560 Гц, НЧ-срез 5 кГц, подъём 260 мс, спад 440 мс; «лепестки» — 11 коротких зёрен шелеста из дубля шёлка (ВЧ > 3 кГц, −24 дБ) |
| `voice_pen.ogg` | 0,4 с | −4,3 | `0727170d-1104-4bbe-bd60-8f66beeb4529` (1 с) | Soft paper sheet sliding across a smooth lacquered wooden table: smooth papery slide, close-up, gentle, clean, no reverb tail, mobile game UI sound | Скольжение бумаги дубля (0,15–0,62 с), полоса 2–2,6 кГц, НЧ-срез 6,5 кГц, огибающая мазка кистью (атака 35 мс, вершина 200 мс, сход к 0,4 с), зернистость щетины ±25 % |
| `card_slide.ogg` | 0,2 с | −2,5 | `0727170d-…` + `4cb56c54-69bd-4234-b7ef-b8d2f754939c` | (см. `voice_pen`) + (см. `odometer_tick`) | Скольжение бумаги дубля (0,2–0,42 с), полоса 2 кГц; на 135 мс — мягкое «сел на лак»: щелчок бусины, НЧ-срез 2,2 кГц, −5 дБ |
| `odometer_tick.ogg` | 60 мс | −1,3 | `4cb56c54-…` (1 с) | Very soft wooden abacus bead click: three tiny separate light clicks with gaps between them, small polished wood beads, gentle, close-up, dry, quiet, no reverb tail, mobile game UI sound | Первый щелчок дубля (резонанс дерева ≈ 1,9 кГц), полоса 150 Гц–4,5 кГц, 60 мс, fade-out 25 мс |

`pluck_pitch.txt` — основной тон `pluck.ogg` в Гц, измерен БПФ по готовому файлу (окно 0,01–1,2 с, 2^19 точек, параболическое уточнение):
**261,64 Гц = C4** (+0,1 цента). `V10HudFx.PENTA` (pitch_scale 1,0 = C) даёт C-мажорную пентатонику C4…A5 без поправки.

## Отбракованные дубли (не используются)

| Job id | Что просили | Почему нет |
|---|---|---|
| `a1a9e7d2-a946-4504-9a95-399666edca8d` | guzheng pluck (2 с) | Почти синус 247 Гц с биениями 8,6 Гц (вторая струна 256 Гц), гул вместо спада |
| `1c03d4ef-01f6-4522-b503-30a192b1411c` | koto pluck (2 с) | Нарастающий гул с 0,7 с, щипка нет |
| `95fa4803-641e-4cfd-b751-067baeb1809e` | singing bowl swell (2 с) | Шум и рокот < 150 Гц, тона почти нет |
| `4420c7a1-cd92-4a7e-baf3-f9c0d7bd937d` | lantern ignite (1 с) | Суб-рокот 61 Гц + шипение > 10 кГц, звона нет |
| `bdc58673-eb92-42ca-9824-cf716fb32138` | candle blow-out (1 с) | Тихий фон с потрескиванием, «пыха» нет |
| `e3b1a160-63e4-4216-b2f3-14e1f96ed918` | brush stroke (1 с) | Два щелчка и тишина |
| `9ad2b402-1b7f-410d-b0f2-e563a8144b1b` | card slide (1 с) | Почти тишина (пик −38 dBFS) |

Примечание: слово `quiet` в промпте `mirelo_text_to_audio` даёт почти пустой или очень тихий шум. Мягкость задавать словами `soft/gentle`, а уровень — в обработке.

Скрипты сборки (вне репозитория): `scratchpad/hudfx_art/sfx/scripts/{process,finalize,contact}.py`. Цепочка: декод → нарезка/спектральная огибающая (STFT 1024/256) → выравнивание L100 с потолком пика → libvorbis q5 → проверка декодированного пика.
