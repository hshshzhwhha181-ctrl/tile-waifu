# Ростер 20 богинь: лестница A / S / SSR

> **Статус:** проект на утверждение владельцу, 2026-11-24. Генерация не запускалась, код не менялся.
> **Опирается на:** `HEROINES.md` (поправки владельца, красные линии, §2 ульты, §3 лестница, §5 героини), `ART_DIRECTION_v2.md` (рецепт стиля v4 и цены §5), `ROADMAP.md`, `0.9-spec.md`, `CEO_PLAN.md`, `game/scripts/g.gd` (HEROES, ITEMS, `roll()`), `game/scripts/hero.gd` (RIGS).
> **Красные линии из HEROINES.md действуют без исключений:** все богини явно взрослые (возраст 20+ в каноне и в профиле), нет школьной тематики и «учитель — ученик», нет наготы, белья как самостоятельного наряда, просвечивающей ткани на интимных зонах, сексуальных действий, ракурсов под юбку и камеры, которая разглядывает тело. Флирт направлен только на игрока. Для Яндекс-сборки у каждого наряда есть скромный вариант: непрозрачные колготки и обрезка `alt_rect`.

**Что решить владельцу** (подробности в §6):
1. Лестница 8 / 7 / 5. Основательницы: МТ, Рин и Хана в A, Юэ и Нова в S, все пять SSR-богинь новые.
2. Правило набора: SSR-наряд поднимает набор косметики на одну ступень, но не выше S. Полный HUD-скин есть только у SSR-богинь.
3. Физика в idle: волосы, ткань, покачивание всего тела и мягкая вторичная физика груди/бёдер от дыхания и движения — можно (решено 2026-11-24, «сочно как в BD2»). Нельзя: изолированное колыхание как самоцель кадра и камера по телу.
4. Бюджет: стартовые пакеты 15 новых богинь стоят ≈2,9 тыс. кр, поздние наряды ещё ≈1,8 тыс. кр. Это в 3–4 раза больше, чем заложено в ROADMAP. Волна 1 стоит ≈0,9 тыс. кр (экономный вариант ≈0,7 тыс.).

---

## 0. Рамка мира (5 строк)

«Богиня стола» — это титул сильнейших игроков всех миров. Стол «Пяти ветров» в салоне Маджонг-тян стоит на перекрёстке миров: через фишку 東 к нему приходят гостьи из пустынь, морей, звёздных флотов и северных княжеств. Каждая пришла за одной партией и осталась. Игрок — единственный хозяин стола, кого признали все двадцать. Сюжет каждой богини держится на трёх опорах: зачем пришла, что ищет, что открывает игроку на высокой симпатии.

---

## 1. Лестница и экономика

### 1.1 Распределение 8 / 7 / 5

| Ранг | Сколько | Основательницы | Новые | Смысл ранга |
|---|---|---|---|---|
| **A** | 8 | **mc** (стартовая, талисман, бесплатно), **rin**, **hana** | tsubame, miel, lian, tsuru, jess | Легко получить, повседневная роль, малый набор косметики |
| **S** | 7 | **yue**, **nova** | kohaku, shirin, mari, hibana, nemi | Яркая роль-фантазия, своя тема фишек и стол |
| **SSR** | 5 | — | zlata, minamo, kira, vesper, sigrid | Флагман баннера, полный HUD-скин, больше всего анимации |

- Ранги основательниц совпадают с рангом их базовых нарядов в коде: `o_base`, `r_base`, `h_base` — R, `y_base`, `n_base` — SR (g.gd:56–75). Миграция сохранений не нужна.
- **Ранг богини не означает силу и откровенность.** Он означает редкость и объём косметического набора. Рин в A не «хуже» Веспер в SSR.
- В UI R/SR/SSR переименовываются в **A/S/SSR** во всём, включая наряды и скины. Значения `rar` в коде соответствуют 1:1 (R→A, SR→S). Цвета рамок совпадают с цветами фонарей призыва (0.9-spec §E): A — нефрит, S — лаванда-серебро, SSR — золото.

### 1.2 Наряды по рангам

У каждой богини 3–4 наряда. Базовый наряд имеет ранг самой богини.

| Богиня | Наряды |
|---|---|
| A | A (база) → S → SSR (+ «Обет» SSR на симпатии 10, позже) |
| S | S (база) → A (повседневный, магазин) → SSR → SSR (сезонный или «Обет») |
| SSR | SSR (база) → S (гэп-моэ «вне службы») → SSR → SSR (сезонный или «Обет») |

**Эскалация привлекательности по рангу наряда** (сборка RuStore/APK, решение владельца от 2026-11-24, 17+/18+):

| | A | S | SSR |
|---|---|---|---|
| Образ | Повседневно-милый, один акцент: чулки, перчатки, лента | Облегающий костюм роли, подчёркнутая фигура: талия, декольте, ноги, 2+ фактуры | Самый эффектный: вечернее или церемониальное платье, 4+ слоя, открытые плечи или спина, высокий разрез, кружевной верх чулок и подвязки как часть костюма |
| Поза | 3/4 на уровне глаз | Фирменный жест, нога на ногу во взрослом контексте | Диагональ, передний план, ветер в волосах и лентах (не в подоле); не больше одного «взгляда через плечо» на богиню |
| Анимация | Риг + 1–2 видео | Риг + петли и реакции | Всё, плюс кат-ин из видео и HUD-перестройка |

Дороже — значит больше мастерства, роскоши, движения и сюжета. **Никогда не растут:** нагота, кадрирование на части тела, сексуальность действия. Скромная Яндекс-версия делается из того же опорного кадра.

### 1.3 Что открывает ранг (набор богини)

Набор включается, когда богиня назначена партнёром (`S.partner`).

| Ранг набора | Рамка аватара | Акцент фишек (цвет подсветки, частицы пары) | Тема фишек (рубашка, рамка, фишка-подпись) | Стол (фон и материал подложки) | HUD/меню-скин | Музыкальный стинг |
|---|---|---|---|---|---|---|
| A | ✓ | ✓ | — | — | — | — |
| S | ✓ | ✓ | ✓ | ✓ | — | — |
| SSR | ✓ | ✓ | ✓ | ✓ | ✓ (панели, кнопки, вкладки, валюты, диалоги, фон меню, экран загрузки) | ✓ (4–6 с на входе в меню и на победе) |

- **SSR-наряд поднимает набор на одну ступень, но не выше S.** Например, МТ в `o_dragon` получает тему «Золото дракона» и стол. Полный HUD остаётся только у пяти SSR-богинь, иначе SSR-ранг обесценивается.
- **SSR-наряды SSR-богини** меняют палитру её HUD-скина (пресеты шейдера, без новых картинок).
- Существующие предметы входят в наборы основательниц: `s_sakura`, `s_mint`, `s_lemon`, `s_night`, `s_neon`, `s_gold`, `b_palace`, `b_neon`. Кто уже владеет ими, ничего не теряет.
- Базовый HUD игры — это набор МТ «Пять ветров». Без партнёра или с A-богиней игрок видит его.

### 1.4 Как получить

| Кто | Путь |
|---|---|
| Основательницы | Как сейчас: МТ сразу, остальные через осколки портрета на Пути |
| A | Стандартный призыв, гарантированный путь за Лепестки (фиксированная цена, CEO_PLAN №12), награда за 7-дневный вход (одна A-богиня в квартал) |
| S | Стандартный и сезонный призыв, награда трека ивента («Испечь вместе») |
| SSR | Лимитированный баннер на 14 дней с повышенным шансом, через 6 месяцев рерун со «звёздочкой», затем стандартный пул. **Пропуск сезона даёт SSR-наряд, но не SSR-богиню** |

**Шансы (оставляем текущий `G.roll()`, g.gd:924):** SSR 3%, мягкий гарант с 46-й крутки, жёсткий на 60-й; S 15% и гарант каждые 10; A — остальное. На баннере богини SSR-слот делится 50/50: богиня баннера или другой SSR. Правило 50/50 действует только для новых счётчиков, с анонсом за 14 дней (CEO_PLAN №10). Цена в ₽ показана у каждой крутки (№11).
**Пулы:** наряд выпадает только для богинь, которыми игрок уже владеет. Наряды чужих богинь в пуле не участвуют.
**Дубликаты дают «Созвездие» 0–5★**, с гарантированным путём через Лепестки:
- ★1 — вторая пачка реплик;
- ★2 — золотая фишка-подпись;
- ★3 — второй вариант idle;
- ★4 — анимированная рамка;
- ★5 — аура в профиле и на карточке лиги.

Силы Созвездие не даёт.

### 1.5 Что видят другие игроки

| Где | Что видно |
|---|---|
| Карточка лиги и таблицы | Портрет богини в надетом наряде (обрезка из опорного кадра), рамка ранга, рамка аватара, Созвездие, миниатюра рубашки фишек |
| Дуэль и призрак-дуэль | По HEROINES §2: соперница показана портретом и рамкой, её ульта идёт без кат-ина (строка и подсветка цели). На мини-столе соперника видны **её рубашка фишек и акцент**. HUD-скин соперника на чужой экран не применяется: у каждого свой HUD |
| Профиль (витрина) | Богиня в наряде с живой idle-петлёй, если пакет скачан, иначе стоп-кадр; названия темы фишек и стола; коллекция «N/20»; Созвездие |
| «Поделиться» (сетка дня) | Сетка без спойлеров, подкрашенная акцентом богини |

### 1.6 Рейтинговый режим: богини и наряды не дают силы

- Правило HEROINES §2 распространяется на всех 20: стартовый заряд 0, порог 6 пар, модификаторы выключены, клип короткий, ядра выровнены в «парах-эквиваленте» с разбросом ≤10% (прогон бота, population.gd).
- Набор косметики в рейтинге:
  - тема фишек меняет только рубашку и рамку, лица фишек остаются стандартными (контраст ≥4,5:1);
  - стол статичный, 6-секундный скин после SSR-ульты выключен;
  - HUD-скин остаётся, потому что он вне поля.
- В профиле и магазине пишем: «В рейтинге богини и наряды не дают силы».

---

## 2. Ростер: сводная таблица

| # | id | Имя | Ранг | Возраст (канон) | Стихия / тема | Концепт в одну строку | Фишка-подпись | Палитра | Волна |
|---|---|---|---|---|---|---|---|---|---|
| 1 | mc | Маджонг-тян | A | 26 | ветер, сакура | Хозяйка салона «Пять ветров», талисман и стартовая богиня | sakura | ff8fb8 · 3fae8c · fff4ec | осн. |
| 2 | rin | Рин | A | 27 | чай, нефрит | Мастер чая «Ледяного павильона», тает медленно | matcha | 4fbf9f · 1e3b33 · e9d8a6 | осн. |
| 3 | hana | Хана | A | 24 | солнце, бег | Капитан фонарной эстафеты, вечно зовёт на реванш | sunflower | ffb35c · 2b4a7a · fff1d6 | осн. |
| 4 | tsubame | Цубамэ | A | 24 | тень, дым | Куноити-курьер, носит письма между мирами | plum | 1d1b2e · c8283c · a9b0c2 | 1 |
| 5 | miel | Миэль | A | 25 | сахар | Кондитер западного квартала, кормит весь салон | cake | f6e7cf · c98a4b · e0566f | 1 |
| 6 | lian | Лянь | A | 28 | струна, река | Музыкантша пипы с чайной лодки | koi | 1f4e5a · f1d6cf · c9a35b | 2 |
| 7 | jess | Джесс | A | 25 | пыль, закат | Ковбойша чайного тракта из Медного каньона | clover | 3d5a80 · b5532f · e8cf9a | 2 |
| 8 | tsuru | Цуру | A | 31 | пар, журавль | Хозяйка горного онсэн-рёкана, «старшая сестра» | lantern | 2e3a6b · e0703b · f1ece4 | 3 |
| 9 | yue | Юэ | S | на вид 27 | луна | Правительница Лунного дворца, проигрывает нарочно | moon | c8b6ff · 2a2350 · e8e4f4 | осн. |
| 10 | nova | Нова | S | 23 | неон, данные | Белый хакер и гонщица, говорит логами | diamond | 4fe3ff · ff6fd8 · 1a1530 | осн. |
| 11 | kohaku | Кохаку | S | на вид 25 (лисе 900) | лисий огонь | Белая лиса-жрица храма Тысячи врат, хранит удачу салона | fox | f3efe9 · d63a2a · e2a23d | 1 |
| 12 | shirin | Ширин | S | 26 | песок, солнце | Танцовщица и гадалка каравана «Семь колодцев» | sun | d9b26f · 1f8f8a · c08a1e | 1 |
| 13 | mari | Марисоль | S | 29 | шторм, море | Вольный капитан чайного клипера | bell | 1f2f4a · c23a3a · d4b15a | 2 |
| 14 | hibana | Хибана | S | 27 | гром | Барабанщица-тайко, будит грозой чайные сады | lightning | 2c2650 · ffd23f · 8e8fa3 | 3 |
| 15 | nemi | Неми | S | на вид 26 | лес | Эльфийка-лучница, страж диких чайных деревьев | maple | 4f6b35 · b8612e · ece4cf | 3 |
| 16 | zlata | Злата | SSR | 25 | жар-птица, весна | Царевна Жар-птица из сказочного царства, приносит весну | fire | c3242b · e8b23a · 1b1513 | 1 |
| 17 | minamo | Минамо | SSR | на вид 26 | жемчуг, море | Принцесса подводного Жемчужного дворца | water | 7fd3d0 · f3e9f1 · 3a4fa0 | 2 |
| 18 | kira | Кира | SSR | 23 | сталь, тяга | Ас-пилот мех-фрейма «Хризантема» | star | f2f2f5 · e03a3e · 1c2b4a | 2 |
| 19 | vesper | Веспер | SSR | на вид 28 (ей 400) | алая ночь | Графиня-вампир, пьёт только гранатовый чай | crown | 6b0f1a · 141018 · c9c3cf | 3 |
| 20 | sigrid | Сигрид | SSR | 24 | иней, сияние | Северная княжна, приносит северное сияние | snowflake | dff1f7 · 7fc8d8 · 8b7fd6 | 3 |

**Проверка на различимость.** У всех 20 разные силуэты причёсок:
- высокие хвосты (mc), коса набок (rin), каре (hana), длинные волосы до пояса с рожками (yue), асимметричная стрижка (nova);
- сверхдлинный хвост (tsubame), локоны набок (miel), химэ-кат до пола (lian), высокая причёска с канзаси (tsuru), две низкие косы под шляпой (jess);
- лисьи уши и хвост (kohaku), пышные волны с монетами (shirin), рыжие кудри под треуголкой (mari), вулф-кат с цветной изнанкой (hibana), эльфийские уши и тонкие косички (nemi);
- одна толстая коса с кокошником (zlata), плывущие пастельные волны с жемчугом (minamo), короткий белый боб с гарнитурой (kira), винные локоны с вуалеткой (vesper), коронная коса с ледяной тиарой (sigrid).

Типы фигуры тоже разные, все мягкие и женственные, без мышц: от «миниатюрная пышная» до «высокая статная».

**ИС:** имена сверены с очевидными совпадениями. Отброшены: «Касуми» (куноити DOA), «Райко» (барабанщица Touhou), «Самира» (пустыня, LoL), «Ясмин», «Нами», «Палех» и «Хохлома» (охраняемые наименования промыслов, используем «орнамент в духе народной росписи, свой рисунок»). До релиза сверить с каталогом BD2 (DotGG) и kamigame по ART_DIRECTION §2 «ИС».

---

## 2.1 Общая часть промпта (рецепт стиля v4, дословно для всех 20)

Промпт собирается так: `twaifu_<id>, adult woman, <возраст> years old, <роль>, ` + **V4_FACE** + `<выражение>, ` + **ТЕЛО** (из карточки: облик и наряд, затем поза, окружение, свет и кадр богини из `POSES.md`) + **V4_TAIL**.
Поза, окружение, свет и кадр у каждой богини свои и не повторяются (правило владельца, `POSES.md` §0). Для другого слота (`select`, `win`, `lose`, `shy`, `tease`) в промпте карточки меняется только фраза позы. Кадр и ракурс задаёт строка «Кадр» богини, поэтому в V4_TAIL общего `knees-up three-quarter view, eye-level camera` больше нет.
В `image_references` подаётся лист персонажа (лицо анфас и 3/4, причёска сзади и сбоку, фигура, HEX). Для основательниц дополнительно эталоны `docs/concepts/v4/cute_<id>.webp`.

