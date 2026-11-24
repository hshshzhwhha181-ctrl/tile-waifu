# POSES.md — библия поз и постановки 20 богинь

> **Статус:** 2026-11-24, утверждаемый черновик. Собран из черновиков поз по каждой богине и отзыва критика: исправлены все 45 групп столкновений, 16 замечаний «шаблонно / красная линия» и ещё 14 совпадений, найденных при сведении (итог в §0.6).
> **Опирается на:** `ROSTER_20.md` (id, роли, наряды), `ART_DIRECTION_v2.md` (рецепт стиля v4, правило камеры), `HEROINES.md` §4 (красные линии).
> **Правило владельца:** у двух богинь не может быть общей позы, окружения, света или подачи. Богиню узнают по силуэту и пластике, даже если закрыть лицо.

---

## 0. Правила

### 0.1 Правило уникальности

1. **Одна поза — одна богиня.** У каждой богини шесть слотов: `idle`, `select`, `win`, `lose`, `shy`, `tease`. У каждого слота есть **ключ силуэта** (таблица §0.5). Если две позы совпадают по силуэту в миниатюре 64×114, одна из них переделывается. Разный реквизит при том же силуэте совпадением считается.
2. **Пластика идёт от характера и профессии.** Чайный мастер — вертикаль и неподвижность, бегунья — выпады и прыжки, фигуристка — позиции и скольжение. Сначала решаем, *почему* она так стоит, и только потом *как*.
3. **У каждой свой словарь ног** (§0.4). Чужой приём не берём, даже ради разнообразия.
4. **Окружение, свет и кадр тоже уникальны** (таблица §0.5). Повторы, которые критик нашёл и закрыл:
   - зима только у Сигрид;
   - луна только у Юэ;
   - крыша только у Цубамэ;
   - бумажные фонари только у МТ (сакура), каменные фонари только у Кохаку;
   - пар как среда (клубы пара, чугунный чайник на огне) только у Цуру. Тонкая струйка над пиалой — канон-комбо Рин, только у неё;
   - голландский наклон только у Мари;
   - низкий ракурс только у Киры;
   - выход за рамку только у Хибаны;
   - рамка из двух столбов только у Кохаку;
   - строгая фронтальная симметрия только у Златы;
   - полный рост по умолчанию только у Неми, Минамо и Сигрид.
5. **Мимика тоже распределена:**
   - **подмигивание** — МТ (только `select`), Кохаку, Джесс;
   - **надутые щёки** — Миэль, Минамо, Хибана;
   - **взгляд на игрока сверху вниз** — Веспер и Неми. Юэ смотрит мимо игрока, вдаль. Цуру смотрит глаза в глаза.
   - Остальные используют свои фирменные выражения из карточек.
6. **«Взрыв частиц» на победе** есть только у Кохаку (лисьи огни) и Ширин (монеты). Веспер, Злата и Цубамэ получают лёгкий акцент: несколько лепестков, искр или писем, а не вихрь.
7. **Вращение — только стоп-кадр.** Позы Юэ `select`, Ширин `win`, Сигрид `win` и Минамо `tease` — это замороженный момент поворота. Движение передают рукава, волосы, лента и монеты, а подол обёрнут вокруг ног и не поднимается. В видео spin не анимируем (ROSTER §4.3).

### 0.2 Как пользоваться в промптах

Промпт из `ROSTER_20.md` §2.1 собирается так:

`twaifu_<id>, adult woman, <возраст>, <роль>, ` + **V4_FACE** + `<выражение>, ` + **ТЕЛО** (облик и наряд из карточки) + **ПОЗА** (EN-фраза слота отсюда) + `background: ` **ОКРУЖЕНИЕ** EN + **СВЕТ** EN + **КАДР** EN + **V4_TAIL**.

- Выражение лица в EN-фразе позы **заменяет** выражение из карточки, если они спорят.
- Строка **КАДР** заменяет общий `knees-up three-quarter view, eye-level camera`. В V4_TAIL этой фразы больше нет.
- Реквизит позы должен быть в руках, а не «где-то в кадре». Модель сама переставляет предметы.
- Для видео Kling: опорный кадр = поза из этого файла, привычки из строки «Анимация» идут в `{фирменный жест}` шаблона idle-петли (ROSTER §4.3).

### 0.3 Красные линии (без исключений)

Из `HEROINES.md` §4 и `ART_DIRECTION_v2.md`:
- все богини явно взрослые: в промпте `adult woman`, зрелое лицо, 7,5 головы;
- нет наготы, белья как наряда, просвечивающей ткани на интимных зонах (прозрачный легвир в APK разрешён по `LEGWEAR.md` §1; лиф, бёдра под юбкой и юбка всегда непрозрачны), сексуальных действий и их имитации;
- нет школы и «учитель — ученик»;
- **позы:** нельзя лёжа, на четвереньках, с прогибом спины, ноги врозь к камере, тянуть ворот или подол, «прикрываться», сидеть на столе;
- **камера:** на юбках и платьях не ниже уровня талии, наклон вверх не больше 10°. Низкий ракурс только в брюках, комбинезоне или доспехе (у нас это Кира). Нет камеры, которая разглядывает тело, нет крупных планов груди, ягодиц и паха, нет ракурса «под юбку»;
- **спиной к камере** — кадр выше талии;
- **сидя** — колени вместе, ноги уведены вбок, камера на уровне её глаз. «Колени вместе вбок» — это техника безопасности, а не поза: уникальность сидячей позы задают опора и верх тела;
- ветер треплет волосы, ленты и рукава, но **не подол**;
- рука на бедре анфас, «фишка в поднятой руке» и A-поза не используются (ART_DIRECTION §2).

### 0.4 Правило «две ноги явно» и словарь ног

**В каждой EN-фразе положение обеих ног (и обеих стоп) названо явно.** Если оставить ноги на усмотрение модели, она сама скрестит их, расставит к камере или подогнёт одну внутрь. Шаблон: `left leg … , right leg … , left foot … , right foot …`. Если ноги вне кадра (кадр выше талии) или закрыты предметом, это тоже пишется явно: `cropped above the waist` или `legs hidden behind the drum`. Хвосты в промпте обязательны: `hem stays in place`, `slit unchanged`, `camera at her eye level`.

| Богиня | Словарь ног (чужое не брать) |
|---|---|
| mc | колено внутрь и поднятая пятка (ревнивое смущение); широкая стойка по боковой оси; бедро на краю стола |
| rin | прямые параллельные ноги, стопы вместе; нога на ногу только на высоком табурете |
| hana | спортивные стойки: выпад, растяжка, прыжок, бег спиной вперёд |
| yue | длинные скрещивающиеся «скольжения», носок вытянут, S-линия |
| nova | вес свален на одно бедро, носок ботинка отбивает ритм, корточки |
| tsubame | края и высота: стопа перед стопой, носки, приземление на колено |
| miel | пятка выскальзывает из туфельки, подскок на носках, коленки трутся |
| lian | мелкие шаги, стопы близко, шаг в разрез в профиль |
| jess | сапоги широко и впечатаны, каблук вбит в землю |
| tsuru | гэта вместе, носок гэты на переднем зубце, сэйдза, мелкий шаг |
| kohaku | лисья косолапость (носки внутрь, стоя), подброшенная пятка, ступени |
| shirin | релеве на полупальцах, перекат с пятки на носок, ёкодзувари |
| mari | широкая морская стойка под качку; сапоги вместе «смирно», когда смущена |
| hibana | пружинит на носках, топ на сильную долю; носки внутрь — только сидя в тишине |
| nemi | неподвижные вертикали: поза дерева, стойка лучника |
| zlata | симметрия на обеих ногах; плясовой «каблучок» носком вверх |
| minamo | не касается опоры: ноги вместе, как русалочий хвост |
| kira | угловатая уставная пластика: щелчок каблуков, стрелковая стойка, ботинок на броне |
| vesper | балетный тандю, придворный реверанс, длинная диагональ |
| sigrid | позиции фигуристки: Т-позиция, скольжение, перебежка, аттитюд, вращение |

### 0.5 Таблица уникальности

**Ключи силуэтов** (по ним проверяем новые наряды и позы):

| id | idle | select | win | lose | shy | tease |
|---|---|---|---|---|---|---|
| mc | table-hip-lean-tile-twirl | wide-side-stance-tile-flick | table-slam-flourish | arms-crossed-tile-fist-turnaway | sleeve-tug-twin-tail-wind | armrest-perch-tile-shh |
| rin | tall-stool-cross-hooked-foot | high-pour-between-shelves | formal-half-bow-parallel | fogged-lenses-push-up | ladder-rung-knuckle-glasses | slide-bowl-over-glasses |
| hana | one-leg-quad-stretch | lunge-high-five | airborne-fist-knee-tuck | hands-on-knee-panting-point | triceps-stretch-hide | backward-jog-beckon |
| yue | fan-at-lips-s-curve | water-sleeve-spiral | seated-on-crescent-moon | lean-in-hands-behind-curious | full-fan-face-shield | balustrade-step-fan-chin-lift |
| nova | air-typing-slouch | bike-sidesaddle-knees-together | mic-drop-tile | side-crouch-poke-cable | popup-panic-swipe | cable-hang-heart-lure |
| tsubame | ridge-tightrope-read-letter | profile-tuck-leap-letter | ridge-one-knee-landing | roof-slope-knees-up-retie | letter-for-me-arms-length | tiptoe-dodge-letter-high |
| miel | bowl-on-hip-whisk | piping-cupcake-hip-sway | tray-forward-curtsy-dip | souffle-horror-hands-cheeks | cakebox-hug-chin-on-lid | across-counter-spoon-say-ahh |
| lian | silk-stool-upright-pipa | glowstring-draw-feet-close | final-strum-arm-arc | forehead-on-pillar | snapped-string-flinch | profile-over-shoulder-slit-step |
| jess | fence-forearms-ankles-crossed | boots-planted-thumb-belt-brim | lasso-loop-overhead-hat-slap | lasso-hop-windmill | hat-down-neckrub-boot-scuff | lasso-catch-pull-heel-dug |
| tsuru | doorframe-sleeves-geta-tooth | noren-part-palm-up-welcome | pingpong-smash | tenugui-taut-foot-stamp | folding-crane-busy-hands | seiza-cushion-pat-invite |
| kohaku | stair-split-level-wand-yoke | pillar-peek-tail-gives-away | airborne-heels-back-sleeves-flared | steps-legs-long-tail-hug | head-offer-pigeon-toe-tail-wag | lean-in-fox-sign-heel-flick |
| shirin | lamp-on-head-snake-arms | promenade-veil-sweep | pirouette-retire-coin-spray | cushion-side-fold-forearm-brow | coin-strand-curtain-peek | ankle-cross-own-palm-trace |
| mari | boot-on-rail-shroud-grip | tea-chest-point-horizon | rope-swing-boot-hooked | mast-sit-legs-long-hat-tipped | tricorne-over-heart-attention | wheel-hat-offer-heel-propped |
| hibana | bounce-air-roll-elbows-out | kamae-lunge-stick-sky | odaiko-overhead-strike | slumped-over-odaiko | low-drum-sit-toes-in | oni-horns-side-knee-pounce |
| nemi | tree-pose-bow-planted-leaf-catch | full-draw-side-stance | bow-horizontal-bird | trunk-hug-slide-dango | ears-pulled-down | looming-headpat |
| zlata | frontal-mantle-braid-candle | folk-heel-step-arm-sweep | sunburst-V-tiptoe | wet-firebird-cape-drooped | turnaway-dip-pancake-plate | lean-back-braid-ribbon-pull |
| minamo | upright-float-mermaid-legs | prone-float-peek-hands-cupped | turtle-ride-shawl-sail | side-curl-cocoon-drift | clam-shell-lid-peek | slow-spin-empty-box |
| kira | lean-back-boot-on-armor-helmet-spin | narrow-shooter-finger-gun | mech-palm-V-sign | soot-smoking-helmet | rigid-attention-salute | hatch-standing-headset-pendulum |
| vesper | chaise-upright-legs-long-rose | tendu-lace-parasol | deep-court-reverence | swoon-lean-harpsichord | ventriloquist-plush-bat | bench-glove-bite-knees-aside |
| sigrid | skater-T-tiara-touch-mug-at-waist | crossover-glide-carriage-arms | scratch-spin-wrists-crossed | slipped-sit-on-ice-profile | behind-ice-pane-frost-flower | glide-attitude-blow-snowflake |

**Сцена, свет и кадр:**

| id | Окружение | Свет | Кадр |
|---|---|---|---|
| mc | салон «Пять ветров», стол с сукном | только фонари сакуры, поздний вечер, нефритовый отсвет сукна | взгляд соперника через стол, сукно на переднем плане |
| rin | чайная библиотека «Ледяного павильона» | пасмурный полдень, ровный северный свет из фонаря в крыше | правая треть, сильные вертикали, пустота над головой |
| hana | стадион эстафеты, прожекторные мачты | закат, контровое солнце | от колен, проводка камерой, горизонтальный смаз |
| yue | терраса Лунного дворца над облаками | полнолуние, серебряный контровой | диск луны нимбом, она в верхних 2/3 |
| nova | гараж-мастерская под эстакадой | только экраны и голограммы снизу | ровно, «экран в экране», от середины бедра |
| tsubame | верх почтовой башни над каналами | безлунная ночь, подсветка тумана снизу, алая лампа | ровно, ультравертикаль, огромное пустое небо |
| miel | кухня-витрина кондитерской | утреннее солнце в окно, отсвет печи | взгляд покупателя через прилавок, +10° |
| lian | музыкальная баржа, лаковый помост | коралловые свечи-лотосы на воде снизу | вне центра, сквозь нити бусин |
| jess | загон у чайного каравана | жёсткий полдень сверху, марево | «ковбойский» кадр от середины бедра |
| tsuru | комната с очагом в рёкане | осеннее солнце полосами сквозь сёдзи, очаг | высота сидящего гостя, решётка сёдзи |
| kohaku | лестница-тоннель тысячи ториев | ночь, точечные лисьи огни | кадр в кадре из столбов тории |
| shirin | шатёр гадалки изнутри | синий час, медные лампы, бирюза из полога | арка цепей ламп вне центра |
| mari | бак чайного клипера в шквал | дневной прорыв солнца, брызги | голландский наклон, 28 мм |
| hibana | барабанная башня над чайными террасами | гроза, жёлтые молнии | экшен, выход за рамку |
| nemi | крона исполинских чайных деревьев | осеннее утро, пятнистые лучи | полный рост, телевик 85 мм |
| zlata | резное гульбище терема над рекой | весенний рассвет сквозь резьбу | строгая фронтальная симметрия, рама наличника |
| minamo | жемчужный грот под колодцем | полуденный столб солнца сквозь воду | полный рост, дрейф в кадре |
| kira | двор чайного домика с рухнувшим мехом | натриевые прожекторы, алый строб | низкий ракурс, ровный горизонт |
| vesper | музыкальный салон замка | только свечи, рубиновый витраж от огня снаружи | длинная диагональ, портьера на переднем плане |
| sigrid | замёрзшее горное озеро | полярная ночь, рим сияния | профиль, следящая камера, пустой лёд |

### 0.7 Ножки и горячие жесты

Легвир всех нарядов (коды `LW01…LW87`), ножные и «горячие» жесты, правки поз-витрин и `allure` — в **`LEGWEAR.md`** (источник правды по ногам, заменяет `POSES_HOT.md` §5). В каждой карточке ниже строка «Ножки и горячие жесты» даёт id жестов богини. Жесты стоп (`framing: full`) играют только в кадре «В рост», `allure`, выборе наряда, галерее, раскрытии, победе и ульте. `leg_recross`, `ankle_swap`, `kick_back`, `calf_glide` — только видео.

### 0.6 Что исправлено

- **45 групп столкновений критика** (30 по позам и привычкам, 4 по окружению, 5 по свету, 6 по кадру) и **16 замечаний** «шаблонно / красная линия». Решения критика приняты, где он оставлял позу одной богине.
- **14 совпадений, найденных при сведении:**
  1. «каблук вперёд, носок вверх» у Джесс `select` и Златы → это плясовой «каблучок», он остаётся Злате;
  2. табурет-барабан у Лянь `idle` и Хибаны `shy` → Лянь сидит на шёлковом пуфе;
  3. «пятки вместе, носки врозь» у Рин `win`, Неми `win` и Киры `shy` → остаётся только Кире, по уставу;
  4. выход за рамку у Ханы и Хибаны → только у Хибаны;
  5. МТ `tease` сидела на столе (красная линия) → присела на подлокотник;
  6. Веспер `idle` полулёжа (красная линия «лёжа») → сидит прямо;
  7. Кира `lose` распласталась на спине (красная линия) → закопчённый дымящийся шлем;
  8. рука на бедре анфас у Киры `win` и Мари `select` → шлем у бедра и большой палец за кушаком;
  9. каменные фонари во дворе Киры совпадали с Кохаку → опрокинутая каменная чаша и бамбуковая изгородь;
  10. Сигрид `idle`: обнять себя от холода — это «прикрываться», а «дышать в ладони» дублировало её `tease` → касается тиары, кружка у талии;
  11. Минамо `win` (шаблон «тянется к свету») → верхом на морской черепахе;
  12. Ширин `idle` (шаблон «змеиные руки») → масляная лампа на голове, как в танце с подсвечником;
  13. Сигрид `select` (шаблон «скольжение») → перебежка фигуристки;
  14. длинноносый чайник Рин и чугунный чайник Цуру → у Рин латунный сосуд для налива, у Цуру чайник на огне; «взгляд свысока» у Новы `win` убран.

