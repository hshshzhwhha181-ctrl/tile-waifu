# V10Juice — библиотека «сочности» 0.10

Статический класс `V10Juice` (без автозагрузки) + узлы-исполнители `V10Juice*`. Всё подчиняется `S.fx_level`
через `V9Feel.level()`; нажатия по-прежнему идут через `V9Feel`. Шейдеры: `res://shaders/v10/juice_*.gdshader`.
Звуки (Higgsfield `mirelo_text_to_audio`, обрезаны и нормализованы): `res://scripts/v10/juice/sfx/*.ogg`.
Если файла звука нет, играет запасной из `assets/sfx` (`V10Juice.SOUND_FALLBACK`).

- Витрина: `godot --path game res://scripts/v10/juice/demo/juice_demo.tscn` (кнопка на каждый эффект + переключатель уровня FX).
- Ролик 30 с: `… juice_demo.tscn --write-movie out.avi --fixed-fps 30 -- --juice_showcase=1`.
- Самотест: `godot --headless --path game res://scripts/v10/juice/demo/juice_demo.tscn -- --juice_selftest=1` → `JUICE SELFTEST n/n`.

## Правила (не нарушать при подключении)

1. **Никаких белых вспышек.** Весь свет тёплый, аддитивные слои с потолком (≤ 0,85 альфы, цвет ≤ 0,8 яркости). Своих `flash()` поверх не добавлять.
2. **Поле не закрываем.** Эффекты пары живут в ≈ 1,5 фишки вокруг точки встречи и гаснут за 0,6–0,75 с; аура лихорадки рисуется
   только СНАРУЖИ рамки стола (`inset` 6 px внутрь — тонкая линия); баннеры комбо — только в прямоугольнике, который передаёт экран (полоса HUD).
3. **Одна декорация лихорадки.** Сейчас её несёт рамка `V7Combo`. Подключая `V10Juice.fever_aura`, выключить огонь рамки V7Combo
   (или наоборот) — не две ауры сразу.
4. **Награда летит из источника** (сундук, поле, карточка), а не из-за героини: фонтан из центра экрана проходит через фигуру героини.
5. **≤ 1 блика на экран** (BENCHMARK MD-9): блики всех `idle_sparkle` идут по общим часам, двух одновременно не бывает.
   `idle_sparkle` — только на 1–2 главные платные/премиальные кнопки экрана.
6. **«Без тряски и вспышек»** (BENCHMARK MD-6): ключ сохранения `a11y_calm = true` выключает тряску V10Juice при любом уровне FX
   (тумблер в настройках делает дорожка доступности; `V6Fx.shake` пусть проверяет `V10Juice.calm()` так же).
7. **Цель не внутри Container — уже учтено:** `ult_ready`/`danger_beat` и `idle_sparkle` сами выходят из раскладки контейнера
   (`top_level`) и следуют за кнопкой в координатах холста — ряд кнопок не сдвигается.
8. **Бюджет не течёт при раннем закрытии.** Счётчики эмиттеров/слоёв уменьшаются по `tree_exiting`, поэтому можно смело
   передавать экран или окно как `parent` — если его закроют посреди вспышки, частицы не «кончатся» до конца сессии.
9. Эффекты вешаются на слой `V10Juice_fx` (CanvasLayer 70: над экранами, попапами и сеткой V6Fx). Переходы — `V10JuiceTransition` (CanvasLayer 96).

## Уровни FX

| Эффект | полные | умеренные | минимум |
|---|---|---|---|
| Переходы вкладок | шейдер + частицы-декор | шейдер без декора | тёмная растушёвка 0,12 с |
| Пара фишек (осколки / тушь / рябь) | всё | осколки ×0,55, тушь, рябь | только звук |
| Баннер ×5/×10/×20 | мазок, печать, брызги, тряска | без тряски | табличка с текстом 1,1 с (информация) |
| Аура лихорадки | языки пламени + искры | пламя, меньше искр | статичная линия (информация) |
| «Ульта готова» | сердцебиение + кольца | сердцебиение | статичный контур (информация) |
| Фонтан наград | иконки ≤ 16 | ×0,55 | без иконок, колбэки сразу |
| Счётчик (roll) | тики, прыжок, тёплый блик | то же | быстрый счёт 0,3 с, прыжок |
| Сундук / ранг | лучи, кольца, частицы, тряска | без тряски | открытие и текст |
| Блёстки на кнопках | звёздочки + блик | только звёздочки, реже | нет |
| Выход героини | сдвиг, блик по силуэту, лепестки | то же без тряски | растушёвка 0,25 с |

## Бюджет производительности (средний Android, GL Compatibility)