**V4_FACE**
```
cute adult Japanese gacha-game face: soft rounded yet mature oval face with visible cheekbones, moderately large eyes (not doll-like) with a soft gradient iris and one or two small highlights, thin lashes, small mouth, light blush, simple lively emotion, 
```

**V4_TAIL**
```
7.5 heads tall, soft feminine figure with no visible muscles, form-fitting costume with a detailed cut, fabric texture and at least three accessories, layered fabrics, emphasizing her figure; she is the brightest, most saturated and sharpest element of the frame; full background scene but muted and desaturated, lowered saturation and contrast, light haze and gentle darkening, fewer details, no loud bokeh, no neon clutter; thin warm-colored lineart, lost edges in highlights, soft painterly shading on a cel-shaded base, matte skin, highlights only in the eyes and on the lips, no AI gloss; fully opaque fabric, garment stays exactly in place, adult mature face, no school elements, mahjong tiles blank or absent, no text, no logos, vertical 9:16
```

**Легвир (с 2026-11-24): `LEGWEAR.md` — источник правды по ногам.** Фраза ног в промпте берётся по коду LW из строки наряда (`LEGWEAR.md` §3). APK-сборка добавляет после ТЕЛА `LEG_TAIL` (и `SHEER_TAIL` / `GLOSS_TAIL`), в V4_TAIL заменяет `fully opaque fabric` на `fully opaque fabric on the bodice, hips and skirt; sheerness only on the legwear` и берёт APK-негатив (`LEGWEAR.md` §1.6). Промпты карточек ниже уже содержат APK-фразу базового наряда.

**Скромная версия (Яндекс):** в ТЕЛЕ фраза ног заменяется на Я-фразу кода LW (`opaque <цвет> tights`, без узора выше щиколотки), вырез поднимается, кадр обрезается по `alt_rect`, V4_TAIL остаётся с `fully opaque fabric`.

---

## 3. Карточки богинь

Модификаторы ульт — по схеме HEROINES §2:
- **П** — подсветить пару;
- **О** — открыть закрытую фишку;
- **Л** — лёд или замок;
- **В** — вернуть фишку из лотка;
- **Ц** — видимая автоцель;
- **С** — пара для самой старой фишки лотка.

У базового наряда модификатора нет, у одной богини модификаторы не повторяются. «Рейт.» — как ядро выравнивается в рейтинге.

### 3.1 Основательницы (облик закреплён, подробности в HEROINES.md §5)

#### mc — Маджонг-тян · **A** · ветер и сакура · 26
- **Обаяние:** наставница, которая не умеет проигрывать и ревнует тебя к партиям с другими. Опоры: высокие розовые хвосты с нефритовыми узлами и фишка 東. Тег: «Партия окончена~». Фигура: пышные песочные часы.
- **Поведение:**
  - тап по голове — хвосты подпрыгивают, «Эй, причёска!»;
  - рука — щелчком отправляет 東 в камеру;
  - наряд (веер или 東) — подмигивает;
  - победа — «Партия окончена~» и подмигивание;
  - поражение — надувает щёки, требует реванш;
  - комбо — хвосты взлетают.
- **Эмоции:** победная, дразнящая, ревнивая (надутые щёки), тёплая, удивлённая.
- **Позы:** вся постановка (6 поз, пластика, окружение, свет, кадр, анимация) — в `POSES.md` §1. Главные три:
  1. Щелчок 東 в камеру из широкой боковой стойки, подмигивание (`select`).
  2. Опирается бедром о край стола и крутит фишку (`idle`).
  3. Ревниво держит рукав игрока и наматывает хвост на палец (`shy`).
- **Фирменный idle:** крутит фишку между пальцами, хвосты пружинят.
- **Наряды:**
  - `o_base` A — · ноги **LW01** «Сакуровый след»;
  - `o_cafe` S В · ноги **LW02** «Сакуровый бант»;
  - `o_cozy` S О · ноги **LW03** «Розовая полоска»;
  - `o_tutor` S П (скрыт до перерисовки) · ноги **LW04** «Лекторий»;
  - `o_dragon` SSR Л · ноги **LW05** «Драконья чешуя»;
  - `o_grand` SSR Ц · ноги **LW06** «Четыре ветра»;
  - `o_vow` SSR С · ноги **LW07** «Пион рассвета».
- **Ядро:** снимает 1 пару (тап по паре).
- **История:**
  1. Держит салон на перекрёстке миров.
  2. Хочет, чтобы ты стал ей равным за столом.
  3. На высокой симпатии — «Обет весеннего ветра».
- **Набор:**
  - A — рамка «Пять ветров» и акцент «Сакура» (`s_sakura`). Её HUD — базовый HUD игры.
  - Через SSR-наряд — тема «Золото дракона» (`s_gold`) и стол «Чайный сад».
- **Палитра:** ff8fb8 · 3fae8c · fff4ec.
- **Промпт** (роль: `mahjong salon owner`; выражение: `playful wink with a confident smile`; поза: `select` из `POSES.md`):
```
high pink twin tails tied with jade knots, rose-pink eyes, holding a blank ivory mahjong tile between two fingers near her face, curvy hourglass figure, full bust, soft shoulders; knee-length sakura-pink cheongsam with jade piping and side slits, mandarin collar with a teardrop opening showing light cleavage, cinched waist, sheer blush-pink 20-denier stockings with a visible satin sheen and small embroidered sakura petals clustered just above and below the knee, thinning toward the ankle, tops hidden under the cheongsam hem, jade earrings, pink pumps; standing side-on to the mahjong table in a wide planted stance, feet set wide apart on a line parallel to the table edge and not toward the camera, both legs straight with her weight centered, torso twisted to face the viewer, right arm extended flicking a blank ivory tile off her thumb so it spins toward the camera, left hand catching the end of her left twin tail at shoulder height, playful wink with a confident smile; background: the Five Winds mahjong salon at late evening, warm cherry-wood interior, lattice windows onto the dark night, green-felt mahjong table with a wall of blank tiles, carved salon chairs, sakura-pink paper lanterns, four wind chimes hanging from the ceiling, a sakura branch in a jade vase, petals on the felt, muted; lit only by sakura-pink paper lanterns, warm pink-amber key, soft jade-green bounce light from the felt below; opponent's point of view across the mahjong table, green felt and a wall of blank tiles in the lower foreground, camera at a seated player's eye level, tilt up under 5 degrees, knees-up, she is centered or slightly right, twin tails crossing the top edge, 
```

#### rin — Рин · **A** · чай и нефрит · 27
- **Обаяние:** считает чувства неэффективными, но наливает ещё чашку. Опоры: тёмно-зелёная коса набок, круглые золотые очки (очки есть **только у Рин**), селадоновая пиала. Тег: «Позволь.» Фигура: высокие стройные песочные часы.
- **Поведение:**
  - голова — поправляет очки, смутившись;
  - рука — протягивает пиалу;
  - наряд (коса) — перекидывает косу на другое плечо;
  - победа — сдержанный кивок, «Позволь.»;
  - поражение — снимает очки, протирает их, «…Ещё раз»;
  - комбо — пар из пиалы закручивается.
- **Эмоции:** невозмутимая, смущённая (поправляет очки), тёплая полуулыбка, удивлённая, строгая.
- **Позы:** вся постановка (6 поз, пластика, окружение, свет, кадр, анимация) — в `POSES.md` §2. Главные три:
  1. Сидит прямо на высоком табурете, нога на ногу, стопа на кольце-подножке (`idle`).
  2. Наливает чай с высоты между стеллажами (`select`).
  3. Двигает пиалу к игроку, взгляд поверх очков (`tease`).
- **Фирменный idle:** пар над пиалой, медленно перекладывает ногу на ногу (сидя).
- **Наряды:**
  - `r_base` A — · ноги **LW08** «Чайный лист»;
  - `r_maid` S Л · ноги **LW09** «Викторианская горничная»;
  - `r_after` S В · ноги **LW10** «Бармен»;
  - `r_yukata` S О · ноги **LW11** «Нефритовый карп»;
  - `r_agent` SSR П · ноги **LW12** «Агент под неоном»;
  - `r_idol` SSR Ц · ноги **LW13** «Джазовые горошины»;
  - `r_jade` SSR О (7-й наряд, повтор допустим из другой редкости) · ноги **LW14** «Тушь и бамбук».
- **Ядро:** возвращает лоток на стол; если лоток пуст, снимает 1 пару.
- **История:**
  1. Хозяйка «Ледяного павильона».
  2. Проверяет, достоин ли ты её чая.
  3. «Зови меня просто Рин».
- **Набор:**
  - A — акцент «Мята» (`s_mint`).
  - Через SSR-наряд — тема «Нефрит и иней» (нефритовая рубашка с инеем по краю) и стол «Ледяной павильон».
- **Палитра:** 4fbf9f · 1e3b33 · e9d8a6.
- **Промпт** (роль: `tea master`; выражение: `composed half-smile, slightly flustered blush`; поза: `idle` из `POSES.md`):
```
long dark-green hair in a side braid over the left shoulder, thin round gold glasses, jade drop earrings, sage-green eyes, holding a celadon tea bowl, tall slender hourglass figure, long neck, elegant hands; high stand-collar fitted silk blouse with a keyhole neckline, high-waisted pencil skirt to the knee with a back slit, sheer smoke-grey 20-denier stockings with a soft satin sheen and an embroidered jade tea-leaf sprig on the outer side just below each knee, tops hidden under the pencil skirt, low heels; perched upright on a tall pale-wood stool at a long library counter, legs crossed at the knee with the left leg over the right, right foot hooked on the stool's footrest ring, left foot hanging still, both low shoes firmly on, both hands cradling a celadon bowl on her knee with a thin wisp of steam, spine straight, dark-green side braid over her left shoulder, composed half-smile, calm eyes on the viewer, camera at her eye level, hem stays in place; background: a tall scholar's tea library, floor-to-ceiling shelves of unlabeled tea tins, a rolling library ladder, brass scales, a long pale-ash counter, celadon ware, a skylight in the ceiling, quiet orderly vertical architecture, muted; cool even north light from an overcast skylight at noon, crisp and nearly shadowless, the only warm notes are the glint on her glasses and the tea; she stands on the right third, strong vertical shelf lines parallel to the frame edges, tall empty space above her head, camera level at her eye height, framed from mid-shin, 
```

#### hana — Хана · **A** · солнце и бег · 24
- **Обаяние:** обыгрывает всех, но не может признаться в чувствах и зовёт на реванш. Опоры: рыжее волнистое каре, подсолнух, куртка на поясе. Тег: «На старт!» Фигура: спортивно-стройная, длинные ноги, без рельефа мышц.
- **Поведение:**
  - голова — встряхивает каре и смеётся;
  - рука — «дай пять» (единственный такой жест в ростере);
  - наряд (куртка) — перевязывает куртку на поясе;
  - победа — прыжок с кулаком вверх;
  - поражение — «Реванш! Сейчас же!»;
  - комбо — оранжевый след.
- **Эмоции:** азартная, смущённая (в платье), обиженная, хохочущая, решительная.
- **Позы:** вся постановка (6 поз, пластика, окружение, свет, кадр, анимация) — в `POSES.md` §3. Главные три:
  1. «Дай пять» в беговом выпаде (`select`).
  2. Растяжка квадрицепса с подсолнухом над головой (`idle`).
  3. Победный прыжок с кулаком в небо (`win`).
- **Фирменный idle:** пружинит на носках, крутит подсолнух.
- **Наряды:**
  - `h_base` A — · ноги **LW15** «Спринт-полоса»;
  - `h_street` S Ц · ноги **LW16** «Граффити на одной ноге»;
  - `h_beach` S О · ноги **LW17** «Кинезио»;
  - `h_winter` S Л · ноги **LW18** «Гетры»;
  - `h_gym` S С (перевод в S по HEROINES) · ноги **LW19** «Чемпионские гольфы»;
  - `h_gala` SSR П · ноги **LW20** «Подсолнечное кружево»;
  - `h_lantern` SSR В · ноги **LW21** «Хикяку».
- **Ядро:** снимает 2 пары подряд (свайп-рывок). Рейт.: 1 пара + открыть 1 фишку.
- **История:**
  1. Капитан фонарной эстафеты.
  2. Хочет хоть раз выиграть у тебя честно.
  3. «Не смейся! …Красиво?» в гала-платье.
- **Набор:**
  - A — акцент «Лимон» (`s_lemon`).
  - Через SSR-наряд — тема «Подсолнух» и стол «Стадион на закате».
- **Палитра:** ffb35c · 2b4a7a · fff1d6.
- **Примечание:** в `docs/concepts/v4/` нет эталона Ханы, его нужно сделать первым (лицо повзрослить, один тон кожи).
- **Промпт** (роль: `relay team captain and gym coach`; выражение: `bright competitive grin`; поза: `select` из `POSES.md`):
```
wavy shoulder-length orange bob, amber eyes, sunflower hair clip, track jacket tied around the waist, sporty slender figure, long legs, soft waist; fitted zip-up sports top opened to the collarbone, high-waisted running shorts over sheer black athletic tights with a matte finish and a bright orange stripe down each outer side, white-orange sneakers, wristband; running lunge toward the viewer for a high five: right leg forward with the knee bent over the foot, left leg extended straight behind on the ball of the foot, torso leaning forward, right palm raised open toward the camera at face height, left arm swung back, sleeves of the track jacket tied at her waist flying, bright grin, eyes locked on the viewer; background: relay stadium at sunset, rust-red running track with white lane lines, tall floodlight towers just switching on, bleacher benches, a finish ribbon, a bucket of sunflowers by the coach's bench, an unbranded water bottle, muted; golden-hour sunset backlight, glowing orange halo on her hair, soft floodlight fill from the front; sports panning shot, knees-up, background streaked with horizontal motion blur while she stays sharp, level horizon, eye-level camera, 
```

#### yue — Юэ · **S** · луна · на вид 27
- **Обаяние:** триста лет не знала поражений и теперь иногда проигрывает нарочно. Опоры: лавандовые волосы до пояса, рожки, тиара-полумесяц, веер у губ (веер есть только у Юэ). Тег: «Любопытно…» Фигура: высокая статная.
- **Поведение:**
  - голова — «Смело…», прикрывается веером;
  - рука — подаёт руку как королева;
  - наряд (веер) — раскрывает веер, по нему бегут звёзды;
  - победа — взгляд сверху вниз, улыбка за веером;
  - поражение — «Любопытно…» с интересом, без обиды;
  - комбо — серебряные блики.
- **Эмоции:** надменная, заинтригованная, тёплая, удивлённая, дразнящая.
- **Позы:** вся постановка (6 поз, пластика, окружение, свет, кадр, анимация) — в `POSES.md` §4. Главные три:
  1. Придворная S-линия, веер у губ, взгляд вдаль (`idle`).
  2. Сидит во внутреннем изгибе полумесяца над облаками (`win`).
  3. Стоп-кадр поворота с «водяными рукавами» (`select`).
- **Фирменный idle:** медленно обмахивается веером, волосы плывут.
- **Наряды:**
  - `y_base` S — · ноги **LW22** «Лунное серебро»;
  - `y_duel` SSR Ц · ноги **LW23** «Ботфорт и заклёпки»;
  - `y_queen` SSR П · ноги **LW24** «Созвездие»;
  - `y_ball` SSR В · ноги **LW25** «Лунная пыль»;
  - `y_dragon` SSR Л · ноги **LW26** «Лунные поножи»;
  - `y_city` SSR С · ноги **LW27** «Фазы луны».
- **Ядро:** открывает закрытые фишки и показывает пару (луч по ряду).
- **История:**
  1. Хозяйка Лунного дворца.
  2. Ищет того, кто обыграет её всерьёз.
  3. Проигрывает нарочно, чтобы ты вернулся.
