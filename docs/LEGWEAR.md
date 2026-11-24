# LEGWEAR.md — библия ножек и горячих жестов (LEGWEAR v2)

> **Статус:** 2026-11-24, на утверждение владельцу. Генерация не запускалась, `game/` не менялся.
> **Задача владельца:** «Чулки не только кружевные, а самые разные и вкусные анимешные в разных стилях; рваные на ком-то можно; пофантазируй, чтобы было сексуально; позы всем подобрать и анимировать горячо».
> **Что это.** v2 каталога LEGWEAR v1 после трёх ревью: игрок BD2/Nikke/AL (витрина), арт-директор (уникальность), комплаенс (красные линии и разделение сборок). Все их правки внесены (сводка в §7).
> **Источник правды по ногам — этот файл.** Коды `LW01…LW87` заменяют `POSES_HOT.md` §5 и все места `POSES_HOT.md` §6, где чулки описаны иначе. Карточки `ROSTER_20.md` и строки нарядов ссылаются на эти коды.
> **Опирается на:** `HEROINES.md` (поправки владельца 23.11 и 24.11, §4 красные линии), `ROSTER_20.md` (§1.2, §2.1, §4.3), `POSES.md` (§0.3–0.5), `POSES_HOT.md` (§1–§4, библиотека жестов), `UX_RULES.md` §8, `ART_DIRECTION_v2.md` (рецепт v4), `game/scripts/v10/rig/README.md` (риг v2: каналы, слои, предел подмалёвка 10–35 px).

---

## 1. Правила

### 1.1 Красные линии (для всех сборок, без исключений)

- Все богини взрослые (23+ в каноне), зрелое лицо, 7,5 головы. Никакой школы: в легвире запрещены сочетания «белые гольфы + лоферы/мэри-джейн», «носочки с рюшей + бант», клетка-гингем на ногах, клубнички и прочий «детский» код.
- Нет белья как наряда. Слова `garter belt`, `lingerie`, `panties`, `upskirt` не пишем никогда. **Подвязка — только часть платья, корсажа, пояса доспеха или кителя**, и источник назван в промпте (`from the corset`, `from the armored kimono belt`, `from the uniform tunic`). Одиночных подвязок на ноге (свадебная подвязка, O-кольцо на голом бедре, бахрома-подвязка) нет. В разрезе видна **только концевая застёжка** подвязки у резинки, сама лента от талии не рисуется.
- Резинка, кружево и любая деталь на бедре — **не выше середины бедра**, видна только в разрезе или под подолом; подол и разрез такие же, как в опорном кадре K, и в движении не расширяются (`slit position identical to the key frame, does not widen`).
- Прозрачность — **только на легвире**. Лиф, бёдра под юбкой и юбка всегда непрозрачны.
- Камера на юбках и платьях на уровне глаз, наклон вверх ≤ 10°. Низкий ракурс — только Кира, **только стоя и только в `ki_base` / `ki_stealth`** (комбинезоны). Поза с поднятым коленом и ботинком на броне (`lean-back-boot-on-armor`) в `ki_off` и `ki_dress` запрещена.
- Поднятое колено (Цубамэ, Мари, Хибана, Кира) — только в брюках, шортах или комбинезоне.
- Тап по бёдрам, ногам и юбке — только нейтральный взгляд (UX §8.2). Ни одна реакция на тап не трогает ноги.

### 1.2 Рваное — только мода

- Рваный легвир — это **стиль, в котором его носят**: панк, гранж, «тактический» крой, рабочая потёртость, клановая штопка. В промпте всегда `distressed by design, worn that way`.
- Он нарисован в опорном кадре K и **одинаков во всех кадрах и клипах наряда**, включая раскрытие гачи, победу и ульту. Он никогда не появляется только в `lose`, только в `allure` или «за симпатию».
- **Ульта, тап, поражение и симпатия ничего не рвут** (красная линия «разрушение одежды ультой»).
- Порывы, прорези и стрелки — **только на коленях и голенях**. Выше колена не больше ладони и только с внешней стороны колена; на внутренней стороне колена и бедра, на бёдрах и под юбкой — никогда. Стрелка начинается и заканчивается между коленом и щиколоткой.
- Рваных образов ровно пять, все разные (§3.2): Нова LW28, Цубамэ LW35, Джесс LW42, Хибана LW63, Кира LW77. В Яндекс-сборке у всех целые плотные колготки.

### 1.3 Разнообразие: правила каталога

1. **Силуэт → цвет → деталь.** Каждый образ читается на миниатюре 64×114 за счёт длины, контраста или колор-блока. Мелкая деталь — только третий слой. Слово `tiny` в главной детали не используем; ячейка любого регулярного узора (сетка, горох, соты, решётка) на экране не меньше 6–8 px, иначе под варпом рига идёт муар.
2. **Зона витрины — от колена до середины бедра.** Главный признак образа виден в этой полосе: верх, абсолютная зона, бант у колена, узор на бедре, порыв на колене. Тогда он виден и в лобби на плане «от колен». Признак у щиколотки — только второй слой; главным он бывает лишь у Неми, Минамо и Сигрид (у них полный рост по умолчанию, POSES §0.1.4) и в «закрытых» нарядах.
3. **У каждой богини не больше одного SSR «кружевной верх в разрезе».** Остальные SSR берут другой механизм показа (§3.1, колонка «Показ»): абсолютная зона, ботфорт + полоса чулка, кобура на бедре, асимметрия, две ноги разного цвета, принт по всей ноге, шнуровка по икре, стремя, свечение, доспех, «ноги закрыты».
4. **Основа — в цвет богини**, а не чёрная по умолчанию.
5. **Металл закреплён за богиней:** золото — Злата, Ширин; серебро — Юэ, Сигрид; латунь — Мари; жемчуг — Минамо; рубин — Веспер; нефрит — МТ, Рин. Остальные без золота (коралл, янтарь, лак, сталь, кость). Исключение: `o_dragon` (тема «Золото дракона» — канон `s_gold`).
6. **Шов сзади** — только у Рин (LW12), он виден в 3/4. Остальные «линии» идут по внешнему шву (лампас), который виден в анфас и 3/4. Спиной к камере кадр выше талии (POSES §0.3), поэтому шов сзади на икрах никто не показывает.
7. **Название кружева не работает.** Chantilly, Leavers, guipure на полосе 1–2 см модель рисует одним фестоном. Кружевные верхи различаются **цветом кружева против цвета чулка** и **одним объёмным элементом** (перья, бахрома, тюль, бисер, заклёпки). Полос «просто кружево» в каталоге не больше пяти, все разного цвета.
8. **Нюд и денье модель игнорирует.** У каждого телесного или светлого прозрачного чулка есть видимая граница: тёмный верх, полоса, бант у колена или `visible satin sheen`.
9. **В EN-фразе ног нет слов позы и камеры.** Где деталь видна, пишется отдельно в поле «Видно» (ключ слота из POSES §0.5).
10. **Асимметрия** (LW16, LW32): модель симметризует или меняет ноги местами. Закладывать второй проход правкой утверждённого K (≈0,75 кр).

### 1.4 Ранги: материал, а не площадь кожи

Ширина абсолютной зоны привязана к **крою**, а не к рангу: мини и шорты — до двух ладоней, юбка выше колена — до ладони, миди и в пол — только разрез. Эскалация по рангу идёт через материал и мастерство:

| Ранг наряда | Легвир | Детали |
|---|---|---|
| **A** «один акцент» | Гольфы и гольфы выше колена, прозрачные колготки и чулки с принтом, вязка, полоски, бант | Без подвязок и сетки. Один акцент у колена |
| **S** «костюм роли» | Чулки выше колена с явной резинкой, шнуровка лентой, сетка, подтяжки от шорт, двухцветные и рваные-модные, ботфорты | Подвязка только как лента-шнуровка самого чулка или от костюма |
| **SSR** «витрина» | Кружево разных цветов с объёмным элементом, вышивка металлом богини, жаккард, свечение, голо-латекс, доспех, асимметрия | У каждого SSR есть **живой элемент**: кость украшения ниже колена, шейдер (блеск, свечение, переливы) или видео-жест. Список в §5 |

Это совместимо с HEROINES §3 и ART_DIRECTION стр. 132 («площадь кожи с редкостью не растёт»), если владелец одной строкой синхронизирует их с ROSTER §1.2 (решение №7 в §8).

### 1.5 Сборки

| | RuStore / APK 18+ | Google Play 17+ (база) | Яндекс Игры (веб) |
|---|---|---|---|
| Легвир в арте | Каталог §3, колонка APK | Как APK, кроме `18+`-ассетов | **Только Я-фраза:** плотные колготки (`opaque … tights`), без узора выше щиколотки |
| Кадр | Полный, плюс «В рост» (§2) | Полный | `alt_rect` по пояс; ноги видны только там, где Яндекс показывает полный арт (раскрытие, альбом) |
| Жесты | `все`, `все↑` полностью, `18+` | `все`, `все↑` ×0,6 | `все` без пометки [ноги]; `все↑` ×0,6 |
| Слова в промпте | `stockings`, `garter strap from …`, `fishnet`, `ripped` разрешены по каталогу | — | Запрещены: `stockings`, `garter`, `fishnet`, `ripped`, `thigh-high`, `over-the-knee`, `latex`, `sheer`, `mid-thigh`, `barefoot` |

- **Яндекс — это сборка, а не флаг.** `18+`-видео, поза `allure` и все спрайты с тегами `bold` или `legwear_apk` не попадают в веб-пакет даже за `bold_ok()`: модерация смотрит ассеты. Нужен фильтр при экспорте и проверка в `--rig_selftest` (§6).
- Я-фраза в каталоге написана целиком: «…» и «то же» не используем, иначе генератор подтянет `sheer` и `mid-thigh` из APK-фразы.

### 1.6 Хвосты промпта

**LEG_TAIL (APK, ко всем фразам ног):**
```
legwear fits smoothly and stays exactly in place, top band at mid-thigh at most, skirt hem and slit unchanged, no fabric damage above the knee
```
**SHEER_TAIL (APK, если в фразе есть `sheer`):**
```
realistic sheer denier shading darker toward the leg contours, a soft specular sheen line along the shin and knee
```
**GLOSS_TAIL (APK, LW32 и любой латекс):**
```
high-gloss reflections that follow the leg curve
```
**V4_TAIL для APK:** в V4_TAIL (`ROSTER_20.md` §2.1) `fully opaque fabric` заменяется на
```
fully opaque fabric on the bodice, hips and skirt; sheerness only on the legwear
```
В Яндекс-сборке V4_TAIL остаётся как есть (`fully opaque fabric`).

**Негатив APK** (вместо Яндекс-негатива HEROINES стр. 246, из которого убираются `thigh-high, lace top, garter, zettai ryouiki`):
```
garter belt, lingerie, panties, upskirt, crotch focus, camera below the hem, rips above the knee, inner-thigh rips, clothing tearing, see-through bodice, wet fabric, school uniform, loafers, Mary Janes, frilly ankle socks, childlike proportions, text
```
**Видео-хвост APK** (POSES_HOT §2.7, только APK): `…; face, outfit, neckline, hem, slit, stockings and garter straps stay exactly the same; …`. Для Яндекса тот же хвост без `stockings and garter straps`.

**Если фильтр Higgsfield режет кадр:** заменить `garter strap` на `ribbon at the stocking top`, позу поставить стоя. Это только смягчение. Повторный блок — сигнал убавить кадр, а не переформулировать тот же.

---

## 2. Кадр: где ноги видны

Кадр по UX §8.1 зависит от симпатии: 0–2 от колен, 3–5 от середины бедра, 6–8 по пояс. Если ничего не менять, чем выше симпатия, тем меньше видно ног. Решение:

1. **Главный признак — в зоне колено → середина бедра** (§1.3 п. 2). Его видно на плане «от колен».
2. **Переключатель «В рост»** на главной (APK 18+, симпатия ≥ 3, по умолчанию выключен, в Яндексе его нет). Наезд на лицо остаётся отдельным жестом. *Решение владельца №1.*
3. **Поза `allure` (POSES_HOT §6) — полноростовая сцена** в Альбоме и в режиме «В рост» при симпатии ≥ 6, камера на уровне глаз. Это не живой HUD-кадр: тап-реакции и частицы к ней не применяются. План «от середины бедра» для `allure` отменён.
4. **Тег кадра у каждого ножного жеста** (поле `framing` в `gestures.json`):
   - `knee` — играет на плане «от колен» и шире;
   - `thigh` — играет и на «от середины бедра»;
   - `full` — только в «В рост», `allure`, выборе наряда, галерее, раскрытии гачи, победе и ульте.
5. **Пока двигаются ноги, камера стоит** (POSES_HOT §2.2): `zoom ≤ 0`, `cam_y ≤ 0`, `cam_x = 0`.
6. **Норма:** у каждой богини не меньше двух ножных движений, которые видны на плане «от колен» (`leg_idle` и `sheen_sweep` есть у всех, плюс хотя бы один свой), и свои жесты стоп с тегом `full`.

---

## 3. Каталог: 87 нарядов, 87 разных образов

Формат: **код · наряд (ранг) · «RU» / EN** — что это. **Показ:** механизм. **Видно:** слот POSES. **Живое:** кость (ниже колена), шейдер или «—».
`APK` — EN-фраза для ТЕЛА промпта (к ней добавляются LEG_TAIL и, где нужно, SHEER_TAIL). `Я` — фраза Яндекс-сборки.

### 3.1 Каталог по богиням

#### mc — Маджонг-тян (сакура, нефрит; металл — нефрит)

- **LW01 · o_base (A) · «Сакуровый след» / Sakura Trail.** Розово-телесные чулки с блеском, лепестки собраны у колена. Показ: колено в боковых разрезах. Видно: `select`, `tease`. Живое: блик.
  APK: `sheer blush-pink 20-denier stockings with a visible satin sheen and small embroidered sakura petals clustered just above and below the knee, thinning toward the ankle, tops hidden under the cheongsam hem`
  Я: `opaque blush-pink tights, pink pumps`
