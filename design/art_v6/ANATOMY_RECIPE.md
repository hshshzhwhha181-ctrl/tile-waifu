# ANATOMY_RECIPE: рецепт анатомии, поз и пропорций для арт-фабрики v6

Дата 2026-11-28, ветка `claude/art-recipe`, автор: recipe + pose library. Расход кредитов этой задачей: **0 кр** (только файлы). Основание: `defects_1..3.json` (99 финалов 10 героинь, разбор дефектов), `design/art_v6/BAKEOFF_VERDICT.md` (ветка `claude/art-bakeoff`, 156 изображений, 187.5 кр), решение владельца о пропорциях (`PROPORTIONS_OWNER_BINDING.md`), отзывы владельца 26-30 (анатомия, скрутка корпуса, мало поз сзади, однообразие).

Файлы рецепта:

| файл | что |
|---|---|
| `design/art_v6/ANATOMY_RECIPE.md` | этот документ |
| `design/art_v6/pose_library.json` | 65 поз, побочно: суставы, скрутка в градусах, пригодность по классам нарядов |
| `design/art_v6/assignments.json` | 170 слотов (10 героинь x 17) с id позы |
| `design/art_v6/CRITIC_CHECKLIST.md` | критерии pass/fail для критика |
| `tools/art/recipe_v6.py` | сборщик промптов v6 (`--selftest` собирает все 170 и прогоняет словари валидатора) |
| `tools/art/assign_poses.py` | решатель назначений и проверка ограничений (`--check`) |
| `tools/art/full_tier_wardrobe.py`, `build_art_batches.py`, `validate_batches.py`, `design/ART_TIER_FULL.md` §3a | пропорции владельца применены везде (раздел 1b) |

## 0. Что показали данные (коротко)

1. Главный дефект бейк-оффа был **не анатомией, а жёсткой линией**: мини-платье со щелями на виде сзади, наклоне и коленном прогибе показывает нижнюю ягодицу. Старый рецепт V0: 13 из 24 провалов. Правило подола (hem rule) + умеренные каблуки (V1h): **0 из 18**, 17 из 18 приняты (94 %), 1.06 кр на принятый кадр.
2. Скрутка корпуса лечится **текстом**, если поза записана по суставам («pelvis, buttocks and both legs face AWAY from the camera ... the spine twists gradually ... only the head and neck turn further»): twist 3/3 во всех gpt-вариантах.
3. Лимбы и пальцы у `gpt_image_2_6` в порядке: 1 дефект на 102 кандидата. Дефекты рук/ног в финалах v5 шли от поз (скрещённые ноги спереди, колени, ноги к камере), а не от модели.
4. Бёдра остаются слабым местом (в среднем 2.3 из 3): шарообразные при коленях, при перекосе бедра в 3/4-кропе, при низкой/широкоугольной камере. Правка редактированием («thighs narrower») помогает слабо.
5. Мини-манекен (2D) пользы не дал (46 % против 62 % у чистого текста): **не использовать**. Другие модели (Kling 4.0, Seedream 5.5, flux_3) хуже по стилю/пропорциям, flux_3 отказывает по модерации.
6. Топ-паттерны брака в 99 финалах (critical и major): `thigh_oversize` 48 попаданий, `leg_length_perspective` 22, `legs_too_long_vs_torso` 22, `underwear_read` 17, `thigh_merge_cross` 10, `torso_hip_twist_break` 3 + `rear_not_rotated` 3. Каждый паттерн закрыт блоком в разделе 2 и защитой (`failure_guards`) в позах.

## 1. Модель и вариант по типам поз (точные настройки)

База для всех: **`gpt_image_2_6` + Element** (`<<<element_id>>>` в тексте промпта, Element **не** дублировать в `medias`), вариант **V1h+**: грамматика раздела 2 + правило покрытия по классу наряда + поза по суставам + умеренные каблуки.