- **Набор S:** тема «Полночь» (`s_night`), стол «Лунный дворец» (`b_palace`).
- **Палитра:** c8b6ff · 2a2350 · e8e4f4.
- **Промпт** (роль: `ruler of the Moon Palace`; выражение: `amused gaze into the distance, folding fan at her lips`; поза: `idle` из `POSES.md`):
```
waist-length lavender hair, small elegant horns, crescent-moon tiara, violet-silver gradient eyes, tall statuesque figure, regal posture, long limbs; lavender hanfu-inspired gown with bare shoulders, fitted embroidered bodice showing cleavage, sash-cinched waist, long layered skirt with a high side slit, sheer white stockings with silver lace top bands woven with small crescent moons at mid-thigh in the hanfu's high side slit, silver embroidered slippers, silver jewelry; standing tall in a court-lady S-curve: weight on her straight left leg, right leg crossed in front of it with the right toe pointed on the floor, hips swayed to her left, open folding fan held at her lips in her right hand, left arm hanging long with the trailing sleeve draped behind her, chin raised, amused eyes gazing past the viewer into the distance; background: Moon Palace terrace above a sea of clouds, white jade balustrades, an enormous full-moon disc, an osmanthus tree with tiny golden blossoms, silver bells under the eaves, a path of moonlight across the clouds, drifting glowing motes, muted; midnight full-moon backlight from behind and above, silver rim on her hair and horns, soft lavender fill bouncing up from the clouds; she occupies the upper two thirds of the frame above empty clouds, the full-moon disc directly behind her head like a halo, camera at her eye level, long vertical composition from mid-shin, sleeves and hair leaving the frame edges, 
```

#### nova — Нова · **S** · неон и данные · 23
- **Обаяние:** взломала вывески квартала, чтобы вывести твоё имя, и называет это «тестом на уязвимости». Опоры: асимметричная сине-розовая стрижка, наушники с ушками (единственный «кошачий» элемент), визор. Тег: «Скачано.» Фигура: стройная, узкие бёдра.
- **Поведение:**
  - голова — наушники мигают, «Доступ запрещён»;
  - рука — голограмма фишки над ладонью;
  - наряд (визор) — визор поднимается;
  - победа — «Скачано.»;
  - поражение — «…баг. Не мой.»;
  - комбо — бегущий код по краю HUD.
- **Эмоции:** самодовольная, сосредоточенная, смущённая (без визора), раздражённая, восторженная.
- **Позы:** вся постановка (6 поз, пластика, окружение, свет, кадр, анимация) — в `POSES.md` §5. Главные три:
  1. Сидит боком на байке, колени вместе, голо-фишка над ладонью (`select`).
  2. Сутулясь, печатает по голо-клавиатуре (`idle`).
  3. Висит на кабелях и качает голо-сердечко, как наживку (`tease`).
- **Фирменный idle:** печатает в воздухе, наушники пульсируют.
- **Наряды:**
  - `n_base` S — · ноги **LW28** «Двухцветный надрез»;
  - `n_ssr` SSR О · ноги **LW29** «Гоночный кант»;
  - `n_offline` SSR В · ноги **LW30** «Пастельный офлайн»;
  - `n_root` SSR П · ноги **LW31** «Печатная плата»;
  - `n_diva` SSR Л · ноги **LW32** «Асимметрия».
- **Ядро:** снимает самую глубокую пару (тап по ярусу).
- **История:**
  1. Белый хакер.
  2. Ищет «уязвимость» в твоём сердце.
  3. «Режим офлайн» — первый раз без визора.
- **Набор S:** тема «Неон» (`s_neon`), стол «Неоновый город» (`b_neon`).
- **Палитра:** 4fe3ff · ff6fd8 · 1a1530.
- **Промпт** (роль: `white-hat hacker and street racer`; выражение: `smug little smirk`; поза: `select` из `POSES.md`):
```
asymmetric short haircut in cyan and pink, headphones with small cat-ear shapes, transparent visor pushed up on the forehead, cyan eyes with a pink gradient, slender lean figure, narrow hips; cropped techwear jacket over a high-collar fitted bodysuit, utility mini skirt with straps over two-tone techwear tights, left leg black and right leg neon cyan, clean laser-cut horizontal slashes across both knees and shins showing a black mesh layer underneath (distressed by design, worn that way), nothing cut above the knee or on the inner side, chunky platform combat boots to mid-calf, asymmetric straps; sitting sideways on the seat of her parked unbranded custom motorcycle, both knees together with both legs angled down to her right, both boots resting side by side on the concrete floor, right hand pushing her transparent visor up onto her forehead with two fingers, left palm raised with a small hologram of a blank tile hovering above it, smug little smirk at the viewer, camera at her eye level; background: cramped back-alley garage workshop under an elevated railway, a motorcycle on a lift, cable spaghetti overhead, stacks of old CRT monitors with abstract glowing graphs and no text, one rolled-up shutter onto a dark dry alley, muted, no neon clutter; lit only by her screens and holograms: cyan underlight on her face and hands, magenta rim from a hologram behind her, dark surroundings; perfectly level frame-within-a-frame shot through the rectangle of a foreground CRT bezel or HUD panel with no text, she stands on the left third with space for holograms on the right, tight framing from mid-thigh, eye-level camera, 
```

---

### 3.2 Новые богини — ранг A

#### tsubame — Цубамэ · **A** · тень и дым · 24
- **Кто:** куноити гильдии «Ночные ласточки», курьер писем между мирами. Через неё работает фича «Письма» (0.9-spec §C). Фигура: гибкая, стройно-округлая, длинные ноги, средняя грудь.
- **Опоры:** чёрный сверхдлинный высокий хвост на алом шнуре, длинный алый шарф, шпилька-кунай в форме ласточки.
- **Обаяние и архетип:** холодная профи с гэп-моэ: когда её благодарят, прячет лицо в шарф. Тег: «Доставлено.»
- **Поведение:**
  - тап по голове — исчезает в облачке дыма и появляется рядом, «Не подкрадывайся. Это моя работа»;
  - рука — вручает письмо;
  - наряд (шарф) — натягивает шарф до носа, краснеет;
  - фон — кунай прикалывает падающий лист;
  - победа — салют двумя пальцами;
  - поражение — молча перетягивает хвост, «Ещё заход»;
  - комбо — стайка теневых ласточек.
- **Эмоции:** холодная уверенная, смущённая в шарф, удивлённая (широкие глаза), довольная полуулыбка, решительный прищур.
- **Позы:** вся постановка (6 поз, пластика, окружение, свет, кадр, анимация) — в `POSES.md` §6. Главные три:
  1. Идёт по коньку крыши, как по канату, читает адрес на письме (`idle`).
  2. Стоп-кадр прыжка между крышами в профиль (`select`).
  3. Приземлилась на одно колено на коньке, письма опускаются (`win`).
- **Фирменный idle:** перекатывает кунай-ласточку между пальцами, хвост и шарф колышутся, пятка опорной ноги приподнимается (микробаланс).
- **Наряды:**

| id | Ранг | Образ | Ульта — визуал | М |
|---|---|---|---|---|
| tb_base «Ночная ласточка» | A | Тёмно-синее короткое кимоно-платье с запахом, оби, сетчатые рукава-перчатки, таби-сапожки; ноги **LW33** «Ласточка» | **Теневой шаг**: силуэт проходит сквозь ряд | — |
| tb_post «Почта сквозь миры» | S | Облегающее платье курьера с высоким воротом и разрезом, сумка-почтальонка; ноги **LW34** «Лента почтальона» | **Срочная доставка**: конверт уносит пару | П |
| tb_crimson «Алая луна клана» | SSR | Чёрно-алое боевое кимоно с рукавами-крыльями, корсажный пояс, высокий разрез; ночные крыши; ноги **LW35** «Сасико клана» | **Танец ласточек**: стая сносит пару | Л |

- **Ядро ульты — Теневой шаг:** снимает пару, у которой фишки зажаты соседями сбоку (но не накрыты сверху). Цель: тап по фишке, вторую игра находит сама. Рейт.: 1 пара.
- **История:**
  1. Носит письма между мирами. Одно было адресовано «хозяину стола Пяти ветров», то есть тебе.
  2. Отправитель неизвестен, и она остаётся в салоне, пока не выяснит.
  3. На высокой симпатии приносит письма, которые пишет сама, но не подписывает.
- **Фишки:** подпись — слива на тёмном лаке. Рубашка: индиго-лак с серебряной ласточкой. Стол: ночные татами и крыши в тумане.
- **Палитра:** 1d1b2e · c8283c · a9b0c2.
- **Промпт** (роль: `kunoichi courier`; выражение: `cool confident half-smile`; поза: `idle` из `POSES.md`):
```
jet-black very long high ponytail tied with a crimson cord, side-swept bangs, steel-grey eyes with a crimson gradient, swallow-shaped kunai hairpin, long crimson scarf trailing in the wind, lithe slender-curvy figure, long legs; short dark-indigo wrap kimono dress with an obi belt, crossed neckline showing light cleavage, mesh arm guards, sheer black stockings with one large crimson swallow silhouette printed on the outer side just above the right knee, a crimson cord wrapped twice around the right ankle with loose ends, black split-toe tabi boots, tops hidden under the short kimono dress; walking the ridge of a tiled roof like a tightrope in three-quarter view, right tabi placed directly in front of the left on the ridge line, both legs straight with the back heel lifted, reading the address on a sealed letter in her left hand, right hand spinning the swallow-shaped kunai on one finger, crimson scarf trailing behind in the wind, cool focused eyes flicking up to the viewer, hem stays in place; background: top tier of a courier post tower above a misty canal town at night, dark wet tiled roof ridge, swallow nests under the eaves, lines of sealed envelopes strung like laundry, one small guild-seal paper lamp, moonless overcast sky, muted and hazy; moonless overcast night, cool misty glow rising from the canal town below lighting her from beneath, a narrow crimson side light from the guild lamp; perfectly level horizon, ultra-vertical composition with a huge empty night sky filling over half the frame, she stands in the lower right third, scarf cutting a diagonal, knees-up, eye-level camera, 
```

#### miel — Миэль · **A** · сахар · 25
- **Кто:** кондитер-патиссье с западного квартала, хозяйка кондитерской «Мёд и пар». Связана с событием «Испечь вместе» (ROADMAP 1.0). Фигура: мягкая «груша», широкие бёдра, полные бёдра ног, средне-пышная грудь, родинка у губ, взрослый макияж.
- **Опоры:** белая атласная лента в боковом хвосте, кондитерский мешок или венчик, заколка-макарон.
- **Обаяние и архетип:** солнечная кормилица салона. Гэп: перфекционистка, которая в ярости из-за треснувшего макарона. Тег: «Попробуй!»
- **Поведение:**
  - голова — облачко сахарной пудры, хихикает;
  - рука — протягивает макарон к камере;
  - наряд (лента) — перевязывает бант и подмигивает;
  - фон — звенит духовка, она заглядывает в неё;
  - победа — поднос светящихся пирожных;
  - поражение — надувает губы, «Перестаралась с сахаром»;
  - комбо — взрыв посыпки.
- **Эмоции:** сияющая улыбка, подмигивание с пальцем у губ («секрет рецепта»), надутые щёки, смущённый румянец, восторг.
- **Позы:** вся постановка (6 поз, пластика, окружение, свет, кадр, анимация) — в `POSES.md` §7. Главные три:
  1. Миска на бедре, взбивает крем и напевает (`idle`).
  2. Кондитерский реверанс с подносом пирожных (`win`).
  3. Тянется через стойку с ложкой сливок: «Скажи „а-а“» (`tease`).
- **Фирменный idle:** покачивается в такт музыке, сдувает пудру с ладони, коленки трутся друг о друга.
- **Наряды:**

| id | Ранг | Образ | Ульта — визуал | М |
|---|---|---|---|---|
| me_base «Утренняя выпечка» | A | Кремовая блуза с плечами-фонариками и открытыми плечами, фартук-юбка с корсажем выше колена; ноги **LW36** «Карамельная лента» | **Печенье-джокер**: золотое печенье прыгает в лоток | — |
| me_parlor «Салон „Мёд"» | S | Облегающее платье с кружевным воротом и коротким фартуком; вечерняя кондитерская; ноги **LW37** «Медовые соты» | **Чайная пара**: пара уплывает на подносе | В |
| me_gala «Сахарный бал» | SSR | Платье цвета малинового крема с корсажем, шлейф из органзы-«безе», длинные перчатки; ноги **LW38** «Безе» | **Многоярусный торт**: фишки становятся ярусами торта и тают | О |

- **Ядро ульты — Печенье-джокер:** кладёт в лоток фишку-джокер, которая составляет пару с любой следующей фишкой в лотке. Одновременно в лотке не больше одного джокера. Если лоток пуст, снимает 1 пару. Рейт.: 1 пара.
- **История:**
  1. Приехала поставлять сладости салону, проиграла МТ и теперь отрабатывает долг десертами.
  2. Каждую неделю придумывает «вкус партии» по твоей игре.
  3. На высокой симпатии дарит рецепт, названный твоим именем.
- **Фишки:** подпись — торт. Рубашка: сливочная глазурь с каплей малины. Стол: мраморная столешница в сахарной пудре.
- **Палитра:** f6e7cf · c98a4b · e0566f.
- **Промпт** (роль: `pâtissière`; выражение: `humming with a soft closed-eye smile`; поза: `idle` из `POSES.md`):
```
caramel-honey blonde hair in big loose curls gathered into a side ponytail with a white satin ribbon, macaron hair clip, warm amber eyes, small beauty mark near the lips, soft pear-shaped figure, wide hips, full thighs, medium-full bust; cream off-shoulder blouse with puffed sleeves, fitted corset apron-skirt above the knee showing a soft waist, caramel-brown over-the-knee socks with a cream satin ribbon threaded through eyelets at the top band and tied in a small bow on the outer side, a small embroidered whisk on the outer ankle, a narrow strip of skin below the apron-skirt hem, cherry-red lacquer heels; standing in three-quarter view, a large copper mixing bowl hugged against her right hip with the right arm, right hip pushed out with her weight on the straight right leg, left leg relaxed with the knee bent inward and the left heel lifted out of the pump, left hand whisking cream in the bowl, head tilted toward her right shoulder, humming with a soft closed-eye smile, a small dab of cream on her cheek; background: morning kitchen of a small pastry shop, brick oven arch with an ember glow, marble counter dusted with powdered sugar, copper bowls, cooling racks of macarons, honey jars, flour sacks, a sunlit window with a lace café curtain, muted, soft haze of floating sugar; soft early-morning sun through the window, warm oven glow from the side, powdered sugar glittering in the light beams; customer's view across the counter, camera about 10 degrees above her eye level, warm medium shot from mid-calf in three-quarter view, she stands on the left third, soft out-of-focus pastries in the foreground edge, 
```

#### lian — Лянь · **A** · струна и река · 28
- **Кто:** музыкантша пипы в чайном доме-лодке «Тихая заводь». Фигура: высокая и гибкая, хрупкие плечи, тонкая талия, небольшая грудь, длинные шея и пальцы.
- **Опоры:** пипа, химэ-кат до пола, шпилька-лотос с жемчужными кистями.
- **Обаяние и архетип:** безмятежная мечтательница, говорит музыкальными метафорами и тихо дразнит. Гэп: обожает маджонг, потому что стук фишек для неё ударные, но играет плохо. Тег: «Слышишь?»
- **Поведение:**
  - голова — волосы рябят, она напевает ноту;
  - рука — тянет струну к камере;
  - наряд (кисти) — кисти звенят;
  - фон — раскрывается лотос на воде;
  - победа — торжествующий аккорд с закрытыми глазами;
  - поражение — грустная мелодия, «Минор тебе к лицу»;
  - комбо — ноты поднимаются по лестнице полутонов.
- **Эмоции:** спокойная полуулыбка, лукавый взгляд поверх пипы, удивлённая, мечтательная (глаза закрыты), мягко-грустная.
- **Позы:** вся постановка (6 поз, пластика, окружение, свет, кадр, анимация) — в `POSES.md` §8. Главные три:
  1. Сидит прямо на шёлковом пуфе, пипа вертикально на бедре (`idle`).
  2. Вытягивает к камере светящуюся струну (`select`).
  3. Профиль, взгляд через плечо, шаг сквозь разрез (`tease`, её единственный «через плечо»).
- **Фирменный idle:** перебирает струны, кисти качаются, лёгкое покачивание в ритме.
- **Наряды:**

| id | Ранг | Образ | Ульта — визуал | М |
|---|---|---|---|---|
| li_base «Речная мелодия» | A | Короткий жакет-бэйцзы поверх облегающего платья-миди с разрезом, расшитые туфли; ноги **LW39** «Лотос» | **Эхо струны**: волна звука повторяет пару | — |
| li_lantern «Фонари на воде» | S | Тёмно-синее облегающее платье с высоким воротом и открытой спиной, длинная шаль, фонарь; ноги **LW40** «Рябь на воде» | **Фонари на воде**: пара уплывает фонариками | С |
| li_concert «Тысяча струн» | SSR | Концертное ханьфу с открытыми плечами, рукава из органзы, пояс-корсаж, разрез; ночная сцена в нотах; ноги **LW41** «Кружево карпов» | **Тысяча струн**: струны-лучи режут пару | Ц |