- **LW02 · o_cafe (S) · «Сакуровый бант» / Sakura Bow.** Айвори-чулки, сакуровое кружево по верху, атласный бант у внешней стороны колена. Шов отдан Рин. Показ: бант у колена; верх виден, если юбку кафе поднять выше колена (*решение владельца №2*). Видно: `idle`. Живое: хвосты банта (кость).
  APK: `ivory sheer thigh-high stockings with a narrow sakura-pink lace top band and a sakura-pink satin bow with trailing tails tied at the outer side of each knee, top band a hand-width below the café skirt hem`
  Я: `opaque ivory tights, pink low heels`
- **LW03 · o_cozy (S) · «Розовая полоска» / Pin-Stripe Lounge.** Домашние кремовые гольфы выше колена в розовую полоску с кружевной оборкой. Показ: абсолютная зона под свитером-платьем. Видно: `shy`. Живое: блик.
  APK: `cream lounge thigh-high socks with thin sakura-pink horizontal pin-stripes and a soft lace frill at the top band, slightly slouched at the ankle, fluffy indoor slippers`
  Я: `cream knee-high socks with pink pin-stripes over opaque cream tights, fluffy indoor slippers`
- **LW04 · o_tutor (S, скрыт) · «Лекторий» / Lecture Graphite.** Плотные графитовые колготки. Наставнический наряд без сексуальной подачи: все жесты `18+` и `все↑` для него запрещены (`outfits_deny`). Показ: нет.
  APK: `plain opaque graphite 80-denier tights, low pumps`
  Я: `plain opaque graphite tights, low pumps`
- **LW05 · o_dragon (SSR) · «Драконья чешуя» / Dragon-Scale Jacquard.** Её единственный SSR «кружево в разрезе». Нефритовые чулки, золотая чешуя поднимается от колена и гуще всего у верха. Показ: разрез. Видно: `select`, «взгляд через плечо» выше талии. Живое: блик по чешуе.
  APK: `sheer jade-green stockings with a woven gold dragon-scale jacquard rising from the knee and densest at the top band, a gold Chinese-knot guipure band at mid-thigh showing in the side slit, only the end clip of a gold garter strap from the gown's corset visible at the band, gold-tipped heels`
  Я: `opaque jade-green tights, gold heels`
- **LW06 · o_grand (SSR) · «Четыре ветра» / Four Winds.** Канон — брюки костюма-тройки, ноги закрыты: шёлковые носки с нефритовыми пряжками у щиколотки. Витрина через крой и позу. Вариант Б (*решение владельца №3*): фрак с шортами, чёрные чулки с нефритовым лампасом и широкой нефритовой резинкой. Живое: кисть пряжки (кость, вариант Б — нет).
  APK (канон): `ivory silk dress socks with jade-green ankle bands and small jade buckles, four embroidered wind-swirl motifs at the ankle bone, below cuffed white suit trousers, white-and-jade spectator heels`
  APK (вариант Б): `white tailcoat with high-waisted tailored shorts, sheer black thigh-high stockings with a jade-green outer side stripe, a wide jade satin top band with a jade four-winds buckle on the outer side at mid-thigh, white spats over black patent pumps`
  Я: `opaque ivory socks with jade-green ankle bands, white-and-jade heels`
- **LW07 · o_vow (SSR) · «Пион рассвета» / Dawn Peony Panel.** Кружевная панель с пионами поднимается по внешней стороне от колена в разрез, сквозь кружево пропущена розовая лента, завязанная у колена. Свадебной подвязки нет. Показ: панель по ноге. Видно: `tease`. Живое: хвосты ленты у колена (кость).
  APK: `ivory sheer stockings with a pearl-white peony lace panel climbing the outer side of the leg from the knee up into the cheongsam slit, a pale-pink silk ribbon woven through the lace and tied in a small jade knot at the outer knee, ivory satin heels`
  Я: `opaque ivory tights, ivory satin heels`

#### rin — Рин (чай; металл — нефрит)

- **LW08 · r_base (A) · «Чайный лист» / Tea-Leaf Smoke.** Дымчатые чулки, нефритовая веточка чая у колена. Показ: колено под юбкой-карандаш. Видно: `select`. Живое: блик.
  APK: `sheer smoke-grey 20-denier stockings with a soft satin sheen and an embroidered jade tea-leaf sprig on the outer side just below each knee, tops hidden under the pencil skirt`
  Я: `opaque smoke-grey tights, low heels`
- **LW09 · r_maid (S) · «Викторианская горничная» / Victorian Frill.** Без подвязок (канон). Белая викторианская рюша под коленом, ряд агатовых пуговок по **внешней** стороне икры. Показ: рюша у колена под подолом миди. Видно: `high-pour` (`select`). Живое: —.
  APK: `sheer black stockings with a white frilled Victorian lace band just below the knee and a row of small jet buttons up the outer side of each calf, black button-strap ankle boots, below the mid-calf maid dress`
  Я: `opaque black tights, black button-strap ankle boots`
- **LW10 · r_after (S) · «Бармен» / Bar Fishnet.** Тонкая барная сетка (ячейка ≥ 6 px) и узкий фестон, атласный бант на щиколотке сзади. Показ: край кружева на палец ниже подола футляра, когда сидит. Видно: `idle` (высокий табурет). Живое: хвосты банта (кость).
  APK: `fine black fishnet stockings with a narrow black scalloped lace top band, a black satin bow with short tails at the back of each ankle, black patent stilettos`
  Я: `opaque black tights, black heels`
- **LW11 · r_yukata (S) · «Нефритовый карп» / Closed Yukata.** Ноги закрыты: юката до щиколотки, витрина — затылок и оби. Таби и гэта отданы Цубамэ и Цуру. Живое: —.
  APK: `the yukata closed to the ankle, low lacquered zori with jade-green straps`
  Я: `the yukata closed to the ankle, low lacquered zori`
- **LW12 · r_agent (SSR) · «Агент под неоном» / Neon Seam Agent.** Единственный в игре шов сзади. Глянцевые чёрные чулки, нефритовый шов, пятка-«замочная скважина». Показ: шов вдоль икры в 3/4. Видно: стоя в 3/4. Живое: `sheen_sweep` по шву.
  APK: `glossy black sheer stockings with a jade-green back seam visible along the calf and the back of the knee in three-quarter view, ending in a keyhole-shaped heel, black stilettos`
  Я: `opaque black tights, black heels`
- **LW13 · r_idol (SSR) · «Джазовые горошины» / Velvet Dot Diva.** Её SSR «верх в разрезе». Крупный бархатный горох 1 см, бархатная резинка в боковом разрезе миди (*уточнение канона: боковой разрез*). Показ: разрез. Живое: бант на щиколотке (кость).
  APK: `sheer black stockings with large 1 cm velvet polka dots, a black velvet top band at mid-thigh in the midi dress's side slit, a jade-green velvet bow at the back of each ankle, peep-toe heels`
  Я: `opaque black tights, peep-toe heels`
- **LW14 · r_jade (SSR) · «Тушь и бамбук» / Sumi-e Bamboo.** Селадоновые чулки, роспись тушью — бамбук поднимается от щиколотки выше колена. Показ: принт по ноге в разрезе ханьфу. Живое: нефритовый браслет-анклет (кость).
  APK: `pale celadon sheer stockings with a hand-painted sumi-e bamboo ink-wash print climbing from the ankle to above the knee, a carved jade bangle worn as an anklet, embroidered silk shoes`
  Я: `opaque celadon tights, embroidered silk shoes`

#### hana — Хана (солнце; металл — янтарь)

- **LW15 · h_base (A) · «Спринт-полоса» / Sprint Stripe.** Канон.
  APK: `sheer black athletic tights with a matte finish and a bright orange stripe down each outer side, under high-waisted running shorts, white-orange sneakers`
  Я: `opaque black leggings with an orange side stripe, white-orange sneakers`
  Показ: силуэт под шортами. Видно: `idle`. Живое: блик.
- **LW16 · h_street (S) · «Граффити на одной ноге» / Graffiti One-Leg.** Асимметрия, второй проход. *Уточнение канона: карго укорочены до шорт.* Показ: асимметрия. Видно: `select`. Живое: —.
  APK: `black opaque tights with a bold sunflower-yellow spray-paint graffiti swirl printed up the left leg only, from the ankle to above the knee, white slouchy crew socks pushed down over chunky sneakers, below cropped cargo shorts`
  Я: `opaque black tights, white slouchy socks, chunky sneakers`
- **LW17 · h_beach (S) · «Кинезио» / Kinesio Tape.** Подсолнух отдан LW20. В APK кадр в рост. Показ: ярко-оранжевый тейп крест-накрест на колене. Живое: напульсник —.
  APK: `bare legs with bright orange kinesiology tape crossing the right knee, a white terry sweatband on the left ankle, barefoot on the sand`
  Я: `cropped above the waist, legs out of frame`
- **LW18 · h_winter (S) · «Гетры» / Leg Warmers.** Коньки отданы Сигрид (зима и лёд — её). Показ: гетры до колена, контраст. Живое: —.
  APK: `ribbed orange-and-navy leg warmers bunched from the ankle to just below the knee over sheer black tights, white winter sneakers with orange laces`
  Я: `ribbed orange-and-navy leg warmers over opaque black tights, white winter sneakers`
- **LW19 · h_gym (S) · «Чемпионские гольфы» / Champion Over-Knees.** Её главный образ: абсолютная зона. Показ: зона под шортами. Видно: `idle`, `select`. Живое: жест `ha.sock_pullup`.
  APK: `white over-the-knee athletic socks with two bold orange stripes at the top band and a small embroidered orange star on the outer side above the knee, a palm-width of bare thigh below short running shorts, white-orange trainers`
  Я: `white knee-high socks with orange stripes over opaque black tights, white-orange trainers`
- **LW20 · h_gala (SSR) · «Подсолнечное кружево» / Sunflower Lace Gala.** Её SSR «кружево в разрезе». Медово-янтарная основа, оранжевое кружево-лепестки, янтарный блеск на голенях. *Уточнение канона: боковой разрез.* Живое: блеск (шейдер), жест `ha.heel_wobble`.
  APK: `sheer honey-amber stockings with a visible satin sheen, a deep-orange sunflower-petal lace top band at mid-thigh in the gown's side slit, fine amber shimmer on the shins, amber ankle-strap heels`
  Я: `opaque honey-beige tights, ankle-strap heels`
- **LW21 · h_lantern (SSR) · «Хикяку» / Runner Wraps.** Канон закрыт. Вариант (*решение владельца №4*): комбинезон-шорты. Таби отданы Цубамэ. Показ: стёганые обмотки. Живое: концы шнуров ниже колена (кость).
  APK: `orange-red quilted kyahan shin guards tied with white cords whose ends hang loose, over the closed jumpsuit legs, white canvas runner's boots with orange laces`
  Я: `orange-red quilted shin guards over the closed jumpsuit legs, white canvas boots`

#### yue — Юэ (луна; металл — серебро)

Полумесяц остаётся только в базе (LW22) и в доспехе (LW26).

- **LW22 · y_base (S) · «Лунное серебро» / Crescent Silver Lace.** Канон.
  APK: `sheer white stockings with silver lace top bands woven with small crescent moons at mid-thigh in the hanfu's high side slit, silver embroidered slippers`
  Я: `opaque white tights, silver slippers`
  Показ: разрез (S). Видно: `idle`. Живое: блик.
- **LW23 · y_duel (SSR) · «Ботфорт и заклёпки» / Over-Boot Studs.** Её главный образ на баннер. Ботфорт чуть выше колена, полоса чулка на ладонь выше, атласная резинка с круглыми серебряными заклёпками. Показ: ботфорт + полоса чулка. Видно: `select`. Живое: блик по голенищу.
  APK: `black over-the-knee boots ending just above the knee, sheer black stockings showing a hand-width above the boot tops, a black satin top band studded with small round silver studs at mid-thigh in the qipao side slit`
  Я: `opaque black tights, tall black riding boots to just above the knee`
- **LW24 · y_queen (SSR) · «Созвездие» / Constellation Map.** Её SSR «кружево в разрезе», отсылка к ульте «Затмение». Серебряные звёзды, гуще от колена вверх. От серебряной цепочки лифа видна только застёжка у резинки. Видно: `select` `water-sleeve-spiral` (стоп-кадр поворота). Живое: —, цепочка только follow-through ≤ 3 px.
  APK: `sheer midnight-violet stockings embroidered with silver stars joined by fine constellation lines, densest from the knee up, a black Chantilly lace top band at mid-thigh in the high slit, only the end clip of a fine silver chain from the bodice visible at the band, silver slippers`
  Я: `opaque midnight-violet tights, silver slippers`
- **LW25 · y_ball (SSR) · «Лунная пыль» / Moon-Dust Sparkle.** Жемчужно-серые, серебряная пыль от колена вверх. Шва нет. Показ: блеск по ноге в разрезе бального платья. Живое: шейдер-мерцание (серо-серебряное, не путать с ледяным блеском Сигрид).
  APK: `sheer pearl-grey stockings with fine silver moon-dust sparkle rising from the knee up, a pale satin sheen, silver heels`
  Я: `opaque pearl-grey tights, silver heels`
- **LW26 · y_dragon (SSR) · «Лунные поножи» / Moon Greaves.** Доспех. Показ: поножи + полоса чулка до разреза. Живое: блик по перламутру.
  APK: `pearlescent lilac armored greaves with crescent-shaped knee cops and silver filigree over sheer lavender stockings that show between the greave tops and the slit at mid-thigh, pointed armored sabatons`
  Я: `opaque lavender tights, armored greaves, slit closed`