---

## 1. mc — Маджонг-тян · хозяйка салона

**Пластика.** Хозяйка за своим столом. Всё время опирается на стол, стул или край сукна, вес тела подан к игроку. Двигается бодро и театрально, руки всегда при деле: фишка катается по костяшкам, пальцы отбивают ритм по сукну. Высокие хвосты подпрыгивают при каждом переносе веса. Ревнует всем телом: разворачивается плечом, отводит стопу «уйти», а потом тут же снова тянется к игроку.
**Ноги.** Колено внутрь и поднятая пятка (только в ревнивом смущении), широкая стойка по боковой оси, бедро на краю стола.
**Реквизит.** Пустая фишка из слоновой кости (東 накладывается кодом), стол с зелёным сукном, резной стул салона, нефритовые узлы на хвостах, ветка сакуры в нефритовой вазе, четыре колокольчика ветров.

**Позы**

1. **idle** · `table-hip-lean-tile-twirl` — Стоит у угла стола, правым бедром опирается о край. Левая нога прямая и держит вес, правое колено согнуто и чуть повёрнуто внутрь, носок у левой пятки. Левая ладонь лежит на сукне позади, правая крутит фишку у груди.
   `standing at the corner of a mahjong table with her right hip resting against the table edge, left leg straight bearing her weight, right knee bent and turned slightly inward with the toe of the right pink pump touching the floor beside her left heel, left palm flat on the green felt behind her, right hand twirling a blank ivory tile between thumb and two fingers at chest height, head tilted toward her right twin tail, relaxed confident smile, eyes on the viewer`
2. **select** · `wide-side-stance-tile-flick` — Канонический щелчок 東. Стоит боком к столу в широкой стойке по боковой оси кадра (не к камере), ноги прямые. Корпус развёрнут к игроку, щелчком отправляет фишку в камеру, левой ловит кончик хвоста. Её единственное подмигивание.
   `standing side-on to the mahjong table in a wide planted stance, feet set wide apart on a line parallel to the table edge and not toward the camera, both legs straight with her weight centered, torso twisted to face the viewer, right arm extended flicking a blank ivory tile off her thumb so it spins toward the camera, left hand catching the end of her left twin tail at shoulder height, playful wink with a confident smile`
3. **win** · `table-slam-flourish` — «Партия окончена~». Наклонилась над столом, ладонью припечатала фишку к сукну, левая рука взлетела вверх веером пальцев. Ноги прямые на ширине бёдер, обе пятки на полу, бедро подано к столу. Хвосты разлетаются дугой, она смеётся.
   `leaning over the mahjong table from its side, right palm slamming a blank ivory tile flat onto the green felt, left arm thrown high with fingers spread in a flourish, both legs straight at hip width with both heels on the floor, hip pushed toward the table edge, twin tails swinging out in an arc, triumphant open-mouth laugh, eyes on the viewer`
4. **lose** · `arms-crossed-tile-fist-turnaway` — «Ещё.» Руки туго скрещены, фишка зажата в кулаке под локтем. Вес на левой ноге, бедро вбок, правая стопа развёрнута носком прочь, будто сейчас уйдёт. Исподлобья косится в сторону, нижняя губа надута.
   `standing with her arms folded tightly across her waist, a blank ivory tile squeezed in her right fist tucked under her left elbow, weight on her straight left leg with the hip cocked to the side, right leg straight with the right foot turned outward and pointing away as if about to leave, chin down, glaring sideways from under her bangs, pouting lower lip, muttering 'again'`
5. **shy** · `sleeve-tug-twin-tail-wind` — Ревнивое смущение. Стоит вполоборота, правой рукой двумя пальцами держит невидимый рукав игрока у нижнего края кадра, левой наматывает хвост на палец. Колени соприкасаются, правая пятка поднята. Лицо отвёрнуто, щёки красные, глаза возвращаются к игроку.
   `standing turned three-quarters away, right arm reaching toward the viewer and pinching an unseen sleeve between thumb and finger at the lower frame edge, left hand winding the tip of her left twin tail around her index finger, knees touching, left leg straight, right heel lifted with only the toe of the right pump on the floor, face turned aside with a jealous pout and blush, eyes flicking back to the viewer`
6. **tease** · `armrest-perch-tile-shh` — Присела боком на подлокотник резного стула. Колени вместе и уведены влево, стопы рядом, правый носок вытянут. Фишка прижата к губам, как секрет: «Тсс, это между нами».
   `perched sideways on the armrest of a carved salon chair, upper body upright, both knees together angled to her left, both feet side by side on the floor with the right toe pointed, left hand resting on the chair backrest, right hand pressing a blank ivory tile against her lips like a secret, sly half-lidded smile, eyes on the viewer, camera at her eye level, hem and slit stay in place`

**Окружение.** Салон «Пять ветров» на перекрёстке миров: тёплое вишнёвое дерево, решётчатые окна в ночь, стол с зелёным сукном и стенкой фишек, резные стулья, фонари из бумаги цвета сакуры, четыре колокольчика ветров, ветка сакуры в нефритовой вазе, лепестки на сукне.
`background: the Five Winds mahjong salon at late evening, warm cherry-wood interior, lattice windows onto the dark night, green-felt mahjong table with a wall of blank tiles, carved salon chairs, sakura-pink paper lanterns, four wind chimes hanging from the ceiling, a sakura branch in a jade vase, petals on the felt, muted`
**Свет и палитра.** Поздний вечер, солнца нет. Ключевой свет — только бумажные фонари сакуры, плюс нефритовый отражённый свет от сукна снизу. Hex: ffc9a8 (тёплый фонарь), ff8fb8 (сакура), 3fae8c (нефритовый отсвет).
`lit only by sakura-pink paper lanterns, warm pink-amber key, soft jade-green bounce light from the felt below`
**Кадр.** Взгляд соперника через стол: внизу кадра всегда сукно, стенка фишек или спинка стула. Камера на высоте глаз сидящего игрока (на уровне её ключиц), вверх не больше 5°. От колен, она по центру или чуть правее, хвосты уходят за верхний край.
`opponent's point of view across the mahjong table, green felt and a wall of blank tiles in the lower foreground, camera at a seated player's eye level, tilt up under 5 degrees, knees-up, she is centered or slightly right, twin tails crossing the top edge`
**Анимация.** Перекатывает фишку по костяшкам, стучит ею по краю стола «раз-два», хвосты пружинят при переносе веса, ревниво косится за край кадра и тут же возвращает взгляд, привстаёт на носки в азарте.
**Ножки и горячие жесты** (`LEGWEAR.md` §3, §4.3 п. 1): LW01–LW07; витрина `select`, `tease`. Жесты: `mc.knee_in_heel` (18+), `mc.shoe_dangle` (18+), `mc.table_hip_slide`, `mc.scale_glint`, `mc.ribbon_tug`; у всех также `leg_idle`, `sheen_sweep`, `ornament_sway`.
**Взгляд через плечо:** только в `o_dragon` — уходит по алой дорожке, раскрытый веер за головой (кадр выше талии).

---

## 2. rin — Рин · мастер чая

**Пластика.** Вертикальная, неподвижная, экономная. Спина прямая, локти прижаты, ноги прямые и параллельные: говорят руки и взгляд поверх очков. Двигается вдвое медленнее остальных. Смущение выдаёт одна деталь: костяшка поправляет очки, лицо отворачивается.
**Ноги.** Прямые и параллельные, стопы вместе. Нога на ногу — только на высоком табурете.
**Реквизит.** Селадоновая пиала, латунный сосуд с длинным носиком для налива с высоты (не висящий чайник), тонкие круглые золотые очки, банки чая, библиотечная лестница на колёсах, латунные весы, нефритовые серьги-капли.

**Позы**

1. **idle** · `tall-stool-cross-hooked-foot` — Сидит прямо на высоком табурете у длинной стойки, нога на ногу: левая поверх правой, правая стопа зацеплена за кольцо-подножку, обе туфли на ногах. Пиала на колене, над ней тонкая струйка пара.
   `perched upright on a tall pale-wood stool at a long library counter, legs crossed at the knee with the left leg over the right, right foot hooked on the stool's footrest ring, left foot hanging still, both low shoes firmly on, both hands cradling a celadon bowl on her knee with a thin wisp of steam, spine straight, dark-green side braid over her left shoulder, composed half-smile, calm eyes on the viewer, camera at her eye level, hem stays in place`
2. **select** · `high-pour-between-shelves` — Налив с высоты между двумя стеллажами до потолка. Тонкая вертикаль: ноги прямые, стопы вместе. Левая рука поднимает латунный сосуд на высоту плеча, правая держит пиалу у бедра, между ними длинная дуга чая.
   `standing between two floor-to-ceiling shelves of tea tins in a slim vertical line, both legs straight and parallel with the feet together, left hand lifting a long-spouted brass pouring vessel to shoulder height, right hand holding a celadon bowl low at hip height, a long thin arc of tea falling between them without a splash, eyes glancing at the viewer over her gold glasses, quiet focused expression`
3. **win** · `formal-half-bow-parallel` — «Позволь.» Формальный чайный полупоклон: стопы вместе и параллельны, корпус наклонён от бёдер на 20° с прямой спиной, правая ладонь поверх левой у талии, коса качнулась вперёд.
   `formal tea-ceremony half-bow: standing with both legs straight and the feet together and parallel, upper body inclined about twenty degrees forward from the hips with a straight back, right hand laid over the left hand at her waist, side braid swinging forward over her left shoulder, eyes raised to the viewer above her thin round gold glasses, small satisfied smile`
4. **lose** · `fogged-lenses-push-up` — «…Ещё раз.» Стоит прямо и узко, стопы вместе. Смотрит в пиалу у груди, очки запотели белым, одним пальцем поднимает их на лоб и щурится.
   `standing upright and narrow with both legs straight and the feet together, left hand holding a celadon bowl at chest height and staring into it, right index finger pushing her fogged-white glasses up onto her forehead, squinting without them, quiet defeated frown, lips set in 'once more'`
5. **shy** · `ladder-rung-knuckle-glasses` — На второй ступени библиотечной лестницы, почти в профиль. Обе стопы на одной ступени, ноги прямые и вместе. Левой держится за поручень, костяшкой правой поправляет очки, банка чая прижата к боку. Румяная щека повёрнута к игроку.
   `standing two rungs up on a rolling library ladder in near profile, both feet side by side on the same rung, both legs straight and together, left hand gripping the ladder rail, right knuckle pushing her glasses up her nose, a tea tin tucked against her side, cheek turned toward the viewer to show a deep blush, eyes sliding sideways to the viewer, flustered closed-mouth smile, camera at her eye level, hem stays in place`
6. **tease** · `slide-bowl-over-glasses` — Стоит прямо у торца стойки, правая стопа на полшага впереди. Двумя пальцами двигает пиалу по стойке к игроку, голова опущена, взгляд поверх очков, бровь приподнята.
   `standing upright at the end of the counter, both legs straight and parallel with the right foot half a step ahead, sliding a celadon bowl across the counter toward the viewer with two fingertips of her right hand, left hand resting flat on the counter, head lowered to look at the viewer over the top of her gold glasses, one eyebrow raised, knowing half-smile`

**Окружение.** Чайная библиотека «Ледяного павильона». Название — метафора холодной тишины: инея и снега нет. Стеллажи до потолка с банками чая, библиотечная лестница на колёсах, латунные весы, длинная стойка светлого ясеня, селадоновая посуда, фонарь в крыше.
`background: a tall scholar's tea library, floor-to-ceiling shelves of unlabeled tea tins, a rolling library ladder, brass scales, a long pale-ash counter, celadon ware, a skylight in the ceiling, quiet orderly vertical architecture, muted`
**Свет и палитра.** Пасмурный полдень, ровный холодный северный свет из фонаря в крыше, почти без теней, «интеллектуальная» ясность. Тёплые только блики на оправе и чае. Hex: f1efe8 (бумага), 4fbf9f (нефрит), e9d8a6 (золото оправы).
`cool even north light from an overcast skylight at noon, crisp and nearly shadowless, the only warm notes are the glint on her glasses and the tea`
**Кадр.** Вне центра, на правой трети. Сильные вертикали стеллажей параллельны краям кадра, над головой много пустого пространства, это подчёркивает рост. Камера ровно на уровне глаз, от середины голени.
`she stands on the right third, strong vertical shelf lines parallel to the frame edges, tall empty space above her head, camera level at her eye height, framed from mid-shin`
**Анимация.** Моргает вдвое реже остальных; струйка над пиалой закручивается; подносит пиалу к губам и опускает, так и не отпив; блик скользит по очкам; перебирает кончик косы; сидя раз неторопливо перекладывает ногу.
**Ножки и горячие жесты** (`LEGWEAR.md` §3, §4.3 п. 2): LW08–LW14; `idle` статичен, `allure` стоя между стеллажами. Жесты: `rin.leg_recross` (18+, V, только r_after), `rin.shoe_dangle` (18+), `rin.seam_glance`, `rin.over_glasses`, `rin.idol_ankle_bow`; у всех также `leg_idle`, `sheen_sweep`, `ornament_sway`.
**Взгляд через плечо:** только в `r_agent` — очки вспыхивают, как прицел (кадр выше талии).

---

## 3. hana — Хана · капитан эстафеты

**Пластика.** Сплошная кинетика: пружинит на носках, движения широкие, тело наклонено по диагонали, будто сейчас сорвётся с места. Стоит в спортивных стойках, а не в позах моделей, руки работают как у бегуньи. Смущаясь, прячется за «растяжкой».
**Ноги.** Выпад, растяжка, прыжок, бег спиной вперёд.
**Реквизит.** Подсолнух, эстафетная палочка-фонарик, секундомер на шнурке, куртка на поясе, напульсник, заколка-подсолнух.

**Позы**

1. **idle** · `one-leg-quad-stretch` — Растяжка квадрицепса: стоит на прямой левой, правой рукой держит правую щиколотку у бедра, левая рука с подсолнухом над головой.
   `standing quad stretch: balancing on her straight left leg, right knee bent behind her with her right hand holding her right ankle up near her hip, left arm stretched overhead holding a sunflower for balance, slight forward lean, wavy orange bob bouncing, cheerful competitive grin at the viewer`
2. **select** · `lunge-high-five` — «Дай пять» в беговом выпаде к игроку. Единственная ладонь, раскрытая прямо в объектив.
   `running lunge toward the viewer for a high five: right leg forward with the knee bent over the foot, left leg extended straight behind on the ball of the foot, torso leaning forward, right palm raised open toward the camera at face height, left arm swung back, sleeves of the track jacket tied at her waist flying, bright grin, eyes locked on the viewer`
3. **win** · `airborne-fist-knee-tuck` — Победный прыжок: левое колено поджато, правая нога тянется вниз, правый кулак в небо. Единственный «прыжок с кулаком».
   `airborne victory jump: both feet off the ground, left knee tucked up high in front of her, right leg trailing straight down with the toe pointed, right fist punched straight up into the sky, left arm bent with the elbow pulled back, bob and jacket sleeves flying upward, head thrown back in a laughing shout`
4. **lose** · `hands-on-knee-panting-point` — «Реванш! Сейчас же!» Сложилась вперёд, левая ладонь на колене, правой тычет в игрока. Единственное «требую реванш» пальцем.
   `catching her breath in three-quarter view: feet shoulder-width apart along the side axis, both knees bent, body folded forward from the hips with a straight back, left hand braced on her left knee, right arm extended pointing a finger straight at the viewer, flushed cheeks, gritted-teeth determined frown, shouting for a rematch`
5. **shy** · `triceps-stretch-hide` — Делает вид, что тянет трицепс: правая рука согнута за головой, левая тянет локоть. Лицо прячется за поднятым локтем, она подглядывает из-под него и пружинит на носках.
   `pretending to stretch: right arm bent behind her head with the right hand between her shoulder blades, left hand pulling her right elbow so her face hides behind the raised elbow, peeking out from under it with a deep blush and darting eyes, both feet together bouncing lightly on the balls of her feet, both knees soft`
6. **tease** · `backward-jog-beckon` — «Догони!» Бежит спиной вперёд от игрока, манит двумя пальцами.
   `jogging backward away from the viewer in three-quarter view, legs mid-stride with the left foot pushing off on its toes and the right foot reaching back, beckoning the viewer with two fingers of her right hand, left arm swinging, cheeky grin as if saying 'catch me'`

