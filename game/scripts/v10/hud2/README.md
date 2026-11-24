# HUD v2 — «Тишина и лак» (ветка `v10-hud2`)

Реализация `docs/HUD_V2.md`. Новые файлы только в `game/scripts/v10/hud2/`, `game/assets/v10/hud2/`,
`game/shaders/v10/hud2/`. Существующие экраны **не тронуты**: ниже точные шаги миграции для интегратора.
В ветку влиты `v10-fonts` (роли шрифтов) и `v10-hud2-doc` (спека).

## Модули

| Файл | Класс | Что делает (§ HUD_V2) |
|---|---|---|
| `tokens.gd` | `V10DS` | Цвета UX §6.2, метрики (сетка 8, высоты плашек 48/80/160, лоток 104), шкала кеглей, тайминги, акценты 5 героинь. Hex-литералы живут только здесь (до появления общего `DS` — тогда сделать алиас) |
| `type.gd` | `V10Type` | Три роли (§3): Display = Playfair 700 (+italic для цифры комбо), UI = Nunito 700, Numerals = Nunito 900 + `tnum`/`lnum`; Overline 15 (+14 % трекинг), hand = Caveat. `settings()` — `LabelSettings` с обводкой 0 и тенью только `on_art`. `fit()` — ступени кегля → многоточие + `V10Type.overflow`, коробку не меняет. `quant()` — квант старых кеглей к шкале |
| `plate.gd` | `V10Plate` | Единственное семейство плашек S/M/L (§2): фиксированная высота (`_get_minimum_size`, любое растяжение возвращается), ширина только из модулей, одна волосяная линия сверху с затуханием, лак 5 %, нижний тон, состояния selected/disabled/focused/pressed, хит-зона S 80, `ping()` — отклик линии. `draw_surface()` общая для лотка и листов |
| `button.gd` | `V10Button` | 4 класса UX §6.5: `play` (пилюля rose.500, Display 32→26 night.900, дыхание 3,2 с, один блик 2,8 с, надстрочник над кнопкой), `cash` (единственная обводка gold.500), `secondary` (текст + стрелка), `quiet` (иконка в хит-зоне 80) |
| `icons.gd` | `V10Icons` | Монолиния §4 векторами (штрих 2,5, круглые концы): pause, undo, hint, shuffle, sound, settings, help, close, back, arrow_r, more, info, phone, avatar_ring, 5 вкладок, heart, lock_silhouette. `V10Icons.icon()` — Control. `draw_star()` — звезда уровня победы |
| `hud_match.gd` | `V10HudMatch` | Партия §8.1, **ровно 5 постоянных элементов**: пауза, строка «1-2 · Осталось 30» + линия прогресса 2 px, лоток (M-лак 104, 7 ячеек, ember на последней), ряд помощи (3 диска без обода + Numerals 22), сцена героини (риг `V10LiveRig` для МТ, иначе арт наряда) с дугой Приёма за плечами. События: цифра комбо Display 64 italic, баннер старта Display 44 (на мягкой полосе-тоне), «Ставка ×2» до первого хода, реплика Caveat у лица. Сукно — шейдер без рамки. `compute(vs, insets)` — чистая функция раскладки |
| `combo_showcase.gd` | `V10ComboShowcase` | Витрина комбо §7: T1/T2/T3, тайминги 0,9/1,2/1,4 с, высота 60/70/80 %, затемнение 0/45/55 %, пауза ввода (сигнал `input_paused`) и пропуск тапом (ввод возвращается сразу, картинка уходит за 120 мс), маска центра стола для T1 (шейдер), свет акцентом без белого, ≤ 18 частиц стихии, контровой свет T3, одна реплика, звук через `V10SfxBank` (если влита `v10-audio`) или старый `Sfx`. Правила: первый раз за партию на ступень, ≥ 20 с, ≤ 3 за партию, старшая ступень побеждает, `hold()/release()` вокруг кат-ина ульты, «Полностью / Коротко / Выкл», рейтинг → T1, обучение 1–3 → T1. `fx_level=min` — только проявление 120 мс |
| `hud_victory.gd` | `V10HudVictory` | Победа, такт 1 §8.3: героиня ≥ 40 % в клипе до `play.y − 24`, стол (лак night.900 + волосяная линия) закрывает всё ниже бёдер, «Стол чист» Display 64, 3 звезды, Caption 18, кнопки на постоянных местах (`H−B−216` и `H−B−104`), «⋯» |
| `hud_home.gd` | `V10HudHome` | Чайная §8.2: аватар + ник, «Телефон» с точкой, 3 живописных фонаря (`v09/summon/lantern_r.png`), корешок «ЧАЙНАЯ · ВЕЧЕР», плашка партнёра M 200×80, одна «Играть · 1-4», подложка только под рядом действий, навбар 5 равных вкладок |
| `header.gd` | `V10Header` | Одна шапка подэкранов §8.6 (88 + T): «‹», H1 Display 44→32 слева, «?» или одна S-плашка справа |
| `util.gd` | `V10Hud2Util` | Вставки (`V10Layout` из `v10-responsive`, если есть), `fx_level`, звук `V10SfxBank`/`Sfx`, `V10Music` — всё по имени класса, без жёстких зависимостей |
| `hud2_selftest.gd` | `V10Hud2Selftest` | `--hud2_selftest=1` (852 проверки, см. ниже) |
| `hud2_demo.gd/.tscn` | — | Демо: партия со скриптом до ×20, витрины, главная, победа |
| `tools/prep_combo.py` | — | Нарезка спрайтов витрины + `combo_meta.json` |
| `shaders/v10/hud2/felt.gdshader` | — | Сукно: виньетка + ворс, без рамки |
| `shaders/v10/hud2/showcase_sprite.gdshader` | — | Маска стола/центра для T1 + контровой свет T3 |