- **LW27 · y_city (SSR) · «Фазы луны» / Moon-Phase Print.** Лавандово-серая основа, крупный принт фаз луны (диск размером с ладонь) по внешней стороне. Вариант (*решение владельца №5*): миди с боковым разрезом. Показ: принт по всей ноге. Живое: —.
  APK: `sheer lavender-grey tights with a bold large-scale moon-phase print, each disc palm-sized, running down the outer side of the leg, glossy black heeled ankle boots`
  Я: `opaque lavender-grey tights, black heeled ankle boots`

#### nova — Нова (неон, данные)

- **LW28 · n_base (S) · «Двухцветный надрез» / Two-Tone Laser Slash.** Рваный образ. Левая нога чёрная, правая неоново-голубая, лазерные прорези на коленях и голенях. *Уточнение канона: ботфорты → платформы до середины икры, иначе прорезей не видно.* Показ: двухцвет + колени. Видно: `select`. Живое: жест `nv.slash_poke`.
  APK: `two-tone techwear tights, left leg black and right leg neon cyan, clean laser-cut horizontal slashes across both knees and shins showing a black mesh layer underneath (distressed by design, worn that way), nothing cut above the knee or on the inner side, chunky platform combat boots to mid-calf, under the utility skirt`
  Я: `opaque black tights, chunky platform boots`
- **LW29 · n_ssr (SSR) · «Гоночный кант» / LED Racer.** Глянцевый комбинезон, LED-кант пульсирует в такт, ремень с чип-кобурой на бедре поверх костюма. Показ: кобура на бедре. Живое: шейдер-пульс канта.
  APK: `glossy latex-sheen racing jumpsuit legs with neon-pink LED piping down both outer seams, a black thigh strap with a small data-chip holster on the right thigh over the suit, reflective silver ankle gaiters over moto boots`
  Я: `matte racing jumpsuit legs with pink piping, moto boots`
- **LW30 · n_offline (SSR) · «Пастельный офлайн» / Pastel Gradient Over-Knees.** Гэп-моэ: мягкость вместо открытости. Верх гольф чуть выше колена и спрятан под подолом, кожи нет. Лоферы убраны (школьный код). Показ: вязка + градиент. Живое: —.
  APK: `soft fluffy knit over-the-knee socks fading from pale cyan at the toes to pastel pink at the top, slightly slouched, sock tops just above the knee and hidden under the knee-length dress hem, knit slipper-boots`
  Я: `pastel knit knee-high socks over opaque white tights, knit slipper-boots`
- **LW31 · n_root (SSR) · «Печатная плата» / Circuit Trace.** Свечение, в лихорадке ×1,6. Показ: свечение. Живое: шейдер.
  APK: `sheer black stockings with glowing cyan circuit-trace lines running up the leg, brightest at the nodes around the knee, tops hidden under the high-collared sheath dress, black heels`
  Я: `opaque black tights, black heels`
- **LW32 · n_diva (SSR) · «Асимметрия» / Holo-Latex Asymmetric.** Её главный образ, перекличка с асимметричной стрижкой. Слева голо-латекс до бедра, справа глянцевый чёрный гольф выше колена; O-кольцо только на ремешке ботинка. Второй проход. Показ: асимметрия. Живое: шейдер-перелив ×2.
  APK: `asymmetric legwear: left leg in an iridescent holographic latex thigh-high stocking-boot with a pink-cyan oil-slick sheen, right leg in a glossy black over-the-knee sock with a black ankle boot whose strap has a chrome O-ring, both below the dress hem`
  Я: `both legs in opaque black tights with matching black boots`

#### tsubame — Цубамэ (тень; без металла)

Сетка отдана Хибане и Рин. Таби-сапожки остаются только у Цубамэ.

- **LW33 · tb_base (A) · «Ласточка» / Swallow Print.** Один крупный алый силуэт ласточки над правым коленом, алый шнур на щиколотке. Показ: принт у колена. Видно: `idle`. Живое: концы шнура (кость).
  APK: `sheer black stockings with one large crimson swallow silhouette printed on the outer side just above the right knee, a crimson cord wrapped twice around the right ankle with loose ends, black split-toe tabi boots, tops hidden under the short kimono dress`
  Я: `opaque black tights, black split-toe tabi boots`
- **LW34 · tb_post (S) · «Лента почтальона» / Courier Side-Lacing.** Лучшая лента ростера. Алая лента крест-накрест по внешней стороне, плоский бант у резинки (без свободных концов), второй бант с хвостами на щиколотке. Показ: шнуровка + разрез. Живое: хвосты банта на щиколотке (кость).
  APK: `white sheer thigh-high stockings with a crimson satin ribbon criss-cross laced up the outer side from the ankle to the top band, tied in a small flat bow at the band at mid-thigh in the courier dress slit, a second crimson bow with trailing tails at the ankle`
  Я: `opaque white tights with a crimson ribbon wrapped at the ankle, black tabi boots`
- **LW35 · tb_crimson (SSR) · «Сасико клана» / Sashiko Clan Mark.** Рваный образ и её SSR «кружево в разрезе». Прорези на коленях и голенях заштопаны крупными алыми крестиками сасико — знак клана. Видно: `select`. Живое: жест `tb.sashiko_touch`.
  APK: `sheer black stockings with a few deliberate slashes across the knees and shins darned with bold crimson sashiko cross-stitches (a clan mark, distressed by design, worn that way), nothing torn above the knee or on the inner side, a black plum-blossom lace top band at mid-thigh in the high slit, only the end clip of a crimson garter strap from the corset belt visible at the band, black tabi boots`
  Я: `opaque black tights, black tabi boots`

#### miel — Миэль (сахар; без металла, карамель)

Гингем остаётся на фартуке, не на ногах. Клубнички, мэри-джейн и «спадающая туфелька в статике» убраны.

- **LW36 · me_base (A) · «Карамельная лента» / Caramel Ribbon.** Карамельные гольфы выше колена, кремовая лента в люверсах. Показ: узкая полоска кожи под фартуком-юбкой. Видно: `select` (через прилавок — в «В рост»). Живое: хвосты банта (follow-through), жест `me.sock_pullup`.
  APK: `caramel-brown over-the-knee socks with a cream satin ribbon threaded through eyelets at the top band and tied in a small bow on the outer side, a small embroidered whisk on the outer ankle, a narrow strip of skin below the apron-skirt hem, cherry-red lacquer heels`
  Я: `caramel knee-high socks over opaque cream tights, red heels`
- **LW37 · me_parlor (S) · «Медовые соты» / Dripping Honey.** Крупные соты (ячейка с подушечку пальца), кружево-«капли мёда». Показ: верх у подола. Живое: —.
  APK: `cream sheer stockings with a bold honeycomb weave, each cell the size of a fingertip, a honey-amber lace top band scalloped like dripping honey at mid-thigh just below the dress hem, caramel T-strap heels`
  Я: `opaque cream tights, caramel T-strap heels`
- **LW38 · me_gala (SSR) · «Безе» / Meringue Ruffle.** Малиновые чулки, жемчужные пуговки по **внешнему** шву, тюлевая рюша-безе с пришитым бантом. *Уточнение канона: передний край юбки high-low выше колена.* Показ: зона под high-low. Живое: —, рюша follow-through.
  APK: `sheer raspberry-pink stockings with a row of small pearl buttons up the outer side seam, a frothy sugar-white ruffled tulle top band like meringue with a pink satin bow sewn on it, showing below the high-low front hem, pink satin heels`
  Я: `opaque raspberry-pink tights, pink satin heels`

#### lian — Лянь (струна, река; металл — коралл)

- **LW39 · li_base (A) · «Лотос» / Lotus Silk.** Цветок лотоса над коленом, стебель вьётся вниз к щиколотке. Показ: шаг в разрез в профиль. Видно: `tease`. Живое: жест `li.lotus_trace`.
  APK: `white silk stockings with a soft sheen and a pink lotus embroidered on the outer side, the bloom just above the knee and its green stem curling down to the ankle, embroidered shoes`
  Я: `opaque white tights, embroidered shoes`
- **LW40 · li_lantern (S) · «Рябь на воде» / Moonlit Ripple.** Крупный муар-рябь, коралловая линия по внешнему шву с лотосом на косточке. *Уточнение канона: боковой разрез.* Показ: разрез в профиль. Живое: шейдер-мерцание ряби.
  APK: `sheer midnight-teal stockings with a bold horizontal ripple moiré woven wide enough to read at a glance, a thin coral line down the outer side ending in a small lotus at the ankle bone, top band at mid-thigh in the side slit, black satin heels`
  Я: `opaque teal tights, black satin heels`
- **LW41 · li_concert (SSR) · «Кружево карпов» / All-Over Koi Lace.** Её главный образ. Кораллы вместо золота. Показ: кружево по всей ноге. Живое: блик.
  APK: `full-length ivory lace stockings with an all-over pattern of large swimming koi and lotus leaves in teal-tinted lace, the top band edged with small coral beads like pipa-string knots, in the concert hanfu slit at mid-thigh, coral embroidered heels`
  Я: `opaque ivory tights, coral embroidered heels`

#### jess — Джесс (пыль, закат; металл — старый никель)

- **LW42 · je_base (A) · «Пыльный тракт» / Dust-Trail Frayed.** Рваный образ: махровая манжета, заштопанная потёртость на левом колене, кожаный шнурок с подковкой на манжете. Бандана отдана Мари. Показ: колено + абсолютная зона под шортами. Живое: подковка (кость), жест `je.sock_pullup`.
  APK: `dusty brown over-the-knee socks with a frayed cuff and a small darned worn patch at the left knee (rugged style, distressed by design, worn that way), a short leather lace with a small horseshoe charm tied around the left cuff, tooled leather cowboy boots, below high-waisted denim shorts`
  Я: `brown knee-high socks over opaque tan tights, cowboy boots`
- **LW43 · je_rodeo (S) · «Звенящие шпоры» / Concho Boot Harness.** Ноги в брюках и чапсах. Живое: звон шпор (SFX), бахрома чапсов ниже колена (кость).
  APK: `tooled leather boot-harness straps with antique-nickel conchos and spur straps with small rowels on her cowboy boots, over leather trousers with fringed chaps`
  Я: `tooled leather boots with conchos over leather trousers with fringed chaps`
- **LW44 · je_star (SSR) · «Тиснёная роза» / Tooled-Rose Fringe Lace.** Её главный образ и SSR «кружево в разрезе». Короткая замшевая бахрома по краю кружева (не подвязка, не патронташ). Живое: —, бахрома follow-through.
  APK: `sheer tan stockings with a visible satin sheen, a western paisley-and-rose lace top band at mid-thigh edged with short suede fringe, in the long skirt slit, embossed cowboy boots`
  Я: `opaque tan tights, embossed boots`

#### tsuru — Цуру (пар, журавль; металл — лак)

Двупалые чулки — только у Цуру. Гэта — у Цуру и Кохаку (у Кохаку только `ko_matsuri`).

- **LW45 · tu_base (A) · «Пар над источником» / Steam-Swirl Split-Toe.** Индиго, белые завитки пара поднимаются от щиколотки к колену. Показ: колено под кимоно-платьем. Живое: блик.
  APK: `sheer dark-indigo split-toe stockings with a woven white steam-swirl pattern rising from the ankle to the knee, lacquered geta, tops hidden under the knee-length kimono dress`
  Я: `opaque indigo split-toe tights, lacquered geta`
- **LW46 · tu_pingpong (S) · «Журавлиные гольфы» / Crane Knee-Highs.** Хурма, журавли с ладонь, кружевной манжет под коленом. Юката подоткнута до колена — это состояние наряда в K, а не жест. Живое: —.
  APK: `sheer persimmon-orange knee-high stockings with white crane silhouettes each the size of a palm, a white lace cuff just below the knee, geta, the yukata tucked up to just below the knee for play, a tasuki cord tying back the sleeves`
  Я: `opaque persimmon tights, geta, the yukata worn full length`
- **LW47 · tu_snow (SSR) · «Журавлиное перо» / Crane-Feather Band.** Её SSR «кружево в разрезе»: настоящие белые пёрышки с красными кончиками, красный шнур сквозь резинку, узел мидзухики снаружи. Живое: —, перья follow-through ≤ 3 px.
  APK: `snow-white sheer stockings with a top band of small real white feathers tipped in red at mid-thigh in the ceremonial kimono's high slit, a red silk cord laced through the band and tied in a mizuhiki knot on the outer side, lacquered geta`
  Я: `opaque white tights, lacquered geta`

#### kohaku — Кохаку (лисий огонь; без металла, киноварь)

- **LW48 · ko_base (S) · «Бубенцы мико» / Bell-Bow Thigh-Highs.** Её иконка. Бубенцы перенесены с резинки на банты **под коленом**. Показ: разрезы хакамы + банты у колена. Живое: бубенцы (кость + SFX).
  APK: `white opaque thigh-high stockings with a narrow vermilion top band at mid-thigh showing in the hakama side slits, a crimson satin bow with a small round suzu bell tied at the outer side just below each knee, red-thonged zori`
  Я: `opaque white tights, red-thonged zori, hakama slits closed`
- **LW49 · ko_matsuri (A) · «Лисьи огни» / Fox-Fire Knee Socks.**
  APK: `white knee-high socks knitted with flickering orange-red fox-fire flames rising from the ankle to the cuff, red-strapped geta, below the short yukata`
  Я: `plain white knee-high socks over opaque white tights, red-strapped geta`
  Показ: колено под короткой юкатой. Живое: —.
- **LW50 · ko_kyubi (SSR) · «Офуда» / Ofuda Band.** Её SSR «верх в разрезе». Киноварь без «пламени», белая шёлковая резинка, две бумажные офуда плоско под резинкой (не качаются), кисть на щиколотке. Живое: кисть (кость), лисий огонь подсвечивает офуда (шейдер).
  APK: `sheer vermilion stockings with a white silk top band at mid-thigh in the high slit, two paper ofuda talisman strips tucked flat under the band, a white silk tassel tipped in vermilion tied at the outer ankle, black lacquered okobo`
  Я: `opaque vermilion tights, black lacquered okobo`