**Окружение.** Стадион фонарной эстафеты на закате: рыжая дорожка с белой разметкой, прожекторные мачты (фонарей на шестах нет), трибуны, финишная лента, ведро подсолнухов у скамьи тренера, бутылка воды без логотипа.
`background: relay stadium at sunset, rust-red running track with white lane lines, tall floodlight towers just switching on, bleacher benches, a finish ribbon, a bucket of sunflowers by the coach's bench, an unbranded water bottle, muted`
**Свет и палитра.** Золотой час: низкое солнце в контровом, волосы горят оранжевым ореолом, спереди мягкая заливка прожекторов. Hex: ffb35c (солнце), 2b4a7a (тёмно-синее небо и рим), fff1d6 (тёплая заливка).
`golden-hour sunset backlight, glowing orange halo on her hair, soft floodlight fill from the front`
**Кадр.** Спортивная проводка: кадр от колен, камера ведёт её, фон смазан по горизонтали. Горизонт ровный, на уровне глаз.
`sports panning shot, knees-up, background streaked with horizontal motion blur while she stays sharp, level horizon, eye-level camera`
**Анимация.** Пружинит на носках, встряхивает каре и смеётся, крутит подсолнух за стебель, косится на секундомер, вращает стопу, разминая щиколотку.
**Ножки и горячие жесты** (`LEGWEAR.md` §3, §4.3 п. 3): LW15–LW21; витрина `idle`. Жесты: `ha.sock_pullup`, `ha.bounce_toes`, `ha.heel_wobble`, `ha.kick_back` (V), `ha.tape_press`, `ha.lunge_lean` (таз в профиль); у всех также `leg_idle`, `sheen_sweep`, `ornament_sway`.
**Взгляд через плечо:** нет.

---

## 4. yue — Юэ · правительница Лунного дворца

**Пластика.** Медленная, царственная, никогда не спешит. Подбородок поднят, взгляд **мимо игрока, вдаль**, движения плавные, будто гравитация ослаблена. Говорит веером, а не руками. Не садится на мебель: парит или стоит. Любопытство (`lose`) — единственный момент, когда она смотрит прямо на игрока.
**Ноги.** Длинные скрещивающиеся скольжения, носок вытянут, придворная S-линия. Это единственный контрапост с носком в ростере.
**Реквизит.** Складной веер со звёздами, светящийся серебряный полумесяц-сиденье, тиара-полумесяц, маленькие рожки, ветка османтуса, серебряные колокольчики, длинные рукава-шуйсю.

**Позы**

1. **idle** · `fan-at-lips-s-curve` — Придворная S-линия: вес на прямой левой, правая скрещена спереди, носок касается пола, раскрытый веер у губ, длинный рукав струится.
   `standing tall in a court-lady S-curve: weight on her straight left leg, right leg crossed in front of it with the right toe pointed on the floor, hips swayed to her left, open folding fan held at her lips in her right hand, left arm hanging long with the trailing sleeve draped behind her, chin raised, amused eyes gazing past the viewer into the distance`
2. **select** · `water-sleeve-spiral` — Стоп-кадр поворота с «водяными рукавами» пекинской оперы: правый рукав взлетает спиралью над головой, левый стелется низко. Ноги в длинном скрещивающемся шаге, подол лежит.
   `frozen mid-turn in a Chinese opera water-sleeve flourish, right arm flinging its long white sleeve up in a spiral above her head, left arm trailing its sleeve low behind her with the closed fan in the left hand, right leg crossing in front of the left in a long gliding step with both legs straight, gown hem settled and in place, regal amused glance past the viewer`
3. **win** · `seated-on-crescent-moon` — Сидит боком во внутреннем изгибе светящегося полумесяца над облаками. Ноги вместе свисают с нижнего рога, носки вытянуты, правая рука прячет улыбку за веером.
   `seated sideways on the inner curve of a glowing silver crescent moon floating above a sea of clouds, both legs hanging down together from the moon's lower tip, knees together, left foot lower than the right with both toes pointed, left hand resting on the moon's curve beside her hip, right hand hiding her smile behind the open fan, eyes gazing out past the viewer, camera at her eye level`
4. **lose** · `lean-in-hands-behind-curious` — «Любопытно…» Склоняется от талии к игроку с прямой спиной, руки сцеплены за спиной со сложенным веером, ноги прямые, пятки вместе. Здесь она впервые смотрит прямо на игрока.
   `bending forward from the waist toward the viewer with a straight back and open curiosity, both hands clasped behind her back holding the closed fan, both legs straight with the heels together, head tilted, waist-length lavender hair cascading forward over one shoulder, eyes wide and looking straight at the viewer for once, small curious smile, murmuring 'curious...'`
5. **shy** · `full-fan-face-shield` — Царица теряет лицо: обеими руками закрывается полностью раскрытым веером от носа до подбородка. Ноги прямые, правая стопа плотно скрещена перед левой в щиколотках.
   `standing with both legs straight and the right foot crossed tightly in front of the left at the ankles, both hands raising the fully opened fan to cover her face from nose to chin, only her eyes, small horns and crescent tiara showing above the fan, gaze darting aside, deep blush visible at the fan's edges`
6. **tease** · `balustrade-step-fan-chin-lift` — Стоит на верхней ступени балюстрады выше игрока, стопы вместе, слегка склоняется и кончиком сложенного веера приподнимает ему подбородок. На игрока даже не смотрит: глаза полуприкрыты и отведены.
   `standing on the top step of a white jade stairway above the viewer, both feet together and both legs straight, bending forward slightly from the hips with a straight back, right arm extended down holding the closed fan so its tip lifts the viewer's chin just in front of the camera, left hand gathering her trailing sleeve at her waist, half-lidded eyes turned aside as if not even looking, slow knowing smile, camera at the viewer's eye level with an upward tilt under 10 degrees`

**Окружение.** Терраса Лунного дворца над морем облаков: балюстрады белого нефрита, огромный диск полной луны (луна есть только у Юэ), османтус с золотыми цветками, серебряные колокольчики, лунная дорожка на облаках, светящиеся пылинки.
`background: Moon Palace terrace above a sea of clouds, white jade balustrades, an enormous full-moon disc, an osmanthus tree with tiny golden blossoms, silver bells under the eaves, a path of moonlight across the clouds, drifting glowing motes, muted`
**Свет и палитра.** Полночь, полнолуние: холодный контровой свет сзади-сверху, серебряный рим по волосам и рожкам, лавандовая заливка от облаков снизу. Hex: e8e4f4 (лунное серебро), c8b6ff (лаванда), 2a2350 (ночная тень).
`midnight full-moon backlight from behind and above, silver rim on her hair and horns, soft lavender fill bouncing up from the clouds`
**Кадр.** Камера на уровне её глаз, но она стоит высоко и занимает верхние две трети, внизу пустое небо и облака. Диск луны всегда за головой, как нимб. Длинная вертикаль от середины голени, рукава и волосы уходят за край.
`she occupies the upper two thirds of the frame above empty clouds, the full-moon disc directly behind her head like a halo, camera at her eye level, long vertical composition from mid-shin, sleeves and hair leaving the frame edges`
**Анимация.** Медленно обмахивается веером; волосы и рукава дрейфуют вверх, как в невесомости; веер щёлкает, по нему бегут звёзды; лениво прикрывает глаза; колокольчики качаются в такт дыханию.
**Ножки и горячие жесты** (`LEGWEAR.md` §3, §4.3 п. 4): LW22–LW27; витрина `select`, баннер y_duel. Жесты: `yue.toe_point`, `yue.crossing_glide`, `yue.calf_glide` (18+), `yue.boot_glint`, `yue.weightless`; у всех также `leg_idle`, `sheen_sweep`, `ornament_sway`.
**Взгляд через плечо:** только в `y_ball` — в повороте вальса, рука на плече невидимого партнёра.

---

## 5. nova — Нова · белый хакер и гонщица

**Пластика.** Нервно-быстрая, асимметричная, сутулая. Вес свален на одно бедро, к игроку стоит под углом 30–45°, никогда прямо. Пальцы не останавливаются: печатают, щёлкают, вертят голограмму. Голова качается под музыку в наушниках. Уличная пластика: корточки, висит на кабелях, сидит боком на байке.
**Ноги.** Вес на одном бедре, носок ботинка отбивает ритм, корточки.
**Реквизит.** Наушники с кошачьими ушками, прозрачный визор, голо-фишка, кастомный байк без логотипов, голографическая клавиатура, голограмма замка-сердечка, ЭЛТ-мониторы.

**Позы**

1. **idle** · `air-typing-slouch` — Сутулясь, печатает по парящей клавиатуре. Вес на прямой левой, бедро наружу, правое колено расслаблено и развёрнуто наружу, носок отбивает ритм.
   `slouched air-typing: weight dumped on her straight left leg with the hip cocked out, right leg relaxed with the knee turned outward and the right boot's toe tapping the floor, both hands at waist height typing on a floating translucent hologram keyboard, shoulders hunched forward, head bobbing to her cat-ear headphones, visor down, focused smug smirk`
2. **select** · `bike-sidesaddle-knees-together` — Сидит боком на сиденье байка, колени вместе, обе ноги уведены вправо, ботинки рядом на бетоне. Двумя пальцами поднимает визор, над левой ладонью парит голо-фишка.
   `sitting sideways on the seat of her parked unbranded custom motorcycle, both knees together with both legs angled down to her right, both boots resting side by side on the concrete floor, right hand pushing her transparent visor up onto her forehead with two fingers, left palm raised with a small hologram of a blank tile hovering above it, smug little smirk at the viewer, camera at her eye level`
3. **win** · `mic-drop-tile` — «Скачано.» Вес на прямой правой, левая расслаблена, пятка свободно впереди. Правую руку отвела вбок и роняет голо-фишку из двух пальцев, как микрофон. Левой стягивает чашку наушника. За головой дугой горит заполненная полоса загрузки.
   `standing in three-quarter view with her weight dumped on her straight right leg, left leg relaxed with the boot heel resting loosely forward, right arm held out to the side letting a hologram blank tile drop from between two fingers like a mic drop, left hand tugging one cat-ear headphone cup off her ear, chin up with a half-lidded smug look at the viewer, a glowing completely filled progress bar with no text arcing behind her head`
4. **lose** · `side-crouch-poke-cable` — «…баг. Не мой.» Сидит на корточках у байка в профиль, колени вместе смотрят влево, щека сплющена о ладонь, пальцем тычет в искрящий кабель.
   `crouching low on her heels beside the motorcycle in side profile, both knees together pointing to her left, both boots flat on the floor, left elbow resting on her knees with her cheek squashed into her left palm, right index finger poking a sparking cable, sulky narrowed eyes, pouting mouth muttering 'bug, not mine'`
5. **shy** · `popup-panic-swipe` — Перед лицом выскочило розовое голо-окно с сердечком. Откинулась назад и обеими ладонями смахивает его. Вес на левой, правый ботинок оторван от пола, колено в сторону. Огоньки наушников мигают.
   `leaning back away from a pink heart-shaped hologram pop-up that has appeared in front of her face, both palms shoved out to swipe it away, weight on her straight left leg, right boot lifted off the floor with the knee bent out to the side, visor pushed up, eyes wide, headphone LEDs flashing, flustered blush`
6. **tease** · `cable-hang-heart-lure` — Висит на одной руке на толстом пучке кабелей под потолком, свесившись к камере. Ноги прямые, скрещены в щиколотках, носки едва касаются ящика. Правой покачивает на светящейся нити голо-замок-сердечко, как наживку.
   `hanging one-handed from a thick overhead cable bundle by her left hand, body leaning out sideways toward the camera, both legs straight and crossed at the ankles with the boot toes just touching a crate below, right hand dangling a small glowing heart-shaped padlock hologram on a thread of light like a fishing lure, smug smile with both eyes open`

**Окружение.** Тесный гараж-мастерская в переулке под эстакадой: байк на подъёмнике, спагетти кабелей под потолком, стопки ЭЛТ-мониторов, один поднятый рольставень в тёмный переулок. Сухо, без дождя, без неона.
`background: cramped back-alley garage workshop under an elevated railway, a motorcycle on a lift, cable spaghetti overhead, stacks of old CRT monitors with abstract glowing graphs and no text, one rolled-up shutter onto a dark dry alley, muted, no neon clutter`
**Свет и палитра.** Единственная, у кого свет снизу от практических источников: голубые экраны и голограммы подсвечивают лицо и руки, пурпурный рим от голограммы за спиной, всё остальное тёмное. Hex: 4fe3ff (голо-голубой), ff6fd8 (пурпурный рим), 1a1530 (тень).
`lit only by her screens and holograms: cyan underlight on her face and hands, magenta rim from a hologram behind her, dark surroundings`
**Кадр.** Строго ровно, «экран в экране»: она снята сквозь рамку ЭЛТ-монитора или прямоугольник интерфейса на переднем плане (без текста). Она на левой трети, справа место под голограммы. Плотный кадр от середины бедра, камера на уровне глаз.
`perfectly level frame-within-a-frame shot through the rectangle of a foreground CRT bezel or HUD panel with no text, she stands on the left third with space for holograms on the right, tight framing from mid-thigh, eye-level camera`
**Анимация.** Печатает в воздухе; ушки наушников пульсируют в такт; голова кивает; голо-фишка подглючивает; носок отбивает ритм; сдувает прядь асимметричной чёлки.
**Ножки и горячие жесты** (`LEGWEAR.md` §3, §4.3 п. 5): LW28–LW32; рваный LW28. Жесты: `nv.glitch_nod`, `nv.hip_drop_tap` (только «В рост»), `nv.slash_poke`, `nv.led_pulse`, `nv.holo_shift`; у всех также `leg_idle`, `sheen_sweep`, `ornament_sway`.
**Взгляд через плечо:** нет.

---

## 6. tsubame — Цубамэ · куноити-курьер

**Пластика.** Сжатая пружина на краях и высоте: конёк крыши, скат, столб. Темп «замерла — рывок». Руки асимметричны: одна держит письмо или кунай двумя пальцами, другая работает шарфом.
**Ноги.** Стопа перед стопой по коньку, носки, приземление на колено.
**Реквизит.** Длинный алый шарф, шпилька-кунай в форме ласточки, письма с печатью цвета сливы, дымные клочки, верёвки с конвертами.

**Позы**

1. **idle** · `ridge-tightrope-read-letter` — Идёт по коньку крыши, как по канату: правая таби прямо перед левой. Читает адрес на письме, другой рукой крутит кунай.
   `walking the ridge of a tiled roof like a tightrope in three-quarter view, right tabi placed directly in front of the left on the ridge line, both legs straight with the back heel lifted, reading the address on a sealed letter in her left hand, right hand spinning the swallow-shaped kunai on one finger, crimson scarf trailing behind in the wind, cool focused eyes flicking up to the viewer, hem stays in place`
2. **select** · `profile-tuck-leap-letter` — Стоп-кадр прыжка между крышами в профиль: колени вместе поджаты, тело собрано, как у ласточки, письмо зажато в вытянутой вперёд руке.
   `frozen mid-air in a compact leap between two roofs, seen in side profile, both knees drawn up together under her, both feet tucked with the tabi soles side by side, torso leaning forward, right arm extended forward pinching a sealed letter between index and middle finger, left arm swept back, scarf and ponytail streaming behind in one line, head turned to the viewer, cool confident half-smile, dress hem stays in place`
3. **win** · `ridge-one-knee-landing` — Приземлилась на конёк в профиль: правое колено на черепице, левая стопа впереди, ладонь на черепице. Шарф оседает дугой, вокруг опускается несколько писем.
   `landed on the roof ridge in side profile, right knee down on the tiles, left foot planted forward with the left knee bent up and pointing away along the ridge, right hand flat on the tiles, left hand at her side, crimson scarf settling in a curve, a few sealed letters fluttering down around her, head lifted toward the viewer with a sharp smirk, hem stays in place`
4. **lose** · `roof-slope-knees-up-retie` — «Ещё заход.» Сидит на скате строго в профиль, колени вместе подтянуты и смотрят прочь от камеры. Обеими руками за головой перетягивает хвост, алый шнур в зубах.
   `sitting on a sloped tiled roof in strict side profile facing frame-right, both knees drawn up together toward her chest pointing away from the viewer, both feet flat on the tiles side by side, both hands behind her head re-tightening her very long ponytail, the crimson hair cord held between her teeth, eyes looking off into the distance, sulky determined frown, dress hem stays in place over her thighs, camera at eye level`
5. **shy** · `letter-for-me-arms-length` — «Это… мне?» Стоит деревянно, стопы вместе, на вытянутых руках держит конверт с её именем и смотрит на него. Шарф сползает с плеча, хвост обвивает талию.
   `standing stiffly with both feet together and both legs straight, holding a sealed envelope addressed to herself at full arm's length in both hands and staring at it with wide eyes and a deep blush, crimson scarf slipping off one shoulder, the very long ponytail curling around her waist`
