# Mahjong Core — W4 Integration Hooks (`classic`, `connect`, `cube`, `garden`, `bridge`)

Этот документ описывает точные точки подключения 5 завершённых режимов дорожки `mj-modes` для интегратора **Step W4** (`registry_list.gd`, `tables_hub.gd`, `afisha.gd`, `glossary.gd`, выплата наград `finished(result)`), не редактируя общие горячие файлы в ветке `lane/mj-modes`.

---

## 1. Строки регистрации в `game/scripts/v10/core/registry_list.gd`

В `V10RegistryList.register_all()` в секцию `# ── W4 ──` (после `mj_triples` / `mj_koikoi`) добавить по одной строке `R.module(...)` на каждый из 5 модулей:

```gdscript
	R.module("mj_classic", {"step": 4, "selftest": {"scene": "res://scripts/v10/mj/classic/classic_selftest.tscn", "args": ["--mj_classic_selftest=1"],
		"fast_args": ["--mj_classic_selftest=1"], "marker": "MJ_CLASSIC"},
		"save": {"v10_mj_classic": V10MjClassicSave.DEFAULTS},
		"ensure": func(S: Dictionary) -> void: V10MjClassicSave.ensure(S),
		"screens": {
			"mj_classic_lobby": "res://scripts/v10/mj/classic/classic_lobby.gd",
			"mj_classic": "res://scripts/v10/mj/classic/classic_screen.gd",
			"mj_memory": "res://scripts/v10/mj/classic/memory.gd",
		},
		"nav": {"mj_classic_lobby": ["tables"], "mj_classic": ["mj_classic_lobby", "tables"], "mj_memory": ["mj_classic_lobby", "tables"]}})
	R.module("mj_connect", {"step": 4, "selftest": {"scene": "res://scripts/v10/mj/connect/connect_selftest.tscn", "args": ["--mj_connect_selftest=1"],
		"marker": "MJ_CONNECT"},
		"save": {"v10_mj_connect": V10MjConnectSave.DEFAULTS},
		"ensure": func(S: Dictionary) -> void: V10MjConnectSave.ensure(S),
		"screens": {"mj_connect": "res://scripts/v10/mj/connect/connect_screen.gd"},
		"nav": {"mj_connect": ["tables"]}})
	R.module("mj_cube", {"step": 4, "selftest": {"scene": "res://scripts/v10/mj/cube/cube_selftest.tscn", "args": ["--mj_cube_selftest=1"],
		"marker": "MJ_CUBE"},
		"save": {"v10_mj_cube": V10MjCubeSave.DEFAULTS},
		"ensure": func(S: Dictionary) -> void: V10MjCubeSave.ensure(S),
		"screens": {"mj_cube": "res://scripts/v10/mj/cube/cube_screen.gd"},
		"nav": {"mj_cube": ["tables"]}})
	R.module("mj_garden", {"step": 4, "selftest": {"scene": "res://scripts/v10/mj/garden/garden_selftest.tscn", "args": ["--mj_garden_selftest=1"],
		"marker": "MJ_GARDEN"},
		"save": {"v10_mj_garden": V10MjGardenSave.DEFAULTS},
		"ensure": func(S: Dictionary) -> void: V10MjGardenSave.ensure(S),
		"screens": {"mj_garden": "res://scripts/v10/mj/garden/garden_screen.gd"},
		"nav": {"mj_garden": ["tables"]}})
	R.module("mj_bridge", {"step": 4, "selftest": {"scene": "res://scripts/v10/mj/bridge/bridge_selftest.tscn", "args": ["--mj_bridge_selftest=1"],
		"marker": "MJ_BRIDGE"},
		"save": {"v10_mj_bridge": V10MjBridgeSave.DEFAULTS},
		"ensure": func(S: Dictionary) -> void: V10MjBridgeSave.ensure(S),
		"screens": {
			"mj_bridge": "res://scripts/v10/mj/bridge/bridge_screen.gd",
			"mj_bridge_daily": "res://scripts/v10/mj/bridge/bridge_daily_screen.gd",
			"mj_bridge_hand": "res://scripts/v10/mj/bridge/bridge_hand_screen.gd",
		},
		"nav": {"mj_bridge": ["tables"], "mj_bridge_daily": ["tables"], "mj_bridge_hand": ["tables"]}})
```

