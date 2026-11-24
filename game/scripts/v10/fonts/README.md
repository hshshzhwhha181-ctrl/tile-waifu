# V10Fonts — шрифты богинь (0.10, spec D2)

Ветка `v10-fonts`. Новые файлы только в `game/assets/v10/fonts/` и `game/scripts/v10/fonts/`;
существующие файлы не тронуты — точки встраивания ниже.

## Что выбрано

Все шрифты — Google Fonts (`github.com/google/fonts/ofl/*`), SIL OFL 1.1, полная кириллица
(66 букв с Ё/ё проверены fontTools и самотестом). Закрепление по `docs/0.10-spec.md` D2;
для основательниц S (Юэ, Нова) добавлены акцидентные шрифты для баннеров их SSR-нарядов.

| id | Шрифт | Кому / зачем | Почему | Файл | Размер |
|---|---|---|---|---|---|
| `ui_body` | Nunito (0.8, var) | весь UI, все цены | округлый, тёплый, читается в 16 px | `assets/fonts/nunito-*.woff2` | — |
| `ui_display` | Playfair Display (0.8, var) | заголовки, режимы, «по умолчанию» | дидона, «дорого» | `assets/fonts/playfair-*.woff2` | — |
| `ui_display_italic` | Playfair Display Italic | кат-ины, зоны салона | | `assets/fonts/playfair-i-*.woff2` | — |
| `hand` | Caveat 600 | почерк основательниц, письма | живой почерк, contextual alternates | `caveat/caveat-600.woff2` | 83 КБ |
| `palm` | Neucha | «Чтение руки» | рукописная, мягкая | `neucha/neucha.woff2` | 20 КБ |
| `zlata_title` | Ruslan Display | Злата — заголовки | древнерусский устав, жар-птица, лубок | `ruslan_display/*.ttf` (RFN) | 55 КБ |
| `zlata_text` | Kurale | Злата — акцент | каллиграфичная антиква с кириллицей «книжной» | `kurale/kurale.woff2` | 19 КБ |
| `minamo_title` | Cormorant Infant SemiBold Italic | Минамо | текучий курсив, жемчуг и волна | `cormorant_infant/*-i600.woff2` | 35 КБ |
| `minamo_text` | Great Vibes | Минамо — акцент, подпись | связный парадный скрипт, «письмо из Жемчужного дворца» | `great_vibes/great-vibes.woff2` | 60 КБ |
| `kira_title` | Russo One | Кира | рубленый техно-гротеск, мех-фрейм | `russo_one/*.ttf` (RFN) | 39 КБ |
| `kira_text` | Exo 2 SemiBold | Кира — акцент | HUD-гротеск | `exo2/exo2-600.woff2` | 24 КБ |
| `vesper_title` | Yeseva One | Веспер | контрастная «готическая графиня» | `yeseva_one/*.ttf` (RFN) | 108 КБ |
| `vesper_text` | Cormorant Garamond Medium Italic | Веспер — акцент | старинный курсив | `cormorant_garamond/*-i500.woff2` | 37 КБ |
| `sigrid_title` | Philosopher Bold | Сигрид | северная, с «рунными» засечками | `philosopher/philosopher-700.woff2` | 20 КБ |
| `sigrid_text` | Jura SemiBold | Сигрид — акцент | холодный узкий гротеск, иней | `jura/jura-600.woff2` | 19 КБ |
| `yue_title` | Tenor Sans | Юэ (SSR-наряды) | придворная элегантность, острые Л/Д, «Любопытно…» | `tenor_sans/*.ttf` (RFN) | 132 КБ |
| `nova_title` | Unbounded Bold | Нова (SSR-наряды) | широкий цифровой гротеск, неон и данные; не путается с Russo One Киры | `unbounded/unbounded-700.woff2` | 36 КБ |
| `sym` | Nunito (₽ № € × −) | хвост каждой цепочки | в 0.8-сабсетах nunito/playfair **нет ₽** | `nunito_sym/nunito-sym.woff2` | 2,7 КБ |

Итого новых файлов шрифтов ≈ 0,69 МБ (бюджет spec — ≈0,8 МБ / 1 МБ в самотесте).

**Отступление от spec D2:** Marck Script (акцент Минамо) заменён на Great Vibes — в превью Godot
Marck рвёт связки букв («П р и л и в ы»), выглядит дёшево; Great Vibes — полноценный связный скрипт
с кириллицей. Остальные закрепления spec D2 сохранены.

Отвергнуты после превью: Prata (слишком похожа на Playfair), Poiret One (волосяные штрихи
пропадают на 24–30 px), Rubik Glitch (шумно, «дёшево» в заголовках), Tektur (близко к Russo One
Киры), Pixelify Sans (нет кириллических О и П), Oranienbaum/Forum (дидона, дублирует Playfair).