- **Ядро ульты — Эхо струны:** следующая пара, которую соберёт игрок, отзывается эхом: снимается ещё одна свободная пара того же вида. Если такой нет, подсвечивается лучшая пара. Рейт.: 1 пара.
- **История:**
  1. Играет в салоне по вечерам и уверяет, что слышит, какая фишка ляжет следующей (не слышит).
  2. Ищет мелодию, которую ей пела мать на реке.
  3. На высокой симпатии сочиняет «твою тему»: она становится музыкой лобби.
- **Фишки:** подпись — карп. Рубашка: тёмная бирюза с золотыми струнами. Стол: палуба лодки, отражения фонарей.
- **Палитра:** 1f4e5a · f1d6cf · c9a35b.
- **Промпт** (роль: `pipa musician on a river teahouse boat`; выражение: `serene half-smile with half-closed eyes`; поза: `idle` из `POSES.md`):
```
floor-length straight dark teal-black hair with a hime cut and blunt bangs, lotus hairpins with pearl tassels, soft grey-teal eyes, willowy tall figure, delicate shoulders, small waist, modest bust, long neck and fingers; short embroidered beizi jacket over a form-fitting midi dress with a high side slit, white silk stockings with a soft sheen and a pink lotus embroidered on the outer side, the bloom just above the knee and its green stem curling down to the ankle, embroidered shoes; sitting upright on a low round embroidered silk ottoman on the lacquered dais, the pipa held vertically on her left thigh with its neck rising beside her left shoulder, left fingers pressing the frets, right fingers plucking the strings, both knees together angled toward frame-right, both feet side by side with the right toe pointed, long neck tilted toward the instrument, eyes half-closed, serene half-smile, camera at her eye level, hem and slit stay in place; background: a river music barge at night, a raised red-lacquered dais under a curved boat roof on red lacquer pillars, hanging bead-string blinds, lotus-shaped floating candles drifting on black water, lotus leaves, a mooring rope, light mist over the water, muted, no moon; warm coral candlelight rising from floating lotus candles on the water below, low mist, deep teal shadows, no moonlight; off-center three-quarter view shot through hanging bead strings in the soft foreground, knees-up, eye-level camera, no reflection of her legs in the water, 
```

#### jess — Джесс · **A** · пыль и закат · 25
- **Кто:** ковбойша, гоняет караваны чая по прерии из Медного каньона. Фигура: высокая, длинноногая, средняя грудь. Лёгкие веснушки при взрослом лице со скулами.
- **Опоры:** шляпа с перьями и кончо, лассо, пояс с подковой.
- **Обаяние и архетип:** громкая, прямая, хохочет. Гэп: до ужаса боится призраков (зацепка для Хэллоуина). Тег: «Йи-ха!»
- **Поведение:**
  - голова — шляпа сползает на глаза, она смеётся;
  - рука — раскручивает петлю лассо;
  - наряд (шляпа) — бросает шляпу в камеру и ловит;
  - фон — катится перекати-поле;
  - победа — шляпа в воздух;
  - поражение — «Дикая лошадка. Объезжу!»;
  - комбо — петля лассо растёт.
- **Эмоции:** широкая улыбка, подмигивание из-под шляпы, удивлённая с открытым ртом, раздражённая (сдувает чёлку), испуганная.
- **Позы:** вся постановка (6 поз, пластика, окружение, свет, кадр, анимация) — в `POSES.md` §9. Главные три:
  1. Предплечья на жерди загона, щиколотки скрещены (`idle`).
  2. Раскручивает лассо над головой и ловит падающую шляпу (`win`).
  3. «Попался!» — тянет лассо, каблук вбит в землю (`tease`).
- **Фирменный idle:** перекидывает косу, постукивает сапогом, переносит вес с ноги на ногу.
- **Наряды:**

| id | Ранг | Образ | Ульта — визуал | М |
|---|---|---|---|---|
| je_base «Чайный тракт» | A | Клетчатая рубашка, завязанная узлом на животе, джинсовые шорты с высокой посадкой, сапоги, пояс с подковой; ноги **LW42** «Пыльный тракт» | **Лассо**: петля затягивает пару | — |
| je_rodeo «Родео в огнях» | S | Облегающий жилет с бахромой, кожаные брюки с чапсами, шейный платок; вечерний стадион с гирляндами; ноги **LW43** «Звенящие шпоры» | **Аркан**: двойная петля | Ц |
| je_star «Дикая звезда прерии» | SSR | Платье цвета ржавчины с корсажем и бахромой, длинный разрез, шляпа с пером; закат над каньоном; ноги **LW44** «Тиснёная роза» | **Закат каньона**: солнечный диск выжигает пару | П |

- **Ядро ульты — Лассо:** тап по фишке в лотке, и её пара затягивается с доски (может быть зажата сбоку, но не накрыта сверху). Если пары нет, снимает 1 свободную пару. Рейт.: 1 пара.
- **История:**
  1. Пригнала караван чая и застряла: мост смыло.
  2. Учит тебя «объезжать» сложные раскладки.
  3. На высокой симпатии зовёт смотреть закат с крыши салона.
- **Фишки:** подпись — клевер. Рубашка: потёртая кожа с тиснением. Стол: коновязь и закат в дымке.
- **Палитра:** 3d5a80 · b5532f · e8cf9a.
- **Промпт** (роль: `cowgirl caravan driver`; выражение: `relaxed easy grin`; поза: `idle` из `POSES.md`):
```
sandy wheat-blonde hair in two long low braids, cowboy hat with feathers and silver conchos, sky-blue eyes, light freckles on a mature face, tall long-legged figure, medium bust; plaid shirt tied in a knot above a soft bare midriff, high-waisted denim shorts, dusty brown over-the-knee socks with a frayed cuff and a small darned worn patch at the left knee (rugged style, distressed by design, worn that way), a short leather lace with a small horseshoe charm tied around the left cuff, tooled leather cowboy boots, belt with a horseshoe buckle, coiled lasso; leaning forward with both forearms folded on the top rail of a wooden corral fence, body in three-quarter view, both boots on the dirt with the right ankle crossed behind the left, both legs straight, hat tilted to one side, a wheat stalk between her lips, relaxed easy grin, sky-blue eyes on the viewer; background: corral beside a tea caravan in a copper-red canyon, sun-bleached wooden hitching fence, covered wagon loaded with tea crates under canvas, a windmill, scattered hay, tumbleweed, distant red mesas, muted; harsh high-noon sun directly overhead, short hard shadows under the hat brim, heat shimmer above the ground, bleached pale sky; classic western cowboy shot cropped at mid-thigh, eye-level camera, horizon in the lower third, she stands on the right third with sky and canyon on the left, 
```

#### tsuru — Цуру · **A** · пар и журавль · 31
- **Кто:** хозяйка (окамисан) горного онсэн-рёкана «Журавлиный пар». Старшая из всех, «старшая сестра». Фигура: пышная, полные грудь и бёдра, мягкая; родинка под глазом.
- **Опоры:** канзаси-журавль, бумажный журавлик, хаори с гербом журавля.
- **Обаяние и архетип:** тёплая, дразнящая, бесконечно гостеприимная, мягко ругает тебя за недосып. Гэп: яростно азартна в настольный теннис. Тег: «Отдохни у меня».
- **Поведение:**
  - голова — «Ох?» и гладит тебя в ответ (рука к камере);
  - рука — подаёт тёплое полотенце;
  - наряд (хаори) — поправляет хаори на плечах;
  - фон — клуб пара, взлетает журавлик;
  - победа — мягкие хлопки, «Отличная работа»;
  - поражение — «Ну-ну» и складывает журавлика на удачу;
  - комбо — журавли взлетают.
- **Эмоции:** тёплая (глаза-полумесяцы), дразнящая (прищур, ладонь у щеки), строгая забота, удивлённая, растроганная.
- **Позы:** вся постановка (6 поз, пластика, окружение, свет, кадр, анимация) — в `POSES.md` §10. Главные три:
  1. Плечом в раме сёдзи, руки в рукавах, гэта на зубце (`idle`).
  2. Раздвигает норэн: «Проходи» (`select`).
  3. Сэйдза у очага, похлопывает по подушке рядом (`tease`).
- **Фирменный idle:** заправляет прядь за ухо, пар клубится, журавлик в пальцах.
- **Ограничение:** без бани и полотенец на теле, только хозяйка и гостиница.
- **Наряды:**

| id | Ранг | Образ | Ульта — визуал | М |
|---|---|---|---|---|
| tu_base «Хозяйка рёкана» | A | Облегающее кимоно-платье до колена с оби, хаори с гербом, гэта; ноги **LW45** «Пар над источником» | **Горячий источник**: пар растапливает лёд | — |
| tu_pingpong «Турнир в юкате» | S | Юката с бантом-оби, рукава подвязаны тасуки, ракетка; ночной фестиваль онсэна; ноги **LW46** «Журавлиные гольфы» | **Смэш!**: шарик уносит пару | О |
| tu_snow «Снежный журавль» | SSR | Бело-алое церемониальное кимоно с открытыми плечами, мех на плечах, алый оби-корсаж, высокий разрез; снег, фонари; ноги **LW47** «Журавлиное перо» | **Тысяча журавлей**: стая уносит пару | Л |

- **Ядро ульты — Горячий источник:** растапливает до 3 льдов или замков. Если их нет, открывает 1 закрытую фишку и снимает 1 пару. Рейт.: 2 льда или 1 пара.
- **История:**
  1. Её рёкан стоит на перевале, туда приходят отдохнуть после проигрыша.
  2. У неё гостили все богини, и она хранит их секреты.
  3. На высокой симпатии сама просит тебя остаться ещё на вечер у очага.
- **Фишки:** подпись — фонарь. Рубашка: тёплое дерево хиноки с журавлём. Стол: камень у источника в пару.
- **Палитра:** 2e3a6b · e0703b · f1ece4.
- **Промпт** (роль: `hot-spring inn proprietress`; выражение: `warm crescent-eyed smile`; поза: `idle` из `POSES.md`):
```
chocolate-brown elegant updo with a crane kanzashi and loose framing strands, warm hazel-gold gentle eyes, beauty mark under one eye, voluptuous soft figure, full bust and hips; knee-length fitted indigo kimono dress with a wide persimmon obi, crossed neckline showing cleavage, haori with a crane crest draped on her shoulders, sheer dark-indigo split-toe stockings with a woven white steam-swirl pattern rising from the ankle to the knee, lacquered geta, tops hidden under the knee-length kimono dress; standing in a shoji doorframe with her right shoulder resting against the wooden frame, both hands tucked into the opposite kimono sleeves in front of her obi, both geta together with the knees softly bent, the right geta tipped forward onto its front tooth, head tilted against the frame, warm crescent-eyed smile, eyes level with the viewer's, hem stays in place; background: hearth room of a mountain onsen ryokan, sunken irori hearth with an iron kettle on a hook breathing steam, tatami and floor cushions, open shoji onto an autumn mountain pass with distant hot-spring steam and no bathers, crane-crest noren at the entrance, a string of paper cranes, muted; late-afternoon autumn sun raking through the shoji in striped bars of persimmon light, warm hearth glow as secondary fill from below; camera at a seated guest's height for seated poses and at her eye level for standing poses, perfectly horizontal, the shoji lattice as a graphic frame, close warm framing from the knees, 
```

---

### 3.3 Новые богини — ранг S

#### kohaku — Кохаку · **S** · лисий огонь · на вид 25 (лисе 900 лет)
- **Кто:** белая лиса-жрица храма Тысячи врат на холме, на котором стоит салон. Фигура: среднего роста, мягкие песочные часы, длинные ноги.
- **Опоры:** белые лисьи уши и хвост с киноварными кончиками, киноварные стрелки, колокольчик-судзу и лисья маска сбоку головы. Лисий мотив только у неё, кошачий — только у Новы.
- **Обаяние и архетип:** проказница-трикстер, надменная, дразнит без конца. Гэп: тает от поглаживаний, и хвост выдаёт её. Тег: «Удача любит меня».
- **Поведение:**
  - голова — уши дёргаются, хвост виляет вопреки её «Не гладь!»;
  - рука — лисий огонёк прыгает тебе на палец;
  - наряд (маска) — надевает маску и подглядывает;
  - фон — зажигаются фонари врат;
  - победа — «Удача любит меня, а значит, и тебя»;
  - поражение — уши прижаты, хвост поник;
  - комбо — число огоньков растёт.
- **Эмоции:** хитрая ухмылка с клычком, надменная, смущённая (уши прижаты), возмущённая, счастливая (глаза закрыты, хвост ходит).
- **Позы:** вся постановка (6 поз, пластика, окружение, свет, кадр, анимация) — в `POSES.md` §11. Главные три:
  1. На лестнице, гохэй поперёк плеч (`idle`).
  2. Выглядывает из-за столба тории, хвост выдаёт (`select`).
  3. «Лисичка» из пальцев и подброшенная пятка (`tease`).
- **Фирменный idle:** хвост мягко ходит, уши подрагивают, звякает колокольчик.
- **Наряды:**

| id | Ранг | Образ | Ульта — визуал | М |
|---|---|---|---|---|
| ko_base «Жрица тысячи врат» | S | Стилизованный наряд мико: облегающий белый верх с отдельными рукавами и открытыми плечами, алая юбка-хакама с разрезами до бедра; ноги **LW48** «Бубенцы мико» | **Лисий оберег**: офуда вспыхивает на лотке | — |
| ko_matsuri «Ночной мацури» | A | Короткая юката, оби-бант, маска лисы; фестиваль; ноги **LW49** «Лисьи огни» | **Огни мацури**: фонарики уносят пару | В |
| ko_kyubi «Девятихвостая» | SSR | Пробуждённый облик: 9 хвостов, чёрно-золотое церемониальное кимоно с открытыми плечами и спиной, высокий разрез, кружевной верх чулок; ноги **LW50** «Офуда» | **Девять огней**: огни сходятся на паре | Л |
| ko_vow «Обет лисьей свадьбы» | SSR | Белое свадебное кимоно с капюшоном-ватабоси и алым подбоем; «слепой дождь» (симпатия 10); ноги **LW51** «Красная нить» | **Солнечный дождь**: капли уносят пару | С |

- **Ядро ульты — Лисий оберег:** вешает на лоток офуду. Если лоток переполнится, оберег сгорает и уносит 2 фишки вместо проигрыша. При запуске сразу подсвечивает 1 пару. Одновременно только один оберег. Рейт.: оберег без подсветки.
- **История:**
  1. 900 лет хранит удачу холма, а салон стоит на её земле.
  2. Когда-то МТ её обыграла, и с тех пор Кохаку «приглядывает» за салоном.
  3. На высокой симпатии показывает настоящий облик, Девятихвостую, только тебе.
- **Фишки:** подпись — лиса. Рубашка: алый лак с белой лисой и золотыми вратами. Лица фишек в мягкой красной обводке (вне рейтинга). Стол: ступени храма с тысячей ториев в тумане.
- **Палитра:** f3efe9 · d63a2a · e2a23d.
- **Промпт** (роль: `fox shrine maiden`; выражение: `sly smirk with a tiny fang`; поза: `idle` из `POSES.md`):
```
long snow-white hair with vermilion tips, white fox ears with red inner fur, one fluffy white fox tail with a red tip, vermilion eyeliner, amber-gold eyes, small bell on a red cord, fox mask worn on the side of her head, medium-height soft hourglass figure, long legs; stylized shrine-maiden outfit: fitted white top with detached wide sleeves and bare shoulders showing cleavage, vermilion hakama skirt with thigh-high side slits, white opaque thigh-high stockings with a narrow vermilion top band at mid-thigh showing in the hakama side slits, a crimson satin bow with a small round suzu bell tied at the outer side just below each knee, red-thonged zori; standing on a stone stairway in three-quarter view, left foot up on the next step with the left knee bent forward, right leg straight on the lower step bearing her weight, gohei wand laid horizontally across the back of her shoulders with both wrists draped lazily over it and the wide sleeves hanging down, fluffy tail curled around the front of her shins, head tilted toward her raised knee, sly smirk with a tiny fang, amber eyes on the viewer, camera at eye level; background: night stairway tunnel of countless vermilion torii gates climbing a hillside, worn stone steps with mossy edges, stone kitsune statues wearing red bibs, stone lanterns with floating amber foxfire orbs, golden ginkgo leaves on the steps, low drifting mist, muted and desaturated; night, key light from small floating amber foxfire orbs, vermilion bounce from the lacquered torii, cool blue-grey fill from the mist; frame within a frame: the two pillars of the nearest torii crop the left and right edges, the stairway climbing diagonally into the depth, she stands on the right third with her tail filling the left, knees-up, 50mm lens, eye level, 
```