6. **tease** · `tiptoe-dodge-letter-high` — Уворачивается вбок на носках обеих ног, ноги вместе. Письмо поднято высоко: «Угадай, от кого».
   `dodging sideways on the tiptoes of both feet with both heels lifted, legs straight and close together, body leaning away in three-quarter view, right arm stretched straight up holding a letter between two fingers out of the viewer's reach, left hand swinging the scarf end in a loop, sly sideways glance, teasing smirk with one eyebrow raised, hem stays in place`

**Окружение.** Верхний ярус почтовой башни курьеров над туманным городом каналов: конёк мокрой чёрной черепицы, гнёзда ласточек под карнизом, верёвки с конвертами, как бельё, один маленький бумажный светильник с печатью гильдии «Ночные ласточки». Луны нет, мостов нет.
`background: top tier of a courier post tower above a misty canal town at night, dark wet tiled roof ridge, swallow nests under the eaves, lines of sealed envelopes strung like laundry, one small guild-seal paper lamp, moonless overcast sky, muted and hazy`
**Свет и палитра.** Безлунная пасмурная ночь. Снизу туман светится огнями города каналов, сбоку узкий алый отблеск лампы гильдии. Hex: 1d1b2e (ночной индиго), c8283c (алый), a9b0c2 (туманное серебро).
`moonless overcast night, cool misty glow rising from the canal town below lighting her from beneath, a narrow crimson side light from the guild lamp`
**Кадр.** Ровный горизонт, ультравертикаль: огромное пустое ночное небо занимает больше половины кадра, она в нижней правой трети, шарф идёт диагональю. Кроп от колен.
`perfectly level horizon, ultra-vertical composition with a huge empty night sky filling over half the frame, she stands in the lower right third, scarf cutting a diagonal, knees-up, eye-level camera`
**Анимация.** Перекатывает кунай по костяшкам; раз в ~8 с резко поворачивает голову на звук и медленно расслабляется; пятка опорной ноги приподнимается (микробаланс); у ног вьётся дым; шарф и хвост тянутся по ветру.
**Ножки и горячие жесты** (`LEGWEAR.md` §3, §4.3 п. 6): LW33–LW35; рваный LW35, в `allure` порыва нет. Жесты: `tb.micro_balance`, `tb.freeze_dash`, `tb.sashiko_touch`, `tb.ridge_balance`; у всех также `leg_idle`, `sheen_sweep`, `ornament_sway`.
**Взгляд через плечо:** только в SSR-наряде — уходит в дым, два пальца подняты в прощании (кадр выше талии).

---

## 7. miel — Миэль · кондитер

**Пластика.** Всё идёт от бёдер: бедро в сторону, покачивается на «раз-два», опирает на бедро миску или поднос. Руки всегда заняты едой или инструментом, голова склонена к плечу. Темп пружинистый и тёплый. Её фирменное выражение — напевает с закрытыми глазами.
**Ноги.** Пятка выскальзывает из туфельки (это есть только у неё), подскок на носках, коленки трутся.
**Реквизит.** Венчик и медная миска, кондитерский мешок, макароны, круглая розовая коробка с тортом, белая атласная лента в боковом хвосте, заколка-макарон.

**Позы**

1. **idle** · `bowl-on-hip-whisk` — Медная миска прижата к правому бедру, бедро в сторону. Левое колено внутрь, пятка выскользнула из туфельки. Взбивает крем и напевает с закрытыми глазами.
   `standing in three-quarter view, a large copper mixing bowl hugged against her right hip with the right arm, right hip pushed out with her weight on the straight right leg, left leg relaxed with the knee bent inward and the left heel lifted out of the pump, left hand whisking cream in the bowl, head tilted toward her right shoulder, humming with a soft closed-eye smile, a small dab of cream on her cheek`
2. **select** · `piping-cupcake-hip-sway` — Капкейк на левой ладони, выдавливает на него розочку. Стопы вместе, коленки вместе и пружинят на «раз-два», бёдра качнулись влево, правая пятка выскользнула из туфли.
   `standing in three-quarter view with both feet together and both knees together, bouncing lightly on the beat with her hips swayed to her left, right heel slipped out of its pump, left palm holding a cupcake at chest height, right hand squeezing a piping bag to pipe a cream rosette onto it, eyes lifting from the cupcake to the viewer with a beaming smile`
3. **win** · `tray-forward-curtsy-dip` — Кондитерский реверанс: обеими руками выносит вперёд серебряный поднос светящихся пирожных, правая нога за левой на носке, колени слегка присели.
   `a little pastry curtsy: holding a large silver tray of glowing pastries forward and up at shoulder height with both hands, right leg crossed behind the left with only the right toe on the floor, both knees softly bent in a small curtsy dip, upper body upright, side ponytail with white ribbon bouncing, bright open-mouth laugh, eyes on the viewer`
4. **lose** · `souffle-horror-hands-cheeks` — Склонилась над осевшим суфле на мраморе, ладони прижаты к щекам от ужаса. Колени сведены, левая пятка выскользнула из туфли, нос в муке, щёки надуты.
   `standing at the marble counter and leaning forward over a collapsed soufflé, both hands pressed to her puffed cheeks in horror, both knees knocked together, left heel slipped out of its pump, right foot flat, a flour smudge on her nose, wide watery eyes`
5. **shy** · `cakebox-hug-chin-on-lid` — Развернулась на 45° и обнимает круглую розовую коробку с тортом, подбородок на крышке, колени сжаты, пятка правой выскальзывает из туфли.
   `standing with her body turned 45 degrees away, both arms hugging a round pink cake box tightly in front of her, chin resting on the box lid, eyes glancing up sideways at the viewer, deep blush, both knees pressed together, left leg straight bearing weight, right foot lifted slightly with the heel slipping out of the pump`
6. **tease** · `across-counter-spoon-say-ahh` — Тянется к игроку через торец мраморной стойки на левом предплечье, на носках обеих ног, обе пятки вынырнули из туфель. Протягивает ложку сливок: «Скажи „а-а“».
   `leaning sideways across the end of the marble counter on her left forearm, standing on the tiptoes of both feet with both heels lifted out of her pumps and the legs together, right hand holding out a spoonful of whipped cream toward the viewer, head tilted, mouth open in a teasing 'say ahh', eyes crinkled with glee`

**Окружение.** Утренняя кухня-витрина кондитерской «Мёд и пар»: кирпичная арка печи с углями, мраморная столешница в сахарной пудре, медные миски, решётки с макаронами, банки мёда, мешки муки, солнечное окно с кружевной занавеской. Пара нет: пар у Цуру.
`background: morning kitchen of a small pastry shop, brick oven arch with an ember glow, marble counter dusted with powdered sugar, copper bowls, cooling racks of macarons, honey jars, flour sacks, a sunlit window with a lace café curtain, muted, soft haze of floating sugar`
**Свет и палитра.** Около 7 утра: мягкое солнце в окно, тёплое свечение печи сбоку, в лучах висит сахарная пудра. Hex: f6e7cf (сливки), c98a4b (карамель), e0566f (малина).
`soft early-morning sun through the window, warm oven glow from the side, powdered sugar glittering in the light beams`
**Кадр.** Взгляд покупателя через прилавок: камера на ~10° выше её глаз, тёплый средний план от середины икры, 3/4. Она на левой трети, по краю кадра мягкий передний план из пирожных.
`customer's view across the counter, camera about 10 degrees above her eye level, warm medium shot from mid-calf in three-quarter view, she stands on the left third, soft out-of-focus pastries in the foreground edge`
**Анимация.** Покачивается на «раз-два»; дважды стучит венчиком о миску; сдувает пудру с ладони; пятка выскальзывает из туфельки и возвращается; хвост с лентой подпрыгивает с задержкой.
**Ножки и горячие жесты** (`LEGWEAR.md` §3, §4.3 п. 7): LW36–LW38; ножные жесты только в кадре «В рост». Жесты: `me.hip_sway`, `me.heel_slip` (18+), `me.tiptoe_reach`, `me.sock_pullup`; у всех также `leg_idle`, `sheen_sweep`, `ornament_sway`.
**Взгляд через плечо:** нет.

---

## 8. lian — Лянь · музыкантша пипы

**Пластика.** Самая медленная: всё тело — длинная S-линия, движения текут, как под водой. Длинные пальцы на струнах или в волосах, шея вытянута, голова склонена к звуку, глаза полуприкрыты.
**Ноги.** Мелкие бесшумные шаги, стопы близко, шаг в разрез — только в профиль.
**Реквизит.** Пипа, шпильки-лотосы с жемчужными кистями, волосы химэ-кат до пола, светящаяся золотая струна, свечи-лотосы на воде.

**Позы**

1. **idle** · `silk-stool-upright-pipa` — Сидит прямо на низком круглом шёлковом пуфе на помосте, как настоящая исполнительница: пипа вертикально на левом бедре, колени вместе уведены вправо.
   `sitting upright on a low round embroidered silk ottoman on the lacquered dais, the pipa held vertically on her left thigh with its neck rising beside her left shoulder, left fingers pressing the frets, right fingers plucking the strings, both knees together angled toward frame-right, both feet side by side with the right toe pointed, long neck tilted toward the instrument, eyes half-closed, serene half-smile, camera at her eye level, hem and slit stay in place`
2. **select** · `glowstring-draw-feet-close` — Стоит, стопы близко, левая на полшага впереди. Пипа вертикально перед телом, правой рукой вытягивает к камере светящуюся струну.
   `standing with both legs straight and the feet close together, the left foot a half-step ahead, the pipa held upright in front of her body by its neck in her left hand, right arm extended toward the viewer with thumb and index finger drawing a single glowing golden string of light toward the camera, head inclined, half-lidded knowing eyes, faint smile`
3. **win** · `final-strum-arm-arc` — Последний аккорд: пипа прижата к телу, правая рука после удара уходит широкой дугой-веером вверх. Левая стопа шагнула на ступень помоста. Волосы до пола разлетаются дугой.
   `standing in three-quarter view, the pipa upright against her body held by the left hand, right arm sweeping outward and upward in a wide fan-shaped arc just after a final strum with fingers spread, left foot stepped up onto the low step of the dais with the knee bent, right leg straight behind her, chin lifted, eyes closed in rapture, open blissful smile, floor-length hair fanning out in an arc`
4. **lose** · `forehead-on-pillar` — «Минор тебе к лицу.» Прислонилась лбом к красному лаковому столбу, глаза закрыты, ладонь на столбе. Пипа свисает за гриф и касается палубы корпусом, волосы стекают на доски.
   `standing with her forehead resting against a red lacquer pillar of the barge, eyes closed, left hand flat on the pillar, right hand letting the pipa hang by its neck so its body touches the deck, both legs straight and close together with the right foot half a step behind, floor-length hair pooling on the boards, soft melancholy smile`
5. **shy** · `snapped-string-flinch` — Со звоном лопнула струна. Отпрянула на полупальцы, стопы вместе, обеими руками подняла пипу к груди. Глаза широко открыты, лёгкий румянец.
   `a pipa string has just snapped with a twang: she flinches back onto the balls of both feet with both legs straight and the feet together, lifting the pipa in front of her chest with both hands, the broken string curling in the air, eyes wide, lips parted, faint blush`
6. **tease** · `profile-over-shoulder-slit-step` — Её единственный взгляд через плечо. Корпус в профиль, голова повёрнута назад через правое плечо, пипа спрятана перед телом, волосы закрывают спину. Правая нога в шаге вперёд сквозь разрез, виден чулок с лотосом.
   `body in side profile facing frame-left, head turned back over her right shoulder toward the viewer with half-lidded eyes, the pipa held upright in front of her and hidden by her body, floor-length hime hair covering her back, right leg mid-step forward through the side slit with the knee softly bent and the foot flat, left leg straight behind bearing her weight, showing the lotus-embroidered white stocking, small teasing smile, camera at eye level focused on her face and hair, slit unchanged`

**Окружение.** Музыкальная баржа «Тихая заводь» ночью: приподнятый лаковый помост, изогнутая крыша на красных лаковых столбах, занавеси из нитей бусин, свечи в форме лотосов плывут по чёрной воде, швартовый канат. Чайного столика и чайника нет. Луны нет.
`background: a river music barge at night, a raised red-lacquered dais under a curved boat roof on red lacquer pillars, hanging bead-string blinds, lotus-shaped floating candles drifting on black water, lotus leaves, a mooring rope, light mist over the water, muted, no moon`
**Свет и палитра.** Тёплый коралловый свет свечей-лотосов снизу от воды, низкий туман, луны нет. Hex: 1f4e5a (тёмная бирюза тени), f1d6cf (коралл-лотос), c9a35b (старое золото струн).
`warm coral candlelight rising from floating lotus candles on the water below, low mist, deep teal shadows, no moonlight`
**Кадр.** Вне центра, 3/4. Снято сквозь нити бусин на переднем плане, они размывают край кадра. От колен, камера на уровне глаз. Отражений её ног в воде нет.
`off-center three-quarter view shot through hanging bead strings in the soft foreground, knees-up, eye-level camera, no reflection of her legs in the water`
**Анимация.** Тремоло пальцев по струнам; жемчужные кисти качаются с задержкой; раз в ~10 с закрывает глаза на 2 с, «слушает»; кончики волос скользят по палубе; рядом раскрывается лотос.
**Ножки и горячие жесты** (`LEGWEAR.md` §3, §4.3 п. 8): LW39–LW41; разрез как в K, не расширяется. Жесты: `li.slit_step`, `li.lotus_trace` (18+), `li.toe_ripple`, `li.ripple_shimmer`; у всех также `leg_idle`, `sheen_sweep`, `ornament_sway`.
**Взгляд через плечо:** только `tease` базового наряда.

---

## 9. jess — Джесс · ковбойша чайного тракта

**Пластика.** Занимает много места: открытые жесты, сапоги впечатаны в землю, плечи развёрнуты. Одна рука у полей шляпы, другая на лассо или поясе. Быстрая и громкая, смеётся всем телом.
**Ноги.** Сапоги широко и впечатаны, каблук вбит в землю.
**Реквизит.** Шляпа с перьями и серебряными кончами, лассо, пряжка-подкова, соломинка в зубах, забор загона.

**Позы**

1. **idle** · `fence-forearms-ankles-crossed` — Навалилась предплечьями на верхнюю жердь загона, корпус в 3/4. Оба сапога на земле, правая щиколотка заведена за левую. Шляпа набок, соломинка в зубах.
   `leaning forward with both forearms folded on the top rail of a wooden corral fence, body in three-quarter view, both boots on the dirt with the right ankle crossed behind the left, both legs straight, hat tilted to one side, a wheat stalk between her lips, relaxed easy grin, sky-blue eyes on the viewer`
2. **select** · `boots-planted-thumb-belt-brim` — Сапоги широко впечатаны, вес в правое бедро. Большой палец левой за поясом у подковы, указательный правой поднимает поля шляпы.
   `standing tall in three-quarter view with both boots planted wide apart in the dirt along the side axis, both legs straight, weight sunk into her right hip, left thumb hooked in her belt beside the horseshoe buckle, right index finger pushing the hat brim up, coiled lasso hanging from her belt, wide confident grin`
3. **win** · `lasso-loop-overhead-hat-slap` — Сапоги на ширине плеч, раскручивает над головой плоскую петлю лассо, другой рукой нахлобучивает на голову падающую шляпу. Улюлюкает.
   `boots planted shoulder-width apart with the knees slightly bent, right arm raised spinning a big flat lasso loop horizontally above her head, left hand slapping her falling hat back onto her head, both long braids swinging, whooping open-mouth laugh`
4. **lose** · `lasso-hop-windmill` — Лассо запуталось на правом сапоге. Скачет на левой, правую ногу отвела вбок и трясёт, руки мельницей, шляпа слетает.
   `hopping on her left boot with the left knee slightly bent, the lasso tangled around her right boot which is kicked out to her side, not toward the camera, as she tries to shake it loose, both arms windmilling for balance, hat flying off her head, gritted-teeth grin, annoyed but laughing`
5. **shy** · `hat-down-neckrub-boot-scuff` — Отвернулась на 3/4, левой натягивает поля шляпы на глаза, правой трёт затылок, носком правого сапога чертит дугу в пыли.
   `standing turned three-quarter away, left hand pulling the hat brim down over her eyes, right hand rubbing the back of her neck, weight on the straight left leg, right leg bent with the right boot toe scuffing a small arc in the dust behind her, deep blush visible below the brim, lips pressed in an embarrassed wobbly smile`
6. **tease** · `lasso-catch-pull-heel-dug` — «Попался!» В профиль откинулась от бёдер с прямой спиной, тянет натянутое лассо, петля летит в камеру. Левый каблук вбит в землю впереди. Подмигивает.
   `in side profile, leaning back from the hips with a straight unarched spine, both hands gripping a taut lasso rope whose open loop flies toward the viewer, left leg braced straight forward with the boot heel dug into the dirt, right leg bent behind her bearing the weight, head turned to the viewer, cocky wink, lopsided grin`