### Лицензии
* `OFL.txt` лежит рядом с каждым шрифтом; для 0.8-шрифтов — `assets/v10/fonts/licenses/`.
* Шрифты с Reserved Font Name (Ruslan, Russo, Yeseva, Tenor; Playfair — 0.8) поставляются
  **без изменений** (оригинальный TTF, без subset), остальные — статический инстанс веса +
  subset (Latin-1, кириллица, пунктуация, №, ₽, €) в WOFF2, все OpenType-фичи сохранены.
* Пересборка: `python3 -I game/scripts/v10/fonts/tools/build_fonts.py <dl_dir> game/assets/v10/fonts`
  (`pip install fonttools brotli`; `<dl_dir>/<google_dir>/<file>` как в `FONTS`).

## API (`scripts/v10/fonts/fonts.gd`, `class_name V10Fonts`)

```gdscript
V10Fonts.font(id, weight := -1) -> FontVariation      # кэш, цепочка fallbacks
V10Fonts.skin(skin, role := "title", size := 44)      # шрифт партнёра или Playfair/Nunito
V10Fonts.skin_id(skin, role, size) -> String          # < 24 px -> ui_body; deco=false -> ui_display
V10Fonts.px(id, size) -> int                          # оптическая поправка кегля (OPTICS)
V10Fonts.fit_title(text, skin, size, max_w) -> {font, size, id}  # ужать до 36 px, затем Playfair
V10Fonts.coverage(id, text, with_fallback := false) -> float
V10Fonts.credits() -> Array[{family, id, who, licence, copyright}]
V10Fonts.licence_text(id) -> String
V10Fonts.deco: bool                                   # «Декоративные шрифты»
```
Цепочка fallbacks: шрифт → playfair-cyr → playfair-lat → nunito-cyr → nunito-lat → nunito-sym
(для `ui_body` Playfair пропускается).

## Тесты
```
flock /tmp/tw-godot.lock /opt/tw-tools/godot --headless --path game res://scripts/v10/fonts/fonts_runner.tscn -- --fonts_selftest=1
flock /tmp/tw-godot.lock xvfb-run -a /opt/tw-tools/godot --path game res://scripts/v10/fonts/fonts_runner.tscn -- --fonts_preview=/abs/fonts_preview.png
```
Самотест: каждый файл грузится, OFL.txt рядом и начинается с Copyright; кириллица+«»—…№₽ через
цепочку 100 %, собственный файл ≥ 98 % и все 66 букв; 5 длинных заголовков в 44 px ≤ 600 px для
каждого из 7 скинов (или fit_title уходит на Playfair); deco off → Playfair/Nunito; < 24 px → Nunito;
бюджет ≤ 1 МБ.

## Точки встраивания (сделать интегратору)
1. **`ui.gd`** `UI.font(kind, weight)`: если `kind == "title"` и есть партнёр-SSR —
   `return V10Fonts.skin(G.S.partner_skin, "title", size)`; порог тот же `TITLE_MIN = 24`. Цены — всегда `UI.font("body")`.
   Заодно добавить `res://assets/v10/fonts/nunito_sym/nunito-sym.woff2` в конец `fallbacks` у `UI.font`
   (сейчас ₽ рисуется только системным шрифтом: в 0.8-сабсетах его нет).
2. **`v09/ult/cutin.gd` `_name_font()`** → `V10Fonts.skin(heroine_skin, "title", 44)` (для не-SSR остаётся Playfair Italic: `V10Fonts.font("ui_display_italic")`).
3. **Заголовки экранов**: Label с `set_meta("v10_title", true)` слушают `V10Look.look_changed` и
   делают `fit_title(text, skin, 44, avail)` + кроссфейд `V10Fonts.XFADE` (0,25 с).
4. **Настройки**: `G.S.deco_fonts` (по умолч. true) → `V10Fonts.deco` при загрузке и переключении;
   экран «Шрифты и лицензии» строится из `V10Fonts.credits()` + `licence_text(id)`.
5. **`main.gd`**: диспетчер `--fonts_selftest=1` → `V10FontsSelftest.run()` (код выхода = число провалов);
   до этого работает отдельный `fonts_runner.tscn`.
6. **`export_presets.cfg`**: `include_filter` + `assets/v10/fonts/*/OFL.txt, assets/v10/fonts/licenses/*.txt`
   (иначе txt не попадут в APK и экран лицензий будет пуст; самотест сборки должен это проверить).
7. **`banners.json`** (Г6): поле `font` = id из `SKIN_FONTS[*].title` (`zlata_title`, `yue_title`, `nova_title`, …).
8. Письма основательниц / подписи в чатах: `V10Fonts.font("hand")` (Caveat 600, `px("hand", n)`).