- **LW51 · ko_vow (SSR) · «Красная нить» / Red Thread.** Ноги закрыты, витрина через лицо, позу и «слепой дождь». Живое: красная нить (кость).
  APK: `the bridal kimono closed to the ankle, white bridal socks and zori, a single fine red thread tied in a small bow at the left ankle`
  Я: `the bridal kimono closed to the ankle, white socks and zori`

#### shirin — Ширин (песок, солнце; металл — золото)

- **LW52 · sh_base (S) · «Пайал» / Coin Payal.** Её главный образ, канон. Признак у щиколотки, поэтому витрина — в «В рост» и `select`. Показ: разрез + монеты. Живое: монеты (кость + SFX).
  APK: `bare legs with layered gold coin payal anklets hung with small bells and a fine gold chain from each anklet to a toe ring, the skirt's high slit showing the leg to mid-thigh only`
  Я: `opaque sand-beige tights with the coin anklets worn over them, slit closed`
- **LW53 · sh_oasis (A) · «Базарные манжеты» / Embroidered Cuffs.** Шаровары. Живое: цепочки (кость).
  APK: `fitted turquoise harem trousers gathered into gold-embroidered ankle cuffs, thin gold ankle chains, pointed embroidered slippers`
  Я: `fitted turquoise harem trousers with embroidered ankle cuffs, pointed slippers`
- **LW54 · sh_sun (SSR) · «Мехенди-стремя» / Henna Stirrup.** Стремя из POSES_HOT: пятка и пальцы открыты, крупный узор мехенди от подъёма стопы выше колена, филигранные манжеты на икрах. Показ: стремя + принт. Живое: манжеты (follow-through), блик.
  APK: `sheer sand-gold stirrup stockings leaving the heel and toes bare, printed with a bold henna mehndi pattern climbing from the instep to above the knee, gold filigree calf cuffs matching her arm bracers, in the layered skirt's slits`
  Я: `opaque turquoise tights, gold calf cuffs`
- **LW55 · sh_night (SSR) · «Тысяча и одна» / Star Arabesque.** Её SSR «кружево в разрезе». Звёзды гуще от колена, на кружеве плоско пришит шарм-лампа, на щиколотках манжеты с подвесками-звёздами (монеты только у LW52). Живое: подвески-звёзды (кость + SFX).
  APK: `sheer midnight-blue stockings scattered with embroidered gold stars, densest from the knee up, a gold arabesque lace top band at mid-thigh in the long slit with a small lamp-shaped charm sewn flat on the outer side, gold ankle cuffs with small dangling star pendants, gold-embroidered slippers`
  Я: `opaque midnight-blue tights, gold ankle cuffs, embroidered slippers`

#### mari — Марисоль (шторм, море; металл — латунь)

- **LW56 · ma_base (S) · «Кушак и пистолет» / Sash & Flintlock.** Кушак перенесён с бедра на голенище, кремнёвый пистолет за голенищем. Показ: ботфорты. Живое: кушак на ветру (кость).
  APK: `glossy cuffed black over-the-knee boots with brass buckles over tight leather trousers, a red silk sash knotted around the right boot shaft at mid-calf with long ends fluttering in the wind, a flintlock pistol tucked into the left boot top`
  Я: `black boots over leather trousers, a red silk sash at the waist`
- **LW57 · ma_port (A) · «Бандана» / Sailor Bandana.** Бандана под левым коленом — по-пиратски и в кадре. Ленточные эспадрильи отданы Веспер (балетные ленты). Живое: концы банданы (кость).
  APK: `bare legs, a red bandana with white dots tied around the left leg just below the knee with its ends fluttering, rope-soled espadrilles, below the linen shirt dress`
  Я: `opaque skin-tone tights, rope-soled espadrilles`
- **LW58 · ma_admiral (SSR) · «Латунный лампас» / Brass-Braid Jackboots.** Латунь вместо золота. Живое: кисть на ботфорте у колена (кость).
  APK: `fitted white breeches with a brass-braid stripe down the outer seam tucked into glossy black knee-high jackboots topped with brass braid and a small brass front tassel`
  Я: `fitted white breeches tucked into black knee-high jackboots`
- **LW59 · ma_summer (SSR) · «Морской узел» / Sailor-Knot Anklet.** В APK кадр в рост, в Яндексе по пояс. Живое: компас-шарм (кость).
  APK: `a white sailor's rope anklet tied in a reef knot with a small brass compass charm on the left ankle, barefoot on the sunny deck, the sarong knotted at the hip`
  Я: `cropped above the waist, legs out of frame`

#### hibana — Хибана (гром; без металла, лимонно-жёлтый)

- **LW60 · hi_base (S) · «Молния и подтяжки» / Zigzag Suspenders.** Её главный образ, **целый** (рваный у Хибаны только `hi_rock`). Подтяжки защёлкиваются **снаружи** на подол шорт, шорты непрозрачны. Показ: абсолютная зона. Живое: —, клипсы не качаются.
  APK: `black opaque thigh-high stockings with a bold yellow lightning-zigzag stripe down the outer side, short black elastic suspender straps clipping onto the outside of the hakama-shorts hem with yellow buckles, shorts fully opaque, a palm-width of skin between`
  Я: `opaque black tights, straw sandals`
- **LW61 · hi_fest (A) · «Шмелиная полоска» / Bumblebee Stripes.** Гэта убраны (у Цуру).
  APK: `black-and-yellow horizontal striped over-the-knee socks, slightly bunched at the ankle, below the festival shorts, black canvas sneakers with yellow laces`
  Я: `black-and-yellow striped knee-high socks over opaque black tights, black sneakers`
  Показ: полоски. Живое: жест `hi.sock_pullup`.
- **LW62 · hi_raijin (SSR) · «Грозовой разряд» / Lightning Stripe.** Её SSR «верх в разрезе». Дымчато-чёрная основа, лимонная зубчатая молния по внешней стороне до резинки. Фиолет отдан Юэ, золото убрано. Живое: шейдер-разряд, в лихорадке ×1,6.
  APK: `sheer smoke-black stockings with a jagged lemon-yellow lightning stripe running up the outer side from the ankle to the top band, a lemon-yellow lace top band at mid-thigh in the armored kimono's high slit, only the end clip of a yellow mitsudomoe garter clasp from the armored kimono belt visible at the band`
  Я: `opaque charcoal tights, black lacquered sandals`
- **LW63 · hi_rock (SSR) · «Панк-сцена» / Punk Safety-Pin Rips.** Рваный образ: панк. Сетка цела выше колена. Живое: жест `hi.rip_knee_beat`.
  APK: `black sheer tights under a wide-hole fishnet layer, punk-style rips only at the knees and shins held with steel safety pins (distressed by design, worn that way), fishnet intact above the knee, no rips on the thighs, the inner knee or under the skirt, a yellow lightning-bolt patch on the left knee, black platform boots, below the leather mini skirt`
  Я: `intact opaque black tights, black platform boots`

#### nemi — Неми (лес; без металла)

- **LW64 · ne_base (S) · «Плющ» / Ivy Vine.** Крупные листья плюща от голенища вверх до резинки. Показ: разрезы юбки из пластин. Живое: жест `ne.leaf_on_knee`.
  APK: `sheer moss-green stockings with a bold woven ivy-vine pattern climbing from the boot tops to the top band, the leaves large enough to read at a glance, top band at mid-thigh in the slits of the leather tasset skirt, soft brown knee boots`
  Я: `opaque moss-green tights, soft brown knee boots`
- **LW65 · ne_town (A) · «Кленовая вязка» / Maple Rib-Knit.**
  APK: `rust-orange ribbed knit tights with a small maple-leaf intarsia at each ankle and a larger one on the outer side above the knee, brown lace-up ankle boots`
  Я: `rust-orange ribbed opaque tights, brown lace-up ankle boots`
  Показ: колено под платьем-свитером. Живое: —.
- **LW66 · ne_spring (SSR) · «Цветущая лоза» / Blossom Vine.** Её SSR «верх»: кружево-цветы между лепестками юбки. Лоза спиралью от колена к щиколотке. Живое: листья лозы (кость), на тап по аксессуару лоза распускает цветы (анимация аксессуара).
  APK: `sheer petal-pink stockings with a lace top band of small blossoms peeking between the petal-skirt layers at mid-thigh, a slender green flowering vine spiralling from the knee down around the calf to the ankle, woven-leaf sandals`
  Я: `opaque pale-pink tights with a flowering vine around the ankle, woven-leaf sandals`
- **LW67 · ne_hunt (SSR) · «Оперённые сапоги» / Fletching Boots.** *Уточнение канона: бриджи → раздельная охотничья юбка* (бриджи в ботфортах остаются Мари). Живое: перья на голенищах (кость).
  APK: `a split hunting skirt over sheer moss stockings, tan suede knee-high boots with fletching-feather tassels at the boot tops`
  Я: `opaque moss tights, tan suede knee-high boots`

#### zlata — Злата (жар-птица; металл — золото)

- **LW68 · zl_base (SSR) · «Золотая роспись» / Gold-Thread Firebird.** Её главный образ и SSR «кружево в разрезе». Роспись гуще от колена к резинке.
  APK: `scarlet silk stockings hand-embroidered with gold-thread curling vines and berries in an original folk-painting style, densest from the knee up to the band, a gold lace top band with firebird-feather scallops at mid-thigh in the sarafan slit, red morocco heeled boots`
  Я: `opaque scarlet tights, red heeled boots`
  Видно: `select` `folk-heel-step`. Живое: искры с каблука (FX ниже колена).
- **LW69 · zl_fair (S) · «Ярмарочная вышивка» / Cross-Stitch Ribbon Ties.** Вязка остаётся у Златы. Живое: концы лент под коленом (кость).
  APK: `white knit over-the-knee stockings with red cross-stitch folk bands at the knee, tied just below the knee with red ribbon ties whose ends hang down, short red boots with fur trim`
  Я: `opaque white tights, short red boots with fur trim`
- **LW70 · zl_ember (SSR) · «Тлеющий шов» / Ember Seam.** Лаковое пламя поднимается от колена, тлеющий золотой шов по внешней стороне. Подвязки убраны (кружевной SSR у неё — LW68). Показ: свечение + принт. Живое: шейдер, в лихорадке ×1,6.
  APK: `sheer black stockings with lacquer-gold flames rising from the knee up to a plain black band at mid-thigh in the high slit, a glowing ember-gold seam line down the outer side, black satin heels`
  Я: `opaque black tights, black satin heels`
- **LW71 · zl_vow (SSR) · «Кокошник» / Gold-Sheen Vow.** Ноги закрыты; золотистое сияние основы, чтобы не повторять белые «Обеты». Живое: шарм-перо (кость).
  APK: `the gown closed to the ankle, warm gold-sheen sheer stockings glimpsed only at the ankle, a thin gold ribbon with a small feather charm at each ankle, white embroidered slippers`
  Я: `the gown closed to the ankle, opaque ivory tights, white slippers`

#### minamo — Минамо (жемчужное море; металл — жемчуг; полный рост по умолчанию)

- **LW72 · mi_base (SSR) · «Жемчужная пена» / Seafoam Pearl Lace.** Её SSR «кружево в разрезе». Живое: жемчужные цепочки на подъёме стопы (кость).
  APK: `sheer aqua-blue stockings with a seafoam lace top band beaded with seed pearls at mid-thigh in the high slit, strands of pearl-chain anklets looping over the instep, pearl-strap slippers`
  Я: `opaque aqua tights with pearl-chain anklets, pearl-strap slippers`
- **LW73 · mi_beach (S) · «Морское стекло» / Sea-Glass Shell Cuff.** Пляж отличается от рифа: гольфы цвета морского стекла с манжетом-ракушкой. Живое: анклет (кость).
  APK: `sheer sea-glass-green knee-high stockings with a scalloped shell-shaped cuff just below the knee, an aqua sea-glass bead anklet, flat sandals, below the sundress`
  Я: `opaque sea-green tights, flat sandals`
- **LW74 · mi_reef (SSR) · «Жемчужная вуаль» / Pearl-Net Calf Veil.** В APK в рост. Живое: жемчужная сеть (кость).
  APK: `a net of pearls draped around the right calf from the knee to the ankle like a veil, a pearl anklet on the left, bare legs below the pareo`
  Я: `cropped above the waist, legs out of frame`
- **LW75 · mi_jelly (SSR) · «Русалочья чешуя» / Mermaid Opal.** Опал с крупной чешуёй, гуще к щиколотке, ленты-щупальца. Живое: ленты (кость), волна блика по чешуе и опал в лихорадке (шейдер).
  APK: `sheer opal stockings with an iridescent fish-scale shimmer, the scales large enough to read and denser toward the ankle like a mermaid tail, long translucent ribbon streamers tied at the ankles drifting like jellyfish tentacles, pearl heels, tops hidden under the gown`
  Я: `opaque pearl-white tights, pearl heels`

#### kira — Кира (сталь; без металла, красно-белое)

- **LW76 · ki_base (SSR) · «Кобура на бедре» / Thigh-Holster Harness.** Канон, поверх комбинезона. Живое: —, кобура не качается.
  APK: `a white-and-red armored thigh harness with a sidearm holster strapped around the right thigh over the pilot suit, red buckles, armored knee boots`
  Я: `a holster on the hip belt over the pilot suit, armored knee boots`
- **LW77 · ki_off (S) · «Тактические D-кольца» / Tactical D-Ring Slits.** Рваный образ: олива, прорези на коленях стянуты D-кольцами, одна короткая стрелка на левой голени. Нашивка-хризантема — на бомбере. Камера на уровне глаз, без поднятого колена. Живое: блик по D-кольцам.
  APK: `olive-drab opaque tights with two short vertical slit cut-outs at each knee bridged by small metal D-rings (tactical fashion, worn that way), one short ladder run on the left shin that starts and ends between the knee and the ankle, nothing cut above the knee or on the inner side, laced ankle booties, below the mini skirt`
  Я: `intact opaque olive tights, laced ankle booties`