**Окружение.** Загон у чайного каравана в Медном каньоне: выбеленный забор коновязи, крытый фургон с ящиками чая, ветряк, сено, перекати-поле, красные столовые горы вдали.
`background: corral beside a tea caravan in a copper-red canyon, sun-bleached wooden hitching fence, covered wagon loaded with tea crates under canvas, a windmill, scattered hay, tumbleweed, distant red mesas, muted`
**Свет и палитра.** Жёсткий полдень: солнце сверху, короткие резкие тени под полями шляпы, марево над землёй, выбеленное небо. Hex: 3d5a80 (джинса), b5532f (ржавчина), f4ead2 (выбеленное небо).
`harsh high-noon sun directly overhead, short hard shadows under the hat brim, heat shimmer above the ground, bleached pale sky`
**Кадр.** Классический «ковбойский» кадр вестерна от середины бедра (кобура-высота), камера на уровне глаз, горизонт в нижней трети, она на правой трети, слева небо и каньон. Низкого ракурса нет: на ней шорты.
`classic western cowboy shot cropped at mid-thigh, eye-level camera, horizon in the lower third, she stands on the right third with sky and canyon on the left`
**Анимация.** Стучит каблуком в ритм; перекидывает косу; большим пальцем поднимает поля; соломинка покачивается; широко переносит вес; лассо качается на поясе; катится перекати-поле.
**Ножки и горячие жесты** (`LEGWEAR.md` §3, §4.3 п. 9): LW42–LW44; рваный LW42, `allure` стоя у столба. Жесты: `je.weight_drop_brim`, `je.heel_stomp`, `je.sock_pullup`, `je.ankle_cross`; у всех также `leg_idle`, `sheen_sweep`, `ornament_sway`.
**Взгляд через плечо:** нет.

---

## 10. tsuru — Цуру · хозяйка рёкана

**Пластика.** Низкий устойчивый центр тяжести, экономия движений: мелкие шаги, колени вместе, руки в рукавах или у оби. Жесты от запястья. Смотрит глаза в глаза, тепло и знающе. Внутри живёт азарт настольного тенниса.
**Ноги.** Гэта вместе, носок гэты на переднем зубце, сэйдза, мелкий шаг.
**Реквизит.** Канзаси-журавль, бумажный журавлик, хаори с гербом журавля, норэн с гербом, чугунный чайник над ирори, тэнугуи, ракетка для пинг-понга за оби.

**Позы**

1. **idle** · `doorframe-sleeves-geta-tooth` — Плечом в раме сёдзи, руки спрятаны в рукава у оби. Гэта вместе, колени мягко согнуты, правая гэта качнулась на передний зубец.
   `standing in a shoji doorframe with her right shoulder resting against the wooden frame, both hands tucked into the opposite kimono sleeves in front of her obi, both geta together with the knees softly bent, the right geta tipped forward onto its front tooth, head tilted against the frame, warm crescent-eyed smile, eyes level with the viewer's, hem stays in place`
2. **select** · `noren-part-palm-up-welcome` — Левой раздвигает норэн и мелким шагом переступает порог, правая ладонь вверх: «Проходи».
   `parting a crane-crest noren curtain with her left hand as she steps through the entrance, right hand extended forward palm-up in a welcoming gesture, right foot taking a small step forward over the threshold, left geta behind tipped onto its front tooth, body in three-quarter view, slight inviting bow of the head, warm smile, eyes level with the viewer's`
3. **win** · `pingpong-smash` — Смэш в онсэн-пинг-понге: ракетка проносится через корпус, мячик летит, рукава взлетают. Смеётся глазами-полумесяцами.
   `mid-swing in an onsen ping-pong smash in three-quarter view, right arm sweeping a wooden paddle forward across her body, a small white ball flying off it, kimono sleeves flying, haori fluttering, left foot planted in a small step forward, right geta behind her tipped onto its front tooth, crescent-eyed delighted laugh`
4. **lose** · `tenugui-taut-foot-stamp` — Азарт: натянула тэнугуи у подбородка, закусила губу, брови сведены. Правая нога только что топнула, ракетка за оби.
   `standing in three-quarter view, both hands pulling a folded tenugui towel taut in front of her chin, lower lip bitten in competitive frustration, eyebrows knitted, right foot just stamped flat on the floor with the knee slightly bent, left leg straight, shoulders raised, a ping-pong paddle tucked into her obi`
5. **shy** · `folding-crane-busy-hands` — Руки заняты: отвернулась и быстро складывает журавлика у груди, глаза на пальцах, плечи подняты, косой взгляд на игрока.
   `standing turned three-quarter away, rapidly folding a paper crane at chest height with her eyes fixed on her fingers, shoulders raised, both geta together with the knees together, a flustered glance at the viewer from the corner of her eye, soft blush`
6. **tease** · `seiza-cushion-pat-invite` — «Отдохни у меня.» Сидит в сэйдза на дзабутоне у очага, ладонью похлопывает по свободной подушке рядом, другая ладонь у щеки.
   `sitting in seiza on a floor cushion beside a sunken hearth, both knees together and folded under her, both shins flat on the tatami, feet tucked beneath her hips, upper body upright and turned three-quarter, right palm gently patting an empty cushion beside her in invitation, left palm at her cheek, head tilted, warm teasing smile with narrowed eyes, camera at her seated eye level, hem stays in place`

**Окружение.** Комната с очагом в горном рёкане «Журавлиный пар»: утопленный ирори с чугунным чайником на крюке и паром (пар есть только у Цуру), татами и дзабутоны, раздвинутые сёдзи на осенний перевал с паром источника вдали (без купающихся), норэн с журавлём, нитка бумажных журавликов.
`background: hearth room of a mountain onsen ryokan, sunken irori hearth with an iron kettle on a hook breathing steam, tatami and floor cushions, open shoji onto an autumn mountain pass with distant hot-spring steam and no bathers, crane-crest noren at the entrance, a string of paper cranes, muted`
**Свет и палитра.** Поздний осенний полдень: низкое солнце режет сквозь сёдзи полосами хурмового света, очаг даёт вторую, тёплую заливку снизу. Hex: 2e3a6b (индиго тени), e0703b (хурма), f1ece4 (васи).
`late-afternoon autumn sun raking through the shoji in striped bars of persimmon light, warm hearth glow as secondary fill from below`
**Кадр.** В сидячих позах камера на высоте сидящего гостя (~1 м), в стоячих на уровне её глаз, строго горизонтально. Решётка сёдзи работает как графичная рамка, план от колен.
`camera at a seated guest's height for seated poses and at her eye level for standing poses, perfectly horizontal, the shoji lattice as a graphic frame, close warm framing from the knees`
**Анимация.** Заправляет прядь за ухо; разглаживает ворот хаори; кивает «м-хм»; вертит журавлика; из чайника идёт пар; раз в ~12 с прячет руки в рукава и вынимает.
**Ножки и горячие жесты** (`LEGWEAR.md` §3, §4.3 п. 10): LW45–LW47; в `allure` гэта вместе, пар на уровне лица. Жесты: `tu.geta_rock`, `tu.toe_twist`, `tu.knowing_lean`, `tu.steam_sheen`; у всех также `leg_idle`, `sheen_sweep`, `ornament_sway`.
**Взгляд через плечо:** нет.

---

## 11. kohaku — Кохаку · лиса-жрица

**Пластика.** Лисья: кралась бы на носках, тело в S-изгибе, кисти в широких отдельных рукавах. Голова склоняется набок на каждой реплике. Медленно и лениво, потом резкий рывок. Хвост выдаёт эмоцию раньше лица. Подмигивание — её законное право.
**Ноги.** Лисья косолапость стоя (носки внутрь), подброшенная пятка, ступени.
**Реквизит.** Гохэй, лисья маска сбоку головы, колокольчик-судзу на красном шнуре, лисьи огни, офуда, хвост с киноварным кончиком.

**Позы**

1. **idle** · `stair-split-level-wand-yoke` — Стоит на лестнице: левая стопа ступенью выше, правая прямая ниже. Гохэй поперёк плеч за шеей, кисти лениво свешены через древко, хвост обвивает голени.
   `standing on a stone stairway in three-quarter view, left foot up on the next step with the left knee bent forward, right leg straight on the lower step bearing her weight, gohei wand laid horizontally across the back of her shoulders with both wrists draped lazily over it and the wide sleeves hanging down, fluffy tail curled around the front of her shins, head tilted toward her raised knee, sly smirk with a tiny fang, amber eyes on the viewer, camera at eye level`
2. **select** · `pillar-peek-tail-gives-away` — Выглядывает из-за столба тории: высунулись голова и уши, правая стопа шагнула на носок, а хвост торчит с другой стороны столба и выдаёт её.
   `peeking out from behind a thick vermilion torii pillar, body mostly hidden behind it, right hand gripping the pillar edge at head height, head and both fox ears leaning out sideways past the pillar, right leg stepping out beside the pillar with pointed toes resting on the stone, left leg hidden behind the pillar, her fluffy tail sticking out comically from the opposite side of the pillar giving her away, mischievous wide grin, eyes on the viewer, camera at eye level`
3. **win** · `airborne-heels-back-sleeves-flared` — Игривый прыжок в верхней точке: колени сведены, обе пятки подброшены назад, рукава раскрыты крыльями, из ладоней спиралью летят лисьи огни.
   `mid-air playful hop caught at its apex, body upright, both knees bent and pressed together, both heels kicked up behind her with pointed toes, both arms flung up and outward so the wide detached sleeves flare like wings, open palms releasing a spiral of amber foxfire orbs, tail fluffed and raised high, eyes closed in a happy laugh showing a tiny fang, hakama hem stays in place, camera at eye level`
4. **lose** · `steps-legs-long-tail-hug` — Сидит на ступени, ноги вместе вытянуты вниз через две ступени, обнимает свой хвост и прячет в мех щёку. Уши прижаты.
   `sitting on a stone step in three-quarter view, both legs together stretched long down over the next two steps with the toes pointed, her big fluffy tail pulled around against her side and hugged in both arms, cheek pressed into the fur, fox ears flattened back, pouting lower lip, glossy eyes on the viewer, camera at eye level, hakama stays in place`
5. **shy** · `head-offer-pigeon-toe-tail-wag` — «Тает от поглаживаний»: склоняет голову к игроку, будто подставляет под ладонь. Стоит косолапо, носки внутрь. Кисти в рукавах у живота, а хвост бешено виляет.
   `standing in slight three-quarter view, bowing her head forward toward the viewer as if offering it to be patted, fox ears pressed flat sideways, eyes glancing up through her bangs, deep blush, both hands hidden inside her long sleeves clasped in front of her stomach, both legs straight with the knees soft and both feet turned inward pigeon-toed, tail wagging hard behind her in a blurred arc, camera at eye level`
6. **tease** · `lean-in-fox-sign-heel-flick` — Наклоняется к игроку от бёдер с прямой спиной, правая пятка подброшена назад. Пальцами делает «лисичку» и «кусает» камеру, подмигивает.
   `leaning toward the viewer from the hips with a straight back, standing on her left leg, right knee bent so the right heel flicks up behind her, right hand held beside her face in a fox shadow-puppet sign with the thumb touching the middle and ring fingers and the index and pinky raised as ears, playfully biting toward the camera, left hand hidden in its sleeve behind her back, one eye winking, toothy grin with a tiny fang, fox mask on the side of her head, neckline stays in place, camera at eye level focused on her face`

**Окружение.** Ночная лестница-тоннель тысячи ториев на холме: стёртые ступени с мхом, каменные кицунэ в красных слюнявчиках, каменные фонари (каменные фонари есть только у Кохаку), лисьи огни, листья гинкго, низкий туман. Только лестница, без храмового двора.
`background: night stairway tunnel of countless vermilion torii gates climbing a hillside, worn stone steps with mossy edges, stone kitsune statues wearing red bibs, stone lanterns with floating amber foxfire orbs, golden ginkgo leaves on the steps, low drifting mist, muted and desaturated`
**Свет и палитра.** Ночь: ключ — точечные янтарные лисьи огни, алый отражённый свет от лака ториев, холодная сине-серая заливка тумана. Hex: d63a2a (киноварь), e2a23d (лисий огонь), 2b2f4a (индиго тумана).
`night, key light from small floating amber foxfire orbs, vermilion bounce from the lacquered torii, cool blue-grey fill from the mist`
**Кадр.** Кадр в кадре: столбы ближнего тории режут левый и правый край (это есть только у Кохаку), лестница уходит диагональю вверх. Она на правой трети, хвост заполняет пустоту слева. От колен, 50 мм, уровень глаз.
`frame within a frame: the two pillars of the nearest torii crop the left and right edges, the stairway climbing diagonally into the depth, she stands on the right third with her tail filling the left, knees-up, 50mm lens, eye level`
**Анимация.** Хвост ходит восьмёркой и раз в ~8 с дёргается; уши поворачиваются независимо; судзу звякает при наклоне головы; прячет ухмылку краем рукава; огонёк перекатывается с пальца на палец; переступает с носка на носок.
**Ножки и горячие жесты** (`LEGWEAR.md` §3, §4.3 п. 11): LW48–LW51; бубенцы под коленом, `allure` стоя на ступени. Жесты: `ko.heel_flick`, `ko.pigeon_toe`, `ko.tail_brush`, `ko.bell_chime`, `ko.ofuda_glow`; у всех также `leg_idle`, `sheen_sweep`, `ornament_sway`.
**Взгляд через плечо:** нет.

---

## 12. shirin — Ширин · танцовщица и гадалка

**Пластика.** Всё течёт волной: ведут бёдра и запястья, траектории восьмёркой, спина ровная. Босые стопы мягко перекатываются, пальцы в танцевальной форме. Говорит руками, взглядом держит паузу дольше, чем удобно. По утрам сонная.
**Ноги.** Релеве на полупальцах, перекат с пятки на носок, ёкодзувари.
**Реквизит.** Шифоновая вуаль, пояс-монисто, монетные цепочки в волосах, налобная цепочка, поднос с песком для гадания, медная масляная лампа, браслеты на щиколотках.

**Позы**

1. **idle** · `lamp-on-head-snake-arms` — Танец с лампой: на голове балансирует маленькая медная масляная лампа, руки раскинуты на уровне плеч и медленно идут змеиной волной. Релеве на левой стопе, колени мягкие и вместе.
   `standing in three-quarter view on a kilim carpet, a small lit brass oil lamp balanced on top of her head, weight on her flat right foot, left foot raised onto its ball close beside it, knees soft and together, hips swayed gently to her right with a straight back and no arch, both arms extended out to the sides at shoulder height in a slow serpentine wave, wrists bent and fingers in a dancer's shape, the light veil draped over both forearms behind her shoulders, serene concentrated half-smile, honey-gold kohl-lined eyes on the viewer, camera at eye level`
2. **select** · `promenade-veil-sweep` — Шаг-променад к игроку: левая нога выходит через разрез, правая сзади на носке. Правая рука отводит вуаль, как занавес, пальцы левой касаются налобной цепочки: «Вижу тебя».
   `stepping toward the viewer in a dancer's promenade, left leg forward through the high skirt slit with the knee softly bent and the foot flat, right leg behind her resting on its toes, torso upright, right arm sweeping the veil aside to her right like a curtain being drawn, left fingertips touching the golden chain on her forehead, chin slightly lowered, eyes up at the viewer with a knowing smile, slit and hem stay in place, camera at eye level`
3. **win** · `pirouette-retire-coin-spray` — Стоп-кадр пируэта на полупальцах правой, левое колено поднято вбок (ретире). Левая рука выбрасывает веер золотых монет, монисто и цепочки летят по кругу, юбка обёрнута вокруг ног.
   `frozen mid-pirouette on the ball of her right foot, right leg straight, left knee raised with the pointed left toes touching the inside of her right knee in a parallel retiré, the raised knee angled toward the side of the frame, right arm curved overhead, left arm flung outward releasing a spray of gold coins, coin-belt fringe and coin chains swinging outward in a circle while the skirt stays wrapped around her legs, laughing with eyes closed, camera at eye level`
4. **lose** · `cushion-side-fold-forearm-brow` — Сидит прямо на подушках у валика, обе ноги уложены набок влево (ёкодзувари). Правое предплечье театрально на лбу, из левой ладони сыплется песок на поднос для гадания.
   `sitting upright on floor cushions with her back against a bolster, both legs folded together to her left side, knees together pointing toward frame-left, feet tucked behind her right hip, right forearm draped theatrically across her forehead, left hand held out palm-down letting fine sand pour through her fingers onto a brass divination tray, long dramatic sigh, eyes half-closed, camera at eye level`
5. **shy** · `coin-strand-curtain-peek` — Релеве на обеих стопах, колени вместе. Обеими руками у глаз раздвигает две монетные нити из волос, как бисерную занавеску, и смотрит в щель одним глазом.
   `standing in three-quarter view in relevé on the balls of both feet with the knees together, both hands raised to eye level parting two long gold coin chains from her hair in front of her face like a bead curtain, peeking through the gap with one honey-gold eye, flustered blush, small embarrassed smile, shoulders lifted, camera at eye level`