### Арт витрины (`assets/v10/hud2/combo/`)
15 спрайтов: `{mc,rin,hana,yue,nova}_t{1,2,3}.png` (прозрачные, обрезаны по альфе, низ «кадра от колен» сохранён),
`combo_meta.json` — job id, поза (`combo1..3 <ключ>`), обрезка, `face` (x, y, w, h, приблизительно). Порядок поиска:
`<hero>_<outfit>_t<N>.png` → `<hero>_t<N>.png` → ступень ниже. Новые наряды кладутся как `<hero>_<outfit>_t<N>.png`.

## Проверки

```
cd game
flock /tmp/tw-godot.lock /opt/tw-tools/godot --headless --path . res://scripts/v10/hud2/hud2_demo.tscn -- --hud2_selftest=1
# → HUD2 SELFTEST n/n OK, код выхода = число провалов
```
1. 200 случайных строк × S/M/L в растягивающих контейнерах: высота 48/80/160 не меняется, ширина остаётся модулем, метки не выходят из плашки; реальные строки HUD помещаются без многоточия.
2. Все метки hud2: обводка 0, тень только стандартная «на арте»; постоянный текст партии ≤ 3 кеглей; ровно 5 постоянных узлов партии; шапка не растёт от длинного заголовка.
3. Раскладки партии/главной/победы на 9:16, 9:18, 9:19.5, 9:20, 9:21, 3:4, 10:16 со вставками: внутри safe-области, без пересечений, сетка 8, лицо свободно от UI, героиня в партии ≥ 18 % (9:16) / ≥ 28 % (9:20+) / ≥ 13 % (3:4), главная ≥ 35 %, победа ≥ 40 %, `hero ∩ кнопки = ∅`.
4. Витрина: для 5 героинь × 7 соотношений пиксели T1 в центральной зоне пар α ≤ 0,5 (по реальной альфе спрайта × маске, в покое и на въезде), лицо T1 вне центра и на экране; лицо T2/T3 в верхней трети и не под цифрой комбо; T1 не ставит ввод на паузу; T2 ≤ 1,2 с, T3 ≤ 1,4 с; пропуск возвращает ввод за 0 мс, картинка уходит ≤ 120 мс; fx=min без частиц; правила очереди.
5. Нет `Color("#…")`/`Color(0.…)` вне `tokens.gd`.

Демо и запись:
```
xvfb-run -a -s "-screen 0 1700x2700x24" /opt/tw-tools/godot --path . res://scripts/v10/hud2/hud2_demo.tscn \
  --rendering-driver opengl3 --audio-driver Dummy --resolution 720x1280 \
  --write-movie /abs/hud2_demo.avi --fixed-fps 30 --quit-after 600 -- --view=match --gap=2
ffmpeg -i /abs/hud2_demo.avi -c:v libx264 -pix_fmt yuv420p -crf 20 -an /abs/hud2_demo.mp4
# снимки: -- --view=all --shots=/abs/dir   (match_idle, match_t1/t2/t3, home, victory)
```

## Миграция (шаги интегратора, по порядку)

Номера строк — по `gh-pages` @ `0510188`.