- **Только CPUParticles2D.** GPUParticles2D в Compatibility компилирует шейдер процесса при первом показе (рывок 30–80 мс на Mali/Adreno
  среднего класса) и не выигрывает на разовых вспышках ≤ 40 частиц. Длинные эмиттеры — только искры ауры (≤ 16).
- Живые лимиты (`V10Juice.BUDGET`): полные — 18 эмиттеров / 420 частиц / 5 полноэкранных шейдерных слоёв; умеренные — 9 / 200 / 3; минимум — 0 / 0 / 1.
  Сверх лимита `burst()` молча не создаёт эмиттер (самотест проверяет потолок и отсутствие утечек).
- Осколки и фонтан — **один узел с одним `_process`/`_draw`** на всю вспышку, а не узел на кусочек.
- Полноэкранные шейдеры: только переход (≈ 0,8 с) и затемнение ранга. Тушь — 5 октав шума (самый тяжёлый, ≈ 40 ALU/пиксель), лепестки и фонарь дешевле.
  Аура и сердцебиение — шейдер только на полосе вокруг рамки (fragment внутри рамки выходит сразу).
- Текстуры частиц процедурные (`V10JuiceTex`), 16–64 px; без импорта и без лишних draw call на атлас.
- Замер на устройстве: включить «полные», серия ×20 + лихорадка + ульта; цель ≥ 55 FPS на устройстве уровня Redmi Note 10.

## Подключение по экранам (точные вызовы)

### main.gd — прогрев
`_ready()`: `V10Juice.warm.call_deferred()` — слой, пул звуков, шторка переходов, звуки и текстуры частиц в кэш заранее,
плюс один невидимый кадр каждого из 14 шейдеров (2×2 px, 1 % альфы, 0,25 с): GL Compatibility компилирует шейдер при
первой отрисовке, без прогрева первый переход/пара/баннер дёрнут кадр на 20–80 мс на среднем Android.

### main.gd — переходы вкладок (`go()`)
```gdscript
# вместо твина trans_mat (стр. ~797–800):
if animate:
	var center: = tab_nodes[id].get_global_rect().get_center() if tab_nodes.has(id) else Vector2(-1, -1)
	await V10Juice.cover("auto", 0.34, center, id)     # стиль по вкладке: V10Juice.TAB_STYLE
# … смена экрана как сейчас …
if animate:
	V10Juice.reveal(0.42)                              # вместо обратного твина (стр. ~817–819)
```
Убрать `Sfx.play("whoosh")` в `go()` — у каждого стиля свой звук. Стили: Чайная/Желания/Пагода — фонарь (`lantern`),
Гардероб/Лавка/Салон/Профиль — лепестки (`petal`), Партия/Путь/Телефон/Дуэли — тушь (`ink`).

### play.gd — пары, комбо, лихорадка, ульта
```gdscript
# _on_match(mid, combo, gold, shard) рядом с v7combo.on_match(mid, combo, gain)  (стр. ~855); mid — уже в координатах холста
# (TrayBoard.matched), масть — board.last_face (выставляется до emit):
V10Juice.tile_match(mid, board.last_face, combo, gold)
# V6Fx.on_match уже даёт искры и звон: при подключении снять в нём burst("spark"/"chip") — иначе двойные частицы.
if V10Juice.is_milestone(combo):
	V10Juice.combo_milestone(combo, Rect2(0, HUD_STRIP_Y, W, 120))   # полоса HUD над столом, не над фишками

# _fever() (стр. ~989):
fever_aura = V10Juice.fever_aura(self, board_rect_local)    # и выключить огонь рамки V7Combo (правило 3)
# конец лихорадки (там, где fever_until истёк / V7Combo._on_fever(false)):
V10Juice.stop(fever_aura)

# последнее свободное место лотка (BENCHMARK MD-2): danger = V10Juice.danger_beat(tray_slot) / V10Juice.stop(danger)
# ульта готова (skill_charge >= SKILL_NEED, стр. ~792 / 1397 / 1449):
ult_beat = V10Juice.ult_ready(ult_button)          # кнопка/портрет ульты
# каст ульты или конец партии:
V10Juice.stop(ult_beat)

# победа: счётчики наград
V10Juice.roll(coins_lbl, coins_before, coins_after, 0.9)
```

### Окно победы / сундуки / награды (play.gd итог, daily.gd, v07/eggs, Салон)
```gdscript
V10Juice.chest_open(chest_node, "SSR", func(): chest_node.texture = OPEN_TEX)   # тряска-ожидание 0,55 с → лучи
V10Juice.fountain(chest_node.get_global_rect().get_center(), main.coin_counter, "coin", 12,
	func(i): pass, func(): V10Juice.roll(main.coins_lbl, before, after))
```
`fountain` заменяет `V6Fx.reward_fly` там, где награда крупная (≥ 50 монет / ≥ 10 кристаллов); мелкие — оставить reward_fly.