- **LW78 · ki_dress (SSR) · «Парадный лампас» / Parade Stripe.** Её SSR «кружево в разрезе». Красный лампас по внешнему шву, белое кружево с красными хризантемами; от подвязки кителя видна только застёжка. Живое: блик.
  APK: `white sheer stockings with a red military stripe down the outer side, a white lace top band with red chrysanthemum motifs at mid-thigh in the pencil-skirt slit, only the end clip of a red garter strap from the uniform tunic visible at the band, white heels`
  Я: `opaque white tights, white heels`
- **LW79 · ki_stealth (SSR) · «Гекс-броня» / Hex Armor.** Свечения на ногах нет (оно у Новы), светятся только дюзы на пятках. Живое: шейдер дюз, в лихорадке ×1,6.
  APK: `matte black armored stealth-suit legs with dark-red hexagonal panel lines, armored knee-high stealth boots with small glowing thruster vents at the heels`
  Я: `matte black armored stealth suit, knee-high stealth boots`

#### vesper — Веспер (алая ночь; металл — рубин)

- **LW80 · ve_base (SSR) · «Кровавая роза» / Blood-Rose Chantilly.** Канон, её SSR «кружево в разрезе». Видна только концевая застёжка подвязки от корсажа. Живое: —.
  APK: `sheer black stockings with a deep blood-red rose Chantilly lace top band at mid-thigh in the high slit, only the end clips of black satin garter straps from the corset with small ruby-rose clasps visible at the band, pointed black heeled boots`
  Я: `opaque black tights, pointed black boots`
- **LW81 · ve_day (S) · «Балетные ленты» / Pointe Ribbons.** Гэп-моэ «днём». Носочки с рюшей и мэри-джейн из POSES_HOT отменены (детский код). Живое: хвосты бантов (кость).
  APK: `sheer ivory ballet tights with a soft sheen, black satin ribbons criss-crossing from black ballet flats up to mid-calf like pointe-shoe ribbons, tied in a neat bow with short tails at the back, below the high-collared summer dress`
  Я: `opaque ivory tights with black ankle ribbons, black ballet flats`
- **LW82 · ve_ball (SSR) · «Бархатный дамаск» / Flocked Damask & Calf Lacing.** Шнуровка по икре из POSES_HOT. Вариант (*решение владельца №6*): перёд бального платья каскадом открывается ниже колена; без него образ виден только у щиколотки в реверансе (руки на подол не кладёт, юбка не выше щиколотки). Живое: шарм-мышь (кость).
  APK: `sheer bordeaux stockings with a bold flocked black velvet damask pattern and crimson ribbon lacing up the back of each calf, a thin black velvet ribbon around each ankle with a small ruby bat charm, black lace-up heeled boots`
  APK (вариант): `+ the ball gown's front cascades open below the knee`
  Я: `opaque bordeaux tights, black heeled boots`
- **LW83 · ve_vow (SSR) · «Гранатовая клятва» / Gothic Bride.** Канон «тёмно-алое с белым» → готическая невеста: короткий передний разрез **по подолу** показывает ноги от колена вниз. Живое: —.
  APK: `the dark-crimson-and-white gown's short front split at the hem shows the legs from the knee down: white sheer stockings with black Chantilly lace climbing the shins and a garnet-red velvet bow at each ankle, black heels`
  Я: `opaque white tights, black heels`

#### sigrid — Сигрид (иней; металл — серебро; полный рост по умолчанию)

- **LW84 · si_base (SSR) · «Иней и звёздная пыль» / Frost Glitter.** Её главный образ и SSR «кружево в разрезе». Живое: шейдер-блёстки, в лихорадке ×1,6.
  APK: `sheer white stockings dusted with fine silver-blue glitter that sparkles like frost, densest from the knee up, a frost-crystal lace top band at mid-thigh in the slit, tall white heeled boots`
  Я: `opaque white tights, tall white boots`
- **LW85 · si_newyear (S) · «Карамельная трость» / Candy-Cane Spiral.** Вязка отдана Злате. Живое: меховые манжеты (follow-through).
  APK: `sheer ice-red stockings with a white candy-cane spiral stripe and white fur cuffs just below the knee, under the fur-trimmed coat-dress, fur-trimmed boots`
  Я: `opaque red tights, fur-trimmed boots`
- **LW86 · si_summer (SSR) · «Таю!» / Melting Icicles.** Живое: шейдер-капли.
  APK: `ice-blue sheer knee-high stockings with a lace cuff just below the knee shaped like melting icicles with clear crystal droplets, white strappy sandals`
  Я: `opaque pale-blue tights, white sandals`
- **LW87 · si_throne (SSR) · «Полярное сияние» / Aurora Iridescent.** Вариант (*решение владельца №6*): нижняя панель платья от колена — ледяной тюль. Живое: шейдер-перелив.
  APK: `aurora-iridescent sheer stockings shifting from green to violet, crystal-rhinestone ankle cuffs, clear ice-crystal heels`
  APK (вариант): `+ the crystal gown's sheer ice-tulle lower panel from the knee down reveals the stockings`
  Я: `opaque silver-white tights with crystal ankle cuffs`

### 3.2 Сводная таблица (87 нарядов, 87 образов)

| Богиня | A | S | SSR |
|---|---|---|---|
| mc | o_base LW01 | o_cafe LW02, o_cozy LW03, o_tutor LW04 | o_dragon LW05, o_grand LW06, o_vow LW07 |
| rin | r_base LW08 | r_maid LW09, r_after LW10, r_yukata LW11 | r_agent LW12, r_idol LW13, r_jade LW14 |
| hana | h_base LW15 | h_street LW16, h_beach LW17, h_winter LW18, h_gym LW19 | h_gala LW20, h_lantern LW21 |
| yue | — | y_base LW22 | y_duel LW23, y_queen LW24, y_ball LW25, y_dragon LW26, y_city LW27 |
| nova | — | n_base LW28 | n_ssr LW29, n_offline LW30, n_root LW31, n_diva LW32 |
| tsubame | tb_base LW33 | tb_post LW34 | tb_crimson LW35 |
| miel | me_base LW36 | me_parlor LW37 | me_gala LW38 |
| lian | li_base LW39 | li_lantern LW40 | li_concert LW41 |
| jess | je_base LW42 | je_rodeo LW43 | je_star LW44 |
| tsuru | tu_base LW45 | tu_pingpong LW46 | tu_snow LW47 |
| kohaku | ko_matsuri LW49 | ko_base LW48 | ko_kyubi LW50, ko_vow LW51 |
| shirin | sh_oasis LW53 | sh_base LW52 | sh_sun LW54, sh_night LW55 |
| mari | ma_port LW57 | ma_base LW56 | ma_admiral LW58, ma_summer LW59 |
| hibana | hi_fest LW61 | hi_base LW60 | hi_raijin LW62, hi_rock LW63 |
| nemi | ne_town LW65 | ne_base LW64 | ne_spring LW66, ne_hunt LW67 |
| zlata | — | zl_fair LW69 | zl_base LW68, zl_ember LW70, zl_vow LW71 |
| minamo | — | mi_beach LW73 | mi_base LW72, mi_reef LW74, mi_jelly LW75 |
| kira | — | ki_off LW77 | ki_base LW76, ki_dress LW78, ki_stealth LW79 |
| vesper | — | ve_day LW81 | ve_base LW80, ve_ball LW82, ve_vow LW83 |
| sigrid | — | si_newyear LW85 | si_base LW84, si_summer LW86, si_throne LW87 |

**Рваные (5, все разные, только колени и голени, во всех кадрах наряда):** LW28 Нова — двухцвет и лазерные прорези; LW35 Цубамэ — штопка сасико как знак клана; LW42 Джесс — рабочая потёртость со штопкой; LW63 Хибана — панк с сеткой и булавками; LW77 Кира — олива и D-кольца. В Яндексе у всех целые плотные колготки.

**«Ноги закрыты, витрина через крой, лицо и позу»:** LW06 (канон), LW11, LW21 (канон), LW43, LW51, LW53, LW71; LW29, LW76, LW79 и LW58 — костюм и аксессуар на ноге. Варианты открытия ног — решения владельца №3–6.

**Уточнения канона, без которых чулок не виден:** h_street (карго → шорты), me_gala (юбка high-low), n_base (ботфорты → платформы до икры), ne_hunt (бриджи → раздельная юбка), боковые разрезы у h_gala, li_lantern и r_idol, юбка кафе выше колена у o_cafe (решение №2).

### 3.3 Индекс по силуэту (длина × слой × механизм показа)

Вместо 40 «семейств» v1 — 14 различимых на миниатюре классов. Мотивы (созвездие, соты, муар) — это деталь, а не стиль.

| # | Класс | Образы |
|---|---|---|
| 1 | Кружевной верх в разрезе (одна на богиню, разные цвета и объём) | LW05, 13, 20, 24, 35, 41, 44, 47, 50, 55, 62, 66, 68, 72, 78, 80, 84 |
| 2 | Чулок выше колена с абсолютной зоной под мини или шортами | LW02, 03, 19, 36, 37, 38, 42, 60 |
| 3 | Ботфорт или высокий сапог + полоса чулка или бриджи | LW23, 56, 58, 64, 67 |
| 4 | Принт или вышивка по всей ноге | LW01, 08, 14, 16, 27, 33, 39, 45, 54, 70, 82 |
| 5 | Двухцвет и асимметрия | LW16, 28, 32 |
| 6 | Шов и лампас | LW12 (сзади), 40, 70, 78 (по внешнему шву) |
| 7 | Шнуровка лентой по ноге | LW34, 81, 82 |
| 8 | Сетка | LW10 (барная), 63 (панк) |
| 9 | Рваное-модное | LW28, 35, 42, 63, 77 |
| 10 | Гольфы до колена и вязка | LW03, 18, 30, 46, 49, 61, 65, 69, 73, 85, 86 |
| 11 | Свечение, голо и перламутр (шейдер) | LW25, 29, 31, 32, 75, 84, 87 |
| 12 | Кобура и ремень на бедре поверх костюма | LW29, 76 |
| 13 | Босиком или стремя + украшение | LW17, 52, 54, 57, 59, 74 |
| 14 | Ноги закрыты, акцент обувью или нитью | LW04, 06, 09, 11, 21, 43, 51, 53, 71, 79, 83 (от колена вниз) |

---

## 4. Горячие жесты: библиотека и наборы по богиням

### 4.1 Как читать и что добавлено к POSES_HOT

- **Библиотека и параметры** — `POSES_HOT.md` §3 (единицы px исходника `body.png`, ×0,645 на экране; `a` анти-ход, `p` пик, `h→` hold, ζ и перехлёст), пресеты пластики — §4. Здесь только ножные и «горячие» жесты, правки к ним и новые id. Лицевые жесты (`lip_bite`, `smoulder`, поцелуи) остаются в POSES_HOT §6.
- **Сборка:** `все` — везде; `все↑` — в базе амплитуда ×0,6 без лицевых добавок, в 18+ полностью; `18+` — только APK после возрастного экрана, `V10Age.bold_ok()`, **никогда в ответ на тап**, только idle при симпатии ≥ 6, после комплимента в чате или ответа на письмо.
- **Риг:** `R` — риг v2 как есть; `R+L` — доп. слой из того же K (только если стопа и голень есть в K: Неми, Минамо, Сигрид и полноростовые `allure`/«В рост»); `R+P` — дорисованный патч; `V` — видео start = end = K с хвостом §1.6; `S` — шейдер; `B` — кость украшения.
- **Кадр:** `knee` / `thigh` / `full` (§2).
- **Рецепт горячего** (POSES_HOT §1.1): глаза держат игрока, пока двигается тело; медленно туда, быстро обратно; пауза на пике 0,6–1,5 с; в конце смущение. Звук украшения на каждом ножном жесте.
- **Руки на ногах** — только колено, голень, щиколотка, стопа. Рука никогда не поднимается выше ладони над коленом. Движение по ноге — только от колена вниз.
- В 18+ при симпатии ≥ 6 паузы между автономными жестами ×0,7.

### 4.2 Общие ножные жесты (новые и исправленные)