| параметр | поиск (search) | финал (final) |
|---|---|---|
| model / tool | `gpt_image_2_6` / `generate_image` | то же |
| aspect / resolution | `2:3`, `1k` (680x1024) | `2:3`, `2k` (1368x2048) |
| quality | `medium` | `high` |
| кандидатов | **4** на слот (`batch_size` 4: один вызов; в бейк-оффе 3 кандидата давали 94 % и 1-из-17 промах, четвёртый покрывает его) | 1 с сидом победителя поиска (**не проверено на бейк-оффе**: 2k/high считается по прежнему рецепту H1/H2, первый финал смотреть глазами) |
| цена | 1 кр за картинку | 2 кр |
| `image_references` | нет | нет (референс тянет разрез к референсу, риск жёсткой линии: ART_TIER_FULL §4) |
| ожидаемо | 1.06 кр на принятый кадр (V1h); закладывать **1.2 кр** на принятый, включая V4-спасение примерно для 1 из 8 | |

Стоимость плана: 170 слотов x (4 x 1 + 2) = **1020 кр** + резерв на V4/перебросы примерно 12 % = **около 1140 кр** (в прежнем плане H1 530 + H2 490 = 1020). Для поз с 2 слотами в наряде (7 нарядов x 2) выбор финала делается по лучшему кандидату каждой позы, без отдельного A-E поиска.

Тип позы, вариант, ожидаемая приёмка и страховка:

| тип позы (категория) | рецепт | данные | страховка |
|---|---|---|---|
| `rear_hip` (вид сзади, оглядка) | V1h + строка про ширину бёдер (она уже в ANAT) | бейк-офф a: 2/3 (67 %) | переброс; V4 правка «hem» если подол сместился; не править «shorten legs» (слабо) |
| `rear_lean`, `rear_walk` | V1h; правило подола решающее | b: 3/3; ходьба не тестировалась | пилот 2 позы x 2 кандидата перед партией |
| `leg_focus_seated`, `leg_focus_standing` | V1h; скрещивание ног **только в профиль** (S02), остальные позы без скрещивания бёдер | c: 3/3 (но в старых финалах скрещивание спереди слило бёдра в 10 кадрах) | если ноги слились: переброс, не правка |
| `bust_focus`, `portrait_tease` | V1n/V1h (бёдра в кадре не обязательны) | не тестировались | пилот |
| `lying` | V1h; ноги идут **поперёк кадра**, не к объективу; без манекена | e: 3/3 | при ноге «к камере» переброс |
| `kneeling` | V1h + опора предплечьями (K02), **не** ладони на полу | бейк-офф d (ладони на полу): 3/3, но это ближе всего к all-fours, запрещённому в ART_TIER_FULL §3b; библиотека использует опору на пуф/кровать | запасной вариант: `seedream_5_5` с Element-картинками (1.5 кр, d 2/2, стиль 1/3), только если gpt стабильно не даёт кнеелинг |
| `dynamic` | V1h; прыжок/выпад только в профиль, параллельно плоскости кадра | f: 3/3 | пилот |

Правка (V4 edit pass): вызов `generate_image` с победившим кадром в `image_references` и текстом вида
`Same image, same pose, face, outfit and colors. Fix only: <one defect>.` Примеры: `the skirt hem sits at mid-thigh and fully covers the buttocks`, `the thighs are slightly slimmer and clearly separate at the knees`. Хорошо для подола/покрытия (12 из 12 правок исправили цель, 1 кр за правку), слабо для пропорций и объёма бёдер. Правка не заменяет переброс, а спасает почти-хорошие кадры.

### 1b. Пропорции владельца применены везде (что изменено в репозитории)