Все переходы укладываются в бюджет глубины ≤ 2 от вкладки «Столы» (`tables` → `mj_classic_lobby` → `mj_classic`, остальные — глубина 1).

---

## 2. Полки и врата в `game/scripts/v10/core/tables_hub.gd` (`docs/MODES.md §6, §7.1`)

Все 5 модулей предоставляют `*_info.gd` без побочных эффектов, загружаемые через `ResourceLoader.exists(...)`:

| Модуль | Класс `*_info.gd` | `id` | `title` / `name` | `shelf` | `host` | Врата (`gate`) | Экран (`screen`) |
|---|---|---|---|---|---|---|---|
| `classic` | `V10MjClassicInfo.INFO` | `"classic"` | «Классика» | `"solitaire"` | `"mc"` | `{"level": 10}` | `classic_lobby.gd` → `classic_screen.gd` / `memory.gd` |
| `connect` | `V10MjConnectInfo.INFO` | `"connect"` | «Связи» | `"solitaire"` | `"rin"` | `{"level": 18}` | `connect_screen.gd` |
| `cube` | `V10MjCubeInfo.INFO` | `"cube"` | «Куб» | `"solitaire"` | `"nova"` | `{"level": 40}` | `cube_screen.gd` |
| `garden` | `V10MjGardenInfo.INFO` | `"garden"` | «Сад» | `"solitaire"` | `"yue"` | `{"rank": [1, 0], "title": "Нефрит I"}` (заменяет `"zen"`) | `garden_screen.gd` (карточка полки: `garden_card.gd`) |
| `bridge` (1) | `V10MjBridgeInfo.INFO` | `"bridge_daily"` | «Задача дня» | `"trials"` (`"today_row": true`) | `"mc"` | `{"level": 22}` | `bridge_daily_screen.gd` |
| `bridge` (2) | `V10MjBridgeInfo.INFO_HAND` | `"bridge_hand"` | «Собери руку» | `"table"` | `"hana"` | `{"level": 26}` | `bridge_hand_screen.gd` |

### Сниппет сборки полок в `tables_hub.gd`

```gdscript
const MJ_INFOS: = [
	"res://scripts/v10/mj/classic/classic_info.gd",
	"res://scripts/v10/mj/triples/triples_info.gd",
	"res://scripts/v10/mj/connect/connect_info.gd",
	"res://scripts/v10/mj/cube/cube_info.gd",
	"res://scripts/v10/mj/garden/garden_info.gd",
	"res://scripts/v10/mj/bridge/bridge_info.gd",
	"res://scripts/v10/mj/riichi/riichi_info.gd",
	"res://scripts/v10/mj/sanma/sanma_info.gd",
	"res://scripts/v10/mj/koikoi/koikoi_info.gd",
]

static func collect_mj_cards() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p in MJ_INFOS:
		if not ResourceLoader.exists(p):
			continue
		var cls = load(p)
		if cls == null:
			continue
		if "CARDS" in cls:
			for c in cls.CARDS:
				out.append(c)
		elif "INFO" in cls:
			out.append(cls.INFO)
	return out
```