| id | Что делает | Сборка | Риг | Кадр | Параметры |
|---|---|---|---|---|---|
| `leg_idle` | Непрерывный слой: перенос веса (контрапост) каждые 3–5 с; сидя — покачивание стопы | все | R (стоя) / R+L (сидя, стопа в K) | knee | Стоя: hip_x ±6, ζ .6, поверх idle рига. Сидя: стопа ±3°, период 1,4 с. Выключен у Рин в `idle` (стопа зацеплена за подножку) |
| `sheen_sweep` | Блик едет по голени и колену | все | S (маска голени и колена, R+P) | knee | 0,6 с при любом ножном жесте и раз в 8–12 с; ширина 18 px, сила 0,35; латекс (LW29, LW32) ×2. Маска никогда не выше колена |
| `fever_glow` | В «лихорадке» узор легвира светится сильнее | все | S | knee | Эмиссия ×1,6, вход 0,4 с, ≤ 3 вспышек в секунду, без белого, ≤ 70 % яркости (UX §8.5). LW31, LW62, LW70, LW75, LW84, дюзы LW79 |
| `ornament_sway` | Украшения ниже колена качаются от движений тела, свой SFX | все | B | knee / full | Пружина k 10–13, ζ .3–.4, max 6°/кость. **Выше колена — только follow-through ≤ 3 px, без собственного качания** |
| `tiptoe_rise` | Подъём на носки | все | R (через hip_y, стопы не анимируем) | knee | hip_y −12, shrug +4, ζ .42 |
| `shoe_dangle` | Сидя: пятка выходит из туфли, туфля качается на пальцах | 18+ (база: только пятка приподнята, `все↑`) | R+L (туфля в K) \| V | full | 3,2 с \| пятка выходит @.6 \| туфля ±6° вокруг носка, период 1,2 с, ζ .3, 2–3 качания \| возврат @2,6. В V-версии туфля соскальзывает, она ловит её носком и краснеет |
| `calf_glide` | Стоя в профиль: стопа скользит вверх по икре опорной ноги до места под коленом и обратно | 18+ | V | full | 2,4 с, разрез на дальней от камеры стороне, подол и разрез неподвижны, взгляд на игроке |
| `sock_pullup` | Большими пальцами цепляет манжету гольфа у колена и подтягивает | все↑ | V \| R+P | knee | 1,6 с. Только гольфы выше колена (LW19, 36, 42, 61). Рука не выше ладони над коленом. **Без щелчка резинки:** мягкий шорох вязки. В конце смешок |
| `toe_twist` | Смущённо крутит носком по полу | все | R+L \| V | full | 1,8 с, стопа ±8° вокруг носка, 2 оборота, blush .7 |
| `heel_wobble` | Подворачивает щиколотку на непривычном каблуке, ловит равновесие руками | все | R (+L в «В рост») | knee | 1,6 с \| hip_x ±8s, armL ±6, head 3s°, ζ .38, `oh` → смех |
| `kick_back` | Подбрасывает пятку назад | все↑ | **V** (голень −28° больше предела подмалёвка 35 px) | full | 1,4 с, строго в профиль, пятка за опорную ногу, не к камере. Только шорты и брюки |
| `leg_recross` | Сидя перекладывает ногу на ногу | 18+ | **V** | full | Только `r_after` (LW10). Камера сбоку ≥ 60° со стороны верхней ноги (`yaw_min: 60`), **бёдра соприкасаются весь жест**, подол неподвижен. Негатив видео: `no gap between the thighs, hem does not ride up` |
| `ankle_swap` | Сидя меняет скрещённые лодыжки | 18+ | **V** | full | 3,0 с, голени ±6°, бёдра вместе. Только Веспер `idle` |
| `knee_in` | Колено внутрь, смущение | 18+ | R | knee | Как в риге v2, **перенесён в `bold`** (0.10-spec D4). Только МТ |
| `seated_swing` | Сидя болтает голенями, колени вместе | все | R+L (±5°) \| V (±10°) | full | В риге амплитуда снижена до ±5°: при ±10° кончик голени уходит на ≈50 px |

**Отменено (и почему):** `stocking_pullup` (рука у мини оказывается у верха бедра; заменён на `sock_pullup` только для гольф), `stocking_smooth` (рука вдоль ноги на 200+ px; оставлены только трассы от колена вниз как `V`), щелчок подвязкой и любой звук «резинки», `clip_twang` (клипсы на бедре), `prone_kick` (лёжа — красная линия POSES §0.3), `tb.fishnet_tug` и `tb.tear_notice` (сетки и дырки у `tb_base` больше нет), `me.knees_rub` (вместе с прежним me_base читался моложе), `ki.holster_check` (рука на бедре), разрез, «открывающийся на шаге» (LW13, LW22, LW37, LW40 — открытость задана в K и не растёт).

### 4.3 Наборы по богиням

Столбцы: id · что делает · сборка · риг · кадр · наряды (`allow` / `deny`) · параметры. У всех, кроме оговорённых, есть `leg_idle`, `sheen_sweep`, `ornament_sway`. Слот-витрина — ключ POSES §0.5, где её ножки видны лучше всего.

#### 1. mc — Маджонг-тян (×1,0, ζ .45)
Витрина: `select` `wide-side-stance-tile-flick` (LW05 в разрезе), `tease` `armrest-perch-tile-shh` (туфли в «В рост»). `allure` — POSES_HOT без изменений.

| id | Что | Сборка | Риг | Кадр | Наряды | Параметры |
|---|---|---|---|---|---|---|
| `mc.knee_in_heel` | Ревнивое смущение: колено внутрь, пятка поднята, носок рисует два кружка | 18+ | R+L \| V | knee | deny o_tutor | `knee_in` + `heel_lift`, круги ±4 px ×2 по 0,6 с, blush 1,0, 2,8 с |
| `mc.shoe_dangle` | Присела на подлокотник: лодочка качается в такт стуку фишек | 18+ (база: пятка) | R+L \| V | full | allow o_base, o_cafe, o_dragon, o_vow | `shoe_dangle`, период подогнан к `mc.tile_roll` (1,2 с) |
| `mc.table_hip_slide` | Бедро скользит по краю стола к игроку | все↑ | R | thigh | deny o_tutor | POSES_HOT |
| `mc.scale_glint` | Лампа проходит, блик бежит по драконьей чешуе от колена вверх к разрезу и гаснет у колена | все | S | knee | allow o_dragon | `sheen_sweep` по маске чешуи, но маска обрезана по колену: блик выше колена не идёт |
| `mc.ribbon_tug` | Хвосты ленты у колена вздрагивают на `hip_pop` | все | B | knee | allow o_cafe, o_vow | импульс на hip_pop, k 11, ζ .35 |

SFX: стук фишки, каблук лодочки. Лихорадка: —.

#### 2. rin — Рин (×2,0, ζ .7)
Витрина: `idle` `tall-stool-cross-hooked-foot` — **статична** (стопа на подножке, `leg_idle` выключен). `allure` заменена: `between-shelves-glasses-lowered-braid` — стоя вертикально между стеллажами, очки опущены одним пальцем, коса через плечо, ноги прямые и параллельные (три наклона через стол — МТ, Рин, Миэль — превращались в один силуэт).

| id | Что | Сборка | Риг | Кадр | Наряды | Параметры |
|---|---|---|---|---|---|---|
| `rin.leg_recross` | На табурете медленно перекладывает ногу на ногу, взгляд на игроке | 18+ | V | full | allow r_after | `leg_recross` ×1,5 = 6,0 с, `yaw_min 60`, бёдра вместе |
| `rin.shoe_dangle` | Свободная туфля соскальзывает с пятки и замирает | 18+ | V | full | allow r_after | `shoe_dangle` ×2 медленнее, 1 качание |
| `rin.seam_glance` | Стоя в 3/4 опускает взгляд вниз-назад на шов, блик бежит по шву, глаза возвращаются к игроку поверх очков | все↑ | R + S | knee | allow r_agent | 4,0 с \| head −3s°, look_y +2 → −2,2 @2,4 \| `sheen_sweep` по шву @1,2 \| рук нет |
| `rin.over_glasses` | Опускает очки и смотрит поверх | все | R+P | thigh | — | POSES_HOT |
| `rin.idol_ankle_bow` | Бархатные банты на щиколотках вздрагивают на шаге | все | B | full | allow r_idol, r_after | k 12, ζ .4 |

SFX: тонкий стук каблука о подножку. Лихорадка: —. `rin.seam_check` из POSES_HOT (рука на икре сидя) заменён на `rin.seam_glance`: в позе на табурете (r_after) шва нет.

#### 3. hana — Хана (×0,75, ζ .38)
Витрина: `idle` `one-leg-quad-stretch` (LW19 зона), `select` `lunge-high-five`.

| id | Что | Сборка | Риг | Кадр | Наряды | Параметры |
|---|---|---|---|---|---|---|
| `ha.sock_pullup` | Цепляет манжету гольфа, тянет вверх, он чуть сползает — надула губы и рассмеялась | все↑ | V \| R+P | knee | allow h_gym | `sock_pullup` ×0,75 |
| `ha.bounce_toes` | Пружинит на носках 3 раза | все | R | knee | — | POSES_HOT, через hip_y |
| `ha.heel_wobble` | На гала-каблуках подворачивает щиколотку и ловит воздух руками | все | R | knee | allow h_gala | `heel_wobble`, гэп-моэ «я не умею на каблуках» |
| `ha.kick_back` | На растяжке подбрасывает пятку к бедру, в профиль | все↑ | V | full | allow h_base, h_gym, h_street | `kick_back` |
| `ha.tape_press` | Прижимает пальцем тейп на колене, ухмылка | все | V | full | allow h_beach | 1,8 с, рука только на колене |
| `ha.lunge_lean` | Выпад: **корпус в профиль, таз развёрнут на 90°** | все↑ | V \| R | thigh | allow h_base, h_gym, h_street | POSES_HOT с ограничением: выпад по боковой оси, не к камере |

SFX: скрип кроссовок, шорох вязки. Лихорадка: —.

#### 4. yue — Юэ (×1,6, ζ .65)
Витрина: `select` `water-sleeve-spiral` (LW24 в стоп-кадре поворота), `idle` `fan-at-lips-s-curve`. Баннер — y_duel (LW23).

| id | Что | Сборка | Риг | Кадр | Наряды | Параметры |
|---|---|---|---|---|---|---|
| `yue.toe_point` | Вытягивает носок, линия стопы | все↑ | R+L \| V | full | allow y_base, y_queen, y_ball | POSES_HOT |
| `yue.crossing_glide` | Скрещивающийся шаг-скольжение, разрез неподвижен | все↑ | V | full | — | POSES_HOT |
| `yue.calf_glide` | Невесомость: стопа скользит по икре до места под коленом | 18+ | V | full | allow y_base, y_duel, y_ball, y_city | `calf_glide` ×1,6 = 3,8 с |
| `yue.boot_glint` | Лунный блик скользит по голенищу ботфорта и заклёпкам | все | S | knee | allow y_duel | `sheen_sweep` ×1,4 по маске сапога |
| `yue.weightless` | Волосы и рукава всплывают, поднимается на 6 px | все | R | knee | — | POSES_HOT |

SFX: тихий звон цепочки при шаге (LW24, без качания). Лихорадка: —. Взгляд «мимо игрока» (POSES) против UX §8.1 — решение владельца №8.

#### 5. nova — Нова (×0,8, ζ .42 + глитч)
Витрина: `select` `bike-sidesaddle-knees-together` (кадр от середины бедра — ботинки вне кадра). `allure` (сидя на голо-плите) — одна из трёх сидячих, оставлена.

| id | Что | Сборка | Риг | Кадр | Наряды | Параметры |
|---|---|---|---|---|---|---|
| `nv.glitch_nod` | Кивок в бит с двухкадровым глитчем (вместо отстука ботинком в лобби) | все | R | thigh | — | 0,5 с на долю, head_y ±3, глитч ±2 px |
| `nv.hip_drop_tap` | Вес в бедро, носок ботинка отбивает 4 доли | все↑ | R+L | full | allow n_base, n_diva | POSES_HOT, только в «В рост» |
| `nv.slash_poke` | Стилусом тычет в лазерную прорезь на колене: «это дизайн» | все | V \| R | knee | allow n_base | 2,0 с, стилус, не рука; заменяет `nv.ladder_poke` |
| `nv.led_pulse` | LED-кант пульсирует в такт музыке | все | S | knee | allow n_ssr | BPM трека, яркость .5–.9 |
| `nv.holo_shift` | Перелив голо-латекса по левой ноге | все | S | knee | allow n_diva | `sheen_sweep` ×2 + сдвиг оттенка 20° |

Лихорадка: LW31 ×1,6. SFX: короткий «пик» на глитче.

#### 6. tsubame — Цубамэ (атака ×0,6, hold ×1,5, ζ .5)
Витрина: `idle` `ridge-tightrope-read-letter`, `select` `profile-tuck-leap-letter` (LW35). `allure` — **без порыва** (LW33 цел).

| id | Что | Сборка | Риг | Кадр | Наряды | Параметры |
|---|---|---|---|---|---|---|
| `tb.micro_balance` | Пятка опорной ноги приподнимается, руки ловят баланс | все | R | knee | — | POSES_HOT, через hip_y |
| `tb.freeze_dash` | «Замерла — рывок»: 1,2 с неподвижно, резкий сдвиг корпуса, шарф и шнур догоняют | все | R + B | knee | — | hip_x 18s за 0,15 с, ζ .5; концы шнура LW33 и банта LW34 — импульс |
| `tb.sashiko_touch` | Кончиком пальца ведёт по алому стежку на колене, гордая полуулыбка | все↑ | V | knee | allow tb_crimson | 2,4 с, рука только на колене и голени, вниз |
| `tb.ridge_balance` | В профиль балансирует на одной ноге, другая стопа у икры | все↑ | V | full | — | 3,0 с, разрез на дальней стороне |

SFX: шорох шёлка, тихий «тук» таби по черепице.

#### 7. miel — Миэль (×1,0, ζ .4)
Витрина: `select` `piping-cupcake-hip-sway` — кадр через прилавок, ноги закрыты, поэтому ножные жесты — только `full`. Пятка в статике `select` больше не выскользнувшая (это делает жест).

| id | Что | Сборка | Риг | Кадр | Наряды | Параметры |
|---|---|---|---|---|---|---|
| `me.hip_sway` | Покачивание бёдрами на «раз-два» | все↑ | R | thigh | — | `hip_eight` ×0,7 амплитуды, период 1,0 с |
| `me.heel_slip` | Пятка выскальзывает, туфелька качается 2 раза | 18+ (база: пятка) | R+P+L \| V | full | allow me_base, me_parlor, me_gala | POSES_HOT |
| `me.tiptoe_reach` | Тянется на носках к верхней полке | все | R | thigh | — | `tiptoe_rise` + ikL вверх |
| `me.sock_pullup` | Подтягивает карамельный гольф, бант вздрагивает | все↑ | V | knee | allow me_base | `sock_pullup` |

SFX: стук каблучков по плитке, звяк венчика. `me.knees_rub` и `prone_kick` отменены (§4.2).

#### 8. lian — Лянь (×1,8, ζ .7)
Витрина: `tease` `profile-over-shoulder-slit-step` (LW39/LW41). `allure` (на краю палубы, ноги над водой) — одна из трёх сидячих, оставлена.

