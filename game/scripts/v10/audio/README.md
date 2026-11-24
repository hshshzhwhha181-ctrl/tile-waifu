# 0.10 Audio — музыка на каждую вкладку, премиальные SFX, новые реплики

Ветка `v10-audio`. Код: `game/scripts/v10/audio/`, ассеты: `game/assets/v10/audio/{music,sfx,voice}/` + `manifest.json`
(длины, точки петель, метрики шва, LUFS, job id Higgsfield для каждого файла).

## Звуковая идентичность
Один «чайный дом + аниме-поп»: гучжэн/кото, эрху, флейта дицзы, тёплое пиано/Rhodes, мягкие синты, lo-fi барабаны.
У каждой вкладки своё настроение (таблица ниже), но инструменты общие, поэтому переходы звучат как один саундтрек.

| id | экран | что звучит | петля |
|---|---|---|---|
| `lobby` | титул/главная | яркий хук на гучжэне + колокольчик-синт, тёплое пиано, lo-fi 96 BPM | 80,0 с |
| `path` | карта Пути | дицзы, кото-остинато, «путешествие» 104 BPM | 38,1 с |
| `match_calm` | партия | lo-fi Rhodes + арпеджио гучжэна, 88 BPM | 43,6 с |
| `match_tense` | партия, лоток почти полон | тайко, тремоло гучжэна, стаккато эрху, 120 BPM | 48,0 с |
| `fever` | слой фивера | аниме-EDM, суперсо, хук эрху, 128 BPM | 52,5 с |
| `summon` | призыв | челеста, арфа, тайко-«сердце», ожидание чуда | 24,0 с |
| `shop` | Лавка | ночной рынок: пиццикато, пипа, свинг 108 BPM | 35,6 с |
| `salon` | Салон | city-pop / нео-соул, Rhodes, эрху, «дорого» | 34,3 с |
| `phone` | Телефон | уютный bedroom lo-fi, музыкальная шкатулка | 24,6 с |
| `pagoda` | Пагода Луны | мистика: храмовые колокола, дицзы, trip-hop | 64,4 с |
| `duels` | Дуэли | battle-pop: трэп-хэты, рифф пипы, эрху | 41,1 с |
| `motif_mc/rin/hana/yue/nova` | экраны героини | лейтмотивы 5 основательниц | 12–24 с |
| `sting_victory` / `sting_defeat` | итог партии | фанфара 9,3 с / мягкий ободряющий 7,6 с | нет |

Все петли бесшовные: точка петли найдена автоматически (похожесть 3 с после старта и после конца по мел-спектру,
хроме и атакам, предпочтение целым тактам, подгонка конца до сэмпла по корреляции) + кроссфейд 0,35 с внутри файла.
Проверка «на слух»: изменение спектра на шве ≤ 85-го перцентиля обычных музыкальных событий трека (`seam_flux_pct`
в manifest, у всех петель 9–80), и лист швов `pipeline/seams_plot.py` (форма волны + спектрограмма ±2 с вокруг шва).
Громкость: музыка −16 LUFS, SFX −14 LUFS (щелчки не выше −1 dBFS по пику, без лимитера), голос — как старые реплики героини.
У коротких щелчков из-за потолка по пику LUFS файла ниже цели (до −29), поэтому громкость в игре выравнивает `db` в `BANK`
(и `vdb` для вариантов одного id). Ориентиры в игре (пик 100 мс, K-взвешивание, дБ): нажатия −20…−26, награды −15…−18,
большие моменты (ранг, SSR, фивер, ульта) −8…−13. `match_1` намеренно тихий «щелчок»: на каждой паре поверх него звучит `combo_step` (−12).

## API

```gdscript
V10Music.play_screen("shop")        # экран -> трек, кроссфейд 0,8 с; возврат на вкладку < 90 с продолжает с того же места
V10Music.set_tension(fill)          # только в партии: 0..1, >=0.7 -> match_tense, <0.5 -> назад (гистерезис)
V10Music.fever(true / false)        # слой фивера поверх партии; база играет под ним на -22 дБ и возвращается
V10Music.sting("victory"|"defeat")  # джингл, петля проседает до -30 дБ (resume=true вернёт её)
V10Music.motif("rin")               # лейтмотив героини как музыка экрана
V10Music.stop()

V10SfxBank.play("tile_click")       # вариант без повтора подряд + случайный питч в пределах id
V10SfxBank.play("coin_fly", {"pitch": 1.1, "db": -3})
V10SfxBank.match_tier(1..3)         # match_1 (2 варианта) / match_2 / match_3
V10SfxBank.combo(n)                 # лестница полутонов как Sfx.combo_pitch, на 8/12-й паре ещё combo_finale
V10SfxBank.voice("hana", "riichi")  # новая реплика (riichi/rankup), шлёт Sfx.voice_started (субтитр + липсинк)
```