#### shirin — Ширин · **S** · песок и солнце · 26
- **Кто:** танцовщица и гадалка каравана «Семь колодцев». Фигура: пышные песочные часы, мягкий живот без пресса, полные бёдра, тёплый смуглый тон кожи.
- **Опоры:** пояс-монисто, налобная цепочка, лёгкая вуаль (аксессуар, лицо открыто).
- **Обаяние и архетип:** игриво-загадочная и мудрая, говорит притчами. Гэп: по утрам сонная и ворчливая. Тег: «Звёзды не лгут».
- **Поведение:**
  - голова — звенят монеты, она смеётся;
  - рука — «читает» твою ладонь, «Вижу пару бамбуков…»;
  - наряд (вуаль) — откидывает вуаль и подглядывает;
  - фон — песчаный вихрь, мигает лампа;
  - победа — вуаль летит по дуге, «Звёзды сказали правду»;
  - поражение — театральный вздох, «Пески переменчивы»;
  - комбо — лестница звона монет.
- **Эмоции:** загадочная полуулыбка, смеющаяся, сонно-ворчливая, удивлённая, нежная.
- **Позы:** вся постановка (6 поз, пластика, окружение, свет, кадр, анимация) — в `POSES.md` §12. Главные три:
  1. Танец с лампой на голове, змеиные руки (`idle`).
  2. Шаг-променад, вуаль отводит, как занавес (`select`).
  3. Стоп-кадр пируэта с веером монет (`win`).
- **Фирменный idle:** мягкое покачивание в танцевальном ритме с малой амплитудой, звенят браслеты, вуаль течёт.
- **Наряды:**

| id | Ранг | Образ | Ульта — визуал | М |
|---|---|---|---|---|
| sh_base «Танец семи колодцев» | S | Чоли-топ с шифоновыми рукавами (непрозрачный лиф, не бра), открытый живот, юбка с низкой посадкой и высоким разрезом, пояс-монисто; ноги **LW52** «Пайал» | **Танец монет**: монеты кружат и уносят пару | — |
| sh_oasis «Оазис» | A | Туника-халат с поясом поверх облегающих шаровар, шарф; базар; ноги **LW53** «Базарные манжеты» | **Мираж**: пара тает в мареве | П |
| sh_sun «Дочь полуденного солнца» | SSR | Золото-бирюзовый корсаж с орнаментом, многослойная юбка с разрезами, шлейф-вуаль, наручи; дворец в мареве; ноги **LW54** «Мехенди-стремя» | **Солнечный диск**: диск раскрывает и сжигает пару | О |
| sh_night «Тысяча и одна партия» | SSR | Тёмно-синее с золотом платье со звёздной вышивкой, открытые плечи, длинный разрез; шатёр под звёздами; ноги **LW55** «Тысяча и одна» | **Звёздный шатёр**: созвездие наводит на лучшую пару | Ц |

- **Ядро ульты — Танец монет:** снимает 1 пару и сразу запускает лихорадку по обычным правилам. Рейт.: пара и +0,5 ступени комбо.
- **История:**
  1. Её караван пришёл к салону по звёздам.
  2. Предсказала, что ты обыграешь одну богиню, и не говорит какую.
  3. На высокой симпатии танцует только для тебя под звёздами: взгляд в камеру, без сексуализации.
- **Фишки:** подпись — солнце. Рубашка: бирюзовая мозаика с золотом. Стол: тёплый песчаник и ковры в мареве.
- **Палитра:** d9b26f · 1f8f8a · c08a1e.
- **Промпт** (роль: `desert caravan dancer and fortune teller`; выражение: `serene concentrated half-smile`; поза: `idle` из `POSES.md`):
```
voluminous plum-black wavy hair to the hips with woven gold coin chains, golden forehead chain, honey-gold eyes with kohl, warm brown skin, curvy hourglass figure with a soft belly and no abs, full hips, medium-full bust; opaque embroidered choli top with sheer chiffon sleeves showing cleavage, bare soft midriff, low-slung skirt with a high slit, jingling coin belt, bare legs with layered gold coin payal anklets hung with small bells and a fine gold chain from each anklet to a toe ring, the slit showing the leg to mid-thigh only, gold armlets, light chiffon veil; standing in three-quarter view on a kilim carpet, a small lit brass oil lamp balanced on top of her head, weight on her flat right foot, left foot raised onto its ball close beside it, knees soft and together, hips swayed gently to her right with a straight back and no arch, both arms extended out to the sides at shoulder height in a slow serpentine wave, wrists bent and fingers in a dancer's shape, the light veil draped over both forearms behind her shoulders, serene concentrated half-smile, honey-gold kohl-lined eyes on the viewer, camera at eye level; background: interior of a fortune-teller's caravan tent, layered kilim carpets, low cushions and bolsters, brass oil lamps hanging on chains, a brass sand divination tray, a hanging screen of coin strings, tent flap open onto dunes with the first stars and a distant camel silhouette, muted and desaturated; blue-hour interior, warm key from brass oil lamps, cool turquoise backlight from the open tent flap, plum shadows; eye-level view as if seated on a cushion opposite her, lamp chains and the arc of the veil forming a circular arch around her placed off-center, framed from mid-thigh, torso more frontal with legs in three-quarter, 50mm lens, 
```

#### mari — Марисоль · **S** · шторм и море · 29
- **Кто:** вольный капитан чайного клипера «Летучая чайка». Фигура: высокая, пышная, длинные ноги.
- **Опоры:** треуголка с белым пером, компас-кулон, длинный камзол на плечах.
- **Обаяние и архетип:** бравада, громкий смех, щедрость, защищает своих. Гэп: на суше её укачивает. Тег: «Полный вперёд!»
- **Поведение:**
  - голова — «Руки прочь от треуголки!» со смехом;
  - рука — подаёт подзорную трубу;
  - наряд (камзол) — эффектно взмахивает полой;
  - фон — садится чайка, она её прогоняет;
  - победа — салют саблей;
  - поражение — «Шторм — не повод сдаваться»;
  - комбо — волна растёт.
- **Эмоции:** дерзкая ухмылка, хохот, сердитая, удивлённая, редкая мягкая.
- **Позы:** вся постановка (6 поз, пластика, окружение, свет, кадр, анимация) — в `POSES.md` §13. Главные три:
  1. Ботфорт на планшире, рука на ванте (`idle`).
  2. Вылетает над палубой на канате (`win`).
  3. Стоит на ящике с чаем и указывает на горизонт (`select`).
- **Фирменный idle:** плащ и перо хлопают на ветру, качка передаётся переносом веса.
- **Ограничение:** без бочек, рома и стекла.
- **Наряды:**

| id | Ранг | Образ | Ульта — визуал | М |
|---|---|---|---|---|
| ma_base «Вольный капитан» | S | Белая рубашка с глубоким вырезом под корсажным жилетом, облегающие кожаные брюки, ботфорты выше колена, камзол на плечах; ноги **LW56** «Кушак и пистолет» | **Бортовой залп**: дым вдоль ряда | — |
| ma_port «Увольнение в порт» | A | Льняное платье-рубашка с поясом, косынка, сандалии; гавань; ноги **LW57** «Бандана» | **Попутный ветер**: парус уносит фишку обратно | В |
| ma_admiral «Флагман бури» | SSR | Парадный тёмно-синий мундир-фрак с золотом и эполетами, облегающие белые брюки, ботфорты; шторм в дымке; ноги **LW58** «Латунный лампас» | **Флагман бури**: молния по мачтам | Л |
| ma_summer «Купальный сезон на палубе» | SSR | Слитный купальник с высоким вырезом бедра под расстёгнутой капитанской рубашкой, саронг, шляпа; палуба в солнце (витрина: по пояс); ноги **LW59** «Морской узел» | **Брызги**: волна указывает цель | Ц |

- **Ядро ульты — Бортовой залп:** свайп вдоль ряда снимает до 2 пар среди свободных фишек этого ряда. Рейт.: 1 пара.
- **История:**
  1. Возит лучший чай между мирами, и салон — её любимый порт.
  2. Поспорила с Юэ на звёздную карту и проиграла, теперь отыгрывается.
  3. На высокой симпатии предлагает тебе место старпома.
- **Фишки:** подпись — колокол. Рубашка: синяя парусина с розой ветров. Стол: мокрая палуба в морской дымке.
- **Палитра:** 1f2f4a · c23a3a · d4b15a.
- **Промпт** (роль: `free tea-clipper captain`; выражение: `bold smirk`; поза: `idle` из `POSES.md`):
```
wild crimson-red curls in a loose low ponytail, tricorne hat with a white plume, sea-green eyes, compass pendant, tall full-figured body, long legs, full bust; white shirt with a deep open neckline under a fitted corset vest, tight dark leather trousers, glossy cuffed black over-the-knee boots with brass buckles, a red silk sash knotted around the right boot shaft at mid-calf with long ends fluttering in the wind, a flintlock pistol tucked into the left boot top, long navy coat with gold buttons draped over her shoulders, sash belt; standing at the ship's bulwark in three-quarter view, left boot planted up on the wooden rail at hip height with the left knee bent high, right leg straight on the deck bearing her weight, left forearm resting across the raised thigh, right arm raised gripping a taut rigging shroud above her head, leaning slightly forward into the wind gazing at the horizon past the camera, long navy coat and white plume streaming back, confident grin, camera at eye level; background: foredeck of a tea clipper in a passing daytime squall, wet holystoned planks, taut rigging shrouds and ratlines, furled sails, bowsprit, brass ship's bell, tea chests wrapped in oilcloth with no markings, ship's wheel on a wooden pedestal, sea spray, sunlight breaking through slate storm clouds, muted, no barrels, no bottles; midday squall, hard white sunlight breaking through slate clouds as backlight, glittering spray, cool overcast fill; eye-level camera with a 6 to 8 degree Dutch tilt following the ship's roll, 28mm wide lens, diagonal horizon, rigging lines leading to her, framed from the knees to full length, 
```

#### hibana — Хибана · **S** · гром · 27
- **Кто:** барабанщица-тайко горного святилища, громом будит весной чайные сады. Фигура: мягкая, но крепкая, широкие бёдра, полные бёдра ног, средняя грудь, без мышц.
- **Опоры:** вулф-кат пепельно-сланцевого цвета с ярко-жёлтой изнанкой, палочки-бати, кольцо маленьких барабанов за спиной (появляется в ульте и SSR).
- **Обаяние и архетип:** гиперэнергичная, громкая, смеётся над грозой. Гэп: боится тишины и неловко замолкает в тихие моменты. Тег: «ДОН!»
- **Поведение:**
  - голова — статика поднимает пряди, она хохочет;
  - рука — дробь палочками в воздухе;
  - наряд (палочки или верёвка) — барабаны гудят;
  - фон — вспышка молнии (не больше 3 в секунду, не белая);
  - победа — удар «ДОН!»;
  - поражение — палочки крест-накрест над головой, «Ещё раунд!»;
  - комбо — бит ускоряется вместе с питч-лестницей.
- **Эмоции:** зубастая улыбка, боевой клич, обиженная, растерянная (тишина), тёплая.
- **Позы:** вся постановка (6 поз, пластика, окружение, свет, кадр, анимация) — в `POSES.md` §14. Главные три:
  1. Стойка тайко: выпад, палочка в небо, палочка на игрока (`select`).
  2. Пружинит на носках, дробь в воздухе (`idle`).
  3. Удар двумя руками на верху одайко (`win`).
- **Фирменный idle:** покачивается в ритме, искры в волосах, барабаны медленно вращаются.
- **Наряды:**

| id | Ранг | Образ | Ульта — визуал | М |
|---|---|---|---|---|
| hi_base «Гроза в горах» | S | Короткая хаппи-куртка с открытыми плечами поверх облегающего кроп-топа с высоким воротом, оби-шнур, шорты-хакама; ноги **LW60** «Молния и подтяжки» | **Цепная молния**: разряд прыгает между парами | — |
| hi_fest «Фестиваль барабанов» | A | Хаппи поверх майки, повязка хатимаки, шорты; ночной мацури; ноги **LW61** «Шмелиная полоска» | **Мацури-ритм**: в такт подсвечивает пару | П |
| hi_raijin «Владычица грома» | SSR | Тёмно-лиловое церемониальное кимоно-доспех, золотые наплечники, шлейф-облако, высокий разрез, кружевной верх чулок; грозовое небо; ноги **LW62** «Грозовой разряд» | **Небесный барабан**: удар раскалывает лёд | Л |
| hi_rock «Громовой концерт» | SSR | Кожаная куртка, корсет, мини-юбка; рок-сцена (без неона Новы, тёплый свет); ноги **LW63** «Панк-сцена» | **Соло на бис**: открывает закрытую фишку | О |

- **Ядро ульты — Цепная молния:** снимает выбранную пару. Если рядом (в радиусе одной фишки) после этого освобождается ещё пара, снимает и её, максимум 2. Рейт.: вторая пара только того же вида.
- **История:**
  1. Её гром будит чайные кусты весной.
  2. В святилище скучно, а в салоне шумно, и ей нравится.
  3. На высокой симпатии впервые молчит рядом с тобой, и ей не страшно.
- **Фишки:** подпись — молния. Рубашка: лиловый лак с золотыми томоэ. Стол: камень святилища под дождём в дымке.
- **Палитра:** 2c2650 · ffd23f · 8e8fa3.
- **Промпт** (роль: `taiko drummer of a thunder shrine`; выражение: `toothy excited grin`; поза: `select` из `POSES.md`):
```
medium wolf-cut slate-grey hair with an electric-yellow inner color, small tomoe hair ornaments, electric yellow-gold eyes, soft sturdy figure with wide hips and full thighs, medium bust, no visible muscles; short happi jacket slipping off the shoulders over a fitted high-neck crop top showing a soft waist, twisted rope obi belt, hakama shorts, black opaque thigh-high stockings with a bold yellow lightning-zigzag stripe down the outer side, short black elastic suspender straps clipping onto the outside of the hakama-shorts hem with yellow buckles, shorts fully opaque, a palm-width of skin between, straw sandals, drumsticks in both hands; taiko ready stance in profile-three-quarter view, deep forward lunge toward a giant drum at frame-left, left knee bent directly over the left foot, right leg extended straight behind her with the heel down, torso upright, right arm raised straight up with its drumstick pointing at the sky, left arm extended forward pointing the other drumstick at the viewer, fierce grin, eyes locked on the camera, camera at eye level; background: wooden drum tower above terraced mountain tea plantation rows in a dusk spring thunderstorm, slanting sheets of rain over tea bushes, a giant odaiko drum on a wooden cradle, a ring of small shime-daiko drums, wet plank floor, straw rope tassels, distant lightning over the ridges, muted and desaturated, no shrine buildings, no lanterns; dusk thunderstorm, diffuse violet ambient light, intermittent yellow-gold lightning backlight; eye-level tight action shot from mid-thigh, rim of a near odaiko in the lower-left foreground, 35mm lens, drumsticks and hair strands breaking past the frame edges, slight motion trails on the sticks, 
```

#### nemi — Неми · **S** · лес · на вид 26
- **Кто:** эльфийка-лучница, страж диких чайных деревьев на краю мира. Фигура: очень высокая, стройная, длинные ноги, небольшая или средняя грудь.
- **Опоры:** длинные острые уши с золотыми каффами, длинный лук, венец из листьев.
- **Обаяние и архетип:** отстранённая, невозмутимая, юмор без улыбки, честная до грубости. Гэп: обожает человеческие сладости (дружит с Миэль) и не ладит с техникой. Тег: «Ветер сказал».
- **Поведение:**
  - голова — ухо дёргается, «Уши — не кнопка»;
  - рука — даёт чайный лист;
  - наряд (лук) — натягивает тетиву и целится мимо камеры;
  - фон — на лук садится птица;
  - победа — спокойный кивок, полуулыбка;
  - поражение — уши чуть опускаются, «Ветер был против»;
  - комбо — вихрь листьев.
