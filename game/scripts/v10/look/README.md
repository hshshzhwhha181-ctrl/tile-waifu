# v10/look — «Лицо богинь» (M5: D1–D3, D5–D7)

Ветка `v10-look` (от `gh-pages`, влиты `v10-fonts` и `v10-profile`). Новые файлы только в
`game/scripts/v10/look/` и `game/assets/v10/look/`; горячие файлы 0.9 не тронуты — точки встраивания ниже.

## Что здесь

| Файл | Класс | Что делает (спека) |
|---|---|---|
| `kit_data.gd` | `V10KitData` | D1. Наборы 20 богинь: ранг, рамка (`fr_g_*` из V10ProfileCos), акцент (цвет/свет/глубина + частицы), тема, стол, HUD, стинг, шрифт, фишка-подпись. 5 основательниц + Злата заполнены, 14 — заглушки `hidden`. Правила ROSTER §1.3: A — рамка+акцент; S — +тема+стол; SSR — +HUD+стинг+шрифт; SSR-наряд A-богини поднимает до S (`o_dragon`, `r_agent`/`r_idol`, `h_gym`); SSR-наряды SSR-богини — палитра HUD. Ранги через `V10Rank`, если класс есть (ветка экономики), иначе R→A, SR→S |
| `look.gd` | `V10Look` | D1. `resolve(hero, outfit, ctx)`, `current(S)`, `owned_elements(S)`, `set_choice(S, slot, v)` (auto/base/id), `migrate(S)` (`S.skin`→`look.tile`, `profile.frame`→`look.frame`, идемпотентно), `tile_look()` — замена `G.skin_look()`, `preview()/end_preview()` (примерка, S.look не пишет), `wave(root)` — «надевание» 0,6 с / 0,3 с / ничего, сигнал `hub().look_changed` |
| `tile_themes.gd` + `tile_body_v10.gdshader` + `table_v10.gdshader` | `V10TileTheme` | D3. 9 тем (легаси `s_sakura…s_gold` с теми же side/rim/tint + новые «Нефрит и иней», «Финишная лента», «Лаковая сказка»; «Полночь» и «Неон» обновлены): рубашка-шейдер с узором (лепестки, звёзды, схема, иней, финишные полосы, золотая лоза, сусальные хлопья), кромка, подпись, акцент, частицы. **Один материал на тему** (кэш, батчинг). 6 столов на шейдере v06 + узоры 7–11 (иней, дорожки, звёзды, схема, лепестки) + расписная крышка шкатулки Златы текстурой. Рейтинг/«Крупные символы» — без тинта и кромки, стол статичный |
| `pair_fx.gd` | `V10PairFx` | D3. Частицы пары акцента (лепестки, чаинки, искры, лунная пыль, глитч, перья жар-птицы, жемчуг, иней, угольки), лимит 18/8/0 по fx, без белого |
| `look_board.gd` | `V10LookBoard` | Живое мини-поле (настоящие `Tile` + V6TileLook + тема + стол) для превью |
| `tile_picker.gd` | `V10TilePicker` | D3. «Фишки и столы»: сетка живых превью 3×2, один закрытый тизер, плашка «Рейтинг: лица фишек стандартные» |
| `kit_strip.gd` | `V10KitStrip` | D1. Лента «Набор богини» из 7 чипов, закрытое — «у S»/«у SSR» (без замков), тап — мини-превью 1,2 с |
| `style_picker.gd` | `V10StylePicker` | D1. Профиль → «Мой стиль»: Рамка/Фишки/Стол/HUD — Авто/Базовый/выбор, живой превью, «Сохранить» → `set_choice` + `notify` |
| `look_fonts.gd` | `V10LookFonts` | D2. Шрифт SSR-партнёра на моментах: заголовок экрана и окна, имя Приёма, «Победа!», подпись письма (Kurale/Caveat). <24 px и все цены — Nunito. Смена партнёра — кроссфейд 0,25 с |
| `hud_skin_data.gd` | `V10HudSkinData` | D7. Скины: `five_winds` (базовый, векторный «Тишина и лак», токены HUD v2) и `zlata` «Лаковая сказка» (арт Higgsfield): токены, 11 ролей, 4 класса кнопок, press/open-эффекты, фон меню, загрузка, стинг, SFX, палитры `firebird / ember / dawn` |
| `hud_skin.gd` | `V10HudSkin` | D7. Каркас: `use()`, `skinned()` (единственная проверка для горячих файлов), `nine(role)` (@2x 9-patch в масштабе 0,5 — углы 1:1, HUD_V2 §2.4), `button/plate/window/header/currency/tabs/menu_bg/loading`, `decorate(ctrl, role)` (no-op при five_winds), `sting()` ≤ раз в 600 с, контраст |
| `skin_fx.gd` | `V10SkinFx` | D7. Свой отклик: five_winds — «Шёлк»; Злата — золотой отблеск по лаку при нажатии и перо, прочерчивающее рамку окна за 0,4 с + распускающиеся угловые орнаменты; fx min — проявление 0,12 с |
| `skin_assemble.gd` | `V10SkinAssemble` | D7. «Новый стиль стола»: Чайная собирается от центра 0,6 с, лак + золотое кольцо, стинг, «Оставить» / «Вернуть «Пять ветров»» |
| `preview_bar.gd` | `V10PreviewBar` | D1/D7. «Примерка · Стиль: …» с «Вернуть» и «К баннеру», без таймера |
| `look_cos.gd` | `V10LookCos` | D5. **Единый каталог косметики**: всё из V10ProfileCos (рамки, титулы, значки, фоны — реестр §2.7 остаётся там) + темы, столы, HUD, стинги, шрифты в той же форме. `kit_line()` для баннера «Набор: …». Проверка: элементы набора никогда не продаются, SSR не бывает у симулированных |
| `card_look.gd` | `V10LookCard` | D5/D6. Карточка с набором: `payload(S)` (тема, стол, рамка набора при рамке по умолчанию), `validate`, `sim()` (только A-темы, без стола), `view()` — V10CardView с миниатюрой темы вместо старой TileBack |
| `look_selftest.gd` | `V10LookSelftest` | `--look_selftest=1` |
| `look_runner.gd/.tscn` | — | Самотест и скриншоты без горячих файлов |
| `tools/prep_zlata.py` | — | Нарезка арта скина Златы в @2x 9-patch + `nine.json` |