### Ранг лиги (play.gd итог, `rank_ups`, стр. ~2413)
```gdscript
for u in rank_ups:
	await_close = V10Juice.crest_reveal(load("res://assets/v08/ui/rank/%s.png" % u.id), "Ранг: " + u.title,
		"+%d кристаллов" % u.gems, Color(1.0, 0.78, 0.4), 2.2, on_closed)
```

### Желания (summon.gd)
- В `_sequence` перед раскрытием SSR: `V10Juice.chest_burst(card_center, "SSR")` вместо `_flash()` (белая вспышка не нужна).
- Кнопки «×1 / ×10»: `V10Juice.idle_sparkle(btn, V10Juice.GOLD, 2.8, radius)`.
- Карточка SSR после раскрытия: `V10Juice.sheen(card_art)`; редкий кадр — `V10Juice.dissolve(card_back, 0.5)`.

### Чайная (home.gd), Гардероб (collection.gd), Салон, Профиль
- Героиня при входе на экран / смене героини / смене наряда: `V10Juice.heroine_entrance(hero_node, "right")`.
- Премиальные кнопки (Пропуск, Лавка, «Купить»): `V10Juice.idle_sparkle(btn)` — сам засыпает, когда кнопка скрыта.
- Смена наряда: `V10Juice.dissolve(old_art, 0.45, false, ROSE)` → новый арт `V10Juice.dissolve(new_art, 0.5, true, ROSE)`,
  где `ROSE = Color(0.92, 0.5, 0.62)`. Кромку по умолчанию (оранжевая, «горение») на героиню не ставить: на ревью лицо
  «выгорало» раньше волос — читается как пожар, а не как переодевание. Оранжевая кромка — для печатей, карт, сундуков.

### Лавка (shop.gd)
- Покупка: `V10Juice.fountain(card_center, main.gem_counter, "gem", 10, …)` + `V10Juice.roll(...)`.
- Лучшее предложение: `V10Juice.idle_sparkle(card, V10Juice.GOLD, 2.2, 24)`; на арт товара — шейдер `juice_glint` с `period = 3.5` (бесплатный повторяющийся блик).

## Шейдеры `shaders/v10/`

| Файл | Назначение | Ключевые параметры |
|---|---|---|
| `juice_ink_wipe` | переход «тушь» | `progress`, `origin`, `seed` |
| `juice_iris` | переход «фонарь» | `progress`, `center` |
| `juice_petal_wipe` | переход «лепестки» | `progress`, `dir`, `cell` |
| `juice_dissolve` | растворение с тёплой кромкой | `amount`, `edge_color`, `edge_width` |
| `juice_glint` | блик по альфе предмета | `pos` или `period` (сам повторяется) |
| `juice_sweep_rr` | блик по скруглённому прямоугольнику (кнопки) | `pos`/`period`, `size`, `radius` |
| `juice_outline_glow` | мягкое свечение силуэта | `glow_color`, `radius`, `pulse` |
| `juice_bloom_fake` | «блум» без постобработки (Compatibility), без хроматики | `threshold`, `intensity`, `cap` |
| `juice_frame_aura` | аура снаружи рамки (лихорадка/сердцебиение) | `size`, `pad`, `mode`, `beat` |
| `juice_godrays` | лучи (конус или круг) | `intensity`, `spread`, `aim` |
| `juice_ring` | рябь/ударное кольцо | `t` |
| `juice_ink_splat` | клякса туши масти | `t`, `color` |
| `juice_brush_band` | мазок кистью под баннер | `reveal`, `fade` |
| `juice_seal` | киноварная печать | `color`, `erosion` |

Примечание Godot 4: в `fragment()` у canvas-шейдера `COLOR` уже равен «текстура × modulate», поэтому шейдеры по
текстуре берут `COLOR`, а не `texture(TEXTURE, UV) * COLOR` (иначе картинка «в квадрате» — темнее и злее).

## Звуки (`sfx/`)
`jade_shatter, ink_splash, gold_ripple, stamp_thud, brush_swoosh, trans_ink, trans_lantern, trans_petal, fever_ignite,
ult_heartbeat, rank_gong, chest_open, coin_tick, gem_tick, rollup, heroine_enter` — моно ogg 44,1 кГц, пик −1 dBFS,
громкость задаётся в вызове. Идут на шину `SFX` (компрессор/лимитер V6Fx), уважают `S.sound`.