- **Эмоции:** невозмутимая, лёгкая улыбка, смущение (кончики ушей краснеют), прищур (прицел), удивление (уши вверх).
- **Позы:** вся постановка (6 поз, пластика, окружение, свет, кадр, анимация) — в `POSES.md` §15. Главные три:
  1. Полное натяжение лука в боковой стойке, стрела мимо камеры (`select`).
  2. Поза дерева на ветви, лист на ладони (`idle`).
  3. Гладит игрока по голове сверху (`tease`).
- **Фирменный idle:** уши подрагивают, падают листья, она ловит один.
- **Наряды:**

| id | Ранг | Образ | Ульта — визуал | М |
|---|---|---|---|---|
| ne_base «Страж Чайного леса» | S | Облегающий зелёный жилет-корсаж поверх рубашки, короткий плащ, юбка из кожаных пластин с разрезами, наручи, сапоги; ноги **LW64** «Плющ» | **Стрела в вершину**: стрела пронзает стопку | — |
| ne_town «Эльф в городе» | A | Платье-свитер, вязаный кардиган; осенний город; ноги **LW65** «Кленовая вязка» | **Опавшие листья**: лист падает на нужную пару | С |
| ne_spring «Весенняя дриада» | SSR | Платье из плотных листьев и лепестков, открытые плечи, корсаж из коры с золотом, шлейф из лепестков; рассвет; ноги **LW66** «Цветущая лоза» | **Цветение**: бутон раскрывает фишку | О |
| ne_hunt «Королевская охота» | SSR | Бархатный охотничий камзол-платье, шляпа с пером, раздельная охотничья юбка, высокие сапоги; осенний королевский лес; ноги **LW67** «Оперённые сапоги» | **Королевский выстрел**: стрела возвращает фишку | В |

- **Ядро ульты — Стрела в вершину:** снимает пару с самого высокого яруса, чтобы освободить больше всего фишек под ней. Свайп-прицел по стопке. Рейт.: 1 пара.
- **История:**
  1. Охраняет дикие чайные деревья, и чай салона растёт с них.
  2. Пришла проверить, достоин ли салон её листа.
  3. На высокой симпатии сажает с тобой дерево, которое вырастет через сто лет: «Я подожду».
- **Фишки:** подпись — клён. Рубашка: берёста с резным листом. Стол: мох и корни в лучах.
- **Палитра:** 4f6b35 · b8612e · ece4cf.
- **Промпт** (роль: `elven archer guarding wild tea trees`; выражение: `calm deadpan look with a faint smile`; поза: `select` из `POSES.md`):
```
waist-length deep copper-auburn hair with thin leaf braids, long pointed elf ears with gold cuffs, leaf circlet, moss-green eyes, very tall slender figure, long legs, small-to-medium bust; fitted green corset vest over a white shirt with an open collar, short hooded cape, leather tasset skirt with slits, leather bracers, sheer moss-green stockings with a bold woven ivy-vine pattern climbing from the boot tops to the top band, the leaves large enough to read at a glance, top band at mid-thigh in the slits of the leather tasset skirt, soft brown knee boots; full draw in a side-on archer's stance, feet shoulder-width apart on a line perpendicular to the camera, both knees straight, left arm fully extended holding the longbow, right hand drawing the string back to the corner of her jaw, arrow aimed off-frame to the left and never at the camera, head turned toward the target, eyes narrowed, wind lifting her thin copper braids and short hooded cape, camera at eye level; background: canopy of colossal ancient wild tea trees on an autumn morning, broad living branches used as walkways, bridges of roots and vines, moss and hanging lichen, copper and gold leaves drifting down, mist far below, sun shafts through the foliage, muted and desaturated; early autumn morning, dappled sun shafts through the canopy, warm copper bounce from the leaves, cool green shade; full-length vertical shot from a neighboring branch at eye level, 85mm telephoto compression, lots of air above her head, a vertical trunk as a leading line, she fills a tall narrow strip of the frame, 
```

---

### 3.4 Новые богини — ранг SSR

#### zlata — Злата · **SSR** · жар-птица и весна · 25
- **Кто:** царевна Жар-птица из сказочного царства, дух весеннего солнца. Флагман запуска в RuStore на Масленицу (8–14 марта 2027). Фигура: статная, пышная, широкие бёдра, полная грудь.
- **Опоры:** кокошник с пером жар-птицы, одна толстая коса до пола с градиентом от золота к алому и тлеющим кончиком, плащ-крылья из перьев.
- **Обаяние и архетип:** царственная, тёплая, гордая, щедрая как весеннее солнце. Гэп: ест слишком много блинов и смущается. Тег: «Весна пришла!»
- **Поведение:**
  - голова — кокошник вспыхивает, бровь вверх, «Царевну — по голове?»;
  - рука — дарит светящееся перо;
  - наряд (плащ) — крылья-плащ раскрываются;
  - фон — искры поднимаются;
  - победа — крылья света, «Весна пришла!»;
  - поражение — перья тускнеют, она собирает их, «Пепел — только начало»;
  - комбо — огненные перья множатся.
- **Эмоции:** величественная полуулыбка, тёплый смех, гордая (подбородок вверх), смущённая (блины), гневная искра.
- **Позы:** вся постановка (6 поз, пластика, окружение, свет, кадр, анимация) — в `POSES.md` §16. Главные три:
  1. Строго анфас, тлеющий кончик косы, как свеча (`idle`).
  2. Плясовой «каблучок» с махом крыла-рукава (`select`).
  3. Ведёт игрока косой, как лентой (`tease`).
- **Фирменный idle:** перья плаща колышутся, по косе бегут угольки, ветер приносит искры.
- **Наряды:**

| id | Ранг | Образ | Ульта — визуал | М |
|---|---|---|---|---|
| zl_base «Жар-птица» | SSR | Алый сарафан-корсет с золотым растительным орнаментом в духе народной росписи (свой рисунок), открытые плечи, рукава-крылья из перьев, юбка с разрезом, сапожки; ноги **LW68** «Золотая роспись» | **Огненный шлейф**: огонь бежит от фишки к фишке | — |
| zl_fair «Масленичная ярмарка» | S | Короткая душегрея с мехом, платок, сарафан до колена, сапожки; ярмарка, блины; ноги **LW69** «Ярмарочная вышивка» | **Блинное солнце**: солнце-блин уносит фишку | В |
| zl_ember «Царица-пламя» | SSR | Чёрно-золотое вечернее платье в духе лаковой миниатюры, огненный шлейф, длинные перчатки, высокий разрез; купальская ночь у костров; ноги **LW70** «Тлеющий шов» | **Купальский костёр**: огонь освещает пару | П |
| zl_vow «Обет Жар-птицы» | SSR | Бело-золотое платье, кокошник с фатой; рассвет (симпатия 10); ноги **LW71** «Кокошник» | **Перо на счастье**: перо находит пару старейшей фишке | С |

- **Ядро ульты — Огненный шлейф:** снимает выбранную пару и растапливает все льды и замки на линии между двумя её фишками. Рейт.: пара и 1 лёд.
- **История:**
  1. Её перо приносит весну. Зима затянулась, потому что перо потерялось в салоне.
  2. Ищет перо и находит тебя: это ты подобрал «фишку» с пером.
  3. На высокой симпатии рассказывает, что Жар-птица раз в сто лет выбирает одного человека.
- **Фишки:** подпись — огонь. Рубашка: чёрный лак с золотым пером. Лица фишек с золотой кромкой (вне рейтинга). Стол: расписная лаковая шкатулка.
- **HUD-скин «Лаковая сказка»:**
  - панели — чёрный лак в рамках из золотого растительного орнамента;
  - кнопки — лаковые медальоны с золотым ободком (нажатие даёт отблеск золота);
  - вкладки — перья;
  - полоски валют — огненные ленты;
  - фон меню — тёмный лак с силуэтом жар-птицы, при открытии окна перо прочерчивает рамку (0,4 с);
  - экран загрузки — Злата стоит фронтально на резном гульбище терема над рекой, коса как свеча (POSES.md §16);
  - стинг — гусли и балалайка с женским хором «ой» (4–6 с).
- **Палитра:** c3242b · e8b23a · 1b1513.
- **Промпт** (роль: `firebird tsarevna of a fairy-tale kingdom`; выражение: `regal warm half-smile`; поза: `idle` из `POSES.md`):
```
one thick floor-length braid with a gold-to-scarlet gradient and glowing ember tip, ornate kokoshnik crown with a firebird feather, gold-amber eyes with fire glints, statuesque full figure, wide hips, full bust; scarlet corset sarafan with gold floral folk-style ornament of original design, bare shoulders and cleavage, long feather wing-sleeves, skirt with a high slit, scarlet silk stockings hand-embroidered with gold-thread curling vines and berries in an original folk-painting style, densest from the knee up to the band, a gold lace top band with firebird-feather scallops at mid-thigh in the sarafan slit, red morocco heeled boots, feather wing-cape; standing perfectly frontal and symmetrical, both feet planted hip-width apart with the weight even on both legs, both knees soft, toes turned slightly outward, feather wing-cape folded closed around her shoulders like a mantle and parting at the front to show the sarafan, both hands held together at waist height cradling the glowing ember tip of her floor-length braid like a candle, the braid running down over her right shoulder, chin slightly raised, eyes looking straight into the camera, regal warm half-smile; background: carved wooden terem gallery-porch overlooking a thawing river at spring sunrise, window frames carved with firebirds, embroidered linen towels drying on the railing, birches with first buds, ice floes drifting on the river, no snow, no icicles, muted; low spring sunrise backlight through the carvings, warm ember underglow from her braid and feathers, cool blue shadow from the river; strictly frontal and symmetrical icon composition, she stands dead center inside a carved window-frame or gallery arch like a lubok print, camera at eye level, knees-up, no tilt, no diagonals, 
```

#### minamo — Минамо · **SSR** · жемчужное море · на вид 26
- **Кто:** принцесса подводного Жемчужного дворца. Колодец во дворе салона ведёт в её море. Фигура: мягкая, округлая, длинные конечности, средне-пышная грудь.
- **Опоры:** нити жемчуга в волосах, шаль-хагоромо (полупрозрачна только шаль), шкатулка-тамэтэбако.
- **Обаяние и архетип:** нежная, воздушная, немного рассеянная, с наивным любопытством к миру наверху. Гэп: впервые видит солнце и обгорает. Тег: «Как сверкает!»
- **Поведение:**
  - голова — поднимаются пузырьки, она хихикает;
  - рука — дарит жемчужину;
  - наряд (шкатулка) — приоткрывает шкатулку, оттуда туман, «Не открывай!»;
  - фон — косяк рыб закручивается;
  - победа — шаль вздымается, «Как красиво!»;
  - поражение — «Течение унесло… но вернёт»;
  - комбо — пузырьки и жемчуг.
- **Эмоции:** мечтательная улыбка, игривая (палец у губ), удивлённая, обиженно-надутая, нежная.
- **Позы:** вся постановка (6 поз, пластика, окружение, свет, кадр, анимация) — в `POSES.md` §17. Главные три:
  1. Парит вертикально, ноги русалочьим хвостом (`idle`).
  2. Подплывает к камере, ладони козырьком: «о!» (`select`).
  3. Прячется в раковине, как под крышкой (`shy`).
- **Фирменный idle:** волосы и шаль плывут медленно, как под водой, перламутр переливается.
- **Наряды:**

| id | Ранг | Образ | Ульта — визуал | М |
|---|---|---|---|---|
| mi_base «Принцесса Жемчужного дворца» | SSR | Облегающее платье в духе ханьфу цвета морской волны, открытые плечи, лиф с жемчужной вышивкой, юбка с высоким разрезом, шаль-хагоромо; ноги **LW72** «Жемчужная пена» | **Прилив**: волна собирает пары в лотке | — |
| mi_beach «Первый день на суше» | S | Сарафан с открытой спиной, соломенная шляпа, сандалии; пляж на рассвете; ноги **LW73** «Морское стекло» | **Первая волна**: волна подсвечивает пару | П |
| mi_reef «Коралловый риф» | SSR | Слитный купальник с жемчужной отделкой и парео; летний баннер (витрина: по пояс); ноги **LW74** «Жемчужная вуаль» | **Коралловый вихрь**: вихрь возвращает фишку | В |
| mi_jelly «Праздник медуз» | SSR | Перламутровое вечернее платье с открытой спиной, шлейф-плавник, перчатки; зал с медузами-люстрами; ноги **LW75** «Русалочья чешуя» | **Жемчужная лавина**: жемчуг открывает фишку | О |

- **Ядро ульты — Прилив:** до 2 фишек в лотке, у которых есть свободный близнец на доске, сами собираются в пары. Если таких нет, возвращает 1 фишку из лотка. Рейт.: 1 пара.
- **История:**
  1. Поднялась на поверхность впервые, чтобы увидеть, как играют в маджонг «наверху».
  2. Во дворце время течёт иначе, и она боится вернуться и не застать тебя.
  3. На высокой симпатии дарит шкатулку с просьбой не открывать. Внутри фишка с твоим именем (тайна сюжета).
- **Фишки:** подпись — вода. Рубашка: перламутр с волной. Стол: коралловый песок с каустикой (шейдер, 0 МБ).
- **HUD-скин «Перламутр»:**
  - панели — раковины с мягким радужным переливом (шейдер);
  - кнопки — жемчужины, нажатие пускает пузырёк;
  - фон меню — подводный дворец в лучах (видео-петля 5 с);
  - при прокрутке пузырьки;
  - звук — подводные колокольчики;
  - стинг — арфа и мягкий подводный пэд.
- **Палитра:** 7fd3d0 · f3e9f1 · 3a4fa0.
- **Промпт** (роль: `princess of the undersea Pearl Palace`; выражение: `dreamy parted-lip smile`; поза: `idle` из `POSES.md`):
```
long flowing pastel aqua-pearl wavy hair drifting as if underwater, pearl strands and a coral comb in the hair, aqua-violet gradient eyes, soft rounded figure, long limbs, medium-full bust; form-fitting sea-green hanfu-inspired gown with bare shoulders and cleavage, pearl-embroidered bodice, skirt with a high slit, translucent hagoromo shawl floating around her arms, sheer aqua-blue stockings with a seafoam lace top band beaded with seed pearls at mid-thigh in the high slit, strands of pearl-chain anklets looping over the instep, pearl-strap slippers; floating weightlessly upright in clear water with her feet not touching anything, both legs pressed together and bent at the knees, swept gently to her left like a mermaid's tail with the toes pointed, both arms drifting loosely at shoulder height with palms down and fingers softly spread, translucent shawl and pearl-strung hair drifting upward around her, head tilted back slightly, gazing up toward the sunlight above with half-lidded dreamy eyes and a soft parted-lip smile, gown fully opaque and smoothly in place; background: flooded pearl grotto beneath a stone well, a round shaft above with a bright disc of daylight, mother-of-pearl walls, swaying kelp, jellyfish lanterns, a giant open clam shell, a gentle sea turtle, a sunken lacquered table with blank tiles drifting, light caustics, magical water where fabric stays dry-looking and fully opaque, muted; noon light through deep water, a vertical sun shaft from above, crawling caustics on skin and fabric, pearl-violet rim; always full length with pointed toes visible and feet off the ground, camera at her chest height with no tilt, lots of space above her head for drifting hair and shawl, she drifts slightly off-center, 
```

#### kira — Кира · **SSR** · сталь и тяга · 23
- **Кто:** ас-пилот мех-фрейма «Хризантема» из орбитальной стражи чайных путей. Её мех упал во двор салона. Фигура: среднего роста, пышная, полные бёдра, средне-пышная грудь.
- **Опоры:** короткий серебристо-белый боб с удлинёнными передними прядями, алая пилотская гарнитура с антенной, эмблема-хризантема.
- **Обаяние и архетип:** дерзкий ас, говорит позывными. Гэп: в смущении переходит на устав. Тег: «Цель захвачена!»
- **Поведение:**
  - голова — гарнитура пищит, «Связь установлена»;
  - рука — удар кулачками;
  - наряд (шлем) — крутит шлем на пальце;
  - фон — сенсор меха за спиной вспыхивает;
  - победа — большой палец вверх, мех поднимает руку;
  - поражение — «Отход на перегруппировку!», надевает шлем;
  - комбо — метки захвата по краю HUD.
- **Эмоции:** дерзкая ухмылка, сосредоточенная, смущённая паника, победное подмигивание с салютом, усталая улыбка.
- **Позы:** вся постановка (6 поз, пластика, окружение, свет, кадр, анимация) — в `POSES.md` §18. Главные три:
  1. Откинулась на броню меха, крутит шлем на пальце (`idle`).
  2. «Цель захвачена!» — пистолет из пальцев в объектив (`select`).
  3. Смущение в устав: «смирно» и салют (`shy`).