6. **tease** · `ankle-cross-own-palm-trace` — Скрестила лодыжки (правая впереди), бёдра вбок без прогиба. Левая ладонь раскрыта к игроку, указательный правой ведёт по её линиям: «Наши линии пересекаются».
   `standing with ankles crossed, right ankle in front of the left, both legs straight, hips shifted to one side with a straight back, left hand raised at chest height with its palm turned up toward the viewer, right index fingertip slowly tracing the lines of her own palm, head tilted, looking at the viewer through her lashes with a sly half-smile as if reading their shared fate, veil draped over her bent left elbow, camera at eye level`

**Окружение.** Шатёр гадалки изнутри: слоистые килимы, низкие подушки и валики, медные масляные лампы на цепях, поднос с песком, ширма из монетных нитей. Полог откинут на дюны, первые звёзды и силуэт верблюда.
`background: interior of a fortune-teller's caravan tent, layered kilim carpets, low cushions and bolsters, brass oil lamps hanging on chains, a brass sand divination tray, a hanging screen of coin strings, tent flap open onto dunes with the first stars and a distant camel silhouette, muted and desaturated`
**Свет и палитра.** Синий час, интерьер: тёплый ключ от медных ламп, холодный бирюзовый контровой из полога, сливовые тени. Hex: e0a64a (мёд лампы), 1f8f8a (бирюза сумерек), 3b2240 (слива).
`blue-hour interior, warm key from brass oil lamps, cool turquoise backlight from the open tent flap, plum shadows`
**Кадр.** Уровень глаз, будто зритель сидит на подушке напротив. Цепи ламп и дуга вуали образуют круглую арку, она стоит вне центра. От середины бедра, корпус фронтальнее, ноги в 3/4, 50 мм.
`eye-level view as if seated on a cushion opposite her, lamp chains and the arc of the veil forming a circular arch around her placed off-center, framed from mid-thigh, torso more frontal with legs in three-quarter, 50mm lens`
**Анимация.** Змеиная волна рук малой амплитуды; монисто звенит от покачивания бёдрами (мягкая вторичная физика); перебирает монетки в волосах; браслеты позвякивают; изредка сонно зевает в ладонь; пламя лампы мигает.
**Ножки и горячие жесты** (`LEGWEAR.md` §3, §4.3 п. 12): LW52–LW55. Жесты: `sh.releve`, `sh.anklet_roll`, `sh.calf_glide` (18+), `sh.hip_eight`, `sh.henna_sheen`; у всех также `leg_idle`, `sheen_sweep`, `ornament_sway`.
**Взгляд через плечо:** нет.

---

## 13. mari — Марисоль · капитан чайного клипера

**Пластика.** Занимает всё пространство: широкая морская стойка боком к камере, колени мягкие под качку, большие пальцы за кушаком. Опирается на ванты, мачту, штурвал, борт. Хохочет, запрокинув голову (без прогиба спины). Чем громче бравада, тем быстрее краснеет. Её выражение — дерзкая ухмылка с поднятой бровью, не подмигивание.
**Ноги.** Широкая морская стойка под качку; сапоги вместе «смирно», когда смущена.
**Реквизит.** Латунная подзорная труба, треуголка с белым пером, компас-кулон, тёмно-синий камзол на плечах, кушак, ванты и канат, штурвал, медный судовой колокол.

**Позы**

1. **idle** · `boot-on-rail-shroud-grip` — У фальшборта: левый ботфорт на планшире на высоте бедра, колено высоко, правая нога прямая на палубе. Левое предплечье на поднятом бедре, правая рука над головой держит ванту. Смотрит на горизонт мимо камеры.
   `standing at the ship's bulwark in three-quarter view, left boot planted up on the wooden rail at hip height with the left knee bent high, right leg straight on the deck bearing her weight, left forearm resting across the raised thigh, right arm raised gripping a taut rigging shroud above her head, leaning slightly forward into the wind gazing at the horizon past the camera, long navy coat and white plume streaming back, confident grin, camera at eye level`
2. **select** · `tea-chest-point-horizon` — «Вон там!» Стоит на ящике с чаем в широкой упёртой стойке вдоль палубы, большой палец за кушаком, правой рукой указывает мимо камеры на горизонт. Подзорная труба за кушаком.
   `standing on top of a tea chest in a wide braced sailor's stance seen from the side, both boots planted apart along the deck line with the knees soft, left thumb hooked in her sash, right arm extended pointing past the camera toward the horizon, coat flaring behind her, brass spyglass tucked in her sash, bold smirk with one eyebrow raised, shouting 'there!'`
3. **win** · `rope-swing-boot-hooked` — Вылетает над палубой на канате: правая рука высоко на канате, правый ботфорт обвит вокруг каната, левая нога вытянута назад. Левой машет треуголкой.
   `swinging out over the deck on a rope, right hand gripping the rope high above her head, right boot hooked around the rope below with the right knee bent, left leg extended straight out behind her in the air, body leaning outward on a strong diagonal, left arm thrown up waving her plumed tricorne overhead, crimson curls and coat tails whipping, laughing open-mouthed, sea spray glittering`
4. **lose** · `mast-sit-legs-long-hat-tipped` — Сидит спиной к мачте, ноги далеко вытянуты влево, ботфорты скрещены в лодыжках, руки скрещены. Треуголка надвинута на глаза, из-под полей упрямая кривая ухмылка.
   `sitting on the wet deck with her back against the mast, both legs stretched out long toward frame-left with the boots crossed at the ankles, arms folded, tricorne tipped forward over her eyes by one finger, a crooked defiant grin showing below the brim, long coat pooled around her on the planks, camera at eye level`
5. **shy** · `tricorne-over-heart-attention` — «Капитан не краснеет.» Стоит прямо, сапоги вместе, как матрос на поверке. Сняла треуголку и обеими руками прижала к сердцу, кудри метёт по лицу, упрямо смотрит на море и краснеет.
   `standing tall with both boots together and both legs straight like a sailor at attention, plumed tricorne taken off and held flat over her heart with both hands, loose crimson curls blowing across her face, looking away at the sea with a stubborn blush, lips pressed in a crooked line`
6. **tease** · `wheel-hat-offer-heel-propped` — У штурвала: правая рука на спице, левый каблук на ступени тумбы. Протягивает треуголку в камеру, будто наденет её игроку: «Побудешь капитаном минутку?»
   `standing at the ship's wheel, right hand resting on a wheel spoke, right leg straight, left boot heel propped on the step of the wheel's pedestal with the left knee bent, holding her plumed tricorne out toward the camera with her left hand as if about to place it on the viewer's head, bare head with crimson curls tumbling loose, one eyebrow raised, cocky grin`

**Окружение.** Бак чайного клипера «Летучая чайка» в дневной шквал: мокрая палуба, ванты и выбленки, подобранные паруса, бушприт, медный колокол, ящики с чаем в промасленной парусине без надписей, штурвал на тумбе. Без бочек, рома и стекла.
`background: foredeck of a tea clipper in a passing daytime squall, wet holystoned planks, taut rigging shrouds and ratlines, furled sails, bowsprit, brass ship's bell, tea chests wrapped in oilcloth with no markings, ship's wheel on a wooden pedestal, sea spray, sunlight breaking through slate storm clouds, muted, no barrels, no bottles`
**Свет и палитра.** Полдень в шквал: жёсткий белый прорыв солнца в контровом сквозь сланцевые тучи, искрящиеся брызги, холодная пасмурная заливка. Hex: 1f2f4a (штормовой синий), d4b15a (латунь и солнце), c23a3a (малиновый акцент).
`midday squall, hard white sunlight breaking through slate clouds as backlight, glittering spray, cool overcast fill`
**Кадр.** Уровень глаз (без низкого ракурса), голландский наклон 6–8° синхронно с качкой. Наклон есть только у Мари. Широкий объектив 28 мм, горизонт по диагонали, ванты ведут взгляд к ней. От колен до полного роста.
`eye-level camera with a 6 to 8 degree Dutch tilt following the ship's roll, 28mm wide lens, diagonal horizon, rigging lines leading to her, framed from the knees to full length`
**Анимация.** Переносит вес в такт качке (фон качается синхронно); поправляет треуголку двумя пальцами; перо и полы хлопают; щёлкает крышкой компаса; морщится от брызг и смеётся; отгоняет чайку.
**Ножки и горячие жесты** (`LEGWEAR.md` §3, §4.3 п. 13): LW56–LW59. Жесты: `ma.heel_strike`, `ma.boot_shine`, `ma.sash_wind`, `ma.attention_blush`; у всех также `leg_idle`, `sheen_sweep`, `ornament_sway`.
**Взгляд через плечо:** только в одном SSR-наряде — у штурвала оглядывается на шторм (кадр выше талии).

---

## 14. hibana — Хибана · барабанщица-тайко

**Пластика.** Никогда не стоит на месте: пружинит на носках, локти разведены, палочки крутятся. Каждое действие на сильную долю: топает, отбивает, кивает. Улыбка зубастая, занимает кадр энергией. В тишине резко замирает и сжимается — единственный момент, когда она маленькая.
**Ноги.** Пружинит на носках, топ на сильную долю; носки внутрь только сидя в тишине.
**Реквизит.** Палочки-бати, огромный одайко на подставке, кольцо симэ-дайко, шнур-оби, томоэ в волосах, жёлтые молнии.

**Позы**

1. **idle** · `bounce-air-roll-elbows-out` — Стопы параллельно на ширине бёдер, пятки подняты, пружинит. Локти в стороны, палочки отбивают дробь в воздухе у пояса.
   `standing in three-quarter view on wet wooden boards, feet hip-width apart and parallel, both knees bent and springy with heels lifted as she bounces on the balls of her feet, elbows out, both drumsticks beating an air drum roll in front of her waist, head bobbing to the beat, toothy excited grin, static lifting a few strands of her slate-grey wolf-cut with yellow underlayer, camera at eye level`
2. **select** · `kamae-lunge-stick-sky` — Боевая стойка тайко: глубокий выпад к одайко в левой части кадра, правая палочка вертикально в небо, левая нацелена на игрока.
   `taiko ready stance in profile-three-quarter view, deep forward lunge toward a giant drum at frame-left, left knee bent directly over the left foot, right leg extended straight behind her with the heel down, torso upright, right arm raised straight up with its drumstick pointing at the sky, left arm extended forward pointing the other drumstick at the viewer, fierce grin, eyes locked on the camera, camera at eye level`
3. **win** · `odaiko-overhead-strike` — «ДОН!» На верху одайко, момент удара двумя руками: обе палочки идут вниз вместе, тело собрано вперёд, волосы хлещут вперёд, за спиной молния.
   `standing on top of a giant odaiko drum lying on its wooden cradle, caught at the moment of a two-handed overhead strike with both drumsticks swinging down together in front of her, body coiled forward from the hips with a straight back, standing side-on to the camera with her left foot forward and her right foot back on the barrel and both knees bent, hair whipping ahead of her, shouting with her mouth wide open, electric-yellow lightning splitting the violet sky behind her`
4. **lose** · `slumped-over-odaiko` — Стоит за одайко и обмякла вперёд на его бочку к камере: руки с палочками свисают по фронту барабана, щека на коже, с волос капает дождь, щёки надуты.
   `standing behind the giant odaiko and slumped forward over its curved barrel toward the camera, both arms and drumsticks dangling down the front of the drum, cheek resting on the drum skin, legs hidden behind the drum, rain dripping from her hair, puffed-cheek sulk, camera at her face level`
5. **shy** · `low-drum-sit-toes-in` — Боится тишины: сидит на маленьком симэ-дайко, как на табурете, колени сведены, носки внутрь. Палочки поперёк бёдер, пальцы беззвучно стучат по коленям.
   `sitting on a small shime-daiko drum used as a stool, knees pressed together with the feet apart and the toes turned inward toward each other, both drumsticks laid across her thighs, fingertips silently tapping on her knees, shoulders hunched up, eyes darting sideways then back to the viewer, small awkward closed-mouth smile, camera at eye level`
6. **tease** · `oni-horns-side-knee-pounce` — Игривый «прыжок монстра» в 3/4: на правой ноге, левое колено поднято до бедра и развёрнуто вбок, а не к камере. Палочки у висков, как рожки они, шутливо рычит.
   `standing in three-quarter view on her right leg with the left knee raised to hip height and turned out to the side, not toward the camera, in a playful pounce, holding the two drumsticks upright against her temples like little oni horns, leaning slightly toward the viewer from the hips with a straight back, toothy fang-baring grin, mock growl, eyebrows raised, camera at eye level`

**Окружение.** Деревянная барабанная башня-ягура над террасами горной чайной плантации в весеннюю грозу: косые струи дождя над кустами, огромный одайко на подставке, кольцо симэ-дайко, мокрый настил, соломенные кисти, дальние молнии. Не святилище и без фонарей.
`background: wooden drum tower above terraced mountain tea plantation rows in a dusk spring thunderstorm, slanting sheets of rain over tea bushes, a giant odaiko drum on a wooden cradle, a ring of small shime-daiko drums, wet plank floor, straw rope tassels, distant lightning over the ridges, muted and desaturated, no shrine buildings, no lanterns`
**Свет и палитра.** Сумерки, гроза: фиолетовый рассеянный свет и прерывистый жёлто-золотой контровой от молний (не белый, не чаще 3 вспышек в секунду). Hex: 2c2650 (грозовой фиолет), ffd23f (молния), 8e8fa3 (дождь и сталь).
`dusk thunderstorm, diffuse violet ambient light, intermittent yellow-gold lightning backlight`
**Кадр.** Уровень глаз, плотный экшен от середины бедра. Обод ближнего одайко в нижнем левом углу, объектив 35 мм. Палочки и пряди выходят за край кадра (выход за рамку есть только у Хибаны), лёгкие следы движения на палочках.
`eye-level tight action shot from mid-thigh, rim of a near odaiko in the lower-left foreground, 35mm lens, drumsticks and hair strands breaking past the frame edges, slight motion trails on the sticks`
**Анимация.** Стучит палочками по воздуху около 120 BPM; крутит палочку; статика поднимает пряди, бегут искры; притопывает на сильную долю; если звука нет 5 с, замирает и оглядывается.
**Ножки и горячие жесты** (`LEGWEAR.md` §3, §4.3 п. 14): LW60–LW63; рваный только LW63, hi_base цел. Жесты: `hi.beat_stomp`, `hi.bounce_toes`, `hi.rip_knee_beat` (только hi_rock), `hi.raijin_crackle`, `hi.sock_pullup`; у всех также `leg_idle`, `sheen_sweep`, `ornament_sway`.
**Взгляд через плечо:** нет.

---

## 15. nemi — Неми · эльфийка-лучница

**Пластика.** Экономия движений: стоит неподвижно, как цапля, тело собрано в длинные вертикали, руки близко к корпусу. Лицо почти не меняется, эмоции выдают уши. Юмор держится на контрасте огромного роста и невозмутимости. Смотрит сверху вниз — по праву роста.
**Ноги.** Неподвижные вертикали: поза дерева, стойка лучника.
**Реквизит.** Длинный лук, стрелы с медным оперением, венец из листьев, золотые каффы на ушах, короткий плащ с капюшоном, кленовый лист, шпажка данго.

**Позы**

1. **idle** · `tree-pose-bow-planted-leaf-catch` — Поза дерева на широкой ветви: стоит на прямой правой, левая стопа у правого колена, колено отведено от камеры. Лук вертикально у стопы, на поднятую ладонь садится лист.
   `standing tall on a broad mossy branch in three-quarter profile, balanced on her straight right leg, left foot pressed flat against the inside of her right knee in a yoga tree pose with the left knee pointing away from the camera, longbow planted vertically beside her right foot with her right hand resting lightly on its grip, left hand raised palm-up at shoulder height as a maple leaf drifts into it, perfectly still, calm deadpan face, long ears slightly tilted, camera at eye level`
2. **select** · `full-draw-side-stance` — Полное натяжение в боковой стойке. Стрела направлена за кадр влево, никогда в камеру.
   `full draw in a side-on archer's stance, feet shoulder-width apart on a line perpendicular to the camera, both knees straight, left arm fully extended holding the longbow, right hand drawing the string back to the corner of her jaw, arrow aimed off-frame to the left and never at the camera, head turned toward the target, eyes narrowed, wind lifting her thin copper braids and short hooded cape, camera at eye level`
3. **win** · `bow-horizontal-bird` — Стопы на небольшом шаге, ноги прямые. Лук горизонтально на уровне плеча, на его конец садится птичка, правая рука у бедра показывает крошечный невозмутимый «класс». Уши торчком.
   `standing straight with her feet a small step apart and both legs straight, weight even, left arm extended holding the longbow horizontally at shoulder height with a small songbird landing on its tip, right hand giving a tiny deadpan thumbs-up at hip height, both long ears perked straight up and twitching, the faintest satisfied smile, full-length framing emphasizing her height, camera at eye level`