- **Полка «Пасьянсы» (`shelf == "solitaire"`)**: `classic` (L10), `triples` (L14), `connect` (L18), `garden` (Нефрит I, скрывает старый `"zen"` по `INFO.replaces == "zen"`), `cube` (L40). Правило P0-8 сохраняется: все открытые + максимум 1 тизер следующего закрытого режима.
- **Полка «За столом» (`shelf == "table"`)**: `bridge_hand` (L26), `koikoi`, `riichi` (открывается на L30 **или** досрочно при `V10MjBridgeSave.st(G.S).riichi_open == true` после 3 решённых «Задач дня»!), `sanma`.
- **Полоса «Сегодня» (`today_row == true` / `V10Afisha`)**:
  - При `unlocked >= 22` карточка `bridge_daily` («Задача дня», `done = V10MjBridgeSave.answered(V10MjBridgeSave.st(G.S), V10Meta.cal_key())`) добавляется в блок «Сегодня» и `V10Afisha`.
  - Ежедневная раскладка Классики доступна через `main.go("mj_classic", {"daily": true, "day": V10Meta.day_key()})`.

---

## 3. Контракт запуска экрана и выплата `finished(result)` (`MODES.md §7.1`)

Все 5 экранов поддерживают как `setup(main, opts)`, так и `build(main, opts)`, принимают необязательные `opts.presence` (`V10MjPresence`) и `opts.look` (`V10Look` / `V10MjTables`), **никогда сами не начисляют валюты и симпатию**, и испускают сигнал `finished(result: Dictionary)` со всеми 10 обязательными ключами:

```gdscript
# result: {mode, win, score, stars, time_s, pairs, hero, seed, level, rewards: {coins, gems, petals, aff}, ...}
func _on_mj_mode_finished(main, res: Dictionary) -> void:
	var rw: Dictionary = res.get("rewards", {})
	var reason: = "mj_" + String(res.get("mode", "mode"))
	if int(rw.get("coins", 0)) > 0:
		V10Money.add_coins(G.S, int(rw.coins), reason)
	if int(rw.get("gems", 0)) > 0:
		V10Money.add_gems(G.S, int(rw.gems), reason)
	if int(rw.get("petals", 0)) > 0:
		V10Money.add_petals(G.S, int(rw.petals), reason)
	if int(rw.get("aff", 0)) > 0 and String(res.get("hero", "")) != "":
		V10Bond.add_aff(G.S, String(res.hero), int(rw.aff), reason)
	# События Салона (например, «Чайный куст» каждые 10 волн Сада или звёзды Салона Связей):
	for ev in res.get("events", []):
		if ClassDB.class_exists("V10Hooks") or ResourceLoader.exists("res://scripts/v10/core/hooks.gd"):
			V10Hooks.emit_salon_event(G.S, ev)
	G.save()
	var act: = String(res.get("action", "exit"))
	if act == "next":
		main.go("mj_" + String(res.mode), {"level": int(res.get("level", 1)) + 1, "hero": String(res.get("hero", ""))})
	elif act == "again" or act == "retry":
		main.go("mj_" + String(res.mode), {"level": int(res.get("level", 1)), "hero": String(res.get("hero", ""))})
	else:
		main.go("tables", {})
```

---

## 4. Косметика профиля и Словарь (`V10ProfileCos`, `V10Glossary`)

- **Реликвии Куба (`V10MjCubeSave.showcase(V10MjCubeSave.st(G.S))`)**: массив из 5 реликвий глав (`mc`, `rin`, `hana`, `yue`, `nova` на уровнях 8, 16, 24, 32, 40) для витрины Профиля.
- **Подарки мастерства Связей (`V10MjConnectSave.st(G.S).gifts`)**: 5 памятных нитей/подарков за ранги Мастерства I–V.
- **Веер-календарь Моста (`V10MjBridgeSave.st(G.S).fans`)**: закрытые месяцы `"YYYY-MM"` открывают памятный кадр хозяйки месяца (`V10MjBridgeSave.month_host(month)`).
- **Словарь (`V10Glossary`)**: статьи `V10MjBridgeInfo.GLOSSARY` (`combo.tanyao`, `combo.sanankou`, `combo.ittsu`, `combo.chinitsu`, `bridge.daily`, `bridge.hand`) уже отформатированы под лимиты `V10Glossary` (`name ≤ 26`, `why ≤ 74`, `how ≤ 92`).