- **Фирменный idle:** крутит шлем на пальце и ловит, ночной ветер двора шевелит волосы, сенсор меха медленно моргает.
- **Наряды:**

| id | Ранг | Образ | Ульта — визуал | М |
|---|---|---|---|---|
| ki_base «Ас Хризантемы» | SSR | Облегающий бело-алый пилотный комбинезон с бронепластинами, молния опущена до верха груди, перчатки, шлем; ноги **LW76** «Кобура на бедре» | **Захват цели**: метки на двух парах | — |
| ki_off «Увольнительная» | S | Бомбер лётчика, облегающая майка, мини-юбка, ботильоны; станция; ноги **LW77** «Тактические D-кольца» | **Позывной**: сигнал растапливает лёд | Л |
| ki_dress «Парадный приём флота» | SSR | Белый парадный китель-платье с алыми лампасами, юбка-карандаш с разрезом, перчатки; зал с видом на планету; ноги **LW78** «Парадный лампас» | **Почётный залп**: салют подсвечивает пару | П |
| ki_stealth «Перегрузка реактора» | SSR | Чёрно-алый стелс-комбинезон со светящимися линиями, визор; ночная орбита; ноги **LW79** «Гекс-броня» | **Ракетный рой**: видимая автоцель | Ц |

- **Ядро ульты — Захват цели:** помечает 2 свободные пары. Они снимаются по одной за каждый из 2 следующих ходов игрока. Рейт.: 1 пара сразу.
- **История:**
  1. Мех упал во двор салона после боя.
  2. Пока он чинится, Кира учит маджонг как «тактический симулятор».
  3. На высокой симпатии просит тебя стать её штурманом: второе кресло всегда пустовало.
- **Фишки:** подпись — звезда. Рубашка: белый композит с алой полосой и эмблемой. Стол: ангарный пол с разметкой в дымке.
- **HUD-скин «Кокпит»:**
  - панели — тонкие светящиеся рамки со скосами;
  - валюты — цифровые табло;
  - кнопки — тумблеры, нажатие со щелчком;
  - у края поля (не на поле) прицельные уголки;
  - фон меню — двор чайного домика с коленопреклонённым мехом (видео-петля 5 с);
  - переходы — «загрузка систем»;
  - стинг — синт-оркестр.
- **Палитра:** f2f2f5 · e03a3e · 1c2b4a.
- **Промпт** (роль: `mecha ace pilot`; выражение: `cocky grin`; поза: `idle` из `POSES.md`):
```
short silver-white layered bob with longer front locks, red pilot headset with a small antenna, warm red gradient eyes, chrysanthemum emblem on the shoulder, medium-height curvy figure, full hips, medium-full bust; form-fitting white-and-red pilot bodysuit with armor plates on shoulders and hips, front zipper lowered to the upper chest showing cleavage, fitted gloves, a white-and-red armored thigh harness with a sidearm holster strapped around the right thigh over the bodysuit, red buckles, armored knee boots; leaning back against the knee armor of her kneeling white mecha with her left elbow hooked back over the armor edge, right leg straight and planted, left knee bent with the sole of her left boot flat against the armor behind her, right hand raised at shoulder height spinning her helmet on her index finger, chest open, chin up, cocky lopsided grin at the camera; background: a traditional tea house courtyard at night where a giant white mecha crash-landed and now kneels, a toppled stone water basin, a split bamboo fence, tarps and thick cables, tool carts, scorched raked gravel, tiled tea house eaves above, sci-fi hardware against old wood, muted; night, warm sodium work floodlights from the side, a red warning strobe, the mecha's cold blue sensor eye as backlight; dynamic low angle of 15 to 20 degrees, wide-angle lens, level horizon, huge mecha fingers, armor plates and cables in the foreground, strong diagonal composition, 
```

#### vesper — Веспер · **SSR** · алая ночь · на вид 28 (ей 400 лет)
- **Кто:** графиня-вампир из замка «Вечерняя звезда». Пьёт только гранатовый чай: никакой крови, укусов и стекла. Фигура: высокая, пышная, полная грудь, узкая талия, длинные ноги.
- **Опоры:** винно-чёрные локоны с вуалеткой из чёрного кружева, камея-чокер с алой розой, высокий кейп-воротник «крылья летучей мыши».
- **Обаяние и архетип:** элегантная, снисходительно-дразнящая, театральная, скучает четыреста лет. Гэп: тайно любит милые вещи (плюшевая летучая мышь). Тег: «Как и ожидалось».
- **Поведение:**
  - голова — «Как фамильярно…» и прикрывается кружевным зонтиком;
  - рука — подаёт руку в перчатке для поцелуя (флирт с игроком);
  - наряд (роза) — роза осыпается лепестками;
  - фон — свечи мигают, пролетает летучая мышь;
  - победа — реверанс;
  - поражение — театрально прикладывает руку ко лбу (стоя);
  - комбо — вихрь летучих мышей.
- **Эмоции:** надменная улыбка с клычком, лукавый прищур, скучающая, искренне смущённая, гневная.
- **Позы:** вся постановка (6 поз, пластика, окружение, свет, кадр, анимация) — в `POSES.md` §19. Главные три:
  1. Тандю с кружевным зонтиком на плече (`select`).
  2. Сидит прямо на бархатной кушетке с розой (`idle`).
  3. Снимает перчатку зубами на банкетке клавесина (`tease`).
- **Фирменный idle:** лениво крутит розу, кейп и вуаль колышутся, медленно перекладывает лодыжки (сидя на кушетке).
- **Наряды:**

| id | Ранг | Образ | Ульта — визуал | М |
|---|---|---|---|---|
| ve_base «Графиня Вечерней звезды» | SSR | Чёрно-алое готическое платье с корсажем, глубокое декольте, высокий разрез, кружевные рукава, длинные перчатки, сапоги; ноги **LW80** «Кровавая роза» | **Ночной квартет**: летучие мыши уносят фишки одного вида | — |
| ve_day «Солнечный зонтик» | S | Закрытое летнее платье с высоким воротом, огромная шляпа, кружевной зонтик; полдень; ноги **LW81** «Балетные ленты» | **Тень зонтика**: тень указывает пару старейшей фишке | С |
| ve_ball «Полночный бал» | SSR | Бордовое бальное платье с открытой спиной, маска-домино, шлейф; Хэллоуин в замке; ноги **LW82** «Бархатный дамаск» | **Вальс летучих мышей**: открывает закрытую фишку | О |
| ve_vow «Гранатовая клятва» | SSR | Тёмно-алое с белым платье, кружевная фата; луна (симпатия 10); ноги **LW83** «Гранатовая клятва» | **Клятва при луне**: растапливает замок | Л |

- **Ядро ульты — Ночной квартет:** тап по фишке снимает все свободные фишки этого вида (2 или 4, то есть до 2 пар). Рейт.: 1 пара.
- **История:**
  1. Четыреста лет скуки закончились, когда она услышала стук фишек из салона.
  2. Её условие: проиграет — уйдёт. Не проигрывает.
  3. На высокой симпатии впервые выходит на рассвет ради тебя, под зонтиком.
- **Фишки:** подпись — корона. Рубашка: чёрный бархат с серебряной розой. Стол: тёмный мрамор с витражным светом.
- **HUD-скин «Витраж»:**
  - панели — готические арки с рубиново-чёрным витражом;
  - кнопки — сургучные печати с розой;
  - вкладки — кованое ажурное железо;
  - фон меню — музыкальный салон при свечах;
  - переходы — летучие мыши и лепестки;
  - стинг — орган и клавесин.
- **Палитра:** 6b0f1a · 141018 · c9c3cf.
- **Промпт** (роль: `vampire countess`; выражение: `haughty smile showing a tiny fang`; поза: `select` из `POSES.md`):
```
long black-cherry wine-colored ringlets in a half-up style with a small black lace veil fascinator, ruby-red gradient eyes, cameo choker with a crimson rose, tall voluptuous figure, full bust, narrow waist, long legs; black-and-crimson gothic gown with a corset bodice and deep neckline showing cleavage, high thigh slit, sheer lace sleeves, long satin gloves, sheer black stockings with a deep blood-red rose Chantilly lace top band at mid-thigh in the high slit, only the end clips of black satin garter straps from the corset with small ruby-rose clasps visible at the band, pointed black heeled boots, high bat-wing cape collar; standing tall, an opened black lace parasol resting on her right shoulder so its lace shadow falls across half her face, weight on her straight left leg, right leg extended forward in a ballet tendu with the pointed toe of her heeled boot touching the floor through the high slit, left gloved hand raised with the back of her fingers hiding her lips, narrowed amused eyes looking down at the camera; background: gothic castle music salon, a black lacquered harpsichord, a black velvet chaise longue, a tall pointed-arch stained-glass window glowing ruby from a bonfire outside, no moon, candelabras dripping wax, porcelain tea set with pomegranate tea, black roses in a vase, heavy velvet drapes, muted; candlelight only, warm flickering flames from the front and side, ruby patches of stained-glass light on the floor, deep wine-black shadows; long diagonal of her body across the frame, telephoto compression, a heavy out-of-focus velvet drape or candelabra in the foreground, theatrical opera-box vignette, camera at her face or chest level with an upward tilt under 5 degrees, 
```

#### sigrid — Сигрид · **SSR** · иней и сияние · 24
- **Кто:** северная княжна, дочь Хозяйки зимы, гостья на Новый год. Это не Снегурочка и не «внучка». Фигура: высокая, стройная, средняя грудь, длинные ноги.
- **Опоры:** ледяная тиара-кристалл, белый плащ с мехом, светящаяся лента северного сияния.
- **Обаяние и архетип:** правильная, сдержанная, вежливая, немного одинокая, неловко тёплая. Гэп: обожает горячий шоколад и «тает» от жары. Тег: «Холодно? Мне — нет».
- **Поведение:**
  - голова — падают снежинки, «Это… было приятно»;
  - рука — на стекле с твоей стороны расцветает морозный цветок;
  - наряд (лента) — лента сияния закручивается;
  - фон — вспышка сияния;
  - победа — сияние на всё небо, реверанс;
  - поражение — иней на ресницах, «Холод — ещё не конец»;
  - комбо — снежинки кристаллизуются.
- **Эмоции:** сдержанная, неловкая тёплая улыбка, смущение (румянец на бледной коже, пар изо рта), удивление, решимость.
- **Позы:** вся постановка (6 поз, пластика, окружение, свет, кадр, анимация) — в `POSES.md` §20. Главные три:
  1. Т-позиция на чёрном льду, касается тиары (`idle`).
  2. Перебежка фигуристки мимо камеры (`select`).
  3. Стоп-кадр вращения, запястья скрещены над головой (`win`).
- **Фирменный idle:** видимое дыхание паром, снег, лента сияния течёт.
- **Наряды:**

| id | Ранг | Образ | Ульта — визуал | М |
|---|---|---|---|---|
| si_base «Княжна северного сияния» | SSR | Бело-голубое облегающее платье с меховой оторочкой, корсаж с ледяной вышивкой, открытые плечи под меховой накидкой, разрез, высокие сапоги; ноги **LW84** «Иней и звёздная пыль» | **Ледяной мост**: у лотка вырастает ледяная ячейка | — |
| si_newyear «Новогодняя гостья» | S | Красно-белое пальто-платье с мехом, меховая шапочка, варежки; праздничная площадь; ноги **LW85** «Карамельная трость» | **Хлопушка**: подсветка пары | П |
| si_summer «Таю!» | SSR | Лёгкое белое платье с открытой спиной, веер-снежинка; жаркий летний полдень (комедия); ноги **LW86** «Таю!» | **Ледяной лимонад**: возвращает фишку | В |
| si_throne «Королева вьюги» | SSR | Коронационное хрустальное платье, ледяной шлейф, высокий ворот-корона; вьюга; ноги **LW87** «Полярное сияние» | **Вьюга**: открывает закрытую фишку | О |

- **Ядро ульты — Ледяной мост:** добавляет 1 ледяную ячейку лотка на 10 пар. Не суммируется: повторный запуск продлевает срок. Рейт.: на 5 пар.
- **История:**
  1. Ушла из ледяного дворца, потому что там никто не смеётся.
  2. В салоне впервые проиграла и засмеялась.
  3. На высокой симпатии остаётся до весны, хотя должна была уйти в полночь Нового года.
- **Фишки:** подпись — снежинка. Рубашка: голубой лёд с узором инея. Стол: заснеженный ледяной стол под сиянием.
- **HUD-скин «Иней»:**
  - панели — матовое стекло, иней нарастает по краям при открытии окна (шейдер);
  - кнопки — кристаллы с внутренним светом сияния;
  - валюта — снежинки;
  - фон меню — ельник под сиянием (видео-петля 5 с);
  - снег при прокрутке;
  - стинг — колокольчики и хор.
- **Палитра:** dff1f7 · 7fc8d8 · 8b7fd6.
- **Промпт** (роль: `northern princess of the aurora`; выражение: `reserved, slightly awkward warm smile with a faint blush`; поза: `idle` из `POSES.md`):
```
very long straight pale ice-blue to mint gradient hair with a crown braid, crystal ice tiara, pale blue-violet aurora gradient eyes, visible breath mist, tall slim elegant figure, medium bust, long legs; fitted white-and-ice-blue gown with fur trim, frost-embroidered corset bodice, bare shoulders under a short white fur capelet, skirt with a side slit, sheer white stockings dusted with fine silver-blue glitter that sparkles like frost, densest from the knee up, a frost-crystal lace top band at mid-thigh in the slit, tall white heeled boots, glowing aurora ribbon scarf flowing around her; standing on the black ice of a frozen lake in a figure-skater T-position, right foot forward with the left heel tucked against the right instep, both legs straight and close together, right fingertip adjusting her crystal tiara, left hand holding a small copper mug of hot chocolate low at her waist, visible breath mist, aurora ribbon resting over her forearms, seen in three-quarter profile, reserved small smile at the camera; background: a frozen mountain lake at polar night, black mirror-like ice reflecting the aurora, a carved ice gazebo and snow-laden pines on the shore, a small copper pot of hot chocolate on a brazier, tall clear ice panes standing on the lake, faint frost trails on the ice, muted; deep polar night, cold key light reflected from snow and ice, shimmering violet-green aurora rim from above, the brazier as the only small warm accent; side-on tracking shot like a rink camera, full-length wide frame with large negative space of empty ice and sky, camera strictly at eye level, she sits near one edge of the frame moving along the horizontal, 
```

---

## 4. Анимация: общая спецификация

### 4.1 Принцип: один опорный кадр, два движка

Для каждого наряда утверждается **опорный кадр K** (мастер 9:16, не меньше 1152×2048). Из него делается всё остальное:
- **Видео (Kling, start = end = K):** петли лобби, витрина, призыв, ульта, победа, видео-реакции. Подходит для полнотелого движения: ноги, ткань, вес тела.
- **Риг (Godot Skeleton2D + Polygon2D) из нарезки K:** мгновенные реакции на тап, липсинк, моргание и взгляд, бюст-портрет у края HUD в партии. Даёт резкость и мгновенный отклик.

Все клипы начинаются и заканчиваются на K, поэтому стыки бесшовные: **видео → риг → видео** переключаются на кадре 0 петли. Если нужен мгновенный отклик (тап, реплика), делается кроссфейд 120–150 мс из текущего кадра видео в риг-K. Idle-амплитуда маленькая, поэтому шов не виден. Риг доигрывает реакцию и липсинк, затем на стыке снова включается видео.

### 4.2 Действия

