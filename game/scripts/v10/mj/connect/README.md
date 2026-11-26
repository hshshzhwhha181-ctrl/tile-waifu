# Связи (Шисэн-сё) — пары линией ≤ 2 поворотов, 90 уровней (`v10/mj/connect`)

Основа: `docs/MODES.md` §4.3, §3, §5.5, §7.1; `docs/UX_RULES.md` §3–§6, §10; `docs/HUD_V2.md`.

## Файлы
| Файл | Класс | Назначение |
|---|---|---|
| `connect_info.gd` | `V10MjConnectInfo` | Карточка хаба `INFO` (`id: "connect"`, `shelf: "solitaire"`, `host: "rin"`, `gate: {level: 18}`), 3 строки `HOW` |
| `connect_save.gd` | `V10MjConnectSave` | Идемпотентный сейв `v10_mj_connect`, звёзды, мастерство «Знак Связей» I–V, награды |
| `path.gd` | `V10MjConnectPath` | Поиск пути ≤ 2 поворотов по полю и пустой рамке + быстрый скан и оракул |
| `connect_board.gd` | `V10MjConnectBoard` | Модель стола (`static`, `rain` — Ливень, `shift` — Сдвиг, препятствия сетка/лёд, отмена, перемешивание с гарантией) |
| `connect_gen.gd` | `V10MjConnectGen` | 90 уровней (9 глав × 10), обратная укладка с сертификатом решаемости, казуальный бот |
| `connect_look.gd` | `V10MjConnectLook` | Токены `V10DS`, нити героинь (шёлк Рин, сакура МТ, трек Ханы, луч Юэ, неон Новы) |
| `connect_icon.gd` | `V10MjConnectIcon` | Монолинейные иконки кодом |
| `connect_sound.gd` | `V10MjConnectSound` | ASMR нити и пар через `V10MjAsmr` + вибрация |
| `connect_presence.gd` | `V10MjConnectPresence` | Лёгкое присутствие героини + совместимость с `V10MjPresence` |
| `ults_connect.gd` | `V10MjConnectUlts` | Приёмы 5 основательниц (MODES §5.5) |
| `connect_screen.gd` | `V10MjConnectScreen` | Экран партии, анимация нити и сдвигов, листы старта/помощи «?»/паузы/итога |
| `connect_demo.gd/.tscn` | — | Демо-сцена и снимки |
| `connect_selftest.gd/.tscn` | — | Самотест `--mj_connect_selftest=1` |

## Самотест
```powershell
& $godot --headless --audio-driver Dummy --path game res://scripts/v10/mj/connect/connect_selftest.tscn -- --mj_connect_selftest=1
```