4. **lose** · `trunk-hug-slide-dango` — «Ветер был против.» Обнимает огромный ствол сбоку, щека сплющена о кору, медленно сползает по нему, колени вместе сгибаются. Шпажка данго в зубах, уши обвисли.
   `hugging the huge tree trunk sideways with both arms, cheek squashed against the bark, slowly sliding down it with both knees bending together and both feet on the branch, long ears drooping, a skewer of sweet dango still held in her mouth, blank deadpan eyes, camera at eye level`
5. **shy** · `ears-pulled-down` — Лицо невозмутимо, но оба уха покраснели и обвисли. Хватает по уху в каждую руку и натягивает их на щёки. Стоит прямо, ноги вместе, глаза в сторону.
   `deadpan face, but both long pointed ears have flushed red and drooped, she grabs one ear in each hand and pulls them down over her cheeks, standing straight with both legs straight and together, eyes averted to the side, camera at eye level`
6. **tease** · `looming-headpat` — Шагнула вплотную и сверху кладёт ладонь игроку на макушку. Смотрит вниз со своего роста, едва заметная самодовольная улыбка. Ответ на гэп Кохаку.
   `stepping close to the viewer and reaching her right hand forward and down to pat the top of the viewer's head, the hand at the top edge of the frame palm down, looking down at the camera from her great height with half-lidded eyes and the faintest smug smile, left hand holding the longbow upright at her side, weight on her straight left leg, right leg relaxed with the knee slightly bent and the foot a half-step forward, camera at the viewer's eye level with an upward tilt under 10 degrees`

**Окружение.** Крона исполинских диких чайных деревьев осенним утром: широкие живые ветви-тропы, мосты из корней и лиан, мох и лишайник, падающие медные и золотые листья, туман далеко внизу, лучи сквозь листву. Действие наверху, а не у корней.
`background: canopy of colossal ancient wild tea trees on an autumn morning, broad living branches used as walkways, bridges of roots and vines, moss and hanging lichen, copper and gold leaves drifting down, mist far below, sun shafts through the foliage, muted and desaturated`
**Свет и палитра.** Раннее осеннее утро: пятнистые лучи сквозь крону, тёплый медный отсвет листвы, прохладная зелёная тень. Hex: 4f6b35 (мох), b8612e (медь), f2d98a (утреннее золото).
`early autumn morning, dappled sun shafts through the canopy, warm copper bounce from the leaves, cool green shade`
**Кадр.** Полный рост, вертикаль. Камера на уровне глаз с соседней ветви на расстоянии, телевик 85 мм. Над головой много воздуха, вертикальный ствол ведёт взгляд, она занимает высокую узкую полосу кадра.
`full-length vertical shot from a neighboring branch at eye level, 85mm telephoto compression, lots of air above her head, a vertical trunk as a leading line, she fills a tall narrow strip of the frame`
**Анимация.** Почти неподвижна; уши дёргаются по очереди; моргает медленно; не глядя ловит лист двумя пальцами; поправляет оперение; переносит вес раз в ~10 с; на тап по голове кончики ушей розовеют.
**Ножки и горячие жесты** (`LEGWEAR.md` §3, §4.3 п. 15): LW64–LW67. Жесты: `ne.weight_shift`, `ne.leaf_on_knee`, `ne.toe_twist`, `ne.vine_bloom`, `ne.feather_sway`; у всех также `leg_idle`, `sheen_sweep`, `ornament_sway`.
**Взгляд через плечо:** только в одном наряде — опирается на вертикальный лук и оглядывается вдоль ветви (кадр выше талии).

---

## 16. zlata — Злата · царевна Жар-птица

**Пластика.** Царственная широта: стоит фронтально и симметрично, как на иконе или лубке, твёрдо на обеих ногах. Ноги говорят языком русского пляса: «каблучок» носком вверх. Руки движутся широкими дарящими махами. Главный реквизит — коса до пола: держит её, как свечу, ведёт, как ленту. Никогда: рука на бедре, сидя нога на ногу.
**Ноги.** Симметрия на обеих ногах; плясовой «каблучок» носком вверх (он есть только у Златы).
**Реквизит.** Коса до пола с тлеющим кончиком, светящееся перо жар-птицы, расписная тарелка со стопкой блинов, вышитый рушник.

**Позы**

1. **idle** · `frontal-mantle-braid-candle` — Строго анфас, стопы на ширине бёдер, плащ-крылья запахнуты, как мантия. Обеими руками у талии держит тлеющий кончик косы, как свечу.
   `standing perfectly frontal and symmetrical, both feet planted hip-width apart with the weight even on both legs, both knees soft, toes turned slightly outward, feather wing-cape folded closed around her shoulders like a mantle and parting at the front to show the sarafan, both hands held together at waist height cradling the glowing ember tip of her floor-length braid like a candle, the braid running down over her right shoulder, chin slightly raised, eyes looking straight into the camera, regal warm half-smile`
2. **select** · `folk-heel-step-arm-sweep` — Плясовой «каблучок»: правая нога на пятке носком вверх, разрез открывает узорный чулок. Правая рука широким махом раскрывает крыло-рукав, левая ладонь на сердце.
   `folk-dance heel step: left leg bearing her weight with the knee softly bent, right leg extended forward with the heel planted and the toes lifted up, the skirt slit falling open along the right thigh, right arm swept wide to the side with the feather wing-sleeve fanned open like a flame, left hand pressed flat over her heart, torso upright, head tilted toward the extended arm, braid swinging out behind her, eyes on the camera, bright beaming open-mouth smile`
3. **win** · `sunburst-V-tiptoe` — «Весна пришла!» Обе руки вскинуты широкой V, рукава-крылья веером, как лучи восходящего солнца. Ноги вместе, поднялась на носки. Вокруг лишь несколько искр, без вихря.
   `both arms raised high and wide in a V above her head, feather wing-sleeves fanned out like the rays of a rising sun, both legs together and straight, rising onto the balls of both feet in her heeled boots, head tipped back laughing with eyes happily squeezed shut, floor-length braid swinging around her in a glowing arc, a few sparks drifting upward`
4. **lose** · `wet-firebird-cape-drooped` — Строго анфас, стопы вместе. Плащ-крылья обвисли и сомкнулись, как у вымокшей взъерошенной жар-птицы: видны только лицо, край сарафана и носки сапог. Кончик косы посерел до пепла, улыбка храбрая и дрожащая.
   `standing strictly frontal and symmetrical with both feet together and both legs straight, the feather wing-cape drooping closed around her like the wings of a rain-soaked, ruffled firebird so only her face, the sarafan hem and her boot tips show, hands resting clasped at her waist inside the cape, the braid hanging limp over one shoulder with its tip greyed to ash, brave wobbly small smile, eyes on the camera`
5. **shy** · `turnaway-dip-pancake-plate` — Поймана с блином во рту: развернулась на 3/4 прочь, тарелка с блинами у бедра, недоеденный блин у губ. Колени вместе в испуганном приседе, обе стопы на полу. Оглядывается, густо краснеет.
   `caught mid-bite, standing turned three-quarters away from the camera, a tall stack of golden pancakes on a painted plate balanced against her right hip with her right hand, her left hand holding a half-bitten rolled pancake at her lips with her mouth full, both knees together and softly bent in a small startled dip, both feet flat on the floor side by side, head turned back toward the camera, wide eyes, deep blush, a crumb on her lip`
6. **tease** · `lean-back-braid-ribbon-pull` — Ведёт игрока косой: обмотала её вокруг левого запястья и натягивает к камере, как ленту. Откинулась на прямую левую, правая на пятке носком вверх, палец у нижней губы.
   `leading the viewer along by her braid: the braid looped once around her left wrist and pulled taut toward the camera like a ribbon, its ember tip glowing at the frame edge, weight leaning back onto her straight left leg, right leg extended forward with the heel on the floor and the toes up, right index finger pressed under her lower lip, one eyebrow raised, sly lopsided smile, eyes locked on the viewer`

**Окружение.** Резная деревянная галерея терема (гульбище) над оттаивающей рекой на весеннем рассвете: наличники с жар-птицами, вышитые рушники сохнут на перилах, берёзы с первыми почками, по реке плывут льдины. Снега и сосулек нет: зима есть только у Сигрид. Не тронный зал.
`background: carved wooden terem gallery-porch overlooking a thawing river at spring sunrise, window frames carved with firebirds, embroidered linen towels drying on the railing, birches with first buds, ice floes drifting on the river, no snow, no icicles, muted`
**Свет и палитра.** Низкое восходящее солнце в контровом сквозь резьбу, тёплый угольный подсвет снизу от косы и перьев, холодная голубая тень от реки. Hex: e8b23a (золото), c3242b (угольно-алый), 7e93b5 (тень рассвета).
`low spring sunrise backlight through the carvings, warm ember underglow from her braid and feathers, cool blue shadow from the river`
**Кадр.** Строго фронтально и симметрично (это есть только у Златы), камера на уровне глаз, от колен. Она по центру в «раме в раме» из резного наличника или арки гульбища, как на лубке. Без наклона, без диагоналей.
`strictly frontal and symmetrical icon composition, she stands dead center inside a carved window-frame or gallery arch like a lubok print, camera at eye level, knees-up, no tilt, no diagonals`
**Анимация.** Отбрасывает косу коротким движением шеи, с кончика сыплются искры; отбивает каблучком такт; перья плаща дышат волной; обмахивается собственным пером; смахивает крошку с уголка губ тыльной стороной пальца (облизывание запрещено ROSTER §4.3).
**Ножки и горячие жесты** (`LEGWEAR.md` §3, §4.3 п. 16): LW68–LW71; `allure` анфас с мантией-крыльями. Жесты: `zl.heel_tap`, `zl.drobushka`, `zl.ember_seam`, `zl.ribbon_ends`; у всех также `leg_idle`, `sheen_sweep`, `ornament_sway`.
**Взгляд через плечо:** только в одном SSR-наряде — поднимается по ступеням крыльца, коса тянется следом, как хвост кометы (кадр выше талии).

---

## 17. minamo — Минамо · принцесса Жемчужного дворца

**Пластика.** Невесомая: никогда не стоит на опоре, а парит. Ноги сомкнуты и мягко согнуты вбок, как русалочий хвост, носки вытянуты. Движения медленные и текучие, руки «плывут» на уровне плеч. Рассеянно-любопытная, её выражение — раскрытое «о».
**Ноги.** Не касается опоры, ноги вместе, как русалочий хвост.
**Реквизит.** Лаковая шкатулка-тамэтэбако, шаль-хагоромо, нити жемчуга, жемчужина-подарок, морская черепаха.

**Позы**

1. **idle** · `upright-float-mermaid-legs` — Парит вертикально. Ноги сомкнуты и согнуты влево, как русалочий хвост, руки плывут на уровне плеч, шаль и волосы поднимаются. Мечтательно смотрит на свет колодца.
   `floating weightlessly upright in clear water with her feet not touching anything, both legs pressed together and bent at the knees, swept gently to her left like a mermaid's tail with the toes pointed, both arms drifting loosely at shoulder height with palms down and fingers softly spread, translucent shawl and pearl-strung hair drifting upward around her, head tilted back slightly, gazing up toward the sunlight above with half-lidded dreamy eyes and a soft parted-lip smile, gown fully opaque and smoothly in place`
2. **select** · `prone-float-peek-hands-cupped` — Подплывает к камере лицом вперёд, как к стеклу аквариума, ладони козырьком у глаз. Ноги позади согнуты, голени подняты, лодыжки скрещены. Губы буквой «о».
   `floating horizontally face-first toward the camera as if peering through glass, both hands cupped around her eyes like a diver's mask, head and shoulders in the foreground, both legs trailing behind her bent at the knees with the lower legs raised and the ankles crossed, toes pointed, hair and shawl streaming behind, big curious eyes wide open, lips in a small round 'oh' of wonder`
3. **win** · `turtle-ride-shawl-sail` — Встала на носки на панцирь огромной доброй морской черепахи, которая плывёт вверх к свету. Ноги вместе, руки раскинуты и держат шаль, как парус.
   `riding upward on the shell of a huge gentle sea turtle as it glides toward the light, standing lightly on the tiptoes of both feet on its shell with both legs together and straight, both arms spread wide holding the ends of the translucent shawl so it billows behind her like a sail, hair streaming, sparkling eyes, open delighted 'oh' of a smile`
4. **lose** · `side-curl-cocoon-drift` — Свернулась клубком и медленно дрейфует, вид сбоку: колени у груди, ноги вместе, платье гладко обёрнуто. Обнимает голени, шаль, как кокон. Щёки надуты.
   `curled into a slowly drifting ball, seen from the side, both knees drawn up to her chest with the legs together and the gown wrapped smoothly around her legs, both arms hugging her shins, translucent shawl wrapped around her like a cocoon, cheek resting on her knees, puffed pouting cheeks, glistening eyes looking at the camera`
5. **shy** · `clam-shell-lid-peek` — Спряталась в раковину: сидит прямо в огромной раскрытой раковине, колени вместе вбок, обеими руками тянет верхнюю створку вниз, как крышку, и выглядывает из-под неё.
   `sitting upright inside the giant open clam shell, both knees together turned to her left, both feet tucked side by side on the shell's pearly floor, both hands pulling the upper shell down like a lid, peeking out from under it with a deep blush, only her face, hands and knees visible`
6. **tease** · `slow-spin-empty-box` — «Не открывай!» Медленно вращается вертикально, волосы закручиваются спиралью. Держит шкатулку открытой к камере: пусто! Ноги вместе и прямые, язык высунут, глаза зажмурены от смеха.
   `turning slowly upright in the water with her hair spiralling around her, both legs together and straight with the toes pointed, holding the lacquered jewel box open toward the camera with both hands to show that it is empty, tongue poking out, both eyes squeezed in a giggle, a few bubbles, gown hem wrapped smoothly around her legs`

**Окружение.** Затопленный жемчужный грот под колодцем салона: круглая шахта колодца с диском дневного света, перламутровые стены, ламинарии, медузы-фонари, гигантская раскрытая раковина, морская черепаха, затонувший лаковый стол с плывущими фишками. Вода магическая: ткань не мокнет и не просвечивает.
`background: flooded pearl grotto beneath a stone well, a round shaft above with a bright disc of daylight, mother-of-pearl walls, swaying kelp, jellyfish lanterns, a giant open clam shell, a gentle sea turtle, a sunken lacquered table with blank tiles drifting, light caustics, magical water where fabric stays dry-looking and fully opaque, muted`
**Свет и палитра.** Полдень сквозь толщу воды: вертикальный солнечный столб сверху, каустики по коже и ткани, перламутрово-фиолетовый рим. Hex: 7fd3d0 (аква), f3e9f1 (перламутр), 3a4fa0 (глубина).
`noon light through deep water, a vertical sun shaft from above, crawling caustics on skin and fabric, pearl-violet rim`
**Кадр.** Всегда в полный рост: видны вытянутые носки, ноги не касаются земли. Камера на уровне её груди, без наклона, много воздуха над головой. Она чуть смещена от центра и дрейфует в кадре.
`always full length with pointed toes visible and feet off the ground, camera at her chest height with no tilt, lots of space above her head for drifting hair and shawl, she drifts slightly off-center`
**Анимация.** Покачивается вверх-вниз на 6–8 px, как буй; пальцы ног поджимаются и вытягиваются; накручивает жемчуг на палец; хихикает пузырьками; моргает медленно; шаль и волосы отстают на полтакта.
**Ножки и горячие жесты** (`LEGWEAR.md` §3, §4.3 п. 17): LW72–LW75. Жесты: `mi.mermaid_flutter`, `mi.toe_curl`, `mi.ankle_drift`, `mi.pearl_chime`; у всех также `leg_idle`, `sheen_sweep`, `ornament_sway`.
**Взгляд через плечо:** нет.

---

## 18. kira — Кира · ас-пилот меха

**Пластика.** Угловатая и резкая: широкие стойки, локти наружу, каблуки ботинок впечатаны в металл. Двигается рывками с чёткой фиксацией, как по уставу, даже когда дурачится. Руки заняты железом: шлем, гарнитура, «пистолет» из пальцев. В смущении зажимается в стойку «смирно». Её выражение — ухмылка «язык за щекой», не подмигивание.
**Ноги.** Щелчок каблуков, стрелковая стойка, ботинок на броне.
**Реквизит.** Пилотский шлем, алая гарнитура с антенной, запасная гарнитура «для штурмана», эмблема-хризантема.

**Позы**

1. **idle** · `lean-back-boot-on-armor-helmet-spin` — Откинулась на коленный бронещиток стоящего на колене меха, локоть заброшен за край брони. Правая нога прямая, подошва левого ботинка упёрта в броню. Крутит шлем на пальце.
   `leaning back against the knee armor of her kneeling white mecha with her left elbow hooked back over the armor edge, right leg straight and planted, left knee bent with the sole of her left boot flat against the armor behind her, right hand raised at shoulder height spinning her helmet on her index finger, chest open, chin up, cocky lopsided grin at the camera`