| Действие | Длит. | A | S | SSR | Содержание |
|---|---|---|---|---|---|
| **Появление: призыв** | A 1,2 с · S 2 с · SSR 3–4 с | Код: силуэт-вспышка → K | Видео: start = крупный план глаз (кроп из K), end = K, наезд-отъезд | Видео фирменного появления (перья Златы, пузырьки Минамо, опускающийся мех Киры, собирающиеся летучие мыши Веспер, метель Сигрид), затем стинг | Фонарь цвета ранга (0.9-spec §E) → раскрытие. Пропуск со 2-го раза. Трансформация вспышкой, без промежуточного силуэта тела |
| **Вход в лобби** | 0,6–1 с | Риг: въезд + приветствие с липсинком | То же + видео-петля после стыка | То же + HUD-скин собирается от центра (0,6 с) | Приветствие по времени суток и событию |
| **Idle** | Петля 5 с | Риг (дыхание, моргание, волосы) | 1 петля на наряд | 2 петли на базовый наряд (A: вес и волосы; B: ноги и голова), 1 на прочие | §4.3 |
| **Выбор / надевание** | 1,5–2,5 с | Риг: поза-«да» + реплика | Видео-реакция «рада» (2 с) | Видео «надевание»: вспышка → новый K, HUD перестраивается волной | Реплика на новый наряд. Первый раз — полная ульта-вставка (HEROINES §2) |
| **Тап** | Отклик ≤100 мс | Риг-реакция зоны | Риг-отклик, затем видео-реакция 2 с | То же, 3 видео-реакции | §4.4 |
| **Комбо** | 0,6–1,2 с | Бюст-риг у края HUD: ×3 реплика, ×5 полоса кат-ина (ROADMAP §8), ×8 «золотой» вариант | = A | = A + аура в цвете HUD-скина | Поле не перекрывается (`mouse_filter` ignore) |
| **Ульта** | S/A-наряд 1,33 с · SSR-наряд 2 с | Стоп-кадры A/Б + код | + кусок 1,2–1,5 с из видео-петли | + видео-вставка ульты 2 с | HEROINES §2: ≤3 вспышки в секунду, без белого, тап пропускает |
| **Победа** | 2–3 с | Риг + эмоция | Видео 3 с | Видео 3 с на каждый SSR-наряд | Окно итогов |
| **Поражение** | 1,5 с | Эмоция-бюст + риг | = A | = A | Без насмешки над игроком, с подбадриванием |
| **Реплика / липсинк** | По длине | Риг: виземы | = A | = A | §4.5 |

### 4.3 Idle в стиле BD2: что можно и что нельзя

**Можно:**
- дыхание (плечи и грудная клетка поднимаются на 1–2%);
- моргание раз в 2–6 с, иногда двойное;
- подмигивание, наклон головы, взгляд за пальцем игрока;
- физика волос, лент, шарфа, плаща, хвоста, кистей, вуали;
- покачивание и перенос веса всего тела, смена опорной ноги раз в 6–10 с;
- **смущённые движения ногами** (только видео, камера на уровне глаз, подол неподвижен):
  - стоя: колени сводятся и трутся, носок приподнимается;
  - сидя: медленно перекладывает ногу на ногу или скрещивает щиколотки;
- игра с реквизитом (фирменный idle из карточки);
- «скучает» после 20 с без действий: поправляет волосы, рассматривает фишку, зовёт игрока;
- липсинк.

**Нельзя:**
- сексуальные действия и их имитация (толчки, трение, стоны);
- **изолированное колыхание как самоцель кадра** (мягкая вторичная физика от движения можно, ART_DIRECTION §4);
- камера на пах, грудь или ягодицы, наезд и панорама по телу;
- подол, поднятый ветром, соскальзывающая одежда, раздевание, нагота;
- лёжа, на четвереньках, прогиб спины, ноги врозь к камере;
- облизывание и другие намекающие действия ртом;
- школа и «учитель — ученик»;
- spin и twirl в платье и юбке (подол меняется).

**Шаблон idle-петли (Kling o3 flf, pro, без звука, 9:16, start = end = K):**
```
seamless loop, identical first and last frame, static camera at eye level, subtle natural motion only: slow breathing, one or two blinks, gentle weight shift from one leg to the other, hair strands, ribbons and {прядь/шарф/хвост/плащ} swaying softly, {фирменный жест}; face, outfit, neckline, hem and slit stay exactly the same; no zoom, no pan, no spin, no wind lifting the skirt
```
**Вариант B (ноги):** заменить середину на `she shyly brushes her knees together, lifts one heel slightly and settles back, small head tilt, soft smile` (стоя) или `she slowly uncrosses and recrosses her legs once, hem stays exactly in place` (сидя).
**Видео-реакция (2 с):** `she reacts to a gentle pat on her head: closes her eyes, giggles, small head tilt, then returns exactly to the initial pose`.

### 4.4 Зоны тапа

| Зона | Что входит | Реакция |
|---|---|---|
| **Голова** | Волосы, уши, шляпа, тиара | Погладили: смущение или радость, фирменная реакция из карточки |
| **Рука** | Кисть и предмет в ней | «Дай пять», вручение предмета, жест к игроку |
| **Наряд** | **Только аксессуары и реквизит:** шарф, лента, плащ, маска, веер, хвост, шкатулка, шлем | Аксессуар оживает (бант, маска, роза) |
| **Фон** | Сцена за спиной | Событие окружения (птица, пар, молния, рыбы) |

- **Интимных зон нет:** торс, грудь, бёдра, ноги и юбка не входят ни в один полигон. Тап туда даёт только нейтральный взгляд в камеру, без реплики.
- Полигоны зон хранятся в JSON рига каждого K.
- Третий тап за 2 с даёт мягкое «Ну хватит~».
- Симпатия за тапы ограничена 3 в день (0.9-spec §C).

### 4.5 Липсинк

- Реплики (TTS или актриса) офлайн прогоняются через **Rhubarb Lip Sync** (MIT, фонетический режим, работает с русским аудио). Получаем JSON с метками.
- 6 визем рига: закрыт, A, И/Э, О, У, улыбка. Плюс глаза: открыты, полуприкрыты, закрыты.
- Запасной вариант: амплитуда через `AudioEffectSpectrumAnalyzer`, как нынешний `talk_left` в hero.gd.
- В видео рот не синхронизируется. Пока богиня говорит, работает риг-K (§4.1).

### 4.6 Технический конвейер

1. **K** утверждён по чек-листу HEROINES §6, плюс скромная версия.
2. **Видео:** Kling o3 flf pro без звука, 5 с, 9:16. Черновик на `seedance_2_0_mini` 480p (2 кр).
   - Проверка шва по SSIM, контакт-лист 4 кадра/с: подол, вырез и возраст лица не изменились.
   - Конвертация: `ffmpeg -i in.mp4 -vf scale=540:960 -r 24 -c:v libtheora -q:v 6 -an out.ogv`. SSR-лобби в 720×1280 (q 6–7).
   - Пилот уже есть: `game/assets/v09/video/mc_lobby.ogv`.
3. **Риг:**
   - нарезка K на слои: волосы перед и зад (3–6 прядей), голова, глаза, брови, рот (виземы), шея, торс, руки (плечо, предплечье, кисть), бёдра и голени, юбка (2–3 полосы), аксессуары;
   - скрытые части дорисовываются правкой той же моделью;
   - кости Skeleton2D: 25–40;
   - вторичное движение через `SkeletonModification2DJiggle` только на волосах, лентах и аксессуарах.
   - Трудоёмкость: 1 день на A-наряд, 1–2 дня на SSR-наряд.
4. **Плеер:** два `VideoStreamPlayer` (один играет, второй грузит следующий клип), настройка «Живые фоны» и статичная замена для каждого клипа.
   - Гейт: 60 fps на RedMagic и ≥30 fps на слабом Mali, замер нагрева (ROADMAP §7).
5. **Пакеты богинь:** в APK лежат основательницы и базовые наряды волны 1, остальное скачивается по требованию (сервер и CDN, CEO_PLAN №18/29). Лимит размера RuStore сверить.

### 4.7 Бюджет ассетов на богиню (стартовый пакет: база + 1 наряд)

| | A | S | SSR |
|---|---|---|---|
| Опорные кадры | 2 (+2 скромные) | 2 (+2) | 2 (+2) |
| Эмоции (бюст) | 5 | 5 | 5 |
| Кат-ин, кадр Б | 1 | 2 | 2 |
| Риг | База | База + 2-й наряд | База + 2-й наряд |
| Видео: idle | 1 | 2 | 3 (2 базы + 1) |
| Видео: призыв | 1 (вне рейтинга) | 1 | 1 |
| Видео: реакции | — | 1 | 2 |
| Видео: ульта / победа | — | 1 / — | 1 / 1 |
| **Клипов всего** | **2** | **5** | **8** |
| Реплики | 12 | 18 | 25 |
| Набор | Рамка, акцент | + тема (рубашка, рамка, фишка-подпись), стол | + HUD (≈10 элементов 9-slice, фон меню, загрузка), стинг 4–6 с, видео-фон меню |
| Размер | ≈4 МБ | ≈8 МБ | ≈18 МБ |

Полный ростер в стартовых пакетах занимает ≈8×4 + 7×8 + 5×18 ≈ 180 МБ. Отсюда и скачиваемые пакеты.

---

## 5. Производство и стоимость

### 5.1 Ассеты на богиню (порядок работ)

1. Лист персонажа: лицо анфас и 3/4, причёска сзади и сбоку, фигура, HEX. **Утверждает владелец.**
2. K базового наряда и K второго наряда: 9:16, по 4 сида, скромные версии.
3. Эмоции ×5 правкой из листа. Кадр Б для кат-ина.
4. Видеоклипы по §4.7: черновик, финал, шов, контакт-лист.
5. Риг: нарезка, дорисовка, кости, виземы, полигоны зон.
6. Голос (оценка через `estimate_audio_cost`), Rhubarb, лейтмотив-вариация (pitch и инструмент), стинг для SSR.
7. Набор: рамка, акцент; тема фишек, стол; HUD-скин.
8. Тексты: профиль (возраст, профессия), 30–40 реплик, 3 сцены, 2 письма.
9. Журнал происхождения: модель, промпт, сид, ID референсов, дата.
10. Ручная проверка по чек-листу HEROINES §6 и правилам ИС.

### 5.2 Кредиты Higgsfield

Цены — из ART_DIRECTION §5 и HEROINES §6: GPT 2.6 стоит 0,75–2 кр за картинку, NBP 2 кр, Kling o3 flf pro 5 с — 6,25 кр, принятый клип с 2–3 попытками и черновиком ≈15 кр, L40S 71 кр/ч. Перед каждой партией вызывать `estimate_*` и `balance()`.

| Статья | A | S | SSR |
|---|---|---|---|
| Лист персонажа | 10 | 10 | 12 |
| 2 опорных кадра с кат-ином и слоями рига (≈30 / 36 / 40 за наряд) | 66 | 76 | 76 |
| Эмоции ×5 | 10 | 10 | 10 |
| Видео (клипов × ≈15) | 30 | 75 | 120 |
| Набор (тема, стол, HUD) | 3 | 12 | 35 |
| Голос и стинг | 5 | 8 | 15 |
| **Стартовый пакет** | **≈125** | **≈190** | **≈270** |
| Экономный (видео: A — 0, S — 2, SSR — 5) | ≈95 | ≈145 | ≈225 |
| Каждый следующий наряд | A/S ≈30–36 (+15 с петлёй) | ≈36–50 | SSR ≈85 (K + 3 клипа) |

**Итоги:**
- **15 новых богинь, стартовые пакеты:** 5×125 + 5×190 + 5×270 ≈ **2,9 тыс. кр** (экономный вариант ≈2,3 тыс.).
- **Остальные наряды** (≈30 штук, выходят сезонными дропами): ≈**1,8 тыс. кр** за 12–18 месяцев.
- **Основательницы:**
  - риги — работа, а не кредиты;
  - видео (A по 2 клипа, S по 5) и наборы ≈**300 кр**.
- **LoRA v2 с токенами богинь:**
  - v2 (основательницы + волна 1): датасет ≈60 кр и 1,5–2 ч L40S ≈110–140 кр. Частично уже заложена в HEROINES §6, волна 1;
  - дообучение после волн 2 и 3: по ≈110–140 кр.
- **Резерв на переделки:** ×1,3 к видео.

Это в 3–4 раза больше плана ROADMAP §5 (≈800 кр на всё). Нужно пополнение баланса по волнам. Кредиты идут из выручки после запуска 1.0, что соответствует порогам мягкого запуска в CEO_PLAN §7.

### 5.3 Волны

| Волна | Когда | Богини | Сезон / баннер | Кредиты |
|---|---|---|---|---|
| **0. Системы** | 0.10 | — | Код: ранги A/S/SSR в UI, наборы, HUD-скин (тест на одном скине), тема фишек, сцена богини (видео ↔ риг), риг и липсинк — пилот на МТ, экран «Богини N/20» | ≈50 (листы волны 1) + LoRA v2 |
| **1** | к **1.0 RuStore (~март 2027)** | **tsubame** (A), **miel** (A), **kohaku** (S), **shirin** (S), **zlata** (SSR) | Злата — флагман «Масленица» (8–14.03.2027). Миэль — первый выпуск «Испечь вместе». Цубамэ ведёт «Письма» | ≈900 (экономный ≈700) + основательницы ≈300 |
| **2** | 1.0.x – 1.1 (апрель–июль 2027) | **jess** (A), **lian** (A), **mari** (S), **kira** (SSR), **minamo** (SSR) | Кира — 12 апреля, «космос». Минамо и Марисоль — летний баннер (купальники в пляжном контексте, витрина по пояс) | ≈1 000 + LoRA ≈120 |
| **3** | 1.2 (сентябрь 2027 – январь 2028) | **tsuru** (A), **hibana** (S), **nemi** (S), **vesper** (SSR), **sigrid** (SSR) | Неми — осень. Веспер — Хэллоуин. Цуру и Сигрид — Новый год 2028 | ≈1 050 + LoRA ≈120 |

Состав волн: 1 — 2 A + 2 S + 1 SSR; 2 — 2 A + 1 S + 2 SSR; 3 — 1 A + 2 S + 2 SSR. Ритм ART_DIRECTION: 1 сезон в 4 недели, в сезоне 1 SSR и 1–2 S. Между баннерами богинь идут дропы нарядов.

**Сроки на одного человека (без кода):** A ≈4 дня, S ≈6 дней, SSR ≈9 дней (риг 1–2 дня на SSR-наряд, ручная проверка). Волна 1 займёт ≈30 рабочих дней, параллельно с кодом 0.10–1.0.

### 5.4 Место в ROADMAP

- **0.10:** системы волны 0 (≈12–18 дней кода: наборы и HUD-скины 6–8, сцена видео ↔ риг 3–4, риг и липсинк 5–7 с пилотом на МТ). Листы волны 1, LoRA v2. Задача рейтинга: выравнивание ядер всех 20 через бота.
- **1.0 (RuStore):** волна 1 и наборы основательниц. Пакеты богинь скачиваются через минимальный сервер (CEO_PLAN №18).
- **1.0.x – 1.1:** волна 2, Звёзды и Созвездие с Лепестками (CEO_PLAN №12, 1.1).
- **1.2:** волна 3, рерун-баннеры волны 1 со «звёздочкой».

### 5.5 Гейты

1. Лист персонажа утверждён до любых нарядов.
2. Опорный кадр проходит чек-лист HEROINES §6: силуэт, взрослость, камера, нет текста, опоры на месте.
3. Видео: шов, контакт-лист, подол и вырез не изменились.
4. Риг: резкость на 1080×2400, FPS, нагрев.
5. Баланс: бот по всем ядрам; в рейтинге разброс ≤10%, между нарядами одной богини ≤3%.
6. HUD-скин: контраст ≥4,5:1, поле чистое и кликабельное, переключатель «Эффекты: умеренные» убирает анимацию рамок.
7. ИС: имена, концепты и палитры сверены с каталогами BD2.

---

## 6. Решения владельцу

1. **Лестница 8/7/5** и места основательниц: МТ, Рин, Хана — A; Юэ, Нова — S; все SSR новые. Альтернатива — поднять Юэ в SSR (тогда у неё будет HUD, но SSR станет бесплатным через Путь).
2. **Правило набора:** SSR-наряд поднимает набор до S, полный HUD только у SSR-богинь.
3. **Физика idle:** покачивание всего тела, волосы и ткань — да; отдельная физика груди и бёдер — нет. Подтвердить, потому что формулировка «body physics» в запросе шире ART_DIRECTION §4.
4. **Список 15 новых** и волна 1: Цубамэ, Миэль, Кохаку, Ширин, Злата.
5. **Бюджет:** волна 1 ≈0,9 тыс. кр (экономный ≈0,7 тыс.) плюс ≈0,3 тыс. на основательниц. Весь ростер ≈2,9 тыс. кр стартовых пакетов и ≈1,8 тыс. на поздние наряды. Пополнение из выручки после 1.0.
6. **Скачиваемые пакеты богинь** (размер ≈180 МБ на стартовые пакеты) — вместе с сервером 1.0.