| id | Что | Сборка | Риг | Кадр | Наряды | Параметры |
|---|---|---|---|---|---|---|
| `li.slit_step` | Маленький шаг в профиль; разрез как в K, не расширяется | все↑ | V \| R+L | full | — | POSES_HOT |
| `li.lotus_trace` | В профиль ведёт пальцем по лотосу от колена вниз к щиколотке | 18+ | V | full | allow li_base | 3,2 с, только вниз от колена |
| `li.toe_ripple` | Носок касается воды, расходятся круги | все | V | full | allow `allure` | 3,0 с, FX кругов |
| `li.ripple_shimmer` | Рябь на чулке мерцает, как фонари на воде | все | S | knee | allow li_lantern | сдвиг UV муара 0,3 px/с, ячейка ≥ 8 px |

SFX: стук бусин-кистей, всплеск. Лихорадка: —.

#### 9. jess — Джесс (×0,85, ζ .38)
Витрина: `idle` `fence-forearms-ankles-crossed` (ковбойский кадр от середины бедра). `allure` заменена: `fence-post-heel-dug-brim-lift` — стоя спиной к столбу загона, один каблук вбит в землю, большим пальцем поднимает поля шляпы.

| id | Что | Сборка | Риг | Кадр | Наряды | Параметры |
|---|---|---|---|---|---|---|
| `je.weight_drop_brim` | Сброс веса в бедро, большой палец поднимает поля шляпы (вместо `boot_tap`) | все | R | thigh | — | `weight_drop` + ikR к полям |
| `je.heel_stomp` | Впечатывает каблук, звон шпор | все | R+L \| V | full | — | POSES_HOT |
| `je.sock_pullup` | Рывком подтягивает махровую манжету, подковка качается | все↑ | V | knee | allow je_base | `sock_pullup`, только манжета гольфа |
| `je.ankle_cross` | Стоя меняет скрещённые лодыжки | все | R+L | full | — | POSES_HOT |

SFX: шпоры (je_rodeo), скрип кожи, бахрома.

#### 10. tsuru — Цуру (×1,3, ζ .6)
Витрина: `idle` `doorframe-sleeves-geta-tooth`. `allure` изменена: гэта вместе (зубец только в `idle`), акцент на рукаве и чайнике, пар поднимается на уровне лица (не вуалью у талии).

| id | Что | Сборка | Риг | Кадр | Наряды | Параметры |
|---|---|---|---|---|---|---|
| `tu.geta_rock` | Перекатывается на передний зубец гэты и обратно | все | R+L | full | allow tu_base, tu_pingpong, tu_snow | POSES_HOT |
| `tu.toe_twist` | Смущённо крутит носком гэты | все | R+L \| V | full | — | `toe_twist` |
| `tu.knowing_lean` | Наклон ближе, глаза в глаза | все↑ | R | thigh | — | POSES_HOT |
| `tu.steam_sheen` | Пар оседает влажным блеском на голенях | все | S | knee | allow tu_base | `sheen_sweep` медленный, 1,4 с |

SFX: стук гэты по доскам.

#### 11. kohaku — Кохаку (профиль `lazy`, ζ .4)
Витрина: `shy` `head-offer-pigeon-toe-tail-wag`, `tease` `lean-in-fox-sign-heel-flick`. `allure` заменена: стоя на ступени, хвост вопросом, лисий огонёк на ладони.

| id | Что | Сборка | Риг | Кадр | Наряды | Параметры |
|---|---|---|---|---|---|---|
| `ko.heel_flick` | Подскок, пятка подброшена назад, звенят бубенцы под коленом | все↑ | R+L \| V | full | allow ko_base, ko_matsuri | POSES_HOT |
| `ko.pigeon_toe` | Лисья косолапость: носки внутрь, хвост виляет | все | R+L | full | — | `toe_twist` вариант, хвост опережает на 0,15 с |
| `ko.tail_brush` | Хвост проходит перед коленями, взгляд из-под ресниц | все↑ | R+L | knee | — | хвост на уровне колен, не выше |
| `ko.bell_chime` | Бубенцы под коленом звенят от переноса веса | все | B | knee | allow ko_base | k 12, ζ .35, SFX судзу |
| `ko.ofuda_glow` | Лисий огонь подсвечивает офуда у резинки (свет, не движение) | все | S | thigh | allow ko_kyubi | эмиссия .4 → .8, 1,2 с |

#### 12. shirin — Ширин (×1,4, ζ .55)
Витрина: `tease` `ankle-cross-own-palm-trace`, `select` `promenade-veil-sweep` (монеты LW52 в «В рост»).

| id | Что | Сборка | Риг | Кадр | Наряды | Параметры |
|---|---|---|---|---|---|---|
| `sh.releve` | Подъём на полупальцы, монеты звенят | все | R | knee | — | `tiptoe_rise` ×1,4 |
| `sh.anklet_roll` | Перекат с пятки на носок | все | R+L | full | — | POSES_HOT |
| `sh.calf_glide` | Стопа ведёт по икре, звенят подвески | 18+ | V | full | allow sh_base, sh_sun, sh_night | `calf_glide` |
| `sh.hip_eight` | Восьмёрка бёдрами | все↑ | R | thigh | — | POSES_HOT |
| `sh.henna_sheen` | Блик пробегает по узору мехенди | все | S | knee | allow sh_sun | `sheen_sweep` |

SFX: монеты (LW52), звёзды (LW55). `sh.shoulder_shimmy` не брать в материалы стора.

#### 13. mari — Марисоль (×1,0, ζ .45, качка фона)
Витрина: `idle` `boot-on-rail-shroud-grip` (ботфорт на тумбе — брюки, разрешено). Голландский наклон — только у неё.

| id | Что | Сборка | Риг | Кадр | Наряды | Параметры |
|---|---|---|---|---|---|---|
| `ma.heel_strike` | Удар каблуком ботфорта по палубе, кушак взлетает на ветру | все | R+L \| V | full | allow ma_base, ma_admiral | 1,2 с, cam тряска 2 px, SFX |
| `ma.boot_shine` | Ладонь скользит по голенищу от колена к щиколотке | все↑ | V | full | allow ma_base, ma_admiral | POSES_HOT, только вниз |
| `ma.sash_wind` | Кушак на голенище и бандана под коленом бьются на ветру | все | B | knee | allow ma_base, ma_port | пружина с шумом ветра 0,7 Гц |
| `ma.attention_blush` | Бравада → сапоги вместе «смирно» → краснеет | все | R | thigh | — | POSES_HOT |

SFX: каблук по доскам, ветер, звяк латунной кисти (LW58).

#### 14. hibana — Хибана (квант 0,5 с, ζ .35)
Витрина: `idle` `bounce-air-roll-elbows-out` (LW60 зона). `allure` в `hi_base` — **LW60 целый**, без порыва; поднятое колено — только в шортах (`hi_base`).

| id | Что | Сборка | Риг | Кадр | Наряды | Параметры |
|---|---|---|---|---|---|---|
| `hi.beat_stomp` | Топ на сильную долю | все | R (hip_y) \| R+L | knee | — | POSES_HOT |
| `hi.bounce_toes` | Пружинит на носках в бит | все | R | knee | — | hip_y ±6 на каждую долю |
| `hi.rip_knee_beat` | Кончиком палочки отбивает 4 доли по нашивке на колене | все↑ | V | knee | allow hi_rock | палочка, не рука; только hi_rock |
| `hi.raijin_crackle` | По молнии на чулке бежит разряд | все | S | knee | allow hi_raijin | 0,3 с, раз в 6–9 с, ≤ 3 вспышек/с |
| `hi.sock_pullup` | Подтягивает полосатый гольф | все↑ | V | knee | allow hi_fest | `sock_pullup` |

SFX: удар платформы, барабан. Лихорадка: LW62 ×1,6. `clip_twang` отменён.

#### 15. nemi — Неми (×1,5, ζ .75; полный рост по умолчанию)

| id | Что | Сборка | Риг | Кадр | Наряды | Параметры |
|---|---|---|---|---|---|---|
| `ne.weight_shift` | Медленный перенос веса раз в ~10 с | все | R | knee | — | POSES_HOT |
| `ne.leaf_on_knee` | Лист садится на колено, она смахивает его не глядя, уши розовеют | все | R + FX | knee | — | POSES_HOT |
| `ne.toe_twist` | Смущение: носок сапога крутится, уши дёргаются | все | R+L | full | — | `toe_twist` |
| `ne.vine_bloom` | Тап по аксессуару: лоза на икре распускает цветы | все | B + S | knee | allow ne_spring | 1,6 с, анимация аксессуара, не одежды |
| `ne.feather_sway` | Перья на голенищах колышутся | все | B | knee | allow ne_hunt | k 10, ζ .4 |

#### 16. zlata — Злата (×1,2, ζ .5, симметрия)
Витрина: `select` `folk-heel-step-arm-sweep` (LW68 в разрезе). `allure` заменена: строго анфас, руки разводят мантию жар-птицы, как крылья, подбородок поднят (перьев у лица нет).

| id | Что | Сборка | Риг | Кадр | Наряды | Параметры |
|---|---|---|---|---|---|---|
| `zl.heel_tap` | Плясовой «каблучок» носком вверх, искры с каблука | все | R+L \| V | full | — | POSES_HOT, FX ниже колена |
| `zl.drobushka` | Дробь каблучками на месте | все↑ | V | full | allow zl_base, zl_fair, zl_ember | 2,4 с, 8 ударов, симметрично |
| `zl.ember_seam` | Шов тлеет и разгорается в лихорадке | все | S | knee | allow zl_ember | `fever_glow` |
| `zl.ribbon_ends` | Концы лент под коленом взлетают на «каблучке» | все | B | knee | allow zl_fair | импульс на heel_tap |

SFX: каблучки, треск искр. В POSES §16 «облизывает губы после блинов» заменено на «смахивает крошку тыльной стороной пальца» (ROSTER §4.3).

#### 17. minamo — Минамо (×1,7, ζ .8 + «буй»; полный рост)

| id | Что | Сборка | Риг | Кадр | Наряды | Параметры |
|---|---|---|---|---|---|---|
| `mi.mermaid_flutter` | Ноги вместе «бьют хвостом» от бёдер, по чешуе идёт волна блика | все↑ | R+L + S | full | — | POSES_HOT + волна `sheen_sweep` 0,8 с (LW75) |
| `mi.toe_curl` | Пальцы ног поджимаются и вытягиваются | все | R+L | full | — | POSES_HOT |
| `mi.ankle_drift` | Медленный дрейф щиколоток, жемчуг и ленты тянутся следом | все | R+L + B | full | — | щиколотки ±4 px, 4,2 с |
| `mi.pearl_chime` | Жемчуг на подъёме стопы стучит | все | B | full | allow mi_base, mi_reef | SFX стук жемчуга |

Лихорадка: LW75 опал ×1,6.

#### 18. kira — Кира (×0,7, ступенчатые ключи, ζ .7)
Витрина: `idle` `lean-back-boot-on-armor-helmet-spin` — **только ki_base и ki_stealth**; в `ki_off` и `ki_dress` витрина `shy` `rigid-attention-salute`. `allure` заменена: стоя на ободе люка, шлем под мышкой (сидячая поза с поднятым коленом и низким ракурсом отменена).

| id | Что | Сборка | Риг | Кадр | Наряды | Параметры |
|---|---|---|---|---|---|---|
| `ki.heel_click` | Щелчок каблуков стоя, у ki_stealth — пых дюз | все | R | knee | deny на позе `lean-back-boot-on-armor` | hip_y ступенька −4, SFX |
| `ki.salute_stop` | Чёткий салют со стоп-фиксацией | все | R | thigh | allow ki_off, ki_dress | 0,6 с, ζ .7 |
| `ki.boot_zip` | Застёгивает молнию ботинка от щиколотки до колена | все↑ | V | full | allow ki_base, ki_stealth | POSES_HOT |
| `ki.dring_glint` | Блик по D-кольцам на коленях | все | S | knee | allow ki_off | `sheen_sweep` по маске колец |

Лихорадка: дюзы LW79. Низкий ракурс — только стоя, ki_base/ki_stealth.

#### 19. vesper — Веспер (×1,8, ζ .6)
Витрина: `select` `tendu-lace-parasol`, `idle` `chaise-upright-legs-long-rose`. `allure` заменена: `harpsichord-lid-lean-rose-jaw` — опирается на крышку клавесина, стеблем розы ведёт по своей линии челюсти, лодыжки скрещены на длинной диагонали.

| id | Что | Сборка | Риг | Кадр | Наряды | Параметры |
|---|---|---|---|---|---|---|
| `ve.ankle_swap` | На шезлонге медленно меняет скрещённые лодыжки | 18+ | V | full | — | `ankle_swap` ×1,8 (вместо `leg_recross`) |
| `ve.shoe_dangle` | Каблук верхней ноги лениво свисает с пальцев | 18+ | R+L \| V | full | allow ve_base, ve_ball, ve_vow | `shoe_dangle` ×1,8 |
| `ve.toe_point` | Тандю: носок вытянут, ленивый взгляд | все↑ | R+L \| V | full | — | `toe_point` |
| `ve.calf_glide` | Стопа ведёт по икре в профиль | 18+ | V | full | allow ve_base, ve_ball | `calf_glide` ×1,8 |
| `ve.lace_trace` | Пальцем в перчатке ведёт по шнуровке икры от колена вниз | 18+ | V | full | allow ve_ball | 4,0 с, только вниз от колена |

SFX: цокот каблука, шорох бархата. Шарм-мышь LW82 и банты LW81 — кости.

#### 20. sigrid — Сигрид (×1,2, ζ .6; полный рост)
Витрина: `select` `crossover-glide-carriage-arms`, `tease` `glide-attitude-blow-snowflake`. `allure` заменена: `rink-edge-T-scarf-to-nose` — Т-позиция у бортика, шарф натянут до носа, видны только глаза.