### 0. Общие точки (§9.1) — до экранов
1. **`scripts/ui.gd` `UI.label()` (стр. 62–93)**: игнорировать `outline` (всегда 0); тень ставить только при новом
   аргументе `on_art := false`; кегль пропускать через `V10Type.quant(size, role)`; шрифт — `V10Type.font("ui"|"num"|"display")`.
   Это чинит 362 метки без правки экранов.
2. **`UI.title()` (стр. 106–107)**: `V10Type.settings("display", V10Type.quant(size, "display"), V10DS.PAPER_100, on_art)` — без обводки.
3. **`UI.rbox()` (стр. 109–122)**: вернуть `V10Plate.make(sc, V10DS.plate_width(sc, w), …)`, где `sc` = S/M/L по высоте
   (≤ 56 → S, ≤ 104 → M, ≤ 200 → L); иначе — прозрачный `Control` того же размера. Канты `border_top/bottom` игнорировать.
4. **`scripts/v08/hud/art.gd` (стр. 187–249)**: `nine("panel")` → лист `night.700` (`V10Plate.draw_surface(…, fill_override = V10DS.NIGHT_700)`),
   `nine("ribbon")` → `V10Type.label(title, "display", 44, …)` по левому полю; `nine_scale()` удалить.
5. **`scripts/jbutton.gd` (стр. 141–150, 184–193)**: ужатие до 16 px заменить на `V10Type.fit(label, text, "button_play"|"button_ui", w - 64)`;
   новые кнопки создавать через `V10Button.make()`.

### 1. Партия — `scripts/screens/play.gd`
1. `build()` (стр. 83): после `_make_board()` создать HUD и витрину:
   ```gdscript
   hud2 = V10HudMatch.new(); add_child(hud2); move_child(hud2, 0)   # под доской
   hud2.configure({"hero": partner, "level": cfg.get("code", str(lvl + 1)), "total": board.tiles.size() / 2,
       "left": board.tiles.size() / 2, "helpers": {"undo": G.S.undo, "hint": G.S.hint, "shuffle": G.S.shuffle},
       "stake_offer": mode == ""})
   board_rect = hud2.board_rect()          # поле 688×688 под строкой; раскладки > 9 рядов — дорожка v10-levels
   showcase = V10ComboShowcase.new(); add_child(showcase)   # поверх всего HUD, под листами
   showcase.hud = hud2; showcase.hero = partner; showcase.outfit = G.S.outfit.get(partner, "base")
   showcase.mode = G.S.get("hero_combo", "full"); showcase.ranked = mode in ["duel", "blitz", "tourney"]
   showcase.tutorial_level = lvl + 1 if mode == "" and lvl < 3 else 0
   showcase.input_paused.connect(func(on): board.set_process_input(not on); _frozen = on)
   ```
   `_process()` (стр. 745): при `_frozen` не уменьшать `blitz_left`, `fever_until` и таймеры подсказок.
2. `_make_board()` (стр. 224–257): `slot_rects` брать из `hud2.tray_cell_rect(i)` (7 ячеек); `board.fit_into(hud2.board_rect())`.
3. **Удалить** из `_build_hud()` (стр. 306–428): круглую «домой» (стр. 307; выход — через паузу), плашку цели `gp`
   и осколок (стр. 309–341), кристаллы (377–387), портрет `V6HeroStage` 186×240 (352–358), `tray_box` с кантами
   (395–416), полосу комбо/шкалу `mb` (418–428). Вместо цели: `hud2.set_left(pairs_left)` в `_refresh()` (стр. 499).
4. **Удалить** `_build_bottom()` (стр. 430–448) и `_v8_round_btn` звука: ряд помощи — `hud2.helper_pressed.connect(func(k): {"undo": _undo, "hint": _hint, "shuffle": _shuffle}[k].call())`;
   счётчики — `hud2.set_helper(kind, n)` в `_set_badge()` (стр. 495). Звук — в листе паузы: `hud2.pause_pressed.connect(_open_pause_sheet)`.
5. `_on_match()` (стр. 768–856): вместо `combo_lbl`, `_combo_banner()` (стр. 829) и `_cutin()` (стр. 843):
   ```gdscript
   if showcase.on_combo(combo) == 0 and combo >= 2: hud2.show_combo(combo)
   hud2.set_ult(charge)
   ```
   `_cutin()` (стр. 984–987) удалить. В `_fever()` (стр. 989): `showcase.fever_start()` вместо ленты `Common.ribbon`.
   `V10Juice.combo_milestone` не подключать (его роль — витрина). Летающие «+N» в `v07/integrator/combo.gd` выключить.