* `tools/art/full_tier_wardrobe.py`: `HEADS_MIN, HEADS_MAX = 6.75, 7.0`; `CROTCH_PCT = 46`; `HEIGHTS` Yue 7.0 (177 см), Zlata 7.0 (176), Rin 6.9 (172), MC 6.85 (170), Hana 6.8 (168), Tsubame 6.8 (165), Shirin / Kohaku / Nova / Miel 6.75; теги и `legs` без `statuesque / very long / long legs`; `FIGURE` каждой героини получил `a compact torso` и `a visible knee and calf taper`; шаблоны поз D/H: «one long leg» -> «one leg», `FR["L"]` теперь «full-body standing view, portrait-lens camera at hip height», боевая поза D без «low knee-level view ... elongating her legs».
* `tools/art/build_art_batches.py`: `figure_line` вставляет правило линии паха (46 % роста, ноги не длиннее «плечо-пах + голова»), в хвост `v5f` добавлена «portrait-lens camera ... no wide-angle distortion»; рамка героического сплеша «never from below»; H3 T2 без «low camera at knee level that elongates the legs»; критерии отсева «6.75-7.0 heads, crotch line 45-48 %».
* `tools/art/validate_batches.py`: диапазон голов берётся из `WD` (6.75-7.0, значение должно совпасть с таблицей); `PROPORTION_BANNED` (`very long legs`, `long legs`, `elongat*`, `statuesque`, `leggy`, `endless legs`, `knee-level`, `from below` и `low angle` без отрицания); обязательные фразы `crotch line` и `shoulder-to-crotch` в каждом Full-промпте героини; selftest 24/24 (5 новых проверок).
* `design/ART_TIER_FULL.md`: §3a переписан (новая таблица, правила 1-6, адаптивное «взрослое лицо обязательно»), строка `L` в §3b, строка таблицы §5, заголовки §10.
* Пересборка и проверка: `python tools/art/build_art_batches.py && python tools/art/validate_batches.py` дают `ART_BATCHES OK: 15 batches, 1023 tasks, 0 errors`; бюджет не менялся (1 кр / 2 кр за картинку, те же счётчики).

## 2. Грамматика промпта (блок, который вставляется в каждый промпт)

Порядок (как в победившем V1h): `Element + identity` -> `Outfit` + **правило покрытия по классу наряда** -> `Proportions (binding)` -> `Thighs` -> `ANATOMY RULES` -> `Camera` -> `POSE, joint by joint` -> `Expression / Framing / Setting` -> хвост `v5f`. Все блоки собирает `tools/art/recipe_v6.py`; ниже дословно то, что стоит в коде (проверка `--selftest` падает, если текст здесь разойдётся с кодом).

### 2.1 Пропорции (на героиню)

```
Proportions (binding): adult woman, {heads} heads tall ({cm} cm, {tag}), a slightly larger head and shoulders, a compact torso and balanced proportions: the crotch line sits at about 46% of her total height and her leg length from crotch to floor is no longer than her shoulder-to-crotch length plus one head; {legs}; a mature adult face and figure, a defined waist, a full natural bust in proportion.
```

Рост выражается масштабом и кадром, не длиной ног. Запрещены слова `very long legs / long legs / elongating / statuesque / leggy / endless legs`. Допустимо: `proportionate legs`, `compact torso`, `balanced proportions`. Каблуки умеренные (court heels), шпильки добавляют 5-8 % к линии ноги: `adapt_outfit()` заменяет `stiletto` автоматически.

### 2.2 Анатомия и скрутка (дословно)

```
ANATOMY RULES: exactly two arms and two legs, two hands with five fingers each, two feet; no duplicated, extra or fused limbs; both legs clearly separate and countable; thighs full and soft but anatomically proportional: each thigh is narrower than the pelvis at the hip line and the two thighs together are never wider than the shoulders; knees and calves visible with a calf taper to the ankle; natural foot size, no exaggerated perspective on shins or feet. The body twist is physically continuous: pelvis, buttocks and legs rotate together with the torso, the spine twists gradually through waist and ribcage and only the head and neck turn further.
```

### 2.3 Камера (дословно)

```
Camera: portrait lens (long focal length) at hip height or higher, no wide-angle distortion, no from-below angle, the legs never enlarged by perspective.
```

Позиция камеры у каждой позы своя («camera directly behind her at hip height», «at her side (90 degrees)») и всегда **на уровне бёдер фигуры или выше**; поднятые колени и вытянутые ноги идут **вдоль** плоскости кадра (профиль), никогда на объектив (так делали Yue swim_C, Rin robe_C).