## Арт (Higgsfield, gpt_image_2_6 high)
`game/assets/v10/look/zlata/`: `window` (лаковое окно с золотым растительным орнаментом), `plate_s/m/l`, `btn_play` (алая лаковая пилюля),
`btn_cash` (чёрный лак + золотая линия), `medallion` (кнопки «тихие» и кружки помощи), `feather` (вкладка; `feather_tile` — эмблема рубашки и частица),
`currency` (огненная лента), `header` (лак + орнамент по нижней кромке), `corner` (угол для «пера»), `menu_bg` (жар-птица на лаке),
`table` (крышка лаковой шкатулки — стол Златы), `loading` (одобренная карточка волны 1, POSES §16 поза 1, без новой генерации).
`game/assets/v10/look/emblems/` — эмблемы рубашек тем. Job id — `jobs.tsv` в этой папке ассетов (для референсов). Орнамент — «в духе народной росписи, свой рисунок» (без названий промыслов).

## Самотест и скриншоты
```bash
cd game
flock /tmp/tw-godot.lock /opt/tw-tools/godot --headless --path . res://scripts/v10/look/look_runner.tscn -- --look_selftest=1
# -> LOOK_SELFTEST n/n OK, код выхода = число провалов
flock /tmp/tw-godot.lock xvfb-run -a /opt/tw-tools/godot --path . --rendering-driver opengl3 --audio-driver Dummy \
  --resolution 720x1280 res://scripts/v10/look/look_runner.tscn -- --look_shots=/abs/dir [--views=home,match,...]
```
Виды: `tiles ranked match home window kit style picker fonts card assemble preview loading`.
После добавления файлов в свежий worktree один раз `godot --headless --path . --import` (кэш class_name).

## Хуки для интегратора (короткие вызовы в горячих файлах)
1. **registry_list.gd** (когда появится `V10Registry`): самотест `--look_selftest=1` → `await V10LookSelftest.run(host)`;
   дефолт сейва `look: {frame: "auto", tile: "auto", table: "auto", hud: "auto"}`; миграция `V10Look.migrate(G.S)` один раз при загрузке
   (идемпотентно, `S.look` включить в код восстановления V8Recovery). Опционально autoload `V10LookHub="*res://scripts/v10/look/look.gd"`.
2. **g.gd `skin_look()`** → `return V10Look.tile_look(S, {"ranked": <режим рейтинга>, "big_symbols": S.get("big_symbols", false)})`.
   Старые вызовы `G.skin_look()` (play, album, specials) получат тему без правок.
