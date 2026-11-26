# Дуэли 2.0 и Вызов по коду (`v10/duels` и `v10/duels/challenge`)

Два соревновательных режима полки **«Столы → Испытания и соперницы»** (`docs/0.10-spec.md` R5 и R6, `docs/MODES.md` §6.1 / §7.1, `docs/UX_RULES.md`).

## 1. Состав модулей

### Дуэли 2.0 (`game/scripts/v10/duels/`)
| Файл | Класс | Назначение |
| --- | --- | --- |
| `duel_info.gd` | `V10DuelInfo` | Паспорта `INFO` («Дуэли») и `CHALLENGE_INFO` («Вызов по коду»), правила `HOW` |
| `duel_screen.gd` | `V10DuelScreen` | Экран дуэлей: сегмент «Дружеская / Рейтинговая», карточка «Дуэль недели», показ подлости и потолка `≤ 2` до боя, бейдж «ИИ · героиня», кнопка «Вызов по коду», шторка «?», церемония конца сезона |
| `duel_vs.gd` | `V10DuelVs` | Диагональная заставка перед боем: полная один раз за сессию (`1,15 с`), далее `0,5 с` (`V10Duel.vs_plan()`), пропуск нажатием |
| `duel_play.gd` | — (`extends play.gd`) | Экран матча без правок `play.gd`: фиксированный `seed`, 4 слота и отключение пассивок нарядов в рейтинговой дуэли |
| `duel_run.gd` | `V10DuelRun` | Узел гонки на реальном столе: прицел соперницы, фирменная подлость (`≤ 2`), возврат кристаллов за пары через `V10Money`, честный выход (`= поражение`), шторка итога |
| `duel_forms.gd` | `V10DuelForms` | Формы I–V всех 20 героинь (невышедшие скрыты до появления в `G.HEROES`), подлости и правила «Дуэли недели» |
| `duel_rank.gd` | `V10DuelRank` | Эло (`K = 40` первые 20 партий, далее `24`), «шанс: 46 из 100» (без `%` и `ДР`), 6 ступеней сезона, мягкий сброс, предложения в окне `±150`, сезонная косметика |
| `duel_state.gd` | `V10Duel` | Состояние `S.v10_duel`, 28-дневные сезоны и недели по сетке МСК (`V10Meta`), лимиты наград, защита от закрытия приложения во время боя |
| `duel_sim.gd` | `V10DuelSim` | Офлайн-симуляция и калибровка Брэдли–Терри (`--duel_calibrate=1` → `data/duel_ratings.json`) |
| `duel_util.gd` | `V10DuelUtil` | Единые мосты к `V10Meta`, `V10Money`, `V10Bond`, `V10ProfileCos`, `V10Lint` |
| `duel_selftest.gd` / `.tscn` | — | Полный самотест Эло, сезонов, калибровки, реальных матчей и UX-бюджетов экрана |

### Вызов по коду (`game/scripts/v10/duels/challenge/`)
| Файл | Класс | Назначение |
| --- | --- | --- |
| `challenge_code.gd` | `V10ChallengeCode` | 65-битный Crockford Base32 кодек `TW-XXXX-XXXX-XXXXX` с 13-битным CRC, извлечением из любого текста и фильтром ника |
| `challenge_deal.gd` | `V10ChallengeDeal` | Детерминированное разрешение стола (Путь, Партия дня, Странствие) и проверка правдоподобности времени |
| `challenge_poster.gd` | `V10ChallengePoster` | Рендер постера `720×1280` без спойлеров с обязательной SFW-подменой смелых нарядов (`G.ITEM[id].sfw`) |
| `challenge_screen.gd` | `V10ChallengeScreen` | Экран вызова, карточка сравнения, шторка «Бросить вызов» и хук `victory_more_item()` для меню «⋯» Победы (с 15-го уровня) |
| `challenge_play.gd` | — (`extends play.gd`) | Экран партии по коду: фиксация `seed` до раздачи, блокировка кристаллов со стола через `V10Money` |
| `challenge_run.gd` | `V10ChallengeRun` | Сравнение времени по десятым долям секунды, шторка результата и кнопка «Реванш» |
| `challenge_state.gd` | `V10ChallengeState` | Состояние `S.v10_challenge`: журнал 20 вызовов, свои коды без награды, потолок побед в сутки |
| `challenge_ui.gd` / `challenge_util.gd` | `V10ChallengeUI` / `V10ChallengeUtil` | Обёртки `V10DS` / `V10Header` / `V10BottomSheet`, мосты `V10Meta` и `V10Money` |
| `challenge_selftest.gd` / `.tscn` | — | Полный самотест кодека, опечаток, постера, SFW-проверки, UI и сквозного сценария двух профилей |

## 2. Экономика и правила (§2.3, R5, R6)

- **Рейтинговая дуэль**: нормализованный стол (4 слота у всех, без пассивок нарядов, 1 бесплатная подсказка, без покупок за кристаллы в матче); награда — **5 кристаллов × до 3 побед в сутки** (до 15 в день) через `V10Money`.
- **Дружеская дуэль**: формы II–IV с пассивками напарницы; награда — **3 кристалла × до 3 побед в сутки** + **+1 симпатии** сопернице (`V10Bond.gain`) за каждую победу; 10 побед открывают рейтинговую дуэль раньше ранга «Нефрит III».
- **Дуэль недели**: посев по `V10Meta.cal_key()` (смена в пн `04:00` МСК), особое правило стола; за **3 победы** раз в неделю — **100 кристаллов и 30 Лепестков**.
- **Конец сезона (28 дней)**: награда по **высшей** ступени сезона (50…500 кристаллов + рамки `fr_duel_cinnabar`, `fr_duel_pearl`, `fr_duel_sky` и титул `t_duel_pearl` через `V10ProfileCos`).
- **Вызов по коду**: **+5 кристаллов** за победу над чужим временем (до **3 раз в сутки**, не более раза на один код, свои коды без награды).