### 2.4 Правило покрытия по классу наряда (дословно; вставляется в `Outfit:` для поз, где бёдра в кадре)

Классы нарядов: `long` (длинное платье с разрезом), `mini` (юбка, платье, шорты, короткое кимоно), `leo` (леотард, боди, бодисьют, броня-леотард), `swim` (бикини/купальник), `robe` (халат-платье). Таблица классов по героиням и слотам: `assignments.json` (`outfit_classes`).

**long**
```
SLIT RULE: the long skirt panels always fall in place; the side slit opens no higher than the upper thigh and only the skin of the thigh shows through it; an opaque lining always covers the hip and the buttocks, from behind, from the side and in every pose; no bare skin of the hip or the buttocks is ever visible.
```
**mini**
```
HEM RULE: the opaque skirt or shorts hem always stays in place and fully covers the buttocks from behind, from the side and in every pose; no bare skin of the buttocks is ever visible and the skin between the hem and the stocking tops is only the thigh.
```
**leo**
```
LEOTARD RULE: the high-cut leotard is opaque and lined with a full-coverage seat that covers the whole buttocks; the cut at the hip shows only the outer flank, never a thong cut; no bare skin of the buttocks is ever visible, from behind, from the side or in any pose.
```
**swim**
```
SWIM RULE: the bikini or swimsuit bottoms are an opaque full-coverage cut with side ties at the hips that covers the whole buttocks in every pose, and the wet-look sheer sarong or shirt stays tied on; no bare skin of the buttocks is ever visible, from behind, from the side or in any pose.
```
**robe**
```
ROBE RULE: the satin robe stays belted by its sash and closed over the lined mini nightgown, the nightgown hem stays at mid-thigh, and the robe covers the hips and the buttocks from behind, from the side and in every pose; no bare skin of the buttocks is ever visible.
```

Дополнительно `adapt_outfit()` для поз, где виден тыл, колено или лежачее бедро, понижает разрез: `slit up to the hip` -> `slit up to the upper thigh` (причина: MC evening_C, критический дефект «бедро и ягодица голые через разрез»). Для микро-мини (Hana, Nova, Miel) правило проверено только на подоле «mid-thigh» из бейк-оффа: **первую партию мини-героинь пускать пилотом** (4 кандидата x 2 позы), см. раздел 6.

### 2.5 Бёдра: фраза на героиню

Базовая фраза: `full, soft, athletic-proportional thighs with a visible knee and a calf taper` (слово `balloon` не пишется, обратная формулировка не нужна). Пелвис шире бёдер, бёдра у́же линии таза, пара бёдер не шире плеч. Варианты в `recipe_v6.THIGH`: MC и Kohaku «lush but narrower than the hip line»; Miel «thick, shapely, soft; the hips are the widest point of the pear shape»; Zlata/Yue «balanced by broad shoulders»; Hana «strong, athletic-proportional, soft definition, defined calf taper»; Tsubame/Nova «slim, toned, shapely». Это дополнение к `FIGURE[героиня]` (обязательная фраза валидатора) в блоке `Body:`.

### 2.6 Негативные формулировки: что работает, а что нет

У `gpt_image_2_6` нет negative prompt; «no ...» внутри обычного текста работает, если рядом стоит позитивная замена.