| id | Что | Сборка | Риг | Кадр | Наряды | Параметры |
|---|---|---|---|---|---|---|
| `si.ice_rock` | Покачивается на лезвиях, след инея | все | R+L | full | — | POSES_HOT |
| `si.crossover_glide` | Перебежка | все↑ | V | full | — | 3,0 с |
| `si.low_attitude` | Аттитюд строго в профиль, стопа не выше икры опорной ноги | все↑ | V | full | — | Бильман и любой подъём ноги в юбке выше колена запрещены |
| `si.frost_knee` | Касается колена, по ткани чулка у колена расцветает морозный узор | все↑ | V \| R+P + S | knee | allow si_base, si_summer | POSES_HOT, «на ткани у колена», не на кружеве |
| `si.glitter_sweep` | Блёстки инея вспыхивают волной | все | S | knee | allow si_base | `sheen_sweep` + искры, в лихорадке ×1,6 |

SFX: лезвия по льду, звон кристаллов LW87.

---

## 5. Что нужно ригу: слои, кости, маски, патчи, клипы

### 5.1 Общие требования

- **Чулок рисуется на слое бедра.** Резинку, кружево, узор и застёжку подвязки рисуем на слое `thigh` (по README рига v2 бедро в разрезе — отдельный слой со своим подмалёвком). Тогда при `knee_in` и любом сдвиге бедра край чулка едет вместе с ногой и не «отклеивается».
- **Голень и стопа — слой `shin_L/R` + `foot_L/R`** только если они есть в K (Неми, Минамо, Сигрид, `allure`, «В рост»). Сдвиги ≤ 35 px.
- **Туфля — слой `shoe_*` с костью вокруг носка** для `shoe_dangle` и `heel_slip`, подмалёвок пятки — патч `heel_out` (R+P).
- **Кости украшений** (`orn_*`) — только ниже колена. Выше колена украшения не режутся в отдельный слой и двигаются только с бедром.
- **Шейдер-маски:** `sheen_mask` (голень и колено, рисуется по K, никогда выше колена), `glow_mask` (узор свечения), `shimmer_mask` (блёстки, муар, опал). Сила и цвет — в `rig_def.json` → `shaders`.
- **Узор под варпом:** ячейка ≥ 6–8 px на экране после ×0,645; иначе муар. LW10, LW13, LW37, LW40 проверять `--strain` и кадрами по 0,25 с.
- **Производство.** Риг привязан к K: 1–1,5 дня на каждый K (README). На 87 нарядов это 90–130 человеко-дней, поэтому **ригаем базу и один витринный наряд богини**, остальные наряды — стоп-кадр + idle-петля Kling (ROSTER §4.3). Витринный наряд — тот, где ножки сильнее всего (таблица ниже).

### 5.2 По богиням

| Богиня | Риг-K: база + витрина | Доп. слои (R+L) | Кости `orn_*` (ниже колена) | Шейдер-маски | Патчи (R+P) | Видео V |
|---|---|---|---|---|---|---|
| mc | o_base + **o_dragon** | thigh (есть), shoe (tease) | ribbon_knee (o_cafe, o_vow) | sheen, scale_glint | heel_out | shoe_dangle, knee_in_heel |
| rin | r_base + **r_agent** | — (idle статичен) | ankle_bow (r_idol, r_after) | sheen по шву | glasses_low | leg_recross, shoe_dangle (r_after) |
| hana | h_base + **h_gym** | foot (в «В рост») | cords (h_lantern) | sheen | sock_cuff_up | sock_pullup, kick_back, lunge_lean, tape_press |
| yue | y_base + **y_duel** | foot (toe_point) | — | sheen, boot_glint, moon_dust (y_ball) | — | crossing_glide, calf_glide |
| nova | n_base + **n_diva** | boot (В рост) | — | sheen, holo, led_pulse, circuit_glow | — | slash_poke |
| tsubame | tb_base + **tb_crimson** | — | cord_ends (LW33), ankle_bow (LW34) | sheen | — | sashiko_touch, ridge_balance |
| miel | me_base + **me_parlor** | shoe (В рост) | — | sheen | heel_out | heel_slip, sock_pullup |
| lian | li_base + **li_concert** | foot (slit_step) | — | sheen, ripple (li_lantern) | — | slit_step, lotus_trace, toe_ripple |
| jess | je_base + **je_star** | boot (В рост) | horseshoe (LW42), chaps_fringe, spur (LW43) | sheen | sock_cuff_up | heel_stomp, sock_pullup |
| tsuru | tu_base + **tu_snow** | geta_L/R | — | sheen, steam | — | toe_twist |
| kohaku | ko_base + **ko_kyubi** | foot, tail (есть) | bells (LW48), tassel (LW50), red_thread (LW51) | sheen, ofuda_glow | — | heel_flick |
| shirin | sh_base + **sh_sun** | foot (anklet_roll) | coins (LW52), stars (LW55), chains (LW53) | sheen, henna | — | calf_glide |
| mari | ma_base + **ma_admiral** | boot | sash (LW56), bandana (LW57), tassel (LW58), compass (LW59) | sheen по голенищу | — | heel_strike, boot_shine |
| hibana | hi_base + **hi_rock** | — | — | sheen, raijin_crackle | — | rip_knee_beat, sock_pullup |
| nemi | ne_base + **ne_spring** | shin/foot (полный рост) | vine_leaves (LW66), feathers (LW67) | sheen, vine_bloom | — | — |
| zlata | zl_base + **zl_ember** | foot (heel_tap) | ribbon_ends (LW69), feather_charm (LW71) | sheen, ember_seam | — | drobushka |
| minamo | mi_base + **mi_jelly** | shin/foot (полный рост) | pearl_chains (LW72), streamers (LW75), pearl_net (LW74) | sheen, opal_wave | — | — |
| kira | ki_base + **ki_dress** | — | — | sheen, dring (ki_off), thrusters (LW79) | — | boot_zip |
| vesper | ve_base + **ve_ball** | shoe (chaise), foot | bat_charm (LW82), ribbon_tails (LW81) | sheen | heel_out | ankle_swap, calf_glide, lace_trace, shoe_dangle |
| sigrid | si_base + **si_throne** | shin/foot (полный рост) | — | sheen, frost_glitter, aurora (LW87) | frost_knee | crossover_glide, low_attitude, frost_knee |

### 5.3 Данные (предложение к `gestures.json`, `game/` не трогаем)

```json
{ "id": "ve.ankle_swap", "tier": "bold", "rig": "V", "legs": true, "framing": "full",
  "outfits_allow": [], "outfits_deny": [], "yaw_min": 0, "sfx": "velvet_rustle",
  "clip": "vesper/ve_base_ankle_swap.mp4", "rig_fallback": null }
```
`tier`: `base` (все), `up` (все↑), `bold` (18+). `legs: true` — жест не играет в кадре `alt_rect`. `outfits_deny` у **o_tutor** — все `up` и `bold`.

---

## 6. Производственный чек-лист

**Перед генерацией (промпт):**
- [ ] Фраза ног взята из §3 по коду LW; APK — с LEG_TAIL, SHEER_TAIL или GLOSS_TAIL; V4_TAIL в варианте APK.
- [ ] В EN-фразе ног нет слов позы и камеры; поза — только из POSES, видимость — по полю «Видно».
- [ ] Положение **обеих ног и обеих стоп** названо явно (POSES §0.4), хвосты `hem stays in place`, `slit unchanged`, `camera at her eye level`.
- [ ] Резинка и любые детали на бедре не выше середины бедра; подвязка — только концевая застёжка, источник назван.
- [ ] Рваное — только у LW28, 35, 42, 63, 77, с фразой `distressed by design, worn that way`, только колени и голени.
- [ ] Металл — по богине (§1.3 п. 5); основа — в её цвет.
- [ ] Яндекс-промпт: только Я-фраза, без слов из §1.5, V4_TAIL с `fully opaque fabric`.
- [ ] Асимметрия (LW16, LW32): заложен второй проход.

**Аудит кадра (HANDOFF §3 + этот файл):**
- [ ] Анатомия: две ноги, две стопы, пять пальцев на открытых стопах, коленей два, ни одной «третьей ноги».
- [ ] **Чулки одинаковы на обеих ногах** (кроме LW16, LW28, LW32): цвет, узор, высота резинки, сторона банта.
- [ ] **Согласованность узора между позами и кадрами наряда:** опорный K, шесть слотов, `allure`, кат-ин и раскрытие гачи — одинаковые высота резинки, цвет кружева, сторона банта или шнура, положение порывов (сверять по карте узора из K, наложение 50 %).
- [ ] Главный признак виден в зоне колено → середина бедра (кроме «закрытых» и Неми/Минамо/Сигрид).
- [ ] Регулярный узор не даёт муара на 64×114 и после ×0,645.
- [ ] Подол и разрез как в K; ни одного кадра «под юбку»; камера на юбках на уровне глаз.

**Риг и видео:**
- [ ] Чулок нарисован на слое бедра; `sheen_mask` не выше колена; кости украшений только ниже колена.
- [ ] `--strain=1` по всем ножным жестам: worst ≤ 0,25.
- [ ] Видео: покадрово (ffmpeg fps=4) — подол, разрез, резинка, порывы, лицо как в K; для `leg_recross` и `ankle_swap` — бёдра соприкасаются в каждом кадре.

**Сборки и самотесты (дополнить `--rig_selftest`):**
- [ ] В Яндекс-пакете нет ассетов с тегами `bold` и `legwear_apk`, нет `allure` и `18+`-видео.
- [ ] `bold`-жесты не вызываются из обработчика тапа; o_tutor не получает `up`/`bold`.
- [ ] Жесты с `legs: true` не играют в `alt_rect`; `framing: full` — только в разрешённых контекстах (§2 п. 4).
- [ ] Ни одна реакция на тап не попадает в зону «пупок — середина бедра»; блик и частицы — не выше колена.

---

## 7. Что исправлено после трёх ревью

**Витрина (игрок BD2/Nikke/AL):** кадр «В рост» и `allure` в рост (§2); главный признак продублирован в зону колена (§1.3); одна формула «кружево в разрезе» — не больше одной на богиню, основа в цвет богини (§1.3); правило «силуэт → цвет → деталь»; блик `SHEER_TAIL` и `sheen_sweep`; непрерывный `leg_idle` и паузы ×0,7; связь с лихорадкой (`fever_glow`); звук украшений; индекс пересобран по силуэту (§3.3); единый каталог вместо POSES_HOT §5; новые жесты `shoe_dangle`, `calf_glide`, `toe_twist`, `heel_wobble`, `sock_pullup`; по богиням — o_cafe, o_grand (вариант), r_maid, r_after, r_jade, y_city, n_ssr, n_base двухцвет, me_base, me_parlor, me_gala, li_lantern, je_base, tu_base, ko_kyubi, sh_sun и sh_night (стремя, звёзды), mi_jelly, ve_ball, ve_vow, si_throne. `prone_kick` отклонён (лёжа — красная линия).

**Уникальность (арт-директор):** шов сзади только у Рин (LW02, LW09, LW25, LW78 переделаны); все 14 пар дублей разведены (LW02/12, 05/68, 50/70, 24/62, 63/77, 57/81, 58/67, 69/85, 03/30, 36/19, 11/45, три «Обета», 13/27/33, 31/79); повторы внутри богини (полумесяцы Юэ, монеты Ширин, босые Минамо, подсолнухи Ханы); металл закреплён за богинями; кружево различается цветом и объёмным элементом; денье получило видимую границу; слова позы убраны из EN-фраз; «Я» сведены к одному правилу; позы-витрины поправлены (Рин, Юэ, Нова, Джесс, Миэль, Кира, Веспер, МТ); сидячих `allure` осталось три; поднятое колено только в брюках; ограничения рига (`leg_recross`, `ankle_swap`, `kick_back` — только V; `seated_swing` ±5°); фальшивая физика помечена шейдером; риг только база + витрина.

**Комплаенс:** рваное не появляется в `allure` Хибаны и Цубамэ; hi_rock и hi_base из POSES_HOT отменены; Кира — без низкого ракурса сидя и без поднятого колена в юбках; `leg_recross` — бёдра вместе, сбоку ≥ 60°, только V; `stocking_pullup` заменён на `sock_pullup` без щелчка; одиночные подвязки (LW07, 32, 38, 44, 47, 55) переделаны, у LW62, LW78 назван источник; физика на бедре убрана (бубенцы и монеты ниже колена); разрез не «открывается на шаге»; LW30 без голого бедра, LW82 без руки на подоле; `outfits_allow/deny` и запрет `up`/`bold` для o_tutor; стрелки только между коленом и щиколоткой; LW33 — без сетки в ранге A; детский код у me_base и ve_day снят (плюс лоферы LW30 и мэри-джейн LW37); 8 Яндекс-утечек закрыты (LW06, 23, 56, 61, 76, 79, 85, «…»-строки, LW17/59/74); V4_TAIL-правка только для APK; Яндекс — сборка, а не флаг.

---

## 8. Решения владельцу

1. Переключатель «В рост» на главной (APK 18+, симпатия ≥ 3, по умолчанию выкл.) и `allure` как полноростовая сцена в Альбоме.
2. Юбка кафе выше колена у `o_cafe` (иначе верх LW02 спрятан, остаётся бант у колена).
3. Фрак с шортами у `o_grand` (LW06 вариант Б).
4. Комбинезон-шорты у `h_lantern`.
5. Миди с боковым разрезом у `y_city`.
6. Каскадный перёд у `ve_ball` и ледяная тюлевая панель у `si_throne`.
7. Одной строкой синхронизировать HEROINES §3 и ART_DIRECTION стр. 132 («площадь кожи не растёт») с ROSTER §1.2: эскалация SSR — через материал, ширина зоны — по крою. Там же в ART_DIRECTION стр. 184 «просвечивающая ткань» → «на интимных зонах» (POSES §0.3 уже поправлен).
8. Взгляд Юэ: «мимо игрока» (POSES) или прямой (UX §8.1).
9. Уточнения канона из §3.2: h_street, me_gala, n_base, ne_hunt, разрезы h_gala, li_lantern, r_idol.
