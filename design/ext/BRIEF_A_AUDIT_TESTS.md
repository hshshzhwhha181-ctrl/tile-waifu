# Бриф A — независимый аудит и усиление тестов (для внешней модели)
Цель: второй, независимый взгляд на новое ядро Tile Waifu. Ничего не «улучшать» вне скоупа.
Репозиторий: ветка `claude/integration` (Godot 4.5, headless). Скоуп: `game/core/*` (TWState, TWSave, TWMigrate, TWClock, TWRng, TWFree, TWBoard), `game/shell/*` (TWScreens, TWContext, TWBus, ModalStack, TWAssets), `tools/tw_test.py`.
Запуск тестов: `python3 tools/tw_test.py --fast` (бинарь Godot 4.5.1; exit code 134 на teardown — известная проблема, игнорировать, если все тесты зелёные).
Задачи:
1. Найти баги корректности: детерминизм ядра (никаких обращений к времени/рандому/узлам внутри `game/core`), миграции сейва (TWMigrate: потеря полей, повторное применение, порядок), утечки модалок (ModalStack), гонки событий в TWBus.
2. Для каждой найденной проблемы — минимальный воспроизводящий тест в `tests/` (по конвенциям репозитория) + исправление отдельным коммитом. Не ломать зелёные тесты.
3. Property/fuzz-тесты: TWBoard (решаемость, сертификаты), TWSave round-trip (случайные сейвы v1..vN → миграция → валидность).
4. Отчёт `design/ext/REPORT_A.md`: список находок (BLOCKER/MAJOR/MINOR), что исправлено, что нет.
Границы: ветка `claude/ext-a` от `claude/integration`; не трогать `gh-pages`, `project.godot`, `export_presets.cfg`, `assets/`. Без PR. Коммит-сообщения на английском. Не добавлять текст/логотипы в арт; арт вообще не трогать.