| работает (проверено бейк-оффом) | слабо или вредно |
|---|---|
| `no duplicated, extra or fused limbs; both legs clearly separate and countable` | общие «perfect anatomy», «beautiful hands» (нет эффекта) |
| `exactly two arms and two legs, two hands with five fingers each` + в позе `(exactly two arms)` | «shorten the legs» / «narrower thighs» как правка готового кадра (слабо, 2 -> 2) |
| `no bare skin of the buttocks is ever visible` + явный подол «at mid-thigh» | слово `thong` и любые названия белья (не писать; ловится как риск модерации и как соблазн) |
| `no wide-angle distortion, no from-below angle` | `long legs`, `leggy`, «elongating»: прямо удлиняют ноги |
| `the twist is physically continuous: pelvis, buttocks and legs rotate together with the torso ... only the head and neck turn further` | описание позы одной строкой («looking back over her shoulder»): корпус повернут, таз и ноги смотрят в камеру |
| ноги «ALONG the image plane, never toward the camera» | `stiletto`, высокие шпильки (+5-8 % к ноге) |
| профиль для скрещенных ног, разнесённые «top thigh / lower thigh, visible gap at the shins» | скрещённые бёдра в фас (слияние в 10 кадрах) |
| опора предплечьями вместо «hands flat on the floor» | pose-манекен (2D), референс-картинки позы |

## 3. Библиотека поз (`pose_library.json`)

**65 поз.** Счёт по категориям: rear_hip 7, rear_lean 5, rear_walk 3 (всего «задних» по категории 15; с флагом `rear_emphasis` у лежачих, коленных и динамических задних поз **21**), leg_focus_seated 5, leg_focus_standing 5 (ноги 10), bust_focus 9, lying 7, kneeling 7, dynamic 12, portrait_tease 5. Требования задания (>= 48 поз; >= 12 задних, 8 ног, 8 груди, 6 лежачих, 6 коленных, 8 прочих) выполнены с запасом.

Поля позы: `id`, `name`, `category`, `camera` (позиция, высота), `joints` (`pelvis`, `spine`, `legs`, `arms`, `head`), `yaw_deg` (поворот от камеры: 0 фас, 90 профиль, 180 спиной; для оглядки pelvis >= shoulders >= head, голова поворачивается последней), `prompt` (готовый блок `POSE, joint by joint`), `framing`, `contexts` (indoor / bed / beach_pool / outdoor / stage), `prop` (мебель по контексту), `suited` (long/mini/leo/swim/robe: `ok` / `cond` / `no`), `unsafe_in_skirts`, `boldness` 1-5, `body_fit`, `failure_guards` (какие наблюдавшиеся дефекты поза страхует), `youth_risk`, `canon_ok`, `rear_emphasis`, `hips_in_frame`, `notes`.

Правила библиотеки:

* Камера всегда на уровне бёдер или выше, портретный объектив. Нет ракурса снизу, нет «под юбкой», нет «ног на объектив».
* Поза «на четвереньках» не используется (ART_TIER_FULL §3b). Коленный прогиб из бейк-оффа (ладони на полу) заменён опорой на пуф/кровать предплечьями (K02) и коленом на кровати лицом к изголовью (K05).
* **Небезопасные в юбке/шортах (`unsafe_in_skirts`, `suited.mini = no`):** T03 колено на стене, Y03 лёжа с поднятым коленом, K04 полуколено, K07 колено с откидом назад, D07 оседлать стул, D08 выпад, D09 прыжок, D11 присед. `cond` (допустимо только с правилом покрытия и бюджетом перебросов): все задние позы, наклоны вперёд, коленный прогиб, лёжа на боку/животе.
* Скрещивание ног есть только у S02 (в профиль, камера на 90 градусов); остальные позы ног разводят в разные колонны и называют обе стопы.
* Поднятая нога T02: стопа не выше колена опорной ноги; растяжка/прыжок только в профиль.
* Бюст-позы не требуют бёдер в кадре (`hips_in_frame = false`), правило покрытия не вставляется, но хвост «Garments ... stay exactly in place» остаётся. Вырез: «fingertip hooks the edge of the neckline trim without moving it» (рука на краю, ткань на месте).
* Позы «в подушку» (Y06) и side-sit (S04) помечены `youth_risk: low` и запрещены для нарядов, у которых уже есть юный признак (раздел 7). Не использовать: wariza (колени внутрь, стопы наружу), болтающиеся ноги на высоком стуле у петитных, пухлый «надутый» рот.