6. Ульта: перед `V9Cutin` вызвать `showcase.hold()`, по окончании — `showcase.release()`; `hud2.ult_pressed` = запуск
   ульты по тапу на героиню (вместо портрета). Реплики `_speak()`/`_bubble()` (стр. 722–736) → `hud2.say(text)`.
7. `_intro()` (стр. 524–595): ленту уровня над лотком заменить на `hud2.start_banner("%s · %s" % [code, cfg.name])`;
   первый ход → `hud2.first_move()` (уходит «Ставка ×2», в строке появляется «×2»).
8. Рамку стола выключить: `v06/board/board_table.gd:86–112` и огонь рамки `v07/integrator/combo.gd:248–430`
   (`V7Combo.setup` без рамки); аура Азарта — `V10Juice.fever_aura` снаружи `board_rect`.
9. Победа (`play.gd:1816–2400`, `V8_RES_TOP`, панель 9-patch 1997–1998, бюст 2058–2077): такт 1 = `V10HudVictory`
   (`next_pressed` → следующая партия, `home_pressed` → главная, `more_pressed` → лист «Повтор · Фото · Вызов»);
   такты 2–3 строятся на той же сцене, кнопки остаются на местах из `V10HudVictory.compute()`.

### 2. Главная — `scripts/screens/home.gd`
1. `build()` (стр. 28): оставить фон/риг/видео героини; **удалить** `_build_left()` (131–184, медальоны),
   `_build_right()` (242–410: «Лига», «Ивент», «−20%», «Режимы», «Сесть за стол»), `_build_affection()` (411–450),
   пузырь `_say()` (451–466), затемнение пола.
2. Добавить `home2 = V10HudHome.new(); home2.configure({...}); add_child(home2)`; если на экране уже есть риг/видео
   героини — не создавать второй: `configure({..., "own_figure": true})` и
   позиционировать свою фигуру по `V10HudHome.compute(vs, insets).hero_pos/hero_scale`.
3. Сигналы: `play_pressed` → `main.go("levels")`/быстрый старт, `partner_pressed` → карточка героини,
   `phone_pressed` → `open_mail()` (стр. 203), `lantern_pressed(i)` → Сегодня/Салон/Серия, `tab_pressed(i)` → навбар.
4. `main.gd:490–605` (статус-лента с ником и валютами) на главной не показывать: `main.show_chrome(false, false)`;
   навбар `main.gd:635–720` (звезда) заменён вкладками `V10HudHome`.

### 3. Шапки подэкранов — `scripts/v08/hud/header.gd`
`V8Header.make(screen, main, title, on_back, on_help)` → `V10Header.make(screen, title, on_back, on_help)`
(вызовы: `levels.gd:87`, `collection.gd:49`, `modes.gd:39`, `summon.gd:60`, `shop.gd`). Константы
`V8Header.CONTENT_Y` (= 216) → `V10Header.content_y(get_viewport_rect().size)` (= T + 96). Статус-ленту
`main.gd:490–605` на подэкранах убрать; валюта — `h.right_plate = V10Plate.make("S", 144, "1 980", …)` только там, где её тратят.
Мету `v8_back` для кнопки «назад» Android `V10Header` ставит так же.

### 4. Диспетчер самотеста
`main.gd`: `if "--hud2_selftest=1" in args: get_tree().quit(await V10Hud2Selftest.run(self))`.

## Известные отступления
- Сцена героини в партии: риг есть только у МТ (`mc_gown`, вечернее платье), у остальных — арт наряда как обложка
  сцены. Поэтому в демо в сцене МТ в платье, а на витрине — в базовом ципао (спрайты витрины сделаны для базовых нарядов).
- Планшет 3:4: героиня в сцене под полем (13,8 % экрана), вариант «во внешней колонке справа» (§8.1) не сделан.
- Иконки — векторы в коде, а не SVG (штрих 2,5 одинаков на любом DPI); живописных предметов (кристалл, свеча…) в hud2 нет,
  кроме фонарей (готовый арт `v09/summon/lantern_r.png`) и звёзд победы (вектор до арта).
- Спрайты витрины 1360×2048 (у Рин 1366×2048), а не ≥ 1366: предел генератора; `face` в мете приблизительный.
  Нет мигания, `sway` волос и `sheen_sweep` по легвиру (нужны маски) — вместо этого дыхание 1,5 %, дрейф и контровой свет T3.
- Вариант T3 18+ (`bold_ok()`, симпатия ≥ 6) в API есть через `outfit`-цепочку, но спрайтов 18+ в ветке нет.