Оба класса ставят себя сами под `/root` при первом вызове (автозагрузка не нужна, project.godot не трогаем).
Музыка играет на шине `Music` → `Sfx.duck()/duck_hold()` работают без изменений. Когда V10Music включает трек, он
глушит старый `Sfx.music()`, так что две музыки не наложатся даже при частичной интеграции.
Флаги: `G.S.music` (музыка), `G.S.sound` (SFX и стинги), `G.S.voice` (реплики).

## Хуки интеграции (шаг polish)
Заменить вызовы `Sfx.music(...)` на `V10Music.play_screen(...)`:

| файл | сейчас | поставить |
|---|---|---|
| `scripts/main.gd:154` (старт) | `Sfx.music("menu")` | `V10Music.play_screen("title")` |
| `scripts/main.gd:285` (тумблер музыки) | `Sfx.music("menu" if v else "")` | `V10Music.play_screen(<текущий экран>) if v else V10Music.stop()` |
| `scripts/screens/home.gd:33` | `Sfx.music("menu")` | `V10Music.play_screen("home")` |
| `scripts/screens/levels.gd:58` (+ карта Пути v10) | `Sfx.music("menu")` | `V10Music.play_screen("path")` |
| `scripts/screens/play.gd:141` | `Sfx.music("play"…)` | `V10Music.play_screen("match")` (zen тоже `match`) |
| `scripts/screens/play.gd:489/491` (тумблер звука в партии) | `Sfx.music("play"…)` / `Sfx.music("")` | `V10Music.play_screen("match")` / `V10Music.stop()` |
| `scripts/screens/play.gd` при изменении лотка | — | `V10Music.set_tension(float(tray.size()) / tray_cap)` |
| `scripts/screens/play.gd:993` фивер старт (+ конец фивера) | `Sfx.play("fever")` | `V10SfxBank.play("fever_ignite"); V10Music.fever(true)` / `V10SfxBank.play("fever_end"); V10Music.fever(false)` |
| `scripts/screens/play.gd:2106` (`_victory`) | `Sfx.music("")` + `Sfx.play("win")` | `V10Music.sting("victory")` |
| `scripts/screens/play.gd:1039` (поражение, рядом с `Sfx.say(partner, "lose")`) | — | `V10Music.sting("defeat", true)` |
| `scripts/screens/play.gd:2197` (после окна победы) | `Sfx.music("menu")` | `V10Music.play_screen("home")` |
| `scripts/screens/summon.gd:31, 1078, 1123` | `Sfx.music("summon")` | `V10Music.play_screen("summon")`; на подъём фонаря `V10SfxBank.play("lantern_rise")`, SR/SSR `sr_reveal` / `ssr_reveal` |
| `scripts/screens/summon.gd:423` | `Sfx.music("")` | `V10Music.stop(0.4)` (тишина перед раскрытием) |
| `scripts/screens/shop.gd:31` (+ Лавка 2) | `Sfx.music("menu")` | `V10Music.play_screen("shop")` |
| `scripts/v07/room/room.gd:23`, Салон v10, гардероб, `collection.gd:30` | `Sfx.music("menu")` | `V10Music.play_screen("salon")` |
| `scripts/v09/letters/letters_screen.gd:30`, Телефон v10 (почта/чаты/лента) | `Sfx.music("menu")` | `V10Music.play_screen("phone")` |
| Пагода / Странствие (v10 tower_ui) | — | `V10Music.play_screen("pagoda")` |
| `scripts/v07/event/tourney_screen.gd:33`, `event_screen.gd:24`, Дуэли v10, лиги | `Sfx.music("menu")` | `V10Music.play_screen("duels")` |
| `scripts/screens/modes.gd:32` | `Sfx.music("menu")` | `V10Music.play_screen("modes")` (= path) |
| `scripts/v08/profile/profile_screen.gd:23` | `Sfx.music("menu")` | `V10Music.play_screen("profile")` (= lobby) или `V10Music.motif(<партнёр>)` |
| карточка/история героини, ульта-вставка | — | `V10Music.motif(hero)` |