Распределение boldness (1-5): 3 у спокойных, 4 у большинства задних/ножных/грудных поз, 5 у предела внутри линий: L01 наклон над столом, Y01 боком бедро вверх, Y02 боком спиной, Y04 на животе, K02 прогиб с опорой, K05 на кровати спиной.

## 4. Назначения (`assignments.json`)

Решатель `tools/art/assign_poses.py` (имитация отжига, seed 2611, детерминированный) раздаёт 170 слотов: 3 канон-кадра (`canon_base`, `canon_win`, `canon_tease`) + 7 нарядов x 2 позы на каждую героиню. Жёсткие ограничения (проверяет `python tools/art/assign_poses.py --check`, сейчас `ASSIGNMENTS OK`):

a. у каждой героини **>= 3 слотов с акцентом на тыл** (фактически от 4 до 9: mc 7, rin 7, hana 4, yue 6, nova 4, tsubame 9, miel 4, kohaku 8, shirin 4, zlata 5);
b. в одном и том же слоте наряда (и в одном канон-слоте) **нет одинаковой позы у двух героинь**;
c. поза не повторяется у героини; две позы одного наряда из разных категорий;
d. поза не `no` для класса наряда и подходит окружению слота (по `setting`: indoor / bed / beach_pool / outdoor / stage; лёжа не на улице, качели не в бассейне и т. п.);
e. канон-кадры берут только позы с `canon_ok` для этого кадра; **`canon_tease` теперь поза с корректной скрутой/оглядкой или портрет** (ответ на отзыв владельца про Nova/Tsubame canon_tease);
f. юное правило: поза с `youth_risk != none` не ставится на наряд с юным признаком;
g. у каждой героини есть лёжа, коленная, ножная, грудная и динамическая; ни одна поза не используется больше 4 раз; **использованы все 65 поз**.

Мягкие цели: личность и рост (`PROFILE` в скрипте; Nova приседание/оседлать стул/колено на стене, Tsubame перила/стена/ходьба, Hana шаг/подъём ноги/растяжка, Yue реклайн, Miel грудь/колени/прилавок, Kohaku сейза/колени/лёжа, Shirin танец/side-sit/реклайн, Zlata ходьба/кресло/перила, Rin чай/профиль скрещенных/прилавок, MC стол/S-кривая), подходящесть категории слоту (swim -> лёжа и колени, robe -> лёжа, battle -> динамика и перила). Высота героини влияет на выбор через `PROFILE` и `PETITE` (петитные: Nova, Miel, Kohaku: без высокого стула с болтающимися ногами).

Итоговый счёт категорий по 170 слотам: dynamic 30, bust_focus 27, rear_hip 21, kneeling 20, lying 17, leg_focus_seated 15, rear_lean 14, leg_focus_standing 14, rear_walk 7, portrait_tease 5.

Применение: `python tools/art/recipe_v6.py --show <героиня> <слот> <idx>` печатает готовый промпт; `--dump out.jsonl` отдаёт все 170. Промпты 3.5-4.6 тыс. знаков (против 2.4 в бейк-оффе, лимит на длину у `gpt_image_2_6` в `models_explore` не указан; первый пилот подтвердит, что длина не вредит). Встраивание в JSON-батчи H1/H2 (`build_art_batches.py`) намеренно не сделано: это смена схемы задания (`prompt_variants` по 5 поз -> 2 позы x 4 кандидата) и решение лида.

## 5. Критик

`design/art_v6/CRITIC_CHECKLIST.md`: pass/fail по пропорциям (доля ноги <= 0.48 роста, торс не короче ног, головность 6.75-7.0, юное лицо = провал), числу конечностей, рукам, суставам, скрутке, бёдрам, скрещиванию ног, стопам, идентичности, жёстким линиям и смелости. Критику давать **полноразмерный кадр** и кропы рук/ступней/бёдер (в разборе 99 финалов смотрели на уменьшенных превью, это ограничение метода).

## 6. Пилот и порядок запуска