2. **select** · `narrow-shooter-finger-gun` — «Цель захвачена!» Ботинки на ширине плеч, колени чуть согнуты, корпус развёрнут к камере. Правая рука «пистолетом» в объектив (единственное прицеливание в камеру в ростере), левой прижимает микрофон.
   `standing with both boots planted at shoulder width and both knees slightly bent, torso twisted to face the camera, right arm extended straight toward the lens in a finger-gun, left eye closed sighting along her arm, left hand pressing the headset microphone to her lips, sharp focused grin`
3. **win** · `mech-palm-V-sign` — Стоит на поднятой открытой ладони меха: ботинки вместе, вес в одно бедро, шлем у бедра. Правая рука делает V у глаза, вторая гигантская рука меха позади повторяет V.
   `standing on the mecha's raised open palm in three-quarter view, both boots together with her weight sunk into one hip, left hand holding her helmet against her hip, right hand making a V-sign over her right eye, tongue-in-cheek grin, short bob ruffled by the wind, the mecha's other giant hand behind her copying the V-sign`
4. **lose** · `soot-smoking-helmet` — Плечи сникли, ботинки на ширине плеч. Держит шлем вверх дном у пояса обеими руками, из него вьётся дымок. Сажа на щеке, глаза-спиральки, антенна поникла.
   `standing with both legs straight and both boots at shoulder width, shoulders slumped, holding her helmet upside down at waist height in both hands with a thin curl of smoke rising out of it, a soot smudge on her cheek, dizzy spiral eyes, the small antenna on her headset drooping, groaning open mouth`
5. **shy** · `rigid-attention-salute` — Смущение уходит в устав: «смирно», каблуки щёлкнули, носки врозь, правая ладонь в салюте у брови. Лицо пунцовое, из гарнитуры пар.
   `rigid regulation attention, heels clicked together with the toes angled out, both legs straight and pressed together, body ramrod straight, left arm stiff at her side with fingers together, right hand in a textbook flat-palm salute at her brow, face beet red, eyes darting sideways away from the camera, tiny puffs of steam from her headset, wobbly mouth`
6. **tease** · `hatch-standing-headset-pendulum` — «Второе кресло пустует.» Стоит в открытом люке кокпита, правый ботинок на ободе люка, колено вбок. На вытянутой руке качает запасную гарнитуру за кабель, как маятник, к камере.
   `standing up in the open cockpit hatch, right boot up on the hatch rim with the knee bent out to the side, left leg straight inside the hatch, holding a second pilot headset out at arm's length by its cable and swinging it like a pendulum toward the camera, head tilted, one eyebrow cocked, smug teasing smile`

**Окружение.** Двор чайного домика ночью, куда рухнул мех. Белый мех стоит на одном колене, вокруг опрокинутая каменная чаша для омовения, расколотая бамбуковая изгородь, брезент, кабели, тележки с инструментом, выжженный гравий, черепичные карнизы. Не ангар.
`background: a traditional tea house courtyard at night where a giant white mecha crash-landed and now kneels, a toppled stone water basin, a split bamboo fence, tarps and thick cables, tool carts, scorched raked gravel, tiled tea house eaves above, sci-fi hardware against old wood, muted`
**Свет и палитра.** Ночь: тёплые натриевые рабочие прожекторы сбоку, красный стробоскоп, холодный голубой глаз-сенсор меха в контровом. Hex: ffb866 (прожектор), e03a3e (строб), 1c2b4a (ночная сталь).
`night, warm sodium work floodlights from the side, a red warning strobe, the mecha's cold blue sensor eye as backlight`
**Кадр.** Низкий ракурс 15–20° (на ней комбинезон, правило это допускает; низкий ракурс есть только у Киры), широкоугольник, горизонт **ровный**. На переднем плане крупное железо меха: пальцы, бронеплиты, кабели. Сильная диагональ композиции.
`dynamic low angle of 15 to 20 degrees, wide-angle lens, level horizon, huge mecha fingers, armor plates and cables in the foreground, strong diagonal composition`
**Анимация.** Крутит шлем и ловит; стучит по гарнитуре, когда та пищит; пружинит на каблуках; сдувает чёлку уголком рта; хрустит пальцами в перчатках; на внезапный звук застывает в стойке.
**Ножки и горячие жесты** (`LEGWEAR.md` §3, §4.3 п. 18): LW76–LW79; `lean-back-boot-on-armor` и низкий ракурс только стоя и только ki_base/ki_stealth, в ki_off/ki_dress витрина `rigid-attention-salute`. Жесты: `ki.heel_click`, `ki.salute_stop`, `ki.boot_zip`, `ki.dring_glint`; у всех также `leg_idle`, `sheen_sweep`, `ornament_sway`.
**Взгляд через плечо:** нет.

---

## 19. vesper — Веспер · графиня-вампир

**Пластика.** Томная театральность: длинные вытянутые линии, ленивая неподвижность, замедленный темп. Ноги удлинены в балетный тандю или вытянуты вдоль кушетки. Пальцы в перчатках точные: чашка, роза, зонтик, край кейпа. Смотрит на зрителя сверху вниз, подбородок чуть запрокинут — это её право в ростере.
**Ноги.** Балетный тандю, придворный реверанс, длинная диагональ.
**Реквизит.** Фарфоровая чашка гранатового чая, алая роза, чёрный кружевной зонтик, плюшевая летучая мышь (тайная), длинные атласные перчатки.

**Позы**

1. **idle** · `chaise-upright-legs-long-rose` — Сидит прямо (не полулёжа) в торце чёрной бархатной кушетки, локоть на изогнутом подлокотнике, щека на кончиках пальцев. Ноги вместе вытянуты вдоль кушетки, колени вместе, лодыжки скрещены. Лениво крутит розу.
   `sitting upright, not reclining, at the end of a black velvet chaise longue in a long diagonal across the frame, left elbow on the scrolled armrest with her cheek resting on her gloved fingertips, right hand lazily twirling a crimson rose by its stem, both legs extended together along the chaise with the knees together and the ankles crossed, toes pointed, the gown's slit falling along her outer thigh, heavy-lidded bored eyes looking down at the camera, faint smile showing a tiny fang, camera at her face level`
2. **select** · `tendu-lace-parasol` — «Как фамильярно…» Раскрытый кружевной зонтик на плече бросает кружевную тень на пол-лица. Вес на прямой левой, правая в тандю сквозь разрез (тандю есть только у Веспер). Тыльной стороной пальцев прикрывает губы.
   `standing tall, an opened black lace parasol resting on her right shoulder so its lace shadow falls across half her face, weight on her straight left leg, right leg extended forward in a ballet tendu with the pointed toe of her heeled boot touching the floor through the high slit, left gloved hand raised with the back of her fingers hiding her lips, narrowed amused eyes looking down at the camera`
3. **win** · `deep-court-reverence` — Глубокий придворный реверанс: правая нога отведена далеко назад, колени низко согнуты, руки широко разводят юбку, спина прямая. Вокруг лишь несколько лепестков.
   `deep theatrical court reverence, right leg slid far back behind the left, both knees bent low, both gloved hands holding the skirt out wide to the sides, back straight and head raised, eyes on the camera with a triumphant smile showing a tiny fang, a few rose petals drifting around her`
4. **lose** · `swoon-lean-harpsichord` — Театральный обморок стоя: откинулась на изогнутый бок клавесина длинной диагональю, ноги прямые, лодыжки скрещены, запястье ко лбу, чашка болтается на пальцах.
   `theatrical swoon, leaning back against the curved side of a harpsichord with her body in a long diagonal, both legs straight with the ankles crossed, the back of her right gloved wrist pressed to her forehead, left arm hanging down with a porcelain teacup dangling from her fingers, eyes closed, mouth open in a dramatic sigh, no arched back`
5. **shy** · `ventriloquist-plush-bat` — Чревовещание: держит плюшевую летучую мышь на вытянутой руке перед лицом, как куклу, и «говорит» через неё: «Она НЕ смущена». Пунцовое лицо выглядывает сбоку. Ноги прямые и сомкнуты.
   `standing in profile with both legs straight and pressed together, holding a cute plush bat at arm's length in front of her face like a puppet, its little mouth open as if speaking for her, her deep-red flushed face peeking out beside it, eyes darting to the viewer, lips pressed together`
6. **tease** · `bench-glove-bite-knees-aside` — Сидит на банкетке клавесина, откинулась на правую руку. Колени вместе, обе ноги уведены влево, стопы одна за другой. Снимает зубами левую перчатку, ткань зацепилась за клычок.
   `seated on the harpsichord bench turned toward the camera, upper body leaning back slightly on her right hand braced on the bench, both knees together with both legs angled to her left and one foot placed behind the other, pulling off her left long satin glove with her teeth, the fabric caught on her tiny fang, eyes locked on the viewer, sly smile, camera at her eye level, slit unchanged`

**Окружение.** Музыкальный салон замка «Вечерняя звезда»: чёрный клавесин, бархатная кушетка, высокое стрельчатое витражное окно, которое светится рубиновым от костра снаружи (луны нет), канделябры с оплывшим воском, сервиз с гранатовым чаем, чёрные розы, тяжёлые портьеры. Не тронный зал.
`background: gothic castle music salon, a black lacquered harpsichord, a black velvet chaise longue, a tall pointed-arch stained-glass window glowing ruby from a bonfire outside, no moon, candelabras dripping wax, porcelain tea set with pomegranate tea, black roses in a vase, heavy velvet drapes, muted`
**Свет и палитра.** Только свечи: тёплое дрожащее пламя спереди и сбоку, рубиновые пятна витража на полу, винно-чёрные тени. Hex: e8a05a (свечи), 6b0f1a (вино), c9c3cf (бледное серебро кожи и кружева).
`candlelight only, warm flickering flames from the front and side, ruby patches of stained-glass light on the floor, deep wine-black shadows`
**Кадр.** Длинная диагональ тела через кадр, длиннофокусное сжатие, тяжёлый передний план из бархатной портьеры или канделябра в расфокусе, виньетирование, как из ложи оперы. Камера на уровне её лица или груди, вверх не больше 5°: она всегда смотрит вниз на зрителя.
`long diagonal of her body across the frame, telephoto compression, a heavy out-of-focus velvet drape or candelabra in the foreground, theatrical opera-box vignette, camera at her face or chest level with an upward tilt under 5 degrees`
**Анимация.** Покачивает гранатовый чай в чашке; крутит розу; моргает лениво; сидя перекладывает лодыжки; постукивает пальцем в перчатке по клычку; вуалетка колышется от сквозняка свечей.
**Ножки и горячие жесты** (`LEGWEAR.md` §3, §4.3 п. 19): LW80–LW83; `allure` у клавесина. Жесты: `ve.ankle_swap` (18+, V), `ve.shoe_dangle` (18+), `ve.toe_point`, `ve.calf_glide` (18+), `ve.lace_trace` (18+); у всех также `leg_idle`, `sheen_sweep`, `ornament_sway`.
**Взгляд через плечо:** только в одном наряде — у рубинового витража (кадр выше талии).

---

## 20. sigrid — Сигрид · северная княжна

**Пластика.** Сдержанная, собранная и точная, как фигуристка: локти близко, колени вместе, спина прямая, движения мелкие и выверенные. Её язык — лёд: позиции, скольжение, перебежка, вращение. Под ногой расцветает иней. Тёплая неловкость прорывается только в лице: румянец, пар дыхания.
**Ноги.** Т-позиция, скольжение на одной ноге, перебежка, аттитюд, вращение.
**Реквизит.** Медная кружка горячего шоколада (у талии, к губам не подносит — это право Рин), лента северного сияния, ледяная тиара-кристалл, ледяная пластина с морозным цветком.

**Позы**

1. **idle** · `skater-T-tiara-touch-mug-at-waist` — Т-позиция на чёрном льду: правая стопа впереди, пятка левой у её подъёма. Кончиком пальца поправляет тиару, левой держит кружку у талии. Пар дыхания.
   `standing on the black ice of a frozen lake in a figure-skater T-position, right foot forward with the left heel tucked against the right instep, both legs straight and close together, right fingertip adjusting her crystal tiara, left hand holding a small copper mug of hot chocolate low at her waist, visible breath mist, aurora ribbon resting over her forearms, seen in three-quarter profile, reserved small smile at the camera`
2. **select** · `crossover-glide-carriage-arms` — Перебежка фигуристки: скользит мимо камеры боком на левой, правая стопа перекрещивается через левую, из-под лезвия летит иней. Руки в «карете»: одна вперёд, другая назад на уровне плеч.
   `gliding past the camera side-on in a skater's crossover stride, weight on her left leg with the knee softly bent, right foot crossing over in front of the left, frost spraying from the blade, arms held in a skater's carriage with the right arm forward and the left arm back at shoulder height, palms down, aurora ribbon streaming behind, head turned to the camera with a small polite nod and a faint awkward smile`
3. **win** · `scratch-spin-wrists-crossed` — Стоп-кадр вертикального вращения: руки над головой, запястья скрещены, ноги прямые и плотно скрещены в лодыжках. Юбка прилегает к ногам, спиралью в небо уходит лента сияния.
   `frozen in an upright scratch spin on the ice, both arms raised overhead with the wrists crossed, both legs straight and crossed tight at the ankles, body perfectly vertical, the skirt hugging her legs with the hem in place, the aurora ribbon and her hair carrying the spin in a spiral up into a sky ablaze with northern lights, eyes closed, serene radiant smile`
4. **lose** · `slipped-sit-on-ice-profile` — Поскользнулась и села на лёд, строго профиль: ноги вместе вытянуты вправо, колени чуть согнуты, опора на левую руку сзади. Правой ладонью закрыла глаза, иней на ресницах, тиара съехала.
   `slipped and sat down on the ice, seen in side profile at eye level, both legs extended together to her right with the knees slightly bent, propped back on her left hand behind her, right hand covering her eyes, frost on her eyelashes, crystal tiara tilted askew, a small resigned smile under her palm, a puff of breath mist`
5. **shy** · `behind-ice-pane-frost-flower` — Наполовину за высокой прозрачной ледяной пластиной, кончиком пальца рисует на ней морозный цветок. В профиль, вес на левой, правая стопа на носке заведена за левую лодыжку. Дыхание туманит лёд.
   `half-hidden behind a tall clear pane of ice, drawing a frost flower on it with her right fingertip, left hand curled against her chest, standing in profile with her weight on her straight left leg and the right foot tucked behind the left ankle resting on its toe, pink flush on her pale cheeks, breath fogging the ice, eyes peeking at the camera through the frost`
6. **tease** · `glide-attitude-blow-snowflake` — Сдувает сверкающую снежинку с ладони к камере. Скользит на правой, чуть подавшись вперёд от бёдер, левая нога поднята назад и согнута в низком аттитюде. Губы сложены трубочкой, редкая озорная улыбка в глазах.
   `blowing a sparkling snowflake off her flat open right palm toward the camera while gliding on her straight right leg, leaning forward slightly from the hips with a straight back, left leg lifted low behind her with the knee bent in a skater's attitude, palm held at lip height, lips pursed to blow, eyes half-closed with a rare mischievous smile, seen from the side`

**Окружение.** Замёрзшее горное озеро полярной ночью: чёрный зеркальный лёд отражает сияние, на берегу резная ледяная беседка и заснеженные ели, медный котелок шоколада на жаровне, высокие прозрачные ледяные пластины прямо на льду, следы инея. Зима и снег есть только у Сигрид. Не трон.
`background: a frozen mountain lake at polar night, black mirror-like ice reflecting the aurora, a carved ice gazebo and snow-laden pines on the shore, a small copper pot of hot chocolate on a brazier, tall clear ice panes standing on the lake, faint frost trails on the ice, muted`
**Свет и палитра.** Глубокая полярная ночь: холодный ключ — отражённый свет снега и льда, переливчатый фиолетово-зелёный рим сияния сверху, крошечное тёплое пятно жаровни как единственный тёплый акцент. Hex: 7fc8d8 (лёд), 8b7fd6 (сияние), dff1f7 (иней).
`deep polar night, cold key light reflected from snow and ice, shimmering violet-green aurora rim from above, the brazier as the only small warm accent`
**Кадр.** Профиль или крутые 3/4, как следящая камера на катке. Широкий кадр в полный рост с пустым льдом и небом (негативное пространство), камера строго на уровне глаз. Она ближе к краю кадра, направление движения задаёт горизонталь.
`side-on tracking shot like a rink camera, full-length wide frame with large negative space of empty ice and sky, camera strictly at eye level, she sits near one edge of the frame moving along the horizontal`
**Анимация.** Пар дыхания на каждом выдохе; греет пальцы о кружку у талии; покачивается на льду с тонким следом инея; поправляет тиару кончиком пальца; лента сияния течёт; на миг прикрывает глаза от тепла кружки.
**Ножки и горячие жесты** (`LEGWEAR.md` §3, §4.3 п. 20): LW84–LW87; `allure` Т-позиция у бортика. Жесты: `si.ice_rock`, `si.crossover_glide`, `si.low_attitude`, `si.frost_knee`, `si.glitter_sweep`; у всех также `leg_idle`, `sheen_sweep`, `ornament_sway`.
**Взгляд через плечо:** нет.