SFX (через `V9Feel.press` и места, где сейчас `Sfx.play`):
`tap/select` → `tile_click`/`tile_select`; `deny` → `tile_deny`; `match0..7` → `match_tier(1..3)` по размеру сноса;
`Sfx.combo_step(n)` → `V10SfxBank.combo(n)`; ульта готова/каст → `ult_ready`/`ult_cast`; вставка → `cutin_whoosh`;
сундук → `chest_open`; полёт монет/камней → `coin_fly`/`gem_fly`; звёзды итога → `star`; ранг → `rank_up` +
`V10SfxBank.voice(partner, "rankup")`; риичи → `V10SfxBank.voice(partner, "riichi")`; кнопки → `btn_press`
(наведение/фокус на планшете `btn_hover`); вкладки нижнего меню → `tab_switch`; письма/книга → `page_turn`;
уведомление телефона → `notify`; карты призыва/благословений → `card_flip`; бустеры → `booster`, `undo`, `shuffle`;
сердце/касание героини → `heart`; награда-всплывашка → `reward_pop`.
Все id: `V10SfxBank.ids()`; полифония и антиспам заданы в `BANK` (max голосов на id, минимальный зазор повторов).

## Проверка
- Самотест: `flock /tmp/tw-godot.lock /opt/tw-tools/godot --headless --audio-driver Dummy --path game res://scripts/v10/audio/v10_audio_selftest.tscn`
  → `V10AUDIO OK n/n` (все id грузятся, петли помечены петлями, стинги/SFX — нет, длины = manifest, шов ≤ 90 перцентиля,
  все экраны → реальные треки, щелчки ≤ 0,5 с, кроссфейд/фивер/напряжение/стинг, полифония и антиспам).
- Пульт прослушивания: `res://scripts/v10/audio/v10_audio_demo.tscn` (все экраны, слайдер напряжения, фивер, стинги,
  лейтмотивы, реплики, все SFX). `-- --tour=1` — автотур для записи `--write-movie`.

## Происхождение и лицензия
- Все 64 файла сгенерированы для Tile Waifu через Higgsfield (аккаунт владельца, платный план): музыка — `elevenlabs_music_v2_5`
  (только инструментал), SFX — `mirelo_text_to_audio`, голос — `seed_audio`. Сторонних сэмплов, чужих треков и стоковых библиотек нет.
- Доказательство происхождения: job id Higgsfield у каждого файла в `assets/v10/audio/manifest.json` (не удалять; при замене трека
  обновлять через `pipeline/build_manifest.py`). Исходные mp3 — в аккаунте Higgsfield по тем же job id.
- Коммерческое использование — по условиям Higgsfield для платного плана на дату генерации (2026-11-24). Перед релизом в RuStore
  сохранить снимок действующих условий Higgsfield (и ElevenLabs Music, если Higgsfield на них ссылается) рядом с релизными документами.
- Голоса — клон тембра собственных реплик героинь из 0.7 (`assets/voice/*.mp3`), не реального актёра. Если реплики 0.7 когда-либо
  записывал живой человек, нужен его письменный допуск на клон.
- В экран «Шрифты и лицензии» (0.10-spec) добавить строку: «Музыка, звуки и голоса созданы для игры с помощью Higgsfield AI».

## Пайплайн (повторить / заменить трек)
1. Сгенерировать (Higgsfield): музыка `elevenlabs_music_v2_5` (`force_instrumental: true`, 60–90 с, в промпте «seamless loop, no intro,
   no fade-out»), SFX `mirelo_text_to_audio` (1–4 с), голос `seed_audio` с `audio_references` = склейка 4 старых реплик героини
   (клон тембра; реплики на японском, как все реплики 0.7 — субтитры русские из `Sfx.VOICED`).
2. `python3 pipeline/v10_loop.py music in.mp3 out.ogg` (петля + −16 LUFS), `... music in.mp3 out.ogg --sting`,
   `... sfx in.mp3 out.ogg [--maxlen 0.2]` (щелчки: срез тишины до атаки, быстрый спад хвоста), `... voice in.mp3 out.ogg --lufs <как у героини>`.
3. `python3 pipeline/seams_plot.py seams.png music/*.ogg` — глазами проверить швы; `pipeline/voice_check.py` — распознать реплики (faster-whisper) и сверить высоту голоса со старыми.
4. В `<трек>.ogg.import` поставить `loop=true` для петель, `godot --headless --path game --import`.
5. `pipeline/build_manifest.py` → `manifest.json`, затем самотест.