3. **tile.gd `build()`** после `V6TileLook.dress(self)`: `V10TileTheme.dress(self)` (no-op для словарей без `v10`).
4. **board_table.gd `setup()`**: в конце — `var tid := String(V10Look.current().table); if tid != "": V10TileTheme.apply_table(self, tid, {"static": ranked})`;
   после любого `V6TileLook.relight(tiles)` — `V10TileTheme.relight()`. Стол S/SSR-набора заменяет стол локации (решение D3); `base` — стол локации.
5. **Пары**: в месте, где play.gd/tray_board.gd запускает эффект пары (через `V10Hooks.pair_taken(info)`), — `V10PairFx.burst(board, pos, board.look)`.
6. **fx_level**: при смене «Эффекты» — `V10TileTheme.anim_on = G.fx_level() != "min"` (материалы пересоздаются по ключу).
7. **Гардероб (collection.gd / Героини)**: над нарядом `V10KitStrip.make(hero, outfit, 672)`; «Сделать партнёром» → `G.S.partner = h; V10Look.wave(screen); V10Look.notify(); V10HudSkin.sync(V10Look.current()); V10HudSkin.sting(false)`;
   вкладка «Фишки и столы» → `V10TilePicker.make(G.S, size)` (сигнал `picked(id)` → `V10Look.set_choice(G.S, "tile", id)`).
8. **Профиль → «Мой стиль»**: `V10StylePicker.make(G.S, size)`, `done(changed)` → `G.save()`.
9. **Баннер (Г3/Г6)**: строка `V10LookCos.kit_line(hero, outfit)`; «Примерить стиль» → `V10PreviewBar.open(screen, hero, outfit, func(): <к баннеру>)`.
10. **HUD-скин (D7)** — одна проверка `if V10HudSkin.skinned(): V10HudSkin.decorate(node, role)` в: `jbutton.gd` (класс кнопки → `btn_play/btn_cash/btn_secondary/btn_quiet`),
    `rbox.gd`/`V10Plate` (`plate_s/m/l`), `Common.popup` (`window` + `V10SkinFx.open(win, V10HudSkin.active)`), `V8Header` (`header`), topbar валют (`currency`),
    navbar (`tab`), шапка партии и рамка лотка (`header`, `plate_l`), кружки помощи (`btn_quiet`), загрузка (`V10HudSkin.loading`), фон меню (`V10HudSkin.menu_bg`,
    **не включать, если на главной риг** — правило 1 риг + 1 видео). При `five_winds` ничего не меняется (самотест: снимок дерева до/после).
    Нажатие — `V10SkinFx.press(node, V10HudSkin.active)` после `V9Feel.press`.
11. **Смена партнёра на SSR / первое получение**: `V10SkinAssemble.play(main.overlay, home, V10HudSkin.active, keep_cb, func(): V10Look.set_choice(G.S, "hud", "base"))`.
    Полный стинг 4–6 с — один раз за сессию при входе в Чайную: `V10HudSkin.sting(true)` (лимит 600 с внутри).
12. **Шрифты (D2)**: заголовки экранов/окон, имя Приёма в `cutin.gd`, «Победа!», подпись писем → `V10LookFonts.title(label, text, max_w, moment)`
    (moment: `screen_title / window_title / ult_name / victory / letter_sign`). Цены — только `V10LookFonts.price_font()`.
13. **Профиль 2.0 / карточка (D5/D6)**: вместо `V10CardPayload.mine` — `V10LookCard.payload(G.S, extra)`; вместо `V10CardView.make` — `V10LookCard.view(p, rect, mode)`;
    population.gd → `V10LookCard.sim(rng, tier, nick)`; league.gd строки — `V10LookCard.view(p, rect, "row")`. Сервер (1.0) — `V10LookCard.validate(p)`.
14. **`--skin=zlata`** (тестовая сборка): `V10Look.dev_reveal["zlata"] = true` в разборе аргументов main.gd.
15. **Стинг**: `Sfx.sting(path)` (дакинг −8 дБ) придёт с `v10-audio`; пути в `V10KitData.STINGS` — файлы положить туда (сейчас вызов молчит, лимит работает).
16. **V10Rank** (ветка экономики): `V10KitData.hero_rank/outfit_rank` уже вызывают `V10Rank.hero_rank/outfit_rank`, если класс есть — проверить имена методов при слиянии.

## Открытые вопросы
- Злата скрыта (её нет в `G.HEROES`); весь её набор виден только с `--skin=zlata` и в примерке.
- Стинг-аудио и 5 SFX Златы — дорожка audio (здесь только каркас и лимит).
- Рамки основательниц рисуются кодом (V10FrameView из v10-profile); отдельные орнаменты 256×256 не генерировались.