1. Пилот до 10 слотов x 4 кандидата = 40 кр, обязательно в составе: Hana base (шорты), Nova base (холо-мини), Miel base (мини), по одному `swim`, одному `robe`, одному `kneeling`, одному `rear_lean`, canon_tease Nova и Tsubame (жалобы владельца). Критерий: принято >= 70 % кандидатов по чек-листу, 0 нарушений жёстких линий, в каждом слоте хотя бы 1 принятый кадр из 4.
2. Если мини-слоты (Hana, Nova, Miel) дают прорыв подола: усилить правило фразой «the hem sits at upper-to-mid thigh in every pose» и использовать V4-правку подола.
3. Затем основной прогон по `assignments.json`; в каждом слоте: 4 кандидата, лучший идёт в final; отказ критика = переброс (1 кр); два провала подряд в слоте = замена позы на запасную из той же категории, правила покрытия не ослабляются.

## 7. Аудит «юных» признаков (комплаенс владельца: на наряд не более ОДНОГО)

Автоматический подсчёт по тексту нарядов (`assign_poses.youth_items`): признаки носки (`socks`), `shorts`, `pleated/skater`, `hoodie/oversize/puffer`, `badge`, `hair clip`, `freckles`, `sneakers`; плюс признаки героини, которые идут с каждым нарядом (Hana: веснушки и подсолнух-заколка, Miel: заколка-макарон).

| героиня | признаков на наряд (base / evening / swim / service / robe / battle / seasonal) | вывод |
|---|---|---|
| Hana | 5 / 2 / 2 / 3 / 3 / 3 / 4 | **нарушает** везде: уже веснушки + заколка = 2. Решение владельцу/лиду: оставить один признак (веснушки или заколка) и убрать носки/шорты/спортивные кроссовки в base, мини-юбку и худи в seasonal |
| Nova | 1 / 0 / 2 / 1 / 0 / 0 / 2 | swim (худи + значок-кот) и seasonal (носки + кроссовки) нарушают |
| Miel | 1 / 1 / 1 / 1 / 2* / 1 / 1 | на границе (* двойной счёт одной заколки); заколка-макарон и бант: оставить один |
| Rin, Tsubame, Kohaku | seasonal 1 | в норме |
| MC, Yue, Shirin, Zlata | 0 | в норме |

Рецепт этого документа **не меняет тексты нарядов** (это дизайнерское решение). Но он уже защищает: позы с `youth_risk` не ставятся на такие наряды, а критик проверяет «читается ли 24+». Критерий для Hana, Nova, Miel: сначала снять лишние признаки в таблице нарядов, потом генерировать.
Дополнительно: в `heroines_v2.json` у MC и Miel лицо описано как «rounded cheeks, big warm ... eyes», «round full-cheeked, large gentle amber eyes»; при головности 6.75-6.85 это риск юного лица. Рекомендация: заменить на «defined cheekbones», «almond eyes with adult makeup» либо усилить `mature adult face` взрослым макияжем в блоке `Face:`.

## 8. Честные оговорки

* Все числа бейк-оффа получены на одной героине (MC), одном наряде (qipao), одним оценщиком по 4-up превью. Поза ходьбы, бюст-фокус, портреты и 64 из 65 поз из этой библиотеки **не тестировались** генерацией; тексты поз написаны по принципам выигравшего V1h и по списку дефектов. Первая партия = пилот (раздел 6).
* Подол «mid-thigh» из бейк-оффа не совпадает с микро-мини Hana/Nova/Miel и с боди/купальниками: правила LEO и SWIM, и понижение разреза написаны по аналогии, не проверены.
* Каблуки и подол в V1h менялись вместе: вклад каждого не разделён. Мы сохраняем оба.
* Длина промптов выросла с 2.4 до 3.5-4.6 тыс. знаков; влияние не измерено.
* Назначение подбирается по эвристикам и ограничениям, а не по визуальной проверке: часть сочетаний (например, лёжа в зимней улице) отсечена по тексту `setting`, но тонкости сцены решает пилот.
* Тексты поз описывают позы на английском, а в `assignments.json` поле `prop` вставляется как «the pose uses <prop>».
