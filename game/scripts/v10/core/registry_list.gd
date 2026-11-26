class_name V10RegistryList
extends RefCounted

# ONE line (one module() call) per 0.10 module — the only shared file of the module lanes (spec §2.8).
# Commands and markers: docs/INTEGRATION_0.10.md §0.3 / §2. "step" = the integration step that wires the module.
# Scenes are run by V10RegistryRunner (--v10_selftest=all|fast|<id,id>) as child processes.

static func register_all() -> void:
	var R: = V10Registry
	# one clock (spec §2.5, INTEGRATION §3.2): the wish clock reads V10Meta
	V10GClock.now_fn = V10Meta.now_unix
	# ── W1 ──────────────────────────────────────────────────────────────────────────────────────────────────────
	R.module("responsive", {"step": 1, "selftest": {"scene": "", "args": ["--layout_selftest=1", "--save=user://layout_shots_save.json", "--save_wipe=1"],
		"needs_render": true, "resolution": "1536x2048", "marker": "LAYOUT_SELFTEST"}})
	R.module("economy", {"step": 1, "selftest": {"scene": "res://scripts/v10/economy/econ_selftest.tscn", "args": ["--econ_selftest=1"],
		"fast_args": ["--econ_selftest=1", "--econ_mc=0.1"], "marker": "ECON_SELFTEST"},
		"migrator": func(S: Dictionary, now: int) -> void:
			if not (S.get("econ") is Dictionary) or (S.econ as Dictionary).is_empty():
				S["econ"] = V10Econ.from_legacy(S, now)})
	R.module("meta", {"step": 1, "selftest": {"scene": "res://scripts/v10/meta/meta_runner.tscn",
		"args": ["--meta_selftest=1", "--save=user://meta_runner.json", "--save_wipe=1"], "marker": "META_SELFTEST"},
		# 0.9 «Визиты» streak counter: the new Серия (rituals, W2) starts from zero (spec Р3)
		"migrator": func(S: Dictionary, _now: int) -> void: S["streak"] = 0})
	R.module("hud2", {"step": 1, "selftest": {"scene": "res://scripts/v10/hud2/hud2_demo.tscn", "args": ["--hud2_selftest=1"], "marker": "HUD2 SELFTEST"},
		"save": {"hero_combo": "full"}})
	R.module("fonts", {"step": 1, "selftest": {"scene": "res://scripts/v10/fonts/fonts_runner.tscn", "args": ["--fonts_selftest=1"], "marker": "FONTS SELFTEST"},
		"save": {"deco_fonts": true}})
	R.module("profile", {"step": 1, "selftest": {"scene": "res://scripts/v10/profile/profile2_selftest.tscn", "args": ["--profile2_selftest=1"],
		"marker": "PROFILE2_SELFTEST"},
		"save": {"v10_cos_owned": {}, "v10_feats": {"stats": {}, "done": {}}},
		# seed BEFORE ensure adds an empty v10_cos_seen: a veteran must not get dozens of «новое»
		"migrator": func(S: Dictionary, _now: int) -> void: V10ProfileCos.seed_seen(S, V10ProfileCos.ctx_from_save(S)),
		"ensure": func(S: Dictionary) -> void:
			if not (S.get("v10_cos_seen") is Dictionary):
				S["v10_cos_seen"] = {}})
	R.module("look", {"step": 1, "selftest": {"scene": "res://scripts/v10/look/look_runner.tscn", "args": ["--look_selftest=1"], "marker": "LOOK_SELFTEST"},
		"ensure": func(S: Dictionary) -> void: V10Look.migrate(S)})
	R.module("shop", {"step": 1, "selftest": {"scene": "res://scripts/v10/shop/shop_demo.tscn", "args": ["--shop_selftest=1"], "marker": "SHOP_SELFTEST"},
		"screens": {"shop": "res://scripts/v10/shop/shop2_screen.gd"},
		"save": {"v10_shop": V10ShopModel.defaults()}})
	R.module("auth", {"step": 1, "selftest": {"scene": "res://scripts/v10/auth/auth_dev.tscn",
		"args": ["--auth_selftest=1", "--save=user://auth_selftest_save.json", "--save_wipe=1"], "marker": "AUTH_SELFTEST"},
		"ensure": func(S: Dictionary) -> void: V10Auth.ensure(S)})
	R.module("clarity", {"step": 1, "selftest": {"scene": "res://scripts/v10/clarity/clarity_selftest.tscn", "args": [], "marker": "V10 CLARITY SELFTEST"},
		"ensure": func(S: Dictionary) -> void:
			if not (S.get("v10_clarity") is Dictionary):
				S["v10_clarity"] = {"marks": "auto", "big": false, "asked": false, "seen": {}, "tips": {}}})
	R.module("tutorial", {"step": 1, "selftest": {"scene": "res://scripts/v10/tutorial/tut_selftest.tscn",
		"args": ["--save=user://tut_test.json", "--save_wipe=1", "--tut_static=1"], "marker": "V10TUT", "static_only": true},
		# S.tut_done (0.9) becomes chapters.match1 only when the block is created: the module's own ensure does it
		"ensure": func(S: Dictionary) -> void: V10TutState.ensure(S)})
	R.module("juice", {"step": 1, "selftest": {"scene": "res://scripts/v10/juice/demo/juice_demo.tscn", "args": ["--juice_selftest=1"], "marker": "JUICE SELFTEST"},
		"save": {"a11y_calm": false}})
	# ── W2 ──────────────────────────────────────────────────────────────────────────────────────────────────────
	R.module("levels", {"step": 2, "selftest": {"scene": "res://scripts/v10/levels/levels_selftest.tscn", "args": ["--levels_selftest=1"],
		"fast_args": ["--levels_selftest=1", "--levels_n=200"], "marker": "LEVELS SELFTEST"},
		"migrator": func(S: Dictionary, _now: int) -> void: G.migrate_48_to_1000(S)})
	R.module("path", {"step": 2, "selftest": {"scene": "res://scripts/v10/path/path_demo.tscn", "args": ["--path_selftest=1"], "marker": "PATH SELFTEST"},
		"screens": {"v10path": "res://scripts/v10/path/path_map.gd"}, "nav": {"v10path": ["tables"]},
		"save": {"v10_levels": {}, "v10_boosters": {}},
		"ensure": func(S: Dictionary) -> void:
			var prev = V10PathState.root_override
			V10PathState.root_override = S
			V10PathState.st()
			V10PathBoosters.st()
			V10PathState.root_override = prev})
	R.module("salon", {"step": 2, "selftest": {"scene": "res://scripts/v10/salon/salon_runner.tscn", "args": ["--salon_selftest=1"], "marker": "SALON_SELFTEST"},
		"screens": {"v10salon": "res://scripts/v10/salon/salon_screen.gd", "v10scene": "res://scripts/v10/salon/zone_scene.gd"},
		"nav": {"v10salon": ["home"], "v10scene": ["v10salon"]},
		"save": {"v10_salon": V10Salon.defaults()},
		"ensure": func(S: Dictionary) -> void:
			V10Salon.ensure(S)
			V10Salon.notify_stars(0)})
	R.module("rituals", {"step": 2, "selftest": {"scene": "res://scripts/v10/rituals/rituals_runner.tscn",
		"args": ["--rit=selftest", "--save=user://rit_runner.json", "--save_wipe=1"], "marker": "RIT_SELFTEST"},
		"save": V10RitSave.defaults(),
		"ensure": func(S: Dictionary) -> void:
			var df: = V10RitSave.defaults()
			for k in df:
				if not (S.get(k) is Dictionary):
					S[k] = df[k].duplicate(true)})
	R.module("chat", {"step": 2, "selftest": {"script": "res://scripts/v10/chat/chat_selftest_cli.gd", "args": [], "marker": "CHAT SELFTEST"}})
	R.module("phone", {"step": 2, "selftest": {"scene": "res://scripts/v10/phone/phone_runner.tscn",
		"args": ["--save=user://phone_st.json", "--save_wipe=1", "--phone_selftest=1"], "needs_render": true, "resolution": "720x1280",
		"marker": "PHONE SELFTEST"},
		"save": {"v10_phone": V10Phone.default_state(), "v10_feed": V10ChatFeed.default_state()},
		"ensure": func(S: Dictionary) -> void:
			if is_same(S, G.S):
				V10Phone.ensure()
			else:
				if not (S.get("v10_phone") is Dictionary):
					S["v10_phone"] = V10Phone.default_state()
				if not (S.get("v10_feed") is Dictionary):
					S["v10_feed"] = V10ChatFeed.default_state()})
	if R.STEP >= 2:
		V10Rituals.install()
		V10Salon.grant_cb = func(rewards: Dictionary, src: String) -> void:
			var cur: = {}
			for k in rewards:
				var n: = int(rewards[k])
				if k in ["gems", "coins", "tickets", "petals"]:
					cur[k] = n
				elif k == "leaves":
					V10Streak.st().leaves = mini(V10Streak.LEAF_MAX, int(V10Streak.st().leaves) + n)
				elif k in ["hint", "shuffle", "undo"]:
					var inv: Dictionary = G.S.get("v10_items", {}) if G.S.get("v10_items") is Dictionary else {}
					var ik: String = str(k) + "s"
					inv[ik] = int(inv.get(ik, 0)) + n
					G.S["v10_items"] = inv
			if not cur.is_empty():
				V10Money.grant(cur, src)
		V10Salon.bond_cb = func(hero: String, n: int, src: String) -> void:
			V10Bond.gain(hero, n, src)
		V10Salon.letter_cb = func(hero: String, kind: String) -> void:
			V9Letters.queue(kind, {"hero": hero})
		V10Salon.day_cb = func() -> String:
			return V10Meta.day_key()
		V10Salon.level_cb = func() -> int:
			return V10PathState.current() + 1
		V10Salon.help_cb = func(topic: String) -> void:
			var tree: = Engine.get_main_loop() as SceneTree
			var main = tree.current_scene if tree else null
			if main != null:
				V10Clarity.open_glossary(main, topic)
	# ── W3 ──────────────────────────────────────────────────────────────────────────────────────────────────────
	R.module("gacha", {"step": 3, "selftest": {"scene": "res://scripts/v10/gacha/gacha_demo.tscn", "args": ["--gacha_selftest=1"],
		"fast_args": ["--gacha_selftest=1", "--mc=0.5"], "marker": "GACHA_SELFTEST"},
		"screens": {"summon": "res://scripts/v10/gacha/ui/wish_screen.gd", "odds": "res://scripts/v10/gacha/ui/odds_screen.gd"},
		"nav": {"odds": ["summon", "shop"]},
		"save": {"tickets": 0, "petals": 0, "candles": 0, "pity_std": 0, "s_pity_std": 0, "rates_ver": 2,
			"ostars": {}, "targets": {}, "mastery": {}, "first_pick": "", "first_pick_t": 0,
			"seven": {"days": [], "claimed": [false, false, false, false, false, false, false]}, "v10_gacha": {}},
		"migrator": func(S: Dictionary, _now: int) -> void:
			if int(S.get("ex", 0)) > 0:
				S["petals"] = int(S.get("petals", 0)) + int(S.ex)
				S["ex"] = 0
			if bool(S.get("free10", false)):
				S["tickets"] = int(S.get("tickets", 0)) + 10
				S["free10"] = false,
		"ensure": func(S: Dictionary) -> void:
			var bk: = V10GachaBank.new(S)
			if is_same(S, G.S):
				bk.live_money = true
				bk.give_fn = func(id: String) -> bool: return G.give_new(id)
			V10Gacha2.new(S, G.ITEMS, bk).ensure()})
	R.module("rig", {"step": 3, "selftest": {"scene": "res://scripts/v10/rig/rig_selftest.tscn", "args": [], "marker": "RIG_SELFTEST"}})
	R.module("voice", {"step": 3, "selftest": {"scene": "res://scripts/v10/voice/v10_voice_selftest.tscn", "args": [], "marker": "V10VOICE OK"}})
	if R.STEP >= 3:
		V10Salon.season_cb = func() -> bool:
			return G.econ != null and bool(G.econ.pass_.st.get("prem", false))
		var odds_sc = load("res://scripts/v10/gacha/ui/odds_screen.gd")
		if odds_sc:
			odds_sc.rub_ok_fn = func() -> bool:
				return maxi(0, int(G.S.get("unlocked", 1)) - 1) >= V10ShopData.SHOP_FROM_LEVEL and G.econ != null and V10ShopPay.cash_visible((G.econ as V10Econ).shop.provider)
			odds_sc.register("chest", func(_a: Dictionary) -> Array:
				return [
					{"name": "Сундук главы Пути", "text": "фиксированные кристаллы и монеты"},
					{"name": "Звёздный сундук главы", "text": "фиксированные кристаллы и Лепестки"},
					{"name": "Сундук зоны Салона", "text": "фиксированные награды зоны"},
					{"name": "Лестница возврата", "text": "фиксированные подарки по дням"},
				])
		var seven_fn: = func(_key: String) -> Array:
			if int(G.S.get("unlocked", 1)) < 4 and V10Seven.claimable(G.S).is_empty():
				return []
			var give_fn: = func(rw: Dictionary) -> void:
				var kd: = String(rw.get("kind", ""))
				if kd in ["tickets", "gems", "coins"]:
					V10Money.grant({kd: int(rw.get("n", 0))}, "seven")
				elif kd == "item":
					G.give_new(String(rw.get("id", "")))
				elif kd == "cos":
					V10ProfileCos.grant(G.S, String(rw.get("id", "")))
			var rows: = V10Seven.tray_items(G.S, give_fn)
			for c in rows:
				var ic: = String(c.get("icon", "ticket"))
				c["icon"] = V8Art.cur(ic) if ic in ["ticket", "gem", "coin"] else V8Art.icon("gift")
				c["rewards"] = {}
			return rows
		V10Tray.register("seven", seven_fn, 70)
		var month_fn: = func(_key: String) -> Dictionary:
			if G.econ == null or not G.econ.shop.month_can_claim():
				return {}
			var n: = int(V10Catalog.MONTH_DAILY.crystal)
			return {"icon": "res://assets/v10/shop/item_month.png", "title": "Лунный абонемент",
				"text": "+%d кристаллов" % n, "rewards": {},
				"claim": func() -> void:
					G.econ.shop.month_claim()
					V10Money.sync(G.S)}
		V10Tray.register("month_card", month_fn, 75)
	# ── W4 ──────────────────────────────────────────────────────────────────────────────────────────────────────
	R.module("audio", {"step": 4, "selftest": {"scene": "res://scripts/v10/audio/v10_audio_selftest.tscn", "args": [], "marker": "V10AUDIO"}})
	R.module("hudfx", {"step": 4, "selftest": {"scene": "res://scripts/v10/hudfx/hudfx_selftest.tscn", "args": ["--hudfx_selftest=1"], "marker": "HUDFX SELFTEST"}})
	R.module("tower", {"step": 4, "selftest": {"scene": "res://scripts/v10/tower/tower_selftest.tscn",
		"args": ["--tower_selftest=1"], "fast_args": ["--mods_selftest=1", "--pagoda_selftest=1", "--journey_selftest=1", "--tower_tables=1", "--tower_rules=1", "--tower_hygiene=1"],
		"marker": "TOWER_SELFTEST"},
		"screens": {
			"pagoda": "res://scripts/v10/tower/pagoda_screen.gd",
			"journey": "res://scripts/v10/tower/journey_screen.gd",
			"tower_play": "res://scripts/v10/tower/tower_play.gd",
		},
		"nav": {"pagoda": ["tables"], "journey": ["tables", "home"], "tower_play": ["pagoda", "journey"]},
		"save": {"v10_pagoda": V10Pagoda.DEFAULTS, "v10_journey": V10Journey.DEFAULTS},
		"ensure": func(_S: Dictionary) -> void:
			V10Pagoda.st()
			V10Journey.st()})
	R.module("mj_stage", {"step": 4, "selftest": {"scene": "res://scripts/v10/mj/stage/stage_selftest.tscn", "args": ["--mj_stage_selftest=1"], "marker": "MJ_STAGE"}})
	R.module("mj_look", {"step": 4, "selftest": {"scene": "res://scripts/v10/mj/look/look_selftest.tscn", "args": ["--mj_look_selftest=1"],
		"needs_render": true, "resolution": "720x1280", "marker": "MJ_LOOK"}})
	R.module("mj_triples", {"step": 4, "selftest": {"scene": "res://scripts/v10/mj/triples/triples_selftest.tscn", "args": ["--mj_triples_selftest=1"],
		"marker": "MJ_TRIPLES"},
		"screens": {"mj_triples": "res://scripts/v10/mj/triples/triples_screen.gd"},
		"nav": {"mj_triples": ["tables"]}})
	R.module("mj_riichi", {"step": 4, "selftest": {"scene": "res://scripts/v10/mj/riichi/riichi_selftest.tscn", "args": ["--mj_riichi_selftest=1"],
		"fast_args": ["--mj_riichi_selftest=1", "--games=20"], "marker": "MJ_RIICHI"},
		"screens": {"mj_riichi": "res://scripts/v10/mj/riichi/riichi_screen.gd"},
		"nav": {"mj_riichi": ["tables"]}})
	R.module("mj_sanma", {"step": 4, "selftest": {"scene": "res://scripts/v10/mj/sanma/sanma_selftest.tscn", "args": ["--mj_sanma_selftest=1"],
		"fast_args": ["--mj_sanma_selftest=1", "--games=20"], "marker": "MJ_SANMA"},
		"screens": {"mj_sanma": "res://scripts/v10/mj/sanma/sanma_screen.gd"},
		"nav": {"mj_sanma": ["tables"]}})
	R.module("mj_koikoi", {"step": 4, "selftest": {"scene": "res://scripts/v10/mj/koikoi/koikoi_selftest.tscn", "args": ["--mj_koikoi_selftest=1"],
		"fast_args": ["--mj_koikoi_selftest=1", "--games=100"], "marker": "MJ_KOIKOI"},
		"screens": {"mj_koikoi": "res://scripts/v10/mj/koikoi/koikoi_screen.gd"},
		"nav": {"mj_koikoi": ["tables"]}})
	R.module("mj_classic", {"step": 4, "selftest": {"scene": "res://scripts/v10/mj/classic/classic_selftest.tscn", "args": ["--mj_classic_selftest=1"],
		"marker": "MJ_CLASSIC"},
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
	R.module("palm", {"step": 4, "selftest": {"scene": "res://scripts/v10/palm/hand_selftest.tscn", "args": ["--hand_selftest=1"],
		"fast_args": ["--hand_selftest=1", "--hand_real=24"], "marker": "HAND_SELFTEST"},
		"screens": {"hand": V10PalmInfo.SCREEN_PATH},
		"nav": {"hand": ["tables"]},
		"save": {"v10_hand": V10HandState.defaults()},
		"ensure": func(_S: Dictionary) -> void:
			V10HandState.st()
			V10HandState.register_cos()})
	R.module("duels", {"step": 4, "selftest": {"scene": "res://scripts/v10/duels/duel_selftest.tscn",
		"args": ["--duel_selftest=1", "--save=user://duel_selftest.json", "--save_wipe=1"], "marker": "DUEL_SELFTEST"},
		"screens": {"duels": V10DuelInfo.SCREEN_PATH, "duel2": V10DuelInfo.PLAY_PATH},
		"nav": {"duels": ["tables"], "duel2": ["duels"]},
		"ensure": func(_S: Dictionary) -> void:
			V10Duel.st()
			V10DuelRank.register_cos()})
	R.module("challenge", {"step": 4, "selftest": {"scene": "res://scripts/v10/duels/challenge/challenge_selftest.tscn",
		"args": ["--challenge_selftest=1", "--save=user://ch_selftest.json", "--save_wipe=1"],
		"marker": "CHALLENGE_SELFTEST"},
		"screens": {"challenge": V10DuelInfo.CHALLENGE_PATH, "challenge_play": V10DuelInfo.CHALLENGE_PLAY_PATH},
		"nav": {"challenge": ["tables"], "challenge_play": ["challenge"]},
		"ensure": func(_S: Dictionary) -> void: V10ChallengeState.st()})
	R.module("wave1", {"step": 4, "selftest": {"scene": "res://scripts/v10/wave1/wave1_selftest.tscn",
		"args": ["--wave1_selftest=1"], "marker": "WAVE1_SELFTEST"}})
	V10AdventureReg.register()
	if R.STEP >= 4:
		V10Afisha.set_provider("hand", func() -> bool: return bool(V10PalmInfo.afisha_entry().done))
		for cdef in V10Pagoda.cos_defs():
			if not V10ProfileCos.has(String(cdef.get("id", "")), ""):
				V10ProfileCos.register(cdef)
