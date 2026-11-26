# Чтение руки (`v10/palm`)

Ежедневный режим дедукции ожидания руки риичи-маджонга («Партия дня · Чтение руки» и «Столы → За столом») и интерактивный практикум из 7 разборов «Разбор ожиданий» (`docs/0.10-spec.md` R4, `docs/MODES.md` §7.1, `docs/UX_RULES.md`).

## Состав модуля

| Файл | Класс | Назначение |
| --- | --- | --- |
| `hand_info.gd` | `V10PalmInfo` | Паспорт режима `INFO`, `LESSONS_INFO`, `HOW`, `afisha_entry()` для W4 (`tables_hub.gd` и `V10Afisha`) |
| `hand_screen.gd` | `V10PalmScreen` | Экран режима и практикума (`setup`/`build`, сигнал `finished(result)`, шторка 34 видов, подтверждение, вердикт, разборы, шторка «?») |
| `hand_board.gd` | `V10HandBoard` | Подкласс `TrayBoard` на 5 слотов с плановой раздачей пар и 34 лицами риичи (`assets/v10/palm/faces/f00..f33.png`) |
| `hand.gd` | `V10Hand` | Сессия руки дня (`today()`, `reveal()`, `shutter()`, `guess()`, `candidates()`, `share_text()`) |
| `hand_gen.gd` | `V10HandGen` | Детерминированный генератор руки, доказательство единственности чтения и модель раскладки (`data/hands.json`, 365 дней) |
| `hand_lessons.gd` | `V10HandLessons` | «Разбор ожиданий»: 7 разборов по 3 руки (включая разбор «Рукав») без школьной тематики |
| `hand_state.gd` | `V10HandState` | Ключ сохранения `S.v10_hand`, расписание по `V10Meta.day_key()`, награды и рамка/титул `fr_palm` / `t_palm` |
| `hand_text.gd` | `V10HandText` | Все видимые строки, реплики героинь и записи `V10Glossary` |
| `hand_util.gd` | `V10HandUtil` | Мосты к `V10Meta`, `V10Money`, `V10Bond`, `V10ProfileCos` и `V10Lint` |
| `hand_selftest.gd` / `.tscn` | — | Полный самотест данных (365 дней), единственности чтения, доски, экономики и UX-бюджетов |

## Экономика и правила (§2.3, R4)

- **Одна догадка в сутки** по `V10Meta.day_key()` (смена суток в `04:00` локального времени; откат часов назад не открывает сыгранный день повторно).
- **Кристаллы (`V10Money.grant`)**: верная догадка — **10 / 20 / 30** кристаллов при смелости **×1 / ×2 / ×3** (`<4` / `4–6` / `≥7` закрытых карт); промах — **5** кристаллов. Потолок модуля — 30 кристаллов в день.
- **Симпатия (`V10Bond.gain`)**: **+2** героине дня (мягкий источник).
- **Косметика (`V10ProfileCos`)**: за 30 верных догадок выдаются рамка **«Читающая руки»** (`fr_palm`) и титул **«Читающий руки»** (`t_palm`).
- **Спойлеры**: `share_text()` копируется только по нажатию «Поделиться» и никогда не называет фишку или форму ожидания.

## Как запустить самотест

```powershell
Set-Location "C:\Users\ADMIN\.gemini\antigravity\scratch\tw-worktrees\duels-palm"
$env:APPDATA = "C:\Users\ADMIN\.gemini\antigravity\scratch\tw-appdata\duels-palm"
& "C:\Users\ADMIN\.gemini\antigravity\scratch\tw-tools\godot\Godot_v4.5.1-stable_win64_console.exe" --headless --path game res://scripts/v10/palm/hand_selftest.tscn -- --hand_selftest=1
```
Ожидаемый маркер: `HAND_SELFTEST 163/163` (`data 16/16`, `unique 3/3`, `board 8/8`, `dim 4/4`, `mult 5/5`, `day 17/17`, `state 27/27`, `text 17/17`, `lessons 5/5`, `misc 7/7`, `ui 54/54`).

## Хуки интеграции для Шага W4

1. **`game/scripts/v10/core/registry_list.gd`** (`register_all()`, секция `# ── W4 ──`):
   ```gdscript
   R.module("palm", {
       "step": 4,
       "selftest": {"scene": "res://scripts/v10/palm/hand_selftest.tscn", "args": ["--hand_selftest=1"],
           "fast_args": ["--hand_selftest=1", "--hand_real=24"], "marker": "HAND_SELFTEST"},
       "screens": {"hand": V10PalmInfo.SCREEN_PATH},
       "nav": {"hand": ["tables"]},
       "save": {"v10_hand": V10HandState.defaults()},
       "ensure": func(_S: Dictionary) -> void:
           V10HandState.st()
           V10HandState.register_cos(),
   })
   ```

2. **`game/scripts/v10/core/tables_hub.gd`** (полка **«За столом»**):
   - Добавить карточки `V10PalmInfo.INFO` (`main.go("hand")`, открыто с 30-го уровня: `V10HandState.is_open()`, замок: `V10HandState.lock_text()`) и `V10PalmInfo.LESSONS_INFO` (`main.go("hand", {"view": "lessons"})`, прогресс: `V10PalmInfo.lessons_progress_text()`).

3. **`game/scripts/v10/meta/afisha.gd`** (провайдер вкладки «Партия дня → Чтение руки»):
   ```gdscript
   V10Afisha.set_provider("hand", func() -> bool: return bool(V10PalmInfo.afisha_entry().done))
   ```
   (Экран `V10PalmScreen` при фиксации догадки также вызывает `V10Afisha.on_game_ended({"mode": "hand", "win": right})`.)

4. **`V10Glossary` (`game/scripts/v10/clarity/glossary.gd`)** и **`V10EntryQueue`**:
   - Добавить записи `V10HandState.glossary()` в каталог глоссария.
   - На 30-м уровне зарегистрировать одноразовый анонс `V10HandState.intro_key()` с репликой `V10HandState.intro_line(hero)`.

## Статус UX_RULES

`UX_RULES: P0 8/8, P1 12/12` — палитра только из `V10DS` (0 hex-цветов), ≤ 4 кеглей (`≥ 18 px`), ровно 1 `primary` (`560×104` в нижней трети), ≤ 2 `secondary`, ≤ 2 `tertiary`, зоны нажатия `≥ 80 px`, глубина шторок `≤ 2` (подтверждение в том же `V10BottomSheet`), в списке разборов не более 1 закрытого замка подряд, 0 сырых `Time.*` и 0 прямых записей в `S.gems`.