## 3. Как запустить самотесты

```powershell
Set-Location "C:\Users\ADMIN\.gemini\antigravity\scratch\tw-worktrees\duels-palm"
$env:APPDATA = "C:\Users\ADMIN\.gemini\antigravity\scratch\tw-appdata\duels-palm"
$godot = "C:\Users\ADMIN\.gemini\antigravity\scratch\tw-tools\godot\Godot_v4.5.1-stable_win64_console.exe"
$godot_gl = "C:\Users\ADMIN\.gemini\antigravity\scratch\tw-tools\godot\Godot_v4.5.1-stable_win64.exe"

# 1. Дуэли 2.0
& $godot --headless --path game res://scripts/v10/duels/duel_selftest.tscn -- --duel_selftest=1 --save=user://duel_selftest.json --save_wipe=1

# 2. Вызов по коду (headless + OpenGL проверка пикселей постера и SFW)
& $godot --headless --path game res://scripts/v10/duels/challenge/challenge_selftest.tscn -- --challenge_selftest=1 --save=user://ch_selftest.json --save_wipe=1
& $godot_gl --rendering-driver opengl3 --audio-driver Dummy --resolution 720x1280 --path game res://scripts/v10/duels/challenge/challenge_selftest.tscn -- --challenge_selftest=1 --save=user://ch_selftest_gl.json --save_wipe=1
```
Ожидаемые маркеры: `DUEL_SELFTEST 175/175`, `CHALLENGE_SELFTEST 294/294` (headless) и `CHALLENGE_SELFTEST 298/298` (OpenGL с проверкой рендера PNG `720×1280` и SFW-подмены нарядов).

## 4. Хуки интеграции для Шага W4

1. **`game/scripts/v10/core/registry_list.gd`** (`register_all()`, секция `# ── W4 ──`):
   ```gdscript
   R.module("duels", {
       "step": 4,
       "selftest": {"scene": "res://scripts/v10/duels/duel_selftest.tscn",
           "args": ["--duel_selftest=1", "--save=user://duel_selftest.json", "--save_wipe=1"], "marker": "DUEL_SELFTEST"},
       "screens": {"duels": V10DuelInfo.SCREEN_PATH, "duel2": V10DuelInfo.PLAY_PATH},
       "nav": {"duels": ["tables"], "duel2": ["duels"]},
       "ensure": func(_S: Dictionary) -> void:
           V10Duel.st()
           V10DuelRank.register_cos(),
   })
   R.module("challenge", {
       "step": 4,
       "selftest": {"scene": "res://scripts/v10/duels/challenge/challenge_selftest.tscn",
           "args": ["--challenge_selftest=1", "--save=user://ch_selftest.json", "--save_wipe=1"],
           "needs_render": true, "resolution": "720x1280", "marker": "CHALLENGE_SELFTEST"},
       "screens": {"challenge": V10DuelInfo.CHALLENGE_PATH, "challenge_play": V10DuelInfo.CHALLENGE_PLAY_PATH},
       "nav": {"challenge": ["tables"], "challenge_play": ["challenge"]},
       "ensure": func(_S: Dictionary) -> void: V10ChallengeState.st(),
   })
   ```

2. **`game/scripts/v10/core/tables_hub.gd`** (полка **«Испытания и соперницы»**):
   - Заменить старую карточку `"duel"` на `V10DuelInfo.INFO` (`main.go("duels")`, проверка открытия `V10Duel.menu_open()`, замок `V10Duel.lock_text("menu")`, подпись `V10DuelInfo.status().text`).
   - Добавить карточку `V10DuelInfo.CHALLENGE_INFO` (`main.go("challenge")`, открыта сразу).

3. **Экран Победы — меню «⋯» (`game/scripts/screens/play.gd` / `V10HudVictory.more_pressed`)**:
   - Для фиксации авторского стола при раздаче вызывать посев из `challenge_play.gd` (или подключить `challenge_play.gd` как базовый экран `play` при интеграции).
   - В обработчике кнопки «⋯» на экране Победы (начиная с 15-го уровня, `unlocked >= 16`) добавить пункт:
     ```gdscript
     var ch_item: Dictionary = V10ChallengeScreen.victory_more_item(self, clear_secs, clear_stars)
     if not ch_item.is_empty():
         more_items.append(ch_item)  # {id: "challenge", label: "Бросить вызов", action: Callable}
     ```

4. **`V10Glossary` (`game/scripts/v10/clarity/glossary.gd`)**:
   - Зарегистрировать записи `V10DuelForms.GLOSSARY`.

## 5. Статус UX_RULES

`UX_RULES: P0 8/8, P1 12/12` — только токены `V10DS` (0 hex-литералов в UI), ≤ 4 кеглей (`≥ 18 px`), ровно 1 `primary` (`560×104` в нижней трети), ≤ 2 `secondary`, ≤ 2 `tertiary`, зоны нажатия `≥ 80 px`, `≤ 60` слов на экране, SFW-проверка нарядов на всех постерах (`G.ITEM[id].sfw`), 0 запрещённых жаргонизмов / `%` / `₽` / `ДР`, 0 сырых `Time.*`, 0 прямых мутаций `S.gems` / `G.add_aff`.