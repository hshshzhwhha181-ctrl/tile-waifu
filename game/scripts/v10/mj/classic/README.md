# Классика — Шанхай-пасьянс, Раскладка дня и Память (`v10/mj/classic`)

Основа: `docs/MODES.md` §4.1, §3, §5.5, §7.1; `docs/UX_RULES.md` §3–§6, §10; `docs/HUD_V2.md`.

## Файлы
| Файл | Класс | Назначение |
|---|---|---|
| `classic_info.gd` | `V10MjClassicInfo` | Карточка хаба `INFO` (`id: "classic"`, `shelf: "solitaire"`, `host: "mc"`, `gate: {level: 9}`), 3 строки `HOW` |
| `classic_save.gd` / `classic_data.gd` | `V10MjClassicSave`, `V10MjClassicData` | Идемпотентный сейв `v10_mj_classic`, звёзды, мастерство I–V, дата через `V10Meta` |
| `layouts.gd` | `V10MjClassicLayouts` | 22 объёмные раскладки (12 классических + 10 символов героинь, скрытие неоткрытых) |
| `classic_gen.gd` | `V10MjClassicGen` | Обратная укладка с сертификатом решаемости и полосами сложности |
| `classic_board.gd` | `V10MjClassicBoard` | 3D/плоский стол, зум/щипок, подсветка свободных, отмена, подсказка, автоперемешивание |
| `classic_lobby.gd` | `V10MjClassicLobby` | Экран режима («Свободная · Раскладка дня · Память»), «?» правила, «Играть» 560×104 |
| `classic_screen.gd` | `V10MjClassicScreen` | Экран партии Классики и Раскладки дня, `setup`/`build` + `finished(result)` |
| `memory.gd` | `V10MjClassicMemory` | Вариант «Память» 4×4…6×6 с гербами героинь |
| `classic_presence.gd` | `V10MjClassicPresence` | Лёгкое присутствие героини + интеграция с `V10MjPresence` |
| `ults_classic.gd` | `V10MjClassicUlts` | Приёмы 5 основательниц (MODES §5.5) |
| `classic_style.gd` | `V10MjClassicStyle` | Токены, алиасированные на `V10DS`, монолинейные иконки, кнопки с `ux_role` и хит-зонами ≥80 px |
| `classic_selftest.gd/.tscn` | — | Самотест `--mj_classic_selftest=1` |

## Самотест
```powershell
& $godot --headless --audio-driver Dummy --path game res://scripts/v10/mj/classic/classic_selftest.tscn -- --mj_classic_selftest=1
```